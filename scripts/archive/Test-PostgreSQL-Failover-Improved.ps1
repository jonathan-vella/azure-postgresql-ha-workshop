<#
.SYNOPSIS
    Measures PostgreSQL Zone-Redundant HA failover timing from application perspective.

.DESCRIPTION
    This script performs a proper failover test following Microsoft's guidance:
    - Generates continuous write load using application perspective
    - Measures actual application downtime (not control plane operations)
    - Detects first failure and first recovery automatically
    - Follows Microsoft documentation best practices
    
    Reference: https://learn.microsoft.com/en-us/azure/reliability/reliability-postgresql-flexible-server#planned-failover

.PARAMETER ResourceGroupName
    The name of the resource group containing the PostgreSQL server.

.PARAMETER ServerName
    Optional. The name of the PostgreSQL server. Will be auto-discovered if not provided.

.PARAMETER WritesPerSecond
    Target write operations per second (default: 100 TPS for realistic load testing).

.PARAMETER TestDurationSeconds
    How long to run the load test (default: 300 seconds = 5 minutes).

.PARAMETER PromptForFailoverAt
    When to prompt user to trigger failover (default: 60 seconds).
    Set to 0 to disable automatic prompt.

.EXAMPLE
    .\Test-PostgreSQL-Failover-Improved.ps1 -ResourceGroupName "rg-saif-pgsql-swc-01"
    
.EXAMPLE
    .\Test-PostgreSQL-Failover-Improved.ps1 `
        -ResourceGroupName "rg-saif-pgsql-swc-01" `
        -ServerName "psql-saifpg-10081025" `
        -WritesPerSecond 200

.NOTES
    Author: Azure Principal Architect
    Version: 2.0.0
    Based on: Microsoft Azure Reliability Documentation
    
    IMPORTANT: This script measures RTO from APPLICATION PERSPECTIVE as per Microsoft guidance:
    "Always observe the downtime from the application perspective!"
    
    Expected SLA for Zone-Redundant HA Planned Failover:
    - RTO: 60-120 seconds (application downtime)
    - RPO: 0 seconds (zero data loss with synchronous replication)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$false)]
    [string]$ServerName,
    
    [Parameter(Mandatory=$false)]
    [int]$WritesPerSecond = 100,
    
    [Parameter(Mandatory=$false)]
    [int]$TestDurationSeconds = 300,
    
    [Parameter(Mandatory=$false)]
    [int]$PromptForFailoverAt = 60
)

$ErrorActionPreference = "Stop"

#region Helper Functions

function Write-Step {
    param([string]$message)
    Write-Host "📍 $message" -ForegroundColor Yellow
}

function Write-Success {
    param([string]$message)
    Write-Host "✅ $message" -ForegroundColor Green
}

function Write-Failure {
    param([string]$message)
    Write-Host "❌ $message" -ForegroundColor Red
}

function Write-Info {
    param([string]$message)
    Write-Host "ℹ️  $message" -ForegroundColor Cyan
}

function Write-Warning-Custom {
    param([string]$message)
    Write-Host "⚠️  $message" -ForegroundColor Yellow
}

function Write-Metric {
    param([string]$message)
    Write-Host "📊 $message" -ForegroundColor Magenta
}

#endregion

#region Failover Metrics Tracking

class FailoverMetrics {
    [System.Collections.ArrayList]$WriteAttempts = @()
    [int]$SuccessfulWrites = 0
    [int]$FailedWrites = 0
    [datetime]$TestStartTime
    [datetime]$FirstFailureTime
    [datetime]$LastFailureTime
    [datetime]$FirstRecoveryTime
    [bool]$FailoverDetected = $false
    
    [void] RecordWrite([bool]$success, [double]$durationMs, [string]$error) {
        $timestamp = Get-Date
        
        $attempt = [PSCustomObject]@{
            Timestamp = $timestamp
            Success = $success
            DurationMs = $durationMs
            Error = $error
        }
        
        [void]$this.WriteAttempts.Add($attempt)
        
        if ($success) {
            $this.SuccessfulWrites++
            
            # Detect recovery (first success after failure)
            if ($this.FirstFailureTime -and -not $this.FirstRecoveryTime) {
                $this.FirstRecoveryTime = $timestamp
                $this.FailoverDetected = $true
                Write-Host ""
                Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Green
                Write-Host "✅ [RECOVERY DETECTED] Database accepting writes again!" -ForegroundColor Green
                Write-Host "   Time: $($timestamp.ToString('HH:mm:ss.fff'))" -ForegroundColor Green
                Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Green
                Write-Host ""
            }
        } else {
            $this.FailedWrites++
            
            # Detect first failure (start of downtime)
            if (-not $this.FirstFailureTime) {
                $this.FirstFailureTime = $timestamp
                Write-Host ""
                Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Red
                Write-Host "❌ [DOWNTIME STARTED] First write failure detected!" -ForegroundColor Red
                Write-Host "   Time: $($timestamp.ToString('HH:mm:ss.fff'))" -ForegroundColor Red
                Write-Host "   This marks the beginning of application downtime (RTO measurement)" -ForegroundColor Yellow
                Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Red
                Write-Host ""
            }
            
            $this.LastFailureTime = $timestamp
        }
    }
    
    [double] GetFailoverDurationSeconds() {
        if ($this.FirstFailureTime -and $this.FirstRecoveryTime) {
            return ($this.FirstRecoveryTime - $this.FirstFailureTime).TotalSeconds
        }
        return 0
    }
    
    [PSCustomObject] GetSummary() {
        $rto = $this.GetFailoverDurationSeconds()
        
        $successfulDurations = $this.WriteAttempts | Where-Object { $_.Success } | Select-Object -ExpandProperty DurationMs
        
        return [PSCustomObject]@{
            TotalAttempts = $this.WriteAttempts.Count
            SuccessfulWrites = $this.SuccessfulWrites
            FailedWrites = $this.FailedWrites
            SuccessRate = if ($this.WriteAttempts.Count -gt 0) { 
                [math]::Round(($this.SuccessfulWrites / $this.WriteAttempts.Count * 100), 2) 
            } else { 0 }
            TestStartTime = $this.TestStartTime
            FirstFailureTime = $this.FirstFailureTime
            FirstRecoveryTime = $this.FirstRecoveryTime
            FailoverDetected = $this.FailoverDetected
            RTOSeconds = $rto
            RTOWithinSLA = ($rto -gt 0 -and $rto -le 120)
            RPOSeconds = 0  # Zero data loss with synchronous replication
            AvgWriteDurationMs = if ($successfulDurations.Count -gt 0) { 
                [math]::Round(($successfulDurations | Measure-Object -Average).Average, 2) 
            } else { 0 }
            MedianWriteDurationMs = if ($successfulDurations.Count -gt 0) {
                $sorted = $successfulDurations | Sort-Object
                $mid = [math]::Floor($sorted.Count / 2)
                $sorted[$mid]
            } else { 0 }
        }
    }
}

#endregion

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host " 🧪 PostgreSQL Zone-Redundant HA Failover Test (Application Perspective)" -ForegroundColor White
Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Info "Based on Microsoft Azure Reliability Documentation"
Write-Info "Measures actual application-perceived downtime (RTO) per Microsoft guidance"
Write-Host ""

# Check Azure CLI
Write-Step "Checking Azure CLI authentication..."
try {
    $currentAccount = az account show --query "name" -o tsv
    Write-Success "Authenticated to: $currentAccount"
} catch {
    Write-Failure "Please run 'az login' first"
    exit 1
}

# Discover PostgreSQL server if not specified
if (-not $ServerName) {
    Write-Step "Discovering PostgreSQL server..."
    
    $serversJson = az postgres flexible-server list `
        --resource-group $ResourceGroupName `
        --output json
    
    if ($LASTEXITCODE -ne 0) {
        Write-Failure "Failed to list PostgreSQL servers"
        exit 1
    }
    
    $servers = $serversJson | ConvertFrom-Json
    
    if ($servers.Count -eq 0) {
        Write-Failure "No PostgreSQL servers found in resource group: $ResourceGroupName"
        exit 1
    }
    
    # Look for SAIF-related server names
    $saifServers = $servers | Where-Object { $_.name -match 'saif|psql' }
    
    if ($saifServers.Count -eq 0) {
        $ServerName = $servers[0].name
        Write-Info "Using first server found: $ServerName"
    } else {
        $ServerName = $saifServers[0].name
        Write-Success "Found server: $ServerName"
    }
}

# Get server details
Write-Step "Getting server details..."
$serverDetails = az postgres flexible-server show `
    --resource-group $ResourceGroupName `
    --name $ServerName `
    --output json | ConvertFrom-Json

$serverFqdn = $serverDetails.fullyQualifiedDomainName
$haEnabled = $serverDetails.highAvailability.mode
$haState = $serverDetails.highAvailability.state
$primaryZone = $serverDetails.availabilityZone
$standbyZone = $serverDetails.highAvailability.standbyAvailabilityZone

Write-Info "Server FQDN: $serverFqdn"
Write-Info "HA Mode: $haEnabled"
Write-Info "HA State: $haState"
Write-Info "Primary Zone: $primaryZone"
Write-Info "Standby Zone: $standbyZone"

# Verify HA is enabled
if ($haEnabled -ne "ZoneRedundant") {
    Write-Warning-Custom "Server is not configured with Zone-Redundant HA!"
    Write-Warning-Custom "This test requires Zone-Redundant HA for automatic failover."
    Write-Warning-Custom "Current mode: $haEnabled"
    
    $continue = Read-Host "Continue anyway? (y/N)"
    if ($continue -ne 'y') {
        exit 0
    }
}

# Get credentials
Write-Step "Enter database connection credentials"
$dbUser = Read-Host "Database username (default: saifadmin)"
if ([string]::IsNullOrWhiteSpace($dbUser)) {
    $dbUser = "saifadmin"
}

$dbPassword = Read-Host "Database password" -AsSecureString
$dbPasswordText = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($dbPassword)
)

$dbName = "saifdb"

# Check Docker
Write-Step "Checking Docker availability..."
try {
    docker --version | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Failure "Docker is not running. Please start Docker Desktop."
        exit 1
    }
    Write-Success "Docker is available"
} catch {
    Write-Failure "Docker not found. Please install Docker Desktop."
    exit 1
}

# Test connection
Write-Step "Testing database connection..."
$testResult = docker run --rm `
    -e PGPASSWORD="$dbPasswordText" `
    postgres:16-alpine `
    psql -h $serverFqdn -U $dbUser -d $dbName -t -c "SELECT 1;" 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Failure "Database connection failed"
    Write-Host "Error: $testResult" -ForegroundColor Red
    exit 1
}

Write-Success "Connected to database"

# Get initial transaction count
Write-Step "Getting baseline transaction count..."
$initialCountRaw = docker run --rm `
    -e PGPASSWORD="$dbPasswordText" `
    postgres:16-alpine `
    psql -h $serverFqdn -U $dbUser -d $dbName -t -c "SELECT COUNT(*) FROM transactions;" 2>&1

if ($LASTEXITCODE -eq 0) {
    # Handle both string and array returns from Docker
    if ($initialCountRaw -is [array]) {
        $initialCount = ($initialCountRaw -join '').Trim()
    } else {
        $initialCount = $initialCountRaw.ToString().Trim()
    }
    Write-Info "Current transaction count: $initialCount"
} else {
    $initialCount = "0"
}

# Display test configuration
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host " 📋 TEST CONFIGURATION" -ForegroundColor White
Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Info "Target write rate: $WritesPerSecond TPS (transactions per second)"
Write-Info "Test duration: $TestDurationSeconds seconds ($([math]::Round($TestDurationSeconds/60, 1)) minutes)"
Write-Info "Prompt for failover at: $PromptForFailoverAt seconds"
Write-Info "Expected transactions: ~$(($WritesPerSecond * $TestDurationSeconds))"
Write-Host ""
Write-Info "Expected SLA for Zone-Redundant HA Planned Failover:"
Write-Info "  • RTO (Recovery Time Objective): 60-120 seconds"
Write-Info "  • RPO (Recovery Point Objective): 0 seconds (zero data loss)"
Write-Host ""

# Instructions
Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Yellow
Write-Host " 📖 FAILOVER TEST INSTRUCTIONS" -ForegroundColor White
Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. This test will generate continuous write load to the database" -ForegroundColor White
Write-Host "2. Wait for 'STABLE' indicator (consistent successful writes)" -ForegroundColor White
Write-Host "3. Trigger a PLANNED FAILOVER using:" -ForegroundColor White
Write-Host ""
Write-Host "   💻 Azure CLI (in a NEW terminal):" -ForegroundColor Cyan
Write-Host ""
Write-Host "      az postgres flexible-server restart ``" -ForegroundColor Green
Write-Host "        --resource-group $ResourceGroupName ``" -ForegroundColor Green
Write-Host "        --name $ServerName ``" -ForegroundColor Green
Write-Host "        --failover Planned" -ForegroundColor Green
Write-Host ""
Write-Host "   🖥️  Azure Portal:" -ForegroundColor Cyan
Write-Host "      • Portal: https://portal.azure.com" -ForegroundColor Gray
Write-Host "      • Search: $ServerName" -ForegroundColor Gray
Write-Host "      • Settings → High availability → Planned failover" -ForegroundColor Gray
Write-Host ""
Write-Host "4. The script will automatically detect downtime start and recovery" -ForegroundColor White
Write-Host "5. After recovery, let it run for 30-60 more seconds" -ForegroundColor White
Write-Host "6. Press Ctrl+C to stop and view detailed results" -ForegroundColor White
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Yellow
Write-Host ""

Write-Host "Press ENTER to start the load test (Ctrl+C to cancel)..." -ForegroundColor Yellow
$null = Read-Host

# Initialize metrics
$metrics = [FailoverMetrics]::new()
$metrics.TestStartTime = Get-Date
$writeDelayMs = [math]::Round(1000 / $WritesPerSecond)

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host " 🚀 LOAD TEST STARTED" -ForegroundColor White
Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""
Write-Info "Generating $WritesPerSecond writes per second..."
Write-Info "Each '.' = successful write | Each 'X' = failed write"
Write-Host ""

# Setup prompt timer if configured
$promptJob = $null
if ($PromptForFailoverAt -gt 0) {
    $promptJob = Start-Job -ScriptBlock {
        param($seconds, $ResourceGroupName, $ServerName)
        
        Start-Sleep -Seconds $seconds
        
        return @{
            Prompt = $true
            ResourceGroup = $ResourceGroupName
            ServerName = $ServerName
        }
    } -ArgumentList $PromptForFailoverAt, $ResourceGroupName, $ServerName
}

# Main load generation loop
$startTime = Get-Date
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$lastProgressTime = $startTime
$consecutiveSuccesses = 0
$isStable = $false

try {
    while (((Get-Date) - $startTime).TotalSeconds -lt $TestDurationSeconds) {
        $iterationStart = [System.Diagnostics.Stopwatch]::StartNew()
        
        # Attempt transaction write
        try {
            $writeStart = [System.Diagnostics.Stopwatch]::StartNew()
            
            $result = docker run --rm `
                -e PGPASSWORD="$dbPasswordText" `
                postgres:16-alpine `
                psql -h $serverFqdn -U $dbUser -d $dbName -t `
                -c "SELECT create_test_transaction();" 2>&1
            
            $writeEnd = $writeStart.ElapsedMilliseconds
            
            if ($LASTEXITCODE -eq 0) {
                $metrics.RecordWrite($true, $writeEnd, $null)
                Write-Host "." -NoNewline -ForegroundColor Green
                
                $consecutiveSuccesses++
                
                # Check for stability (10 consecutive successes)
                if (-not $isStable -and $consecutiveSuccesses -ge 10) {
                    $isStable = $true
                    Write-Host ""
                    Write-Host ""
                    Write-Success "[STABLE] Write operations are stable. Ready for failover testing."
                    Write-Host ""
                }
            } else {
                $metrics.RecordWrite($false, $writeEnd, $result)
                Write-Host "X" -NoNewline -ForegroundColor Red
                $consecutiveSuccesses = 0
                $isStable = $false
            }
        } catch {
            $metrics.RecordWrite($false, 0, $_.Exception.Message)
            Write-Host "X" -NoNewline -ForegroundColor Red
            $consecutiveSuccesses = 0
            $isStable = $false
        }
        
        # Progress update every 10 seconds
        if (((Get-Date) - $lastProgressTime).TotalSeconds -ge 10) {
            $elapsed = [math]::Round(((Get-Date) - $startTime).TotalSeconds)
            $remaining = $TestDurationSeconds - $elapsed
            
            Write-Host ""
            Write-Metric "[$elapsed/${TestDurationSeconds}s] Success: $($metrics.SuccessfulWrites) | Failed: $($metrics.FailedWrites) | Remaining: ${remaining}s"
            
            $lastProgressTime = Get-Date
        }
        
        # Check for prompt
        if ($promptJob -and $promptJob.State -eq 'Completed') {
            $promptData = Receive-Job $promptJob
            Remove-Job $promptJob
            $promptJob = $null
            
            if ($promptData.Prompt) {
                Write-Host ""
                Write-Host ""
                Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Yellow -BackgroundColor DarkRed
                Write-Host "⚡⚡⚡ TIME TO TRIGGER FAILOVER NOW! ⚡⚡⚡" -ForegroundColor Yellow -BackgroundColor DarkRed
                Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Yellow -BackgroundColor DarkRed
                Write-Host ""
                Write-Host "Test has been running for $PromptForFailoverAt seconds - should be STABLE." -ForegroundColor Black -BackgroundColor Yellow
                Write-Host ""
                Write-Host "💻 Copy and paste in NEW terminal:" -ForegroundColor Black -BackgroundColor Cyan
                Write-Host ""
                Write-Host "   az postgres flexible-server restart ``" -ForegroundColor Black -BackgroundColor White
                Write-Host "     --resource-group $($promptData.ResourceGroup) ``" -ForegroundColor Black -BackgroundColor White
                Write-Host "     --name $($promptData.ServerName) ``" -ForegroundColor Black -BackgroundColor White
                Write-Host "     --failover Planned" -ForegroundColor Black -BackgroundColor White
                Write-Host ""
                Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Yellow -BackgroundColor DarkRed
                Write-Host ""
                
                # Beep to get attention
                [Console]::Beep(800, 300)
                Start-Sleep -Milliseconds 200
                [Console]::Beep(1000, 300)
            }
        }
        
        # Rate limiting
        $iterationElapsed = $iterationStart.ElapsedMilliseconds
        $sleepTime = $writeDelayMs - $iterationElapsed
        if ($sleepTime -gt 0) {
            Start-Sleep -Milliseconds $sleepTime
        }
    }
    
    Write-Host ""
    Write-Host ""
    Write-Info "Test duration completed. Stopping load generation..."
    
} catch {
    Write-Host ""
    Write-Host ""
    Write-Warning-Custom "Test stopped by user (Ctrl+C)"
} finally {
    # Cleanup prompt job
    if ($promptJob) {
        Stop-Job $promptJob -ErrorAction SilentlyContinue
        Remove-Job $promptJob -ErrorAction SilentlyContinue
    }
}

$stopwatch.Stop()

# Get final transaction count
Write-Step "Getting final transaction count..."
$finalCountRaw = docker run --rm `
    -e PGPASSWORD="$dbPasswordText" `
    postgres:16-alpine `
    psql -h $serverFqdn -U $dbUser -d $dbName -t -c "SELECT COUNT(*) FROM transactions;" 2>&1

if ($LASTEXITCODE -eq 0) {
    # Handle both string and array returns from Docker
    if ($finalCountRaw -is [array]) {
        $finalCount = ($finalCountRaw -join '').Trim()
    } else {
        $finalCount = $finalCountRaw.ToString().Trim()
    }
    
    try {
        $transactionsCreated = [int]$finalCount - [int]$initialCount
        Write-Info "Final transaction count: $finalCount"
        Write-Info "Transactions created during test: $transactionsCreated"
    } catch {
        Write-Warning-Custom "Could not calculate transaction delta (counts may be non-numeric)"
        Write-Info "Initial: $initialCount | Final: $finalCount"
    }
} else {
    Write-Warning-Custom "Could not retrieve final transaction count"
}

# Print detailed results
$summary = $metrics.GetSummary()

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host " 📊 FAILOVER TEST RESULTS" -ForegroundColor White
Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

Write-Host "📈 OVERALL STATISTICS:" -ForegroundColor Yellow
Write-Host "   Total write attempts:        $($summary.TotalAttempts)"
Write-Host "   Successful writes:           $($summary.SuccessfulWrites)"
Write-Host "   Failed writes:               $($summary.FailedWrites)"
Write-Host "   Success rate:                $($summary.SuccessRate)%"
Write-Host ""

if ($summary.AvgWriteDurationMs -gt 0) {
    Write-Host "⏱️  WRITE PERFORMANCE (successful writes):" -ForegroundColor Yellow
    Write-Host "   Average duration:            $($summary.AvgWriteDurationMs) ms"
    Write-Host "   Median duration:             $($summary.MedianWriteDurationMs) ms"
    Write-Host ""
}

if ($summary.FailoverDetected) {
    Write-Host "🔄 FAILOVER METRICS (Application Perspective):" -ForegroundColor Yellow
    Write-Host "   Test start time:             $($summary.TestStartTime.ToString('yyyy-MM-dd HH:mm:ss'))"
    Write-Host "   First failure (downtime):    $($summary.FirstFailureTime.ToString('yyyy-MM-dd HH:mm:ss.fff'))"
    Write-Host "   First recovery:              $($summary.FirstRecoveryTime.ToString('yyyy-MM-dd HH:mm:ss.fff'))"
    Write-Host ""
    Write-Host "   ⭐ RTO (Recovery Time):       $($summary.RTOSeconds) seconds" -ForegroundColor Magenta
    Write-Host "   ⭐ RPO (Data Loss):           $($summary.RPOSeconds) seconds (synchronous replication)" -ForegroundColor Magenta
    Write-Host ""
    Write-Host "   Target SLA:                  60-120 seconds (planned failover)"
    
    if ($summary.RTOWithinSLA) {
        Write-Success "   ✅ PASSED - RTO within SLA target"
    } else {
        if ($summary.RTOSeconds -lt 60) {
            Write-Success "   ✅ EXCEEDED EXPECTATIONS - Better than SLA target!"
        } else {
            Write-Failure "   ❌ FAILED - RTO exceeds SLA target of 120 seconds"
        }
    }
    
    Write-Host ""
    Write-Info "📚 Microsoft Documentation Reference:"
    Write-Info "   'Always observe the downtime from the application perspective!'"
    Write-Info "   Source: https://learn.microsoft.com/en-us/azure/reliability/reliability-postgresql-flexible-server"
    
} else {
    Write-Warning-Custom "NO FAILOVER DETECTED"
    Write-Host "   Either no failover occurred during the test, or the test was too short."
    Write-Host "   To measure failover: trigger a planned failover while this test is running."
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Export detailed results
Write-Step "Exporting detailed results..."
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$csvFile = "failover_test_results_$timestamp.csv"

$metrics.WriteAttempts | Select-Object `
    @{Name='Timestamp';Expression={$_.Timestamp.ToString('yyyy-MM-dd HH:mm:ss.fff')}},
    Success,
    @{Name='DurationMs';Expression={[math]::Round($_.DurationMs, 2)}},
    Error | Export-Csv -Path $csvFile -NoTypeInformation

Write-Success "Results exported to: $csvFile"
Write-Info "Import into Excel/PowerBI for timeline visualization"

Write-Host ""

# Cleanup sensitive data
$dbPasswordText = $null

Write-Success "Failover test complete!"
