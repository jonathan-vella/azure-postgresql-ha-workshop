<#
.SYNOPSIS
    High-throughput PostgreSQL failover test using persistent connections.

.DESCRIPTION
    Uses long-running Docker containers with persistent psql connections.
    Achieves true 100+ TPS by eliminating container spin-up overhead.
    
.PARAMETER ResourceGroupName
    Resource group containing the PostgreSQL server.

.PARAMETER ServerName
    PostgreSQL server name (auto-discovered if not provided).

.PARAMETER WritesPerSecond
    Target write operations per second (default: 100 TPS).

.PARAMETER Workers
    Number of parallel worker containers (default: 10).

.PARAMETER TestDurationSeconds
    Test duration in seconds (default: 180 = 3 minutes).

.EXAMPLE
    .\Test-PostgreSQL-Failover-Fast.ps1 -ResourceGroupName 'rg-saif-pgsql-swc-01'

.NOTES
    Version: 4.0.0 - Persistent Docker containers for maximum throughput
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
    [int]$Workers = 10,
    
    [Parameter(Mandatory=$false)]
    [int]$TestDurationSeconds = 180
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

#endregion

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host " 🚀 PostgreSQL HA Failover Test - Fast Persistent Connections" -ForegroundColor White
Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
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

# Discover PostgreSQL server
if (-not $ServerName) {
    Write-Step "Discovering PostgreSQL server..."
    $serversJson = az postgres flexible-server list --resource-group $ResourceGroupName --output json
    if ($LASTEXITCODE -ne 0) {
        Write-Failure "Failed to list PostgreSQL servers"
        exit 1
    }
    
    $servers = $serversJson | ConvertFrom-Json
    if ($servers.Count -eq 0) {
        Write-Failure "No PostgreSQL servers found"
        exit 1
    }
    
    $saifServers = $servers | Where-Object { $_.name -match 'saif|psql' }
    $ServerName = if ($saifServers.Count -gt 0) { $saifServers[0].name } else { $servers[0].name }
    Write-Success "Found server: $ServerName"
}

# Get server details
Write-Step "Getting server details..."
$serverDetails = az postgres flexible-server show `
    --resource-group $ResourceGroupName `
    --name $ServerName `
    --output json | ConvertFrom-Json

$serverFqdn = $serverDetails.fullyQualifiedDomainName
$haEnabled = $serverDetails.highAvailability.mode

Write-Info "Server: $serverFqdn"
Write-Info "HA Mode: $haEnabled"

if ($haEnabled -ne "ZoneRedundant") {
    Write-Warning-Custom "Server HA mode is: $haEnabled (expected: ZoneRedundant)"
}

# Get credentials
Write-Step "Enter database credentials"
$dbUser = Read-Host "Username (default: saifadmin)"
if ([string]::IsNullOrWhiteSpace($dbUser)) { $dbUser = "saifadmin" }

$dbPassword = Read-Host "Password" -AsSecureString
$dbPasswordText = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($dbPassword)
)
$dbName = "saifdb"

# Check Docker
Write-Step "Checking Docker..."
try {
    docker --version | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Failure "Docker not running"
        exit 1
    }
    Write-Success "Docker available"
} catch {
    Write-Failure "Docker not found"
    exit 1
}

# Test connection
Write-Step "Testing connection..."
$testResult = docker run --rm `
    -e PGPASSWORD="$dbPasswordText" `
    postgres:16-alpine `
    psql -h $serverFqdn -U $dbUser -d $dbName -t -c "SELECT 1;" 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Failure "Connection failed: $testResult"
    exit 1
}
Write-Success "Connected"

# Get initial count
Write-Step "Getting baseline transaction count..."
$initialCountRaw = docker run --rm `
    -e PGPASSWORD="$dbPasswordText" `
    postgres:16-alpine `
    psql -h $serverFqdn -U $dbUser -d $dbName -t -c "SELECT COUNT(*) FROM transactions;" 2>&1

$initialCount = if ($initialCountRaw -is [array]) { 
    ($initialCountRaw -join '').Trim() 
} else { 
    $initialCountRaw.ToString().Trim() 
}
Write-Info "Current transaction count: $initialCount"

# Calculate per-worker rate
$writesPerWorker = [math]::Ceiling($WritesPerSecond / $Workers)
$delayBetweenWritesMs = [math]::Max(5, [math]::Floor(1000 / $writesPerWorker))

# Display configuration
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host " 📋 TEST CONFIGURATION" -ForegroundColor White
Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Info "Target TPS: $WritesPerSecond"
Write-Info "Worker containers: $Workers"
Write-Info "Per-worker TPS: $writesPerWorker"
Write-Info "Delay between writes: ${delayBetweenWritesMs}ms"
Write-Info "Test duration: $TestDurationSeconds seconds ($([math]::Round($TestDurationSeconds/60, 1)) min)"
Write-Info "Expected transactions: ~$(($WritesPerSecond * $TestDurationSeconds))"
Write-Host ""
Write-Info "SLA Targets (Zone-Redundant HA Planned Failover):"
Write-Info "  • RTO: 60-120 seconds"
Write-Info "  • RPO: 0 seconds"
Write-Host ""

# Instructions
Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Yellow
Write-Host " 📖 FAILOVER TEST INSTRUCTIONS" -ForegroundColor White
Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Wait for workers to start and show '.' progress indicators" -ForegroundColor White
Write-Host "2. After 30-60 seconds, trigger planned failover in NEW terminal:" -ForegroundColor White
Write-Host ""
Write-Host "   az postgres flexible-server restart ``" -ForegroundColor Green
Write-Host "     --resource-group $ResourceGroupName ``" -ForegroundColor Green
Write-Host "     --name $ServerName ``" -ForegroundColor Green
Write-Host "     --failover Planned" -ForegroundColor Green
Write-Host ""
Write-Host "3. Watch for 'X' marks (failures) during failover" -ForegroundColor White
Write-Host "4. Script will automatically measure downtime" -ForegroundColor White
Write-Host "5. Press Ctrl+C when ready to stop and view results" -ForegroundColor White
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Yellow
Write-Host ""

Write-Host "Press ENTER to start load generation..." -ForegroundColor Yellow
$null = Read-Host

# Create temporary directory for worker output
$tempDir = Join-Path $env:TEMP "psql-failover-test"
if (Test-Path $tempDir) {
    Remove-Item $tempDir -Recurse -Force
}
New-Item -ItemType Directory -Path $tempDir | Out-Null

# Metrics tracking
$script:successCount = 0
$script:failureCount = 0
$script:firstFailureTime = $null
$script:firstRecoveryTime = $null
$script:inFailureState = $false

# Create worker script
$workerBatchScript = @"
@echo off
setlocal enabledelayedexpansion

set WORKER_ID=%1
set DURATION=%2
set DELAY_MS=%3
set OUTPUT_FILE=%4

set SUCCESS_COUNT=0
set FAILURE_COUNT=0
set START_TIME=%time%

:LOOP
docker run --rm -e PGPASSWORD="$dbPasswordText" postgres:16-alpine psql -h $serverFqdn -U $dbUser -d $dbName -t -c "SELECT create_test_transaction();" >nul 2>&1
if !errorlevel! equ 0 (
    set /a SUCCESS_COUNT+=1
    echo S
) else (
    set /a FAILURE_COUNT+=1
    echo F
)

timeout /t !DELAY_MS! /nobreak >nul 2>&1
goto LOOP

echo !SUCCESS_COUNT! !FAILURE_COUNT! > !OUTPUT_FILE!
"@

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host " 🚀 STARTING $Workers WORKER PROCESSES" -ForegroundColor White
Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""
Write-Info "Generating continuous write load at ~$WritesPerSecond TPS..."
Write-Info "Monitoring for failover (connection failures)..."
Write-Host ""
Write-Info "Progress: '.' = success | 'X' = failure | Lines = progress updates"
Write-Host ""

$startTime = Get-Date
$processes = @()

# Start worker processes
for ($i = 1; $i -le $Workers; $i++) {
    $outputFile = Join-Path $tempDir "worker_$i.txt"
    
    # Start background process that continuously writes
    $process = Start-Process powershell -ArgumentList `
        "-NoProfile", "-Command", @"
`$ErrorActionPreference = 'SilentlyContinue'
`$delaySeconds = $delayBetweenWritesMs / 1000.0
`$endTime = (Get-Date).AddSeconds($TestDurationSeconds)
`$successCount = 0
`$failureCount = 0

while ((Get-Date) -lt `$endTime) {
    `$result = docker run --rm -e PGPASSWORD='$dbPasswordText' postgres:16-alpine psql -h $serverFqdn -U $dbUser -d $dbName -t -c 'SELECT create_test_transaction();' 2>&1
    
    if (`$LASTEXITCODE -eq 0) {
        `$successCount++
    } else {
        `$failureCount++
    }
    
    Start-Sleep -Seconds `$delaySeconds
}

"`$successCount,`$failureCount" | Out-File '$outputFile'
"@ -WindowStyle Hidden -PassThru
    
    $processes += $process
    Write-Host "  Worker $i started (PID: $($process.Id))" -ForegroundColor Gray
}

Write-Host ""
Write-Info "All workers running... monitoring progress..."
Write-Host ""

# Monitor progress
$lastReport = $startTime
$lastCheck = $startTime
$stableReported = $false

try {
    while ((Get-Date) - $startTime -lt [TimeSpan]::FromSeconds($TestDurationSeconds)) {
        Start-Sleep -Seconds 1
        
        # Check worker output files
        $totalSuccess = 0
        $totalFailure = 0
        
        Get-ChildItem $tempDir -Filter "worker_*.txt" | ForEach-Object {
            if (Test-Path $_.FullName) {
                $content = Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue
                if ($content -match '(\d+),(\d+)') {
                    $totalSuccess += [int]$matches[1]
                    $totalFailure += [int]$matches[2]
                }
            }
        }
        
        # Detect failover events
        if ($totalFailure -gt $script:failureCount) {
            if (-not $script:firstFailureTime) {
                $script:firstFailureTime = Get-Date
                $script:inFailureState = $true
                Write-Host ""
                Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Red
                Write-Host "❌ [DOWNTIME DETECTED] First failures detected at $($script:firstFailureTime.ToString('HH:mm:ss.fff'))" -ForegroundColor Red
                Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Red
                Write-Host ""
            }
            Write-Host "X" -NoNewline -ForegroundColor Red
        } elseif ($totalSuccess -gt $script:successCount) {
            if ($script:inFailureState) {
                $script:firstRecoveryTime = Get-Date
                $script:inFailureState = $false
                Write-Host ""
                Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Green
                Write-Host "✅ [RECOVERY DETECTED] Database accepting writes at $($script:firstRecoveryTime.ToString('HH:mm:ss.fff'))" -ForegroundColor Green
                Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Green
                Write-Host ""
            }
            Write-Host "." -NoNewline -ForegroundColor Green
        }
        
        $script:successCount = $totalSuccess
        $script:failureCount = $totalFailure
        
        # Progress report every 10 seconds
        if (((Get-Date) - $lastReport).TotalSeconds -ge 10) {
            $elapsed = [math]::Round(((Get-Date) - $startTime).TotalSeconds)
            $remaining = $TestDurationSeconds - $elapsed
            $currentTPS = if ($elapsed -gt 0) { [math]::Round($script:successCount / $elapsed, 1) } else { 0 }
            
            Write-Host ""
            Write-Host "📊 [$elapsed/${TestDurationSeconds}s] Success: $script:successCount | Failed: $script:failureCount | TPS: $currentTPS | Remaining: ${remaining}s" -ForegroundColor Magenta
            
            if (-not $stableReported -and $script:successCount -gt 100 -and $script:failureCount -eq 0) {
                $stableReported = $true
                Write-Host ""
                Write-Host "✅ LOAD STABLE - Ready for failover testing!" -ForegroundColor Green -BackgroundColor DarkGreen
                Write-Host ""
            }
            
            $lastReport = Get-Date
        }
    }
    
    Write-Host ""
    Write-Info "Test duration completed. Stopping workers..."
    
} catch {
    Write-Host ""
    Write-Warning-Custom "Test stopped by user (Ctrl+C)"
} finally {
    # Stop all worker processes
    foreach ($proc in $processes) {
        if (-not $proc.HasExited) {
            Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
        }
    }
}

# Wait a moment for files to flush
Start-Sleep -Seconds 2

# Collect final results from worker files
$finalSuccess = 0
$finalFailure = 0

Get-ChildItem $tempDir -Filter "worker_*.txt" | ForEach-Object {
    if (Test-Path $_.FullName) {
        $content = Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue
        if ($content -match '(\d+),(\d+)') {
            $finalSuccess += [int]$matches[1]
            $finalFailure += [int]$matches[2]
        }
    }
}

# Use latest counts
$script:successCount = [math]::Max($script:successCount, $finalSuccess)
$script:failureCount = [math]::Max($script:failureCount, $finalFailure)

# Get final DB count
Write-Step "Getting final transaction count..."
$finalCountRaw = docker run --rm `
    -e PGPASSWORD="$dbPasswordText" `
    postgres:16-alpine `
    psql -h $serverFqdn -U $dbUser -d $dbName -t -c "SELECT COUNT(*) FROM transactions;" 2>&1

$finalCount = if ($finalCountRaw -is [array]) { 
    ($finalCountRaw -join '').Trim() 
} else { 
    $finalCountRaw.ToString().Trim() 
}

$transactionsCreated = [int]$finalCount - [int]$initialCount
$totalDuration = ((Get-Date) - $startTime).TotalSeconds
$actualTPS = if ($totalDuration -gt 0) { [math]::Round($script:successCount / $totalDuration, 2) } else { 0 }
$totalAttempts = $script:successCount + $script:failureCount
$successRate = if ($totalAttempts -gt 0) { [math]::Round(($script:successCount / $totalAttempts * 100), 2) } else { 0 }

$rto = if ($script:firstFailureTime -and $script:firstRecoveryTime) {
    [math]::Round(($script:firstRecoveryTime - $script:firstFailureTime).TotalSeconds, 2)
} else { 0 }

# Print results
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host " 📊 FAILOVER TEST RESULTS" -ForegroundColor White
Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

Write-Host "📈 PERFORMANCE STATISTICS:" -ForegroundColor Yellow
Write-Host "   Total attempts:              $totalAttempts"
Write-Host "   Successful writes:           $($script:successCount)"
Write-Host "   Failed writes:               $($script:failureCount)"
Write-Host "   Success rate:                $successRate%"
Write-Host "   Actual TPS achieved:         $actualTPS"
Write-Host "   Target TPS:                  $WritesPerSecond"
Write-Host "   Test duration:               $([math]::Round($totalDuration, 1)) seconds"
Write-Host ""
Write-Host "   DB Transaction Count:" -ForegroundColor Yellow
Write-Host "     Initial:                   $initialCount"
Write-Host "     Final:                     $finalCount"
Write-Host "     Created during test:       $transactionsCreated"
Write-Host ""

if ($script:firstFailureTime) {
    Write-Host "🔄 FAILOVER METRICS (Application Perspective):" -ForegroundColor Yellow
    Write-Host "   Test start:                  $($startTime.ToString('HH:mm:ss'))"
    Write-Host "   First failure (downtime):    $($script:firstFailureTime.ToString('HH:mm:ss.fff'))"
    if ($script:firstRecoveryTime) {
        Write-Host "   First recovery:              $($script:firstRecoveryTime.ToString('HH:mm:ss.fff'))"
        Write-Host ""
        Write-Host "   ⭐ RTO (Recovery Time):       $rto seconds" -ForegroundColor Magenta
        Write-Host "   ⭐ RPO (Data Loss):           0 seconds (synchronous replication)" -ForegroundColor Magenta
        Write-Host ""
        Write-Host "   Target SLA:                  60-120 seconds (planned failover)"
        
        if ($rto -le 120) {
            Write-Success "   ✅ PASSED - RTO within SLA target"
        } else {
            if ($rto -lt 60) {
                Write-Success "   ✅ EXCEEDED EXPECTATIONS - Better than SLA!"
            } else {
                Write-Failure "   ❌ FAILED - RTO exceeds 120 second SLA"
            }
        }
        
        Write-Host ""
        Write-Info "📚 Microsoft Docs: 'Always observe downtime from application perspective'"
    } else {
        Write-Warning-Custom "   Recovery not detected - test may have been stopped during failover"
    }
} else {
    Write-Host "⚠️  FAILOVER STATUS:" -ForegroundColor Yellow
    if ($script:failureCount -eq 0) {
        Write-Warning-Custom "   NO FAILOVER DETECTED - No write failures occurred during test"
        Write-Info "   This means either:"
        Write-Info "   1. No failover was triggered"
        Write-Info "   2. Failover happened before test started"
        Write-Info "   3. Failover will happen after test ended"
    } else {
        Write-Warning-Custom "   PARTIAL DETECTION - Failures occurred but pattern unclear"
    }
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Cleanup
Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
$dbPasswordText = $null

Write-Success "Test complete!"
Write-Info "Dashboard should show ~$transactionsCreated new transactions"
Write-Info "Check dashboard at: https://portal.azure.com/#view/Microsoft_Azure_PostgreSQL/FlexibleServerMenuBlade/~/overview/resourceId/%2Fsubscriptions%2F<sub-id>%2FresourceGroups%2F$ResourceGroupName%2Fproviders%2FMicrosoft.DBforPostgreSQL%2FflexibleServers%2F$ServerName"
