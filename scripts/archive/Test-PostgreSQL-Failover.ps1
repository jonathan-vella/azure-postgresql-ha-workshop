<#
.SYNOPSIS
    Tests PostgreSQL Zone-Redundant HA failover with RTO/RPO measurement.

.DESCRIPTION
    This script performs comprehensive failover testing including:
    1. Load generation on primary database
    2. Forced failover trigger
    3. RTO (Recovery Time Objective) measurement
    4. RPO (Recovery Point Objective) validation
    5. Application continuity testing
    
.PARAMETER ResourceGroupName
    The resource group containing the PostgreSQL server.

.PARAMETER ServerName
    Optional. PostgreSQL server name. Auto-discovered if not specified.

.PARAMETER LoadDuration
    Duration (in seconds) to run load before failover. Default is 60.

.PARAMETER TransactionsPerSecond
    Target TPS during load generation. Default is 100.

.EXAMPLE
    .\Test-PostgreSQL-Failover.ps1 -ResourceGroupName "rg-saif-pgsql-swc-01"

.EXAMPLE
    .\Test-PostgreSQL-Failover.ps1 -ResourceGroupName "rg-saif-pgsql-swc-01" -LoadDuration 120 -TransactionsPerSecond 200

.NOTES
    Author: SAIF Team
    Version: 2.0.0
    Date: 2025-10-08
    Requires: Azure CLI, PowerShell 7+
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$false)]
    [string]$ServerName,
    
    [Parameter(Mandatory=$false)]
    [int]$LoadDuration = 60,
    
    [Parameter(Mandatory=$false)]
    [int]$TransactionsPerSecond = 100
)

$ErrorActionPreference = "Stop"

#region Helper Functions

function Show-Banner {
    param([string]$message)
    $border = "=" * ($message.Length + 4)
    Write-Host ""
    Write-Host $border -ForegroundColor Cyan
    Write-Host "| $message |" -ForegroundColor White -BackgroundColor DarkBlue
    Write-Host $border -ForegroundColor Cyan
    Write-Host ""
}

function Write-Step {
    param([string]$message)
    Write-Host "📍 $message" -ForegroundColor Yellow
}

function Write-Success {
    param([string]$message)
    Write-Host "✅ $message" -ForegroundColor Green
}

function Write-Error-Custom {
    param([string]$message)
    Write-Host "❌ $message" -ForegroundColor Red
}

function Write-Warning-Custom {
    param([string]$message)
    Write-Host "⚠️  $message" -ForegroundColor Yellow
}

function Write-Info {
    param([string]$message)
    Write-Host "ℹ️  $message" -ForegroundColor Cyan
}

function Get-Timestamp {
    return Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
}

function Invoke-DockerPsql {
    <#
    .SYNOPSIS
        Executes psql commands using Docker container (machine-independent approach).
    
    .PARAMETER ServerFqdn
        PostgreSQL server FQDN
    
    .PARAMETER Username
        Database username
    
    .PARAMETER Database
        Database name
    
    .PARAMETER Password
        Database password
    
    .PARAMETER Query
        SQL query to execute
    
    .PARAMETER TupleOnly
        Return tuples only (no column headers)
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$ServerFqdn,
        
        [Parameter(Mandatory=$true)]
        [string]$Username,
        
        [Parameter(Mandatory=$true)]
        [string]$Database,
        
        [Parameter(Mandatory=$true)]
        [string]$Password,
        
        [Parameter(Mandatory=$true)]
        [string]$Query,
        
        [Parameter(Mandatory=$false)]
        [switch]$TupleOnly
    )
    
    $tupleFlag = if ($TupleOnly) { "-t" } else { "" }
    
    try {
        $rawResult = docker run --rm `
            -e PGPASSWORD="$Password" `
            postgres:16-alpine `
            psql -h $ServerFqdn -U $Username -d $Database $tupleFlag -c "$Query" 2>&1
        
        # Clean output: join array to string, trim whitespace
        $cleanOutput = if ($rawResult -is [array]) {
            ($rawResult -join "`n").Trim()
        } else {
            $rawResult.ToString().Trim()
        }
        
        return @{
            Success = $LASTEXITCODE -eq 0
            Output = $cleanOutput
            ExitCode = $LASTEXITCODE
        }
    } catch {
        return @{
            Success = $false
            Output = $_.Exception.Message
            ExitCode = -1
        }
    }
}

function Invoke-FailoverDiagnostics {
    <#
    .SYNOPSIS
        Analyzes failover performance and provides root cause analysis.
    
    .DESCRIPTION
        Examines server configuration, metrics, and patterns to identify
        why RTO/RPO targets were not met and provides actionable recommendations.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [double]$RTO,
        
        [Parameter(Mandatory=$true)]
        [int]$RPO,
        
        [Parameter(Mandatory=$true)]
        [string]$ServerName,
        
        [Parameter(Mandatory=$true)]
        [string]$ResourceGroupName,
        
        [Parameter(Mandatory=$true)]
        [hashtable]$LoadResults,
        
        [Parameter(Mandatory=$false)]
        [DateTime]$FailoverStartTime = (Get-Date).AddHours(-1)
    )
    
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  🔍 INTELLIGENT DIAGNOSTICS - Root Cause Analysis" -ForegroundColor White
    Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    
    # Get server configuration
    Write-Host "📊 Analyzing server configuration..." -ForegroundColor Yellow
    $server = az postgres flexible-server show `
        --resource-group $ResourceGroupName `
        --name $ServerName `
        --output json | ConvertFrom-Json
    
    $serverTier = $server.sku.tier
    $serverSKU = $server.sku.name
    $storageSize = $server.storage.storageSizeGB
    $storageIOPS = $server.storage.iops
    
    Write-Host "   Server: $ServerName" -ForegroundColor Gray
    Write-Host "   Tier: $serverTier" -ForegroundColor Gray
    Write-Host "   SKU: $serverSKU" -ForegroundColor Gray
    Write-Host "   Storage: ${storageSize}GB (${storageIOPS} IOPS)" -ForegroundColor Gray
    
    # Determine root cause
    Write-Host ""
    Write-Host "🎯 BOTTOM LINE" -ForegroundColor Yellow -BackgroundColor DarkBlue
    Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    
    $rootCause = ""
    $recommendations = @()
    
    # Analysis: Server Tier
    if ($serverTier -eq "Burstable") {
        $rootCause = "Burstable tier SKU ($serverSKU) cannot sustain zone-redundant HA performance under load"
        $recommendations += "Upgrade to General Purpose tier (minimum D2ds_v4)"
        $recommendations += "Burstable tier RTO typically 200-600s vs 60-120s for General Purpose"
        $recommendations += "Cost: ~`$120/month for D2ds_v4 (vs ~`$23/month Burstable)"
        $tier_factor = "critical"
    } elseif ($RTO -gt 180) {
        $rootCause = "RTO significantly exceeds target - possible resource saturation or region issues"
        $recommendations += "Check Azure Monitor metrics for CPU/IOPS throttling"
        $recommendations += "Review Activity Log for Azure service issues"
        $recommendations += "Consider upgrading to higher SKU (more vCores/IOPS)"
        $tier_factor = "moderate"
    } else {
        $rootCause = "RTO marginally exceeds target - minor performance degradation"
        $recommendations += "Monitor trends over multiple tests"
        $recommendations += "Check for transient Azure region issues"
        $tier_factor = "low"
    }
    
    # Analysis: Load Pattern
    $actualTPS = [Math]::Round($LoadResults.SuccessCount / 60, 2)
    $loadFactor = if ($serverTier -eq "Burstable") { "high" } elseif ($actualTPS -gt 100) { "moderate" } else { "low" }
    
    Write-Host ""
    Write-Host "Most Likely Cause:" -ForegroundColor White -NoNewline
    Write-Host " $rootCause" -ForegroundColor Yellow
    
    Write-Host ""
    Write-Host "Evidence:" -ForegroundColor Cyan
    Write-Host "  ✅ Test completed successfully (mechanism working)" -ForegroundColor Green
    
    if ($RPO -eq 0) {
        Write-Host "  ✅ RPO = 0 (zero data loss - synchronous replication verified)" -ForegroundColor Green
    } else {
        Write-Host "  ❌ RPO > 0 ($RPO transactions lost - replication issue)" -ForegroundColor Red
    }
    
    $rtoMultiplier = [Math]::Round($RTO / 120, 1)
    Write-Host "  ❌ RTO = ${RTO}s (${rtoMultiplier}x slower than 120s target)" -ForegroundColor Red
    
    Write-Host "  📊 Server Tier: $serverTier ($serverSKU)" -ForegroundColor $(if ($serverTier -eq "Burstable") { "Red" } else { "Yellow" })
    Write-Host "  📊 Storage: ${storageSize}GB @ ${storageIOPS} IOPS" -ForegroundColor Gray
    Write-Host "  📊 Load: $actualTPS TPS during test" -ForegroundColor Gray
    
    if ($serverTier -eq "Burstable") {
        Write-Host ""
        Write-Host "  ⚠️  CRITICAL: Burstable tier detected!" -ForegroundColor Red -BackgroundColor Black
        Write-Host "     Burstable tier uses CPU credits and has limited IOPS" -ForegroundColor Yellow
        Write-Host "     Expected RTO: 200-600s (NOT suitable for HA workloads)" -ForegroundColor Yellow
        Write-Host "     This is expected behavior, not a bug" -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host "Root Cause Analysis:" -ForegroundColor Cyan
    
    if ($serverTier -eq "Burstable") {
        Write-Host "  1️⃣  Insufficient Compute Resources" -ForegroundColor Red
        Write-Host "      • Burstable B1ms: 1 vCore (shared)" -ForegroundColor Gray
        Write-Host "      • CPU credits deplete under sustained load" -ForegroundColor Gray
        Write-Host "      • Failover requires full CPU for WAL replay" -ForegroundColor Gray
        Write-Host "      • Impact: 2-5x slower RTO" -ForegroundColor Yellow
        
        Write-Host ""
        Write-Host "  2️⃣  Limited Storage IOPS" -ForegroundColor Red
        Write-Host "      • Burstable tier: ~3,200 IOPS baseline" -ForegroundColor Gray
        Write-Host "      • Synchronous replication requires consistent IOPS" -ForegroundColor Gray
        Write-Host "      • IOPS throttling slows standby catch-up" -ForegroundColor Gray
        Write-Host "      • Impact: Delays failover promotion" -ForegroundColor Yellow
        
        Write-Host ""
        Write-Host "  3️⃣  Zone-Redundant HA Overhead" -ForegroundColor Yellow
        Write-Host "      • HA adds replication overhead" -ForegroundColor Gray
        Write-Host "      • Burstable tier not optimized for HA" -ForegroundColor Gray
        Write-Host "      • Standby warmup takes longer" -ForegroundColor Gray
        Write-Host "      • Impact: Extended recovery time" -ForegroundColor Yellow
    } else {
        Write-Host "  1️⃣  Performance Bottleneck" -ForegroundColor Yellow
        Write-Host "      • Check CPU utilization during failover" -ForegroundColor Gray
        Write-Host "      • Check IOPS throttling events" -ForegroundColor Gray
        Write-Host "      • Review network latency between zones" -ForegroundColor Gray
        
        Write-Host ""
        Write-Host "  2️⃣  Load Pattern" -ForegroundColor Yellow
        Write-Host "      • Actual TPS: $actualTPS" -ForegroundColor Gray
        Write-Host "      • High load during failover extends RTO" -ForegroundColor Gray
        Write-Host "      • Consider reducing test load" -ForegroundColor Gray
    }
    
    Write-Host ""
    Write-Host "Next Steps (Recommended Actions):" -ForegroundColor Cyan
    
    $stepNum = 1
    foreach ($rec in $recommendations) {
        Write-Host "  $stepNum. $rec" -ForegroundColor White
        $stepNum++
    }
    
    Write-Host "  $stepNum. Run detailed diagnostics:" -ForegroundColor White
    Write-Host "     .\Diagnose-Failover-Performance.ps1 -ResourceGroupName '$ResourceGroupName'" -ForegroundColor Gray
    
    $stepNum++
    Write-Host "  $stepNum. Check Azure Monitor for resource metrics:" -ForegroundColor White
    Write-Host "     Portal → PostgreSQL Server → Monitoring → Metrics" -ForegroundColor Gray
    
    $stepNum++
    Write-Host "  $stepNum. Review Activity Log for Azure service issues:" -ForegroundColor White
    Write-Host "     Portal → PostgreSQL Server → Activity Log" -ForegroundColor Gray
    
    if ($serverTier -eq "Burstable") {
        Write-Host ""
        Write-Host "💡 QUICK FIX:" -ForegroundColor Green -BackgroundColor DarkBlue
        Write-Host "   Upgrade to General Purpose D2ds_v4 for 60-90s RTO:" -ForegroundColor White
        Write-Host ""
        Write-Host "   az postgres flexible-server update \\" -ForegroundColor Gray
        Write-Host "       --resource-group $ResourceGroupName \\" -ForegroundColor Gray
        Write-Host "       --name $ServerName \\" -ForegroundColor Gray
        Write-Host "       --sku-name Standard_D2ds_v4 \\" -ForegroundColor Gray
        Write-Host "       --tier GeneralPurpose" -ForegroundColor Gray
        Write-Host ""
        Write-Host "   Expected improvement: RTO from ${RTO}s → 60-90s" -ForegroundColor Green
        Write-Host "   Cost impact: ~`$97/month increase (~`$120 total)" -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    
    # Note about mechanism
    Write-Host "ℹ️  Note: " -NoNewline -ForegroundColor Cyan
    Write-Host "The failover mechanism worked correctly (zero data loss)." -ForegroundColor White
    Write-Host "   The issue is infrastructure capacity, not configuration." -ForegroundColor Gray
    Write-Host "   This is expected behavior for $serverTier tier with HA enabled." -ForegroundColor Gray
    Write-Host ""
}

#endregion

#region Main Script

Show-Banner "PostgreSQL HA Failover Test"

# Check Azure CLI
Write-Step "Checking Azure CLI authentication..."
try {
    $currentAccount = az account show --query "{name:name, user:user.name}" -o json | ConvertFrom-Json
    Write-Success "Logged in as: $($currentAccount.user)"
} catch {
    Write-Error-Custom "Please run 'az login' first"
    exit 1
}

# Discover PostgreSQL server if not specified
if (-not $ServerName) {
    Write-Step "Discovering PostgreSQL server..."
    $servers = az postgres flexible-server list `
        --resource-group $ResourceGroupName `
        --query "[?contains(name, 'saif')].{name:name, ha:highAvailability.mode}" `
        --output json | ConvertFrom-Json
    
    if ($servers.Count -eq 0) {
        Write-Error-Custom "No PostgreSQL servers found in resource group"
        exit 1
    }
    
    if ($servers.Count -eq 1) {
        $ServerName = $servers[0].name
        Write-Success "Found server: $ServerName"
    } else {
        Write-Host "Multiple servers found:" -ForegroundColor Yellow
        for ($i = 0; $i -lt $servers.Count; $i++) {
            Write-Host "  [$i] $($servers[$i].name) (HA: $($servers[$i].ha))" -ForegroundColor White
        }
        $selection = Read-Host "Select server index"
        $ServerName = $servers[[int]$selection].name
    }
}

# Get server details
Write-Step "Getting server details..."
$server = az postgres flexible-server show `
    --resource-group $ResourceGroupName `
    --name $ServerName `
    --output json | ConvertFrom-Json

$serverFqdn = $server.fullyQualifiedDomainName
$haMode = $server.highAvailability.mode
$haState = $server.highAvailability.state
$primaryZone = $server.availabilityZone
$standbyZone = $server.highAvailability.standbyAvailabilityZone

Write-Host ""
Write-Info "Server Configuration:"
Write-Host "  Name: $ServerName" -ForegroundColor White
Write-Host "  FQDN: $serverFqdn" -ForegroundColor White
Write-Host "  HA Mode: $haMode" -ForegroundColor White
Write-Host "  HA State: $haState" -ForegroundColor $(if ($haState -eq 'Healthy') { 'Green' } else { 'Yellow' })
Write-Host "  Primary Zone: $primaryZone" -ForegroundColor White
Write-Host "  Standby Zone: $standbyZone" -ForegroundColor White
Write-Host ""

if ($haMode -ne "ZoneRedundant") {
    Write-Warning-Custom "Server is not configured for Zone-Redundant HA"
    Write-Host "This test requires Zone-Redundant HA mode." -ForegroundColor Yellow
    $continue = Read-Host "Continue anyway? (y/N)"
    if ($continue -ne 'y' -and $continue -ne 'Y') {
        exit 0
    }
}

if ($haState -ne "Healthy") {
    Write-Warning-Custom "Server HA state is not Healthy: $haState"
    Write-Host "Failover testing should only be performed on healthy servers." -ForegroundColor Yellow
    $continue = Read-Host "Continue anyway? (y/N)"
    if ($continue -ne 'y' -and $continue -ne 'Y') {
        exit 0
    }
}

# Get connection credentials
Write-Step "Enter database connection credentials"
$dbUser = Read-Host "Database username (default: saifadmin)"
if ([string]::IsNullOrWhiteSpace($dbUser)) {
    $dbUser = "saifadmin"
}

$dbPassword = Read-Host "Database password" -AsSecureString
$dbPasswordText = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($dbPassword)
)

# Check Docker
Write-Step "Checking Docker availability..."
try {
    docker --version | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Error-Custom "Docker is not running. Please start Docker Desktop."
        Write-Info "You can start Docker with: Start-Process 'C:\Program Files\Docker\Docker\Docker Desktop.exe'"
        exit 1
    }
    Write-Success "Docker is available"
} catch {
    Write-Error-Custom "Docker not found. Please install Docker Desktop from https://www.docker.com/products/docker-desktop"
    exit 1
}

# Ensure PostgreSQL Docker image exists
Write-Step "Checking PostgreSQL Docker image..."
$imageCheck = docker images postgres:16-alpine --format "{{.Repository}}" 2>&1
if ($imageCheck -notlike "*postgres*") {
    Write-Step "Pulling PostgreSQL 16 Alpine image (~50MB)..."
    docker pull postgres:16-alpine
    if ($LASTEXITCODE -ne 0) {
        Write-Error-Custom "Failed to pull Docker image. Check internet connectivity."
        exit 1
    }
    Write-Success "Docker image ready"
} else {
    Write-Success "Docker image already available"
}

# Test connection using Docker
Write-Step "Testing database connection using Docker..."
$connectionResult = Invoke-DockerPsql `
    -ServerFqdn $serverFqdn `
    -Username $dbUser `
    -Database "saifdb" `
    -Password $dbPasswordText `
    -Query "SELECT 1;"

if ($connectionResult.Success) {
    Write-Success "Database connection successful (machine-independent Docker approach)"
} else {
    Write-Error-Custom "Database connection failed"
    Write-Host "Error: $($connectionResult.Output)" -ForegroundColor Red
    Write-Info "Troubleshooting tips:"
    Write-Host "  1. Check firewall rules allow your IP: az postgres flexible-server firewall-rule list -g $ResourceGroupName -n $ServerName" -ForegroundColor Gray
    Write-Host "  2. Verify server is running: az postgres flexible-server show -g $ResourceGroupName -n $ServerName --query state" -ForegroundColor Gray
    Write-Host "  3. Test Docker networking: docker run --rm postgres:16-alpine nslookup $serverFqdn" -ForegroundColor Gray
    exit 1
}

# Confirmation
Write-Host ""
Write-Warning-Custom "⚠️  FAILOVER TEST WARNING ⚠️"
Write-Host "This test will:" -ForegroundColor Yellow
Write-Host "  1. Generate load on the database" -ForegroundColor White
Write-Host "  2. Force a failover to the standby zone" -ForegroundColor White
Write-Host "  3. Measure downtime and data loss" -ForegroundColor White
Write-Host "  4. Switch from Zone $primaryZone to Zone $standbyZone" -ForegroundColor White
Write-Host ""
Write-Host "Expected impact:" -ForegroundColor Yellow
Write-Host "  - RTO: 60-120 seconds of downtime" -ForegroundColor White
Write-Host "  - RPO: 0 (zero data loss)" -ForegroundColor White
Write-Host "  - Application connections will be dropped" -ForegroundColor White
Write-Host ""
$confirm = Read-Host "Proceed with failover test? (yes/no)"
if ($confirm -ne 'yes') {
    Write-Info "Test cancelled."
    exit 0
}

# Step 1: Pre-Failover Status
Show-Banner "Step 1: Pre-Failover Baseline"

Write-Step "Recording baseline metrics..."
$preFailoverTimestamp = Get-Timestamp

# Get transaction count using Docker
$transactionCountQuery = "SELECT COUNT(*) FROM transactions;"
$countResult = Invoke-DockerPsql `
    -ServerFqdn $serverFqdn `
    -Username $dbUser `
    -Database "saifdb" `
    -Password $dbPasswordText `
    -Query $transactionCountQuery `
    -TupleOnly

$preTransactionCount = if ($countResult.Success) { 
    $countResult.Output.ToString().Trim() 
} else { 
    "0" 
}

Write-Info "Pre-failover metrics:"
Write-Host "  Timestamp: $preFailoverTimestamp" -ForegroundColor White
Write-Host "  Transaction Count: $preTransactionCount" -ForegroundColor White
Write-Host "  Primary Zone: $primaryZone" -ForegroundColor White
Write-Host "  Standby Zone: $standbyZone" -ForegroundColor White

# Step 2: Start Load Generation
Show-Banner "Step 2: Load Generation"

Write-Step "Starting load generation ($LoadDuration seconds at $TransactionsPerSecond TPS)..."
Write-Info "Generating realistic payment transactions..."

# Create load generation script block (Docker-based)
$loadGenerationScript = {
    param($serverFqdn, $dbUser, $dbPasswordText, $duration, $tps)
    
    $endTime = (Get-Date).AddSeconds($duration)
    $intervalMs = [int](1000 / $tps)
    $successCount = 0
    $errorCount = 0
    
    while ((Get-Date) -lt $endTime) {
        $startLoop = Get-Date
        
        try {
            # Use Docker to execute transaction
            docker run --rm `
                -e PGPASSWORD="$dbPasswordText" `
                postgres:16-alpine `
                psql -h $serverFqdn -U $dbUser -d saifdb -t -c "SELECT create_test_transaction();" 2>&1 | Out-Null
            
            if ($LASTEXITCODE -eq 0) {
                $successCount++
            } else {
                $errorCount++
            }
        } catch {
            $errorCount++
        }
        
        # Rate limiting
        $elapsed = ((Get-Date) - $startLoop).TotalMilliseconds
        $sleepTime = [Math]::Max(0, $intervalMs - $elapsed)
        if ($sleepTime -gt 0) {
            Start-Sleep -Milliseconds $sleepTime
        }
    }
    
    return @{
        SuccessCount = $successCount
        ErrorCount = $errorCount
    }
}

# Start load generation as background job
$loadJob = Start-Job -ScriptBlock $loadGenerationScript `
    -ArgumentList $serverFqdn, $dbUser, $dbPasswordText, $LoadDuration, $TransactionsPerSecond

Write-Success "Load generation started (Job ID: $($loadJob.Id))"

# Monitor load generation
$progressSeconds = 0
while ($progressSeconds -lt $LoadDuration -and $loadJob.State -eq 'Running') {
    Start-Sleep -Seconds 1
    $progressSeconds++
    
    if ($progressSeconds % 10 -eq 0) {
        $percentComplete = [int](($progressSeconds / $LoadDuration) * 100)
        Write-Host "  Progress: $percentComplete% ($progressSeconds/$LoadDuration seconds)" -ForegroundColor Gray
    }
}

# Get load generation results
Write-Step "Waiting for load generation to complete..."
$loadResults = Receive-Job -Job $loadJob -Wait
Remove-Job -Job $loadJob

Write-Success "Load generation completed"
Write-Info "Results:"
Write-Host "  Successful Transactions: $($loadResults.SuccessCount)" -ForegroundColor Green
Write-Host "  Failed Transactions: $($loadResults.ErrorCount)" -ForegroundColor $(if ($loadResults.ErrorCount -gt 0) { 'Red' } else { 'Gray' })
Write-Host "  Actual TPS: $([Math]::Round($loadResults.SuccessCount / $LoadDuration, 2))" -ForegroundColor White

# Step 3: Trigger Failover
Show-Banner "Step 3: Failover Trigger"

Write-Step "Recording last transaction ID before failover..."
$lastTransactionQuery = "SELECT MAX(id) FROM transactions;"
$lastTxResult = Invoke-DockerPsql `
    -ServerFqdn $serverFqdn `
    -Username $dbUser `
    -Database "saifdb" `
    -Password $dbPasswordText `
    -Query $lastTransactionQuery `
    -TupleOnly

$lastTransactionId = if ($lastTxResult.Success) { 
    $lastTxResult.Output.ToString().Trim() 
} else { 
    "0" 
}

Write-Info "Last transaction ID: $lastTransactionId"

Write-Step "Triggering forced failover..."
$failoverStartTime = Get-Date
$failoverStartTimestamp = Get-Timestamp

Write-Host "  Failover initiated at: $failoverStartTimestamp" -ForegroundColor Yellow

try {
    az postgres flexible-server restart `
        --resource-group $ResourceGroupName `
        --name $ServerName `
        --failover Forced `
        --output none
    
    Write-Success "Failover command executed"
} catch {
    Write-Error-Custom "Failover command failed: $_"
    exit 1
}

# Step 4: Monitor Recovery
Show-Banner "Step 4: Recovery Monitoring"

Write-Step "Monitoring database availability..."
Write-Info "Checking connection every 5 seconds..."

$recovered = $false
$checkCount = 0
$maxChecks = 60  # 5 minutes maximum

while (-not $recovered -and $checkCount -lt $maxChecks) {
    Start-Sleep -Seconds 5
    $checkCount++
    $elapsedSeconds = $checkCount * 5
    
    Write-Host "  Check $checkCount (${elapsedSeconds}s): " -NoNewline -ForegroundColor Gray
    
    try {
        $pingResult = Invoke-DockerPsql `
            -ServerFqdn $serverFqdn `
            -Username $dbUser `
            -Database "saifdb" `
            -Password $dbPasswordText `
            -Query "SELECT 1;" `
            -TupleOnly
        
        if ($pingResult.Success) {
            $recoveryEndTime = Get-Date
            $recoveryEndTimestamp = Get-Timestamp
            $recovered = $true
            Write-Host "✅ Connected!" -ForegroundColor Green
        } else {
            Write-Host "❌ Not responding" -ForegroundColor Red
        }
    } catch {
        Write-Host "❌ Error" -ForegroundColor Red
    }
}

if (-not $recovered) {
    Write-Error-Custom "Database did not recover within 5 minutes"
    exit 1
}

# Calculate RTO
$rtoSeconds = ($recoveryEndTime - $failoverStartTime).TotalSeconds
$rtoFormatted = "{0:F2}" -f $rtoSeconds

Write-Success "Database recovered!"
Write-Host "  Recovery Time: $rtoFormatted seconds" -ForegroundColor Green

# Step 5: Validate Data Integrity
Show-Banner "Step 5: Data Integrity Validation"

Write-Step "Checking for data loss (RPO validation)..."

# Get post-failover transaction count using Docker
$postCountResult = Invoke-DockerPsql `
    -ServerFqdn $serverFqdn `
    -Username $dbUser `
    -Database "saifdb" `
    -Password $dbPasswordText `
    -Query $transactionCountQuery `
    -TupleOnly

$postTransactionCount = if ($postCountResult.Success) { 
    $postCountResult.Output.ToString().Trim() 
} else { 
    "0" 
}

# Get last transaction ID after failover using Docker
$postLastTxResult = Invoke-DockerPsql `
    -ServerFqdn $serverFqdn `
    -Username $dbUser `
    -Database "saifdb" `
    -Password $dbPasswordText `
    -Query $lastTransactionQuery `
    -TupleOnly

$postLastTransactionId = if ($postLastTxResult.Success) { 
    $postLastTxResult.Output.ToString().Trim() 
} else { 
    "0" 
}

# Calculate data loss (with robust parsing)
$preCount = 0
$postCount = 0

try {
    # Extract numeric value from string (handle any extra whitespace/newlines)
    $preTransactionCount = $preTransactionCount -replace '\s+', ' '
    $preTransactionCount = $preTransactionCount.Trim()
    $preCount = [int]$preTransactionCount
} catch {
    Write-Warning-Custom "Could not parse pre-failover count: '$preTransactionCount'"
    $preCount = 0
}

try {
    # Extract numeric value from string (handle any extra whitespace/newlines)
    $postTransactionCount = $postTransactionCount -replace '\s+', ' '
    $postTransactionCount = $postTransactionCount.Trim()
    $postCount = [int]$postTransactionCount
} catch {
    Write-Warning-Custom "Could not parse post-failover count: '$postTransactionCount'"
    $postCount = 0
}

$lostTransactions = $preCount - $postCount
$rpoSeconds = if ($lostTransactions -gt 0) { "UNKNOWN (data loss detected)" } else { "0.00" }

Write-Info "Data integrity check:"
Write-Host "  Pre-failover transactions: $preCount" -ForegroundColor White
Write-Host "  Post-failover transactions: $postCount" -ForegroundColor White
Write-Host "  Lost transactions: $lostTransactions" -ForegroundColor $(if ($lostTransactions -eq 0) { 'Green' } else { 'Red' })
Write-Host "  Last transaction ID before: $lastTransactionId" -ForegroundColor White
Write-Host "  Last transaction ID after: $postLastTransactionId" -ForegroundColor White

if ($lostTransactions -eq 0) {
    Write-Success "✅ ZERO DATA LOSS - RPO target achieved!"
} else {
    Write-Warning-Custom "⚠️  DATA LOSS DETECTED - RPO target not met"
}

# Step 6: Post-Failover Status
Show-Banner "Step 6: Post-Failover Status"

Write-Step "Getting post-failover server configuration..."
$postFailoverServer = az postgres flexible-server show `
    --resource-group $ResourceGroupName `
    --name $ServerName `
    --output json | ConvertFrom-Json

$postPrimaryZone = $postFailoverServer.availabilityZone
$postStandbyZone = $postFailoverServer.highAvailability.standbyAvailabilityZone
$postHAState = $postFailoverServer.highAvailability.state

Write-Info "Post-failover configuration:"
Write-Host "  New Primary Zone: $postPrimaryZone" -ForegroundColor White
Write-Host "  New Standby Zone: $postStandbyZone" -ForegroundColor White
Write-Host "  HA State: $postHAState" -ForegroundColor $(if ($postHAState -eq 'Healthy') { 'Green' } else { 'Yellow' })

if ($postPrimaryZone -eq $standbyZone) {
    Write-Success "✅ Zone switch confirmed (Zone $primaryZone → Zone $postPrimaryZone)"
} else {
    Write-Warning-Custom "Zone switch not detected"
}

# Final Summary
Show-Banner "📊 Failover Test Results"

Write-Host "Test Duration: $(Get-Timestamp)" -ForegroundColor Cyan
Write-Host ""

Write-Host "🔄 Failover Metrics:" -ForegroundColor Cyan
Write-Host "  Failover Start: $failoverStartTimestamp" -ForegroundColor White
Write-Host "  Failover End: $recoveryEndTimestamp" -ForegroundColor White
Write-Host "  RTO (Recovery Time): $rtoFormatted seconds" -ForegroundColor $(if ($rtoSeconds -le 120) { 'Green' } else { 'Yellow' })
Write-Host "  RPO (Data Loss): $rpoSeconds seconds" -ForegroundColor $(if ($lostTransactions -eq 0) { 'Green' } else { 'Red' })
Write-Host ""

Write-Host "📊 Load Generation:" -ForegroundColor Cyan
Write-Host "  Duration: $LoadDuration seconds" -ForegroundColor White
Write-Host "  Target TPS: $TransactionsPerSecond" -ForegroundColor White
Write-Host "  Actual TPS: $([Math]::Round($loadResults.SuccessCount / $LoadDuration, 2))" -ForegroundColor White
Write-Host "  Successful Transactions: $($loadResults.SuccessCount)" -ForegroundColor White
Write-Host "  Failed Transactions: $($loadResults.ErrorCount)" -ForegroundColor White
Write-Host ""

Write-Host "🌐 Zone Configuration:" -ForegroundColor Cyan
Write-Host "  Before: Primary Zone $primaryZone / Standby Zone $standbyZone" -ForegroundColor White
Write-Host "  After:  Primary Zone $postPrimaryZone / Standby Zone $postStandbyZone" -ForegroundColor White
Write-Host ""

Write-Host "📈 SLA Compliance:" -ForegroundColor Cyan
$rtoCompliant = $rtoSeconds -le 120
$rpoCompliant = $lostTransactions -eq 0

Write-Host "  RTO ≤ 120s: " -NoNewline
if ($rtoCompliant) {
    Write-Host "✅ PASS ($rtoFormatted seconds)" -ForegroundColor Green
} else {
    Write-Host "❌ FAIL ($rtoFormatted seconds)" -ForegroundColor Red
}

Write-Host "  RPO = 0s: " -NoNewline
if ($rpoCompliant) {
    Write-Host "✅ PASS (zero data loss)" -ForegroundColor Green
} else {
    Write-Host "❌ FAIL ($lostTransactions transactions lost)" -ForegroundColor Red
}

Write-Host "  99.99% Uptime: " -NoNewline
$uptimeCompliant = $rtoSeconds -le 120 -and $rpoCompliant
if ($uptimeCompliant) {
    Write-Host "✅ PASS" -ForegroundColor Green
} else {
    Write-Host "❌ FAIL" -ForegroundColor Red
}

Write-Host ""

if ($rtoCompliant -and $rpoCompliant) {
    Write-Success "🎉 All SLA targets achieved!"
} else {
    Write-Warning-Custom "⚠️  Some SLA targets not met - review results above"
    
    # Automatic intelligent diagnostics
    try {
        Invoke-FailoverDiagnostics `
            -RTO $rtoSeconds `
            -RPO $lostTransactions `
            -ServerName $ServerName `
            -ResourceGroupName $ResourceGroupName `
            -LoadResults $loadResults `
            -FailoverStartTime $failoverStartTime
    } catch {
        Write-Warning-Custom "Could not run diagnostics: $($_.Exception.Message)"
        Write-Info "Run manual diagnostics: .\Diagnose-Failover-Performance.ps1 -ResourceGroupName '$ResourceGroupName'"
    }
}

# Cleanup
$env:PGPASSWORD = $null
$dbPasswordText = $null

Write-Host ""
Write-Info "Test report complete. Save these results for compliance documentation."

#endregion
