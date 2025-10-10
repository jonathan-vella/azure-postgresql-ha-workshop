<#
.SYNOPSIS
    Resilient monitoring for Azure Container Instances load tests

.DESCRIPTION
    Monitors ACI container with automatic retry, progress tracking, and log retrieval.
    Handles Azure Logs API failures gracefully.

.PARAMETER ResourceGroup
    Azure resource group name

.PARAMETER ContainerName
    Container instance name

.PARAMETER PollIntervalSeconds
    Seconds between status checks (default: 5)

.EXAMPLE
    .\Monitor-LoadGenerator-Resilient.ps1 -ResourceGroup "rg-saif-pgsql-swc-01" -ContainerName "aci-loadgen-20251010-200833"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroup,

    [Parameter(Mandatory=$true)]
    [string]$ContainerName,

    [Parameter(Mandatory=$false)]
    [int]$PollIntervalSeconds = 5,
    
    [Parameter(Mandatory=$false)]
    [string]$PostgreSQLServer = "",
    
    [Parameter(Mandatory=$false)]
    [string]$DatabaseName = "",
    
    [Parameter(Mandatory=$false)]
    [string]$AdminUser = "",
    
    [Parameter(Mandatory=$false)]
    [string]$AdminPassword = ""
)

$ErrorActionPreference = "Continue"

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "📊 RESILIENT LOAD GENERATOR MONITOR" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "Container: $ContainerName" -ForegroundColor Gray
Write-Host "Resource Group: $ResourceGroup" -ForegroundColor Gray
Write-Host "Poll Interval: $PollIntervalSeconds seconds" -ForegroundColor Gray

$enableDatabaseMonitoring = $false
if ($PostgreSQLServer -and $DatabaseName -and $AdminUser -and $AdminPassword) {
    Write-Host "Database Monitoring: Enabled ✅" -ForegroundColor Green
    $enableDatabaseMonitoring = $true
} else {
    Write-Host "Database Monitoring: Disabled (no credentials provided)" -ForegroundColor DarkGray
}

Write-Host ""

$startMonitoring = Get-Date
$lastLogAttempt = $null
$lastDbCheck = $null
$logAttempts = 0
$maxLogAttempts = 3
$lastDbTxnCount = 0

function Get-ContainerStatus {
    try {
        $status = az container show `
            --resource-group $ResourceGroup `
            --name $ContainerName `
            --query "{state:instanceView.state,startTime:containers[0].instanceView.currentState.startTime,exitCode:containers[0].instanceView.currentState.exitCode,finishTime:containers[0].instanceView.currentState.finishTime,detailStatus:containers[0].instanceView.currentState.detailStatus}" `
            -o json 2>$null | ConvertFrom-Json
        
        return $status
    }
    catch {
        return $null
    }
}

function Get-DatabaseMetrics {
    param(
        [string]$PostgreSQLServer,
        [string]$DatabaseName,
        [string]$AdminUser,
        [string]$AdminPassword
    )
    
    try {
        $query = "SELECT COUNT(*) as total_txns, MAX(transaction_date) as last_txn FROM transactions WHERE transaction_date > NOW() - INTERVAL '10 minutes'"
        
        $result = az postgres flexible-server execute `
            --name $PostgreSQLServer `
            --admin-user $AdminUser `
            --admin-password $AdminPassword `
            --database-name $DatabaseName `
            --querytext $query `
            -o json 2>$null | ConvertFrom-Json
        
        if ($result -and $result.Count -gt 0) {
            return @{
                TotalTransactions = [int]$result[0].total_txns
                LastTransaction = $result[0].last_txn
            }
        }
    }
    catch {
        return $null
    }
    
    return $null
}

function Try-GetLogs {
    param([int]$MaxLines = 50)
    
    $script:logAttempts++
    
    try {
        Write-Host "   Attempting to fetch logs (attempt $script:logAttempts)..." -ForegroundColor Gray
        
        $logs = az container logs `
            --resource-group $ResourceGroup `
            --name $ContainerName `
            2>&1
        
        if ($LASTEXITCODE -eq 0 -and $logs -notmatch "InternalServerError") {
            # Success! Display last N lines
            $logLines = $logs -split "`n"
            $displayLines = $logLines | Select-Object -Last $MaxLines
            
            Write-Host ""
            Write-Host "─────────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
            Write-Host "📋 LATEST LOGS (last $MaxLines lines):" -ForegroundColor Yellow
            Write-Host "─────────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
            $displayLines | ForEach-Object { Write-Host $_ }
            Write-Host "─────────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
            Write-Host ""
            
            return $true
        }
        else {
            Write-Host "   ⚠️  Azure Logs API error (attempt $script:logAttempts)" -ForegroundColor Yellow
            return $false
        }
    }
    catch {
        Write-Host "   ⚠️  Log fetch failed: $($_.Exception.Message)" -ForegroundColor Yellow
        return $false
    }
}

# Initial status check
Write-Host "▶ Checking initial container status..." -ForegroundColor Yellow
$status = Get-ContainerStatus

if (-not $status) {
    Write-Host "❌ Container not found or not accessible" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Container found" -ForegroundColor Green
Write-Host "   State: $($status.state)" -ForegroundColor Gray
if ($status.startTime) {
    Write-Host "   Started: $($status.startTime)" -ForegroundColor Gray
}

# Try to get initial logs
Write-Host ""
Write-Host "▶ Attempting to fetch initial logs..." -ForegroundColor Yellow
$logsAvailable = Try-GetLogs -MaxLines 30

if (-not $logsAvailable) {
    Write-Host ""
    Write-Host "ℹ️  Live logs not available (Azure API issue)" -ForegroundColor Cyan
    Write-Host "ℹ️  Switching to status-only monitoring..." -ForegroundColor Cyan
    Write-Host ""
}

# Monitor loop
$iteration = 0
$lastState = $status.state

Write-Host "▶ Starting monitoring loop..." -ForegroundColor Yellow
Write-Host "   Press Ctrl+C to stop monitoring" -ForegroundColor Gray
Write-Host ""

while ($true) {
    $iteration++
    $now = Get-Date
    $elapsed = ($now - $startMonitoring).TotalSeconds
    
    # Get current status
    $status = Get-ContainerStatus
    
    if (-not $status) {
        Write-Host "[$($now.ToString('HH:mm:ss'))] ⚠️  Status check failed, retrying..." -ForegroundColor Yellow
        Start-Sleep -Seconds $PollIntervalSeconds
        continue
    }
    
    # State change detection
    if ($status.state -ne $lastState) {
        Write-Host ""
        Write-Host "─────────────────────────────────────────────────────────────────" -ForegroundColor Cyan
        Write-Host "📍 STATE CHANGE: $lastState → $($status.state)" -ForegroundColor Cyan
        Write-Host "─────────────────────────────────────────────────────────────────" -ForegroundColor Cyan
        Write-Host ""
        $lastState = $status.state
        
        # Try to get logs on state change
        if (-not $logsAvailable) {
            $logsAvailable = Try-GetLogs -MaxLines 50
        }
    }
    
    # Display status
    $statusColor = switch ($status.state) {
        "Running" { "Green" }
        "Succeeded" { "Cyan" }
        "Failed" { "Red" }
        default { "Yellow" }
    }
    
    $stateIcon = switch ($status.state) {
        "Running" { "🏃" }
        "Succeeded" { "✅" }
        "Failed" { "❌" }
        "Pending" { "⏳" }
        "Terminated" { "🛑" }
        default { "📊" }
    }
    
    Write-Host "[$($now.ToString('HH:mm:ss'))] $stateIcon  State: " -NoNewline
    Write-Host $status.state -ForegroundColor $statusColor -NoNewline
    Write-Host " | Elapsed: $([math]::Round($elapsed))s" -NoNewline
    
    if ($status.startTime) {
        $start = [DateTime]::Parse($status.startTime)
        $runTime = ([DateTime]::UtcNow - $start).TotalSeconds
        Write-Host " | Runtime: $([math]::Round($runTime))s" -NoNewline
    }
    
    if ($null -ne $status.exitCode) {
        $exitColor = if ($status.exitCode -eq 0) { "Green" } else { "Red" }
        Write-Host " | Exit: " -NoNewline
        Write-Host $status.exitCode -ForegroundColor $exitColor -NoNewline
    }
    
    # Database metrics (if enabled and container is running)
    if ($enableDatabaseMonitoring -and $status.state -eq "Running") {
        $timeSinceLastDbCheck = if ($lastDbCheck) { ($now - $lastDbCheck).TotalSeconds } else { 999 }
        
        if ($timeSinceLastDbCheck -gt 10) {  # Check every 10 seconds
            $lastDbCheck = $now
            $dbMetrics = Get-DatabaseMetrics -PostgreSQLServer $PostgreSQLServer -DatabaseName $DatabaseName -AdminUser $AdminUser -AdminPassword $AdminPassword
            
            if ($dbMetrics) {
                $txnDelta = $dbMetrics.TotalTransactions - $lastDbTxnCount
                if ($lastDbTxnCount -gt 0 -and $txnDelta -gt 0) {
                    $tps = [math]::Round($txnDelta / $timeSinceLastDbCheck, 1)
                    Write-Host " | DB: " -NoNewline
                    Write-Host "$($dbMetrics.TotalTransactions) txns" -ForegroundColor Cyan -NoNewline
                    Write-Host " (~$tps TPS)" -NoNewline
                }
                $lastDbTxnCount = $dbMetrics.TotalTransactions
            }
        }
    }
    
    Write-Host ""
    
    # Check for completion
    if ($status.state -in @("Succeeded", "Failed", "Terminated")) {
        Write-Host ""
        Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host "🏁 CONTAINER COMPLETED" -ForegroundColor Cyan
        Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Final State: " -NoNewline
        Write-Host $status.state -ForegroundColor $statusColor
        
        if ($status.exitCode) {
            $exitColor = if ($status.exitCode -eq 0) { "Green" } else { "Red" }
            Write-Host "Exit Code: " -NoNewline
            Write-Host $status.exitCode -ForegroundColor $exitColor
        }
        
        if ($status.startTime -and $status.finishTime) {
            $start = [DateTime]::Parse($status.startTime)
            $finish = [DateTime]::Parse($status.finishTime)
            $duration = ($finish - $start).TotalSeconds
            Write-Host "Duration: $([math]::Round($duration, 2))s" -ForegroundColor Gray
        }
        
        Write-Host ""
        
        # Final attempt to get logs
        Write-Host "▶ Fetching final logs..." -ForegroundColor Yellow
        $finalLogs = Try-GetLogs -MaxLines 100
        
        if (-not $finalLogs) {
            Write-Host ""
            Write-Host "⚠️  Unable to fetch logs from Azure API" -ForegroundColor Yellow
            Write-Host "ℹ️  Logs may be available in Azure Portal:" -ForegroundColor Cyan
            Write-Host "   https://portal.azure.com/#blade/Microsoft_Azure_ContainerInstances/ContainerInstanceMenuBlade/logs/id/%2Fsubscriptions%2F{subscriptionId}%2FresourceGroups%2F$ResourceGroup%2Fproviders%2FMicrosoft.ContainerInstance%2FcontainerGroups%2F$ContainerName" -ForegroundColor Gray
        }
        
        Write-Host ""
        Write-Host "✅ Monitoring complete" -ForegroundColor Green
        break
    }
    
    # Periodic log check for running containers
    if ($status.state -eq "Running" -and $logsAvailable) {
        $timeSinceLastLog = if ($lastLogAttempt) { ($now - $lastLogAttempt).TotalSeconds } else { 999 }
        
        if ($timeSinceLastLog -gt 30) {  # Try every 30 seconds
            $lastLogAttempt = $now
            Write-Host "   Refreshing logs..." -ForegroundColor Gray
            Try-GetLogs -MaxLines 20 | Out-Null
        }
    }
    
    Start-Sleep -Seconds $PollIntervalSeconds
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
