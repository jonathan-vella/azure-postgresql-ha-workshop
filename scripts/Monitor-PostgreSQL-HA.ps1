<#
.SYNOPSIS
    Real-time monitoring dashboard for PostgreSQL Zone-Redundant HA status.

.DESCRIPTION
    Provides continuous monitoring of:
    - Database availability and response time
    - HA status and zone configuration
    - Transaction throughput
    - Connection counts
    - Replication lag (if applicable)

.PARAMETER ResourceGroupName
    The resource group containing the PostgreSQL server.

.PARAMETER ServerName
    Optional. PostgreSQL server name. Auto-discovered if not specified.

.PARAMETER RefreshInterval
    Dashboard refresh interval in seconds. Default is 5.

.EXAMPLE
    .\Monitor-PostgreSQL-HA.ps1 -ResourceGroupName "rg-saif-pgsql-swc-01"

.EXAMPLE
    .\Monitor-PostgreSQL-HA.ps1 -ResourceGroupName "rg-saif-pgsql-swc-01" -RefreshInterval 10

.NOTES
    Author: SAIF Team
    Version: 2.0.0
    Date: 2025-10-08
    Requires: Azure CLI, PowerShell 7+
    Press Ctrl+C to exit
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$false)]
    [string]$ServerName,
    
    [Parameter(Mandatory=$false)]
    [int]$RefreshInterval = 5
)

$ErrorActionPreference = "Stop"

#region Helper Functions

function Get-Timestamp {
    return Get-Date -Format "yyyy-MM-dd HH:mm:ss"
}

function Write-ColoredStatus {
    param(
        [string]$Label,
        [string]$Value,
        [string]$Status  # 'good', 'warning', 'error', 'info'
    )
    
    $color = switch ($Status) {
        'good' { 'Green' }
        'warning' { 'Yellow' }
        'error' { 'Red' }
        'info' { 'Cyan' }
        default { 'White' }
    }
    
    Write-Host "  $Label" -NoNewline -ForegroundColor Gray
    Write-Host $Value -ForegroundColor $color
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

function Get-DatabaseMetrics {
    param(
        [string]$serverFqdn,
        [string]$dbUser,
        [string]$dbPasswordText
    )
    
    try {
        # Response time test
        $startTime = Get-Date
        $pingResult = Invoke-DockerPsql -ServerFqdn $serverFqdn -Username $dbUser `
            -Database "saifdb" -Password $dbPasswordText -Query "SELECT 1;" -TupleOnly
        $responseTime = ((Get-Date) - $startTime).TotalMilliseconds
        
        if (-not $pingResult.Success) {
            return @{
                Available = $false
                ResponseTime = 0
                Error = $pingResult.Output
            }
        }
        
        # Get connection count
        $connectionQuery = "SELECT count(*) FROM pg_stat_activity WHERE datname = 'saifdb';"
        $connResult = Invoke-DockerPsql -ServerFqdn $serverFqdn -Username $dbUser `
            -Database "saifdb" -Password $dbPasswordText -Query $connectionQuery -TupleOnly
        $connectionCount = $connResult.Output.Trim()
        
        # Get transaction count
        $transactionQuery = "SELECT COUNT(*) FROM transactions;"
        $txResult = Invoke-DockerPsql -ServerFqdn $serverFqdn -Username $dbUser `
            -Database "saifdb" -Password $dbPasswordText -Query $transactionQuery -TupleOnly
        $transactionCount = $txResult.Output.Trim()
        
        # Get database size
        $sizeQuery = "SELECT pg_size_pretty(pg_database_size('saifdb'));"
        $sizeResult = Invoke-DockerPsql -ServerFqdn $serverFqdn -Username $dbUser `
            -Database "saifdb" -Password $dbPasswordText -Query $sizeQuery -TupleOnly
        $dbSize = $sizeResult.Output.Trim()
        
        # Get recent TPS (last minute)
        $tpsQuery = "SELECT COUNT(*) FROM transactions WHERE transaction_date >= NOW() - INTERVAL '1 minute';"
        $tpsResult = Invoke-DockerPsql -ServerFqdn $serverFqdn -Username $dbUser `
            -Database "saifdb" -Password $dbPasswordText -Query $tpsQuery -TupleOnly
        $recentTransactions = $tpsResult.Output.Trim()
        $tps = [Math]::Round([int]$recentTransactions / 60, 2)
        
        return @{
            Available = $true
            ResponseTime = [Math]::Round($responseTime, 2)
            ConnectionCount = [int]$connectionCount
            TransactionCount = [int]$transactionCount
            DatabaseSize = $dbSize
            RecentTPS = $tps
            Error = $null
        }
        
    } catch {
        return @{
            Available = $false
            ResponseTime = 0
            Error = $_.Exception.Message
        }
    }
}

#endregion

#region Main Script

# Clear screen and hide cursor
Clear-Host
[Console]::CursorVisible = $false

# Check Azure CLI
try {
    $currentAccount = az account show --query "{name:name}" -o json | ConvertFrom-Json
} catch {
    Write-Host "❌ Please run 'az login' first" -ForegroundColor Red
    exit 1
}

# Discover PostgreSQL server
if (-not $ServerName) {
    Write-Host "🔍 Discovering PostgreSQL server..." -ForegroundColor Yellow
    $servers = az postgres flexible-server list `
        --resource-group $ResourceGroupName `
        --query "[?contains(name, 'saif') || contains(name, 'psql')].{name:name, ha:highAvailability.mode}" `
        --output json | ConvertFrom-Json
    
    if ($servers.Count -eq 0) {
        Write-Host "❌ No PostgreSQL servers found in resource group" -ForegroundColor Red
        exit 1
    }
    
    if ($servers.Count -eq 1) {
        $ServerName = $servers[0].name
        Write-Host "   Found: $ServerName" -ForegroundColor Gray
    } else {
        Write-Host "Multiple servers found:" -ForegroundColor Yellow
        for ($i = 0; $i -lt $servers.Count; $i++) {
            Write-Host "  [$i] $($servers[$i].name) (HA: $($servers[$i].ha))" -ForegroundColor White
        }
        $selection = Read-Host "Select server index"
        $ServerName = $servers[[int]$selection].name
    }
}

# Get initial server details
Write-Host "🔍 Getting server details..." -ForegroundColor Yellow
try {
    $server = az postgres flexible-server show `
        --resource-group $ResourceGroupName `
        --name $ServerName `
        --output json | ConvertFrom-Json
    
    if (-not $server) {
        Write-Host "❌ Failed to retrieve server details" -ForegroundColor Red
        exit 1
    }
    
    $serverFqdn = $server.fullyQualifiedDomainName
    $haMode = $server.highAvailability.mode
    
    if ([string]::IsNullOrWhiteSpace($serverFqdn)) {
        Write-Host "❌ Server FQDN is empty. Server object:" -ForegroundColor Red
        Write-Host ($server | ConvertTo-Json -Depth 2) -ForegroundColor Gray
        exit 1
    }
    
    Write-Host "✅ Connected to: $ServerName" -ForegroundColor Green
    Write-Host "   FQDN: $serverFqdn" -ForegroundColor Gray
    Write-Host ""
} catch {
    Write-Host "❌ Error retrieving server details: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Get database credentials
Write-Host "📝 Enter database credentials:" -ForegroundColor Cyan
$dbUser = Read-Host "Username (default: saifadmin)"
if ([string]::IsNullOrWhiteSpace($dbUser)) {
    $dbUser = "saifadmin"
}

$dbPassword = Read-Host "Password" -AsSecureString
$dbPasswordText = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($dbPassword)
)

# Check Docker availability
Write-Host "� Checking Docker..." -ForegroundColor Yellow
try {
    $dockerCheck = docker --version 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Docker is not available. Please install Docker Desktop." -ForegroundColor Red
        Write-Host "   Download: https://www.docker.com/products/docker-desktop" -ForegroundColor Gray
        exit 1
    }
    Write-Host "✅ Docker available: $dockerCheck" -ForegroundColor Green
} catch {
    Write-Host "❌ Docker is not available. Please install Docker Desktop." -ForegroundColor Red
    exit 1
}

# Test initial connection using Docker
Write-Host "🔌 Testing database connection..." -ForegroundColor Yellow
$testResult = Invoke-DockerPsql -ServerFqdn $serverFqdn -Username $dbUser `
    -Database "saifdb" -Password $dbPasswordText -Query "SELECT 1;" -TupleOnly

if (-not $testResult.Success) {
    Write-Host "❌ Connection failed: $($testResult.Output)" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Connection successful!" -ForegroundColor Green
Write-Host ""
Write-Host "📊 Starting monitoring dashboard..." -ForegroundColor Cyan
Write-Host "   Press Ctrl+C to exit" -ForegroundColor Gray
Write-Host ""
Start-Sleep -Seconds 2

# Monitoring loop
$iteration = 0
$previousTransactionCount = 0
$previousCheckTime = Get-Date

try {
    while ($true) {
        $iteration++
        $currentTime = Get-Date
        
        # Clear screen for dashboard
        Clear-Host
        
        # Header
        Write-Host "╔════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
        Write-Host "║        SAIF-PostgreSQL HA Monitoring Dashboard                         ║" -ForegroundColor White -BackgroundColor DarkBlue
        Write-Host "╚════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
        Write-Host ""
        
        Write-Host "🕐 Timestamp: $(Get-Timestamp)" -ForegroundColor Gray
        Write-Host "🔄 Refresh: $RefreshInterval seconds | Iteration: $iteration" -ForegroundColor Gray
        Write-Host ""
        
        # Get Azure server status
        try {
            $server = az postgres flexible-server show `
                --resource-group $ResourceGroupName `
                --name $ServerName `
                --output json | ConvertFrom-Json
            
            $serverState = $server.state
            $haState = $server.highAvailability.state
            $primaryZone = $server.availabilityZone
            $standbyZone = $server.highAvailability.standbyAvailabilityZone
            $storage = $server.storage
            
            # Server Status Section
            Write-Host "┌─ 🖥️  Server Status ────────────────────────────────────────────────────┐" -ForegroundColor Cyan
            
            $serverStatus = if ($serverState -eq "Ready") { "good" } else { "warning" }
            Write-ColoredStatus "Server State:        " $serverState $serverStatus
            Write-ColoredStatus "FQDN:                " $serverFqdn "info"
            Write-ColoredStatus "Storage Used:        " "$($storage.storageSizeGB) GB" "info"
            Write-Host "└───────────────────────────────────────────────────────────────────────┘" -ForegroundColor Cyan
            Write-Host ""
            
            # HA Status Section
            Write-Host "┌─ ⚡ High Availability ──────────────────────────────────────────────────┐" -ForegroundColor Cyan
            
            $haStatus = switch ($haState) {
                "Healthy" { "good" }
                "CreatingStandby" { "warning" }
                "ReplicatingData" { "warning" }
                "FailingOver" { "warning" }
                default { "error" }
            }
            
            Write-ColoredStatus "HA Mode:             " $haMode "info"
            Write-ColoredStatus "HA State:            " $haState $haStatus
            Write-ColoredStatus "Primary Zone:        " "Zone $primaryZone" "info"
            Write-ColoredStatus "Standby Zone:        " "Zone $standbyZone" "info"
            
            if ($haMode -eq "ZoneRedundant") {
                Write-ColoredStatus "RPO:                 " "0 seconds (zero data loss)" "good"
                Write-ColoredStatus "RTO:                 " "60-120 seconds" "good"
                Write-ColoredStatus "SLA:                 " "99.99% uptime" "good"
            }
            
            Write-Host "└───────────────────────────────────────────────────────────────────────┘" -ForegroundColor Cyan
            Write-Host ""
            
        } catch {
            Write-Host "┌─ ⚠️  Server Status Error ──────────────────────────────────────────────┐" -ForegroundColor Red
            Write-Host "  Failed to retrieve server status from Azure" -ForegroundColor Red
            Write-Host "└───────────────────────────────────────────────────────────────────────┘" -ForegroundColor Red
            Write-Host ""
        }
        
        # Get database metrics
        $metrics = Get-DatabaseMetrics -serverFqdn $serverFqdn -dbUser $dbUser -dbPasswordText $dbPasswordText
        
        # Database Status Section
        Write-Host "┌─ 🗄️  Database Metrics ─────────────────────────────────────────────────┐" -ForegroundColor Cyan
        
        if ($metrics.Available) {
            Write-ColoredStatus "Availability:        " "✅ Online" "good"
            
            $responseStatus = if ($metrics.ResponseTime -lt 100) { "good" } elseif ($metrics.ResponseTime -lt 500) { "warning" } else { "error" }
            Write-ColoredStatus "Response Time:       " "$($metrics.ResponseTime) ms" $responseStatus
            
            Write-ColoredStatus "Active Connections:  " $metrics.ConnectionCount "info"
            Write-ColoredStatus "Total Transactions:  " $metrics.TransactionCount "info"
            Write-ColoredStatus "Database Size:       " $metrics.DatabaseSize "info"
            
            # Calculate TPS since last check
            if ($previousTransactionCount -gt 0) {
                $newTransactions = $metrics.TransactionCount - $previousTransactionCount
                $elapsedSeconds = ($currentTime - $previousCheckTime).TotalSeconds
                $currentTPS = if ($elapsedSeconds -gt 0) { [Math]::Round($newTransactions / $elapsedSeconds, 2) } else { 0 }
                
                $tpsStatus = if ($currentTPS -gt 0) { "good" } else { "info" }
                Write-ColoredStatus "Current TPS:         " "$currentTPS tx/sec" $tpsStatus
            }
            
            Write-ColoredStatus "Recent TPS (1min):   " "$($metrics.RecentTPS) tx/sec" "info"
            
            $previousTransactionCount = $metrics.TransactionCount
            $previousCheckTime = $currentTime
            
        } else {
            Write-ColoredStatus "Availability:        " "❌ Offline" "error"
            Write-ColoredStatus "Error:               " $metrics.Error "error"
            Write-Host ""
            Write-Host "  ⚠️  Database is unavailable - possible failover in progress!" -ForegroundColor Yellow
        }
        
        Write-Host "└───────────────────────────────────────────────────────────────────────┘" -ForegroundColor Cyan
        Write-Host ""
        
        # Status Summary
        if ($metrics.Available) {
            if ($haState -eq "Healthy") {
                Write-Host "🟢 System Status: " -NoNewline -ForegroundColor Green
                Write-Host "All systems operational" -ForegroundColor White
            } elseif ($haState -eq "FailingOver") {
                Write-Host "🟡 System Status: " -NoNewline -ForegroundColor Yellow
                Write-Host "FAILOVER IN PROGRESS" -ForegroundColor White
            } else {
                Write-Host "🟡 System Status: " -NoNewline -ForegroundColor Yellow
                Write-Host "HA state: $haState" -ForegroundColor White
            }
        } else {
            Write-Host "🔴 System Status: " -NoNewline -ForegroundColor Red
            Write-Host "Database unavailable" -ForegroundColor White
        }
        
        Write-Host ""
        Write-Host "Press Ctrl+C to exit..." -ForegroundColor DarkGray
        
        # Wait for next refresh
        Start-Sleep -Seconds $RefreshInterval
    }
} finally {
    # Cleanup
    [Console]::CursorVisible = $true
    $env:PGPASSWORD = $null
    $dbPasswordText = $null
    Clear-Host
    Write-Host "👋 Monitoring stopped." -ForegroundColor Cyan
}

#endregion
