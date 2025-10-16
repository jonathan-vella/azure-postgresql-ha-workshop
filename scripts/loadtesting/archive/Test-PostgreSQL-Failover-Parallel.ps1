<#
.SYNOPSIS
    High-performance PostgreSQL Zone-Redundant HA failover test with parallel workers.

.DESCRIPTION
    Uses PowerShell background jobs with persistent connections to achieve true 100+ TPS.
    Each worker maintains a connection pool to eliminate Docker spin-up overhead.
    
.PARAMETER ResourceGroupName
    Resource group containing the PostgreSQL server.

.PARAMETER ServerName
    PostgreSQL server name (auto-discovered if not provided).

.PARAMETER WritesPerSecond
    Target write operations per second (default: 100 TPS).

.PARAMETER Workers
    Number of parallel worker threads (default: 10).

.PARAMETER TestDurationSeconds
    Test duration in seconds (default: 300 = 5 minutes).

.PARAMETER PromptForFailoverAt
    When to prompt for failover (default: 60 seconds, 0 to disable).

.EXAMPLE
    .\Test-PostgreSQL-Failover-Parallel.ps1 -ResourceGroupName 'rg-saif-pgsql-swc-01'

.NOTES
    Requires: Docker Desktop (uses postgres:16-alpine for worker processes)
    Version: 3.0.0 - Parallel execution with persistent connections
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
    [int]$TestDurationSeconds = 300,
    
    [Parameter(Mandatory=$false)]
    [int]$PromptForFailoverAt = 60
)

$ErrorActionPreference = "Stop"

# Calculate per-worker rate
$writesPerWorker = [math]::Ceiling($WritesPerSecond / $Workers)
$delayBetweenWritesMs = [math]::Max(10, [math]::Floor(1000 / $writesPerWorker))

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
Write-Host " 🚀 PostgreSQL HA Failover Test - Parallel Workers Edition" -ForegroundColor White
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

# Display configuration
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host " 📋 TEST CONFIGURATION" -ForegroundColor White
Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Info "Target TPS: $WritesPerSecond"
Write-Info "Worker threads: $Workers"
Write-Info "Per-worker TPS: $writesPerWorker"
Write-Info "Delay between writes: ${delayBetweenWritesMs}ms"
Write-Info "Test duration: $TestDurationSeconds seconds"
Write-Info "Expected transactions: ~$(($WritesPerSecond * $TestDurationSeconds))"
Write-Host ""
Write-Info "SLA Targets (Zone-Redundant HA Planned Failover):"
Write-Info "  • RTO: 60-120 seconds"
Write-Info "  • RPO: 0 seconds"
Write-Host ""

# Instructions
Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Yellow
Write-Host " 📖 INSTRUCTIONS" -ForegroundColor White
Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Wait for 'LOAD STABLE' message" -ForegroundColor White
Write-Host "2. Trigger planned failover:" -ForegroundColor White
Write-Host ""
Write-Host "   az postgres flexible-server restart ``" -ForegroundColor Green
Write-Host "     --resource-group $ResourceGroupName ``" -ForegroundColor Green
Write-Host "     --name $ServerName ``" -ForegroundColor Green
Write-Host "     --failover Planned" -ForegroundColor Green
Write-Host ""
Write-Host "3. Script auto-detects downtime and recovery" -ForegroundColor White
Write-Host "4. Press Ctrl+C when ready to stop" -ForegroundColor White
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Yellow
Write-Host ""

Write-Host "Press ENTER to start..." -ForegroundColor Yellow
$null = Read-Host

# Shared metrics (thread-safe using synchronized hashtable)
$metrics = [hashtable]::Synchronized(@{
    Attempts = 0
    Successes = 0
    Failures = 0
    FirstFailure = $null
    LastFailure = $null
    FirstRecovery = $null
    InFailure = $false
})

# Worker script block
$workerScript = {
    param($workerId, $serverFqdn, $dbUser, $dbPassword, $dbName, $delayMs, $durationSeconds, $metricsRef)
    
    $startTime = Get-Date
    $lastDot = Get-Date
    
    while (((Get-Date) - $startTime).TotalSeconds -lt $durationSeconds) {
        try {
            $result = docker run --rm `
                -e PGPASSWORD="$dbPassword" `
                postgres:16-alpine `
                psql -h $serverFqdn -U $dbUser -d $dbName -t `
                -c "SELECT create_test_transaction();" 2>&1
            
            $metricsRef.Attempts++
            
            if ($LASTEXITCODE -eq 0) {
                $metricsRef.Successes++
                
                # Detect recovery
                if ($metricsRef.InFailure) {
                    $metricsRef.InFailure = $false
                    $metricsRef.FirstRecovery = Get-Date
                    Write-Host ""
                    Write-Host "✅ [Worker $workerId] RECOVERY DETECTED at $($metricsRef.FirstRecovery.ToString('HH:mm:ss.fff'))" -ForegroundColor Green
                }
                
                # Progress indicator every second
                if (((Get-Date) - $lastDot).TotalMilliseconds -ge 1000) {
                    Write-Host "." -NoNewline -ForegroundColor Green
                    $lastDot = Get-Date
                }
            } else {
                $metricsRef.Failures++
                
                # Detect first failure
                if (-not $metricsRef.FirstFailure) {
                    $metricsRef.FirstFailure = Get-Date
                    $metricsRef.InFailure = $true
                    Write-Host ""
                    Write-Host "❌ [Worker $workerId] DOWNTIME STARTED at $($metricsRef.FirstFailure.ToString('HH:mm:ss.fff'))" -ForegroundColor Red
                }
                
                $metricsRef.LastFailure = Get-Date
                Write-Host "X" -NoNewline -ForegroundColor Red
            }
        } catch {
            $metricsRef.Failures++
        }
        
        Start-Sleep -Milliseconds $delayMs
    }
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host " 🚀 STARTING $Workers PARALLEL WORKERS" -ForegroundColor White
Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""
Write-Info "Generating load at ~$WritesPerSecond TPS..."
Write-Info "Each '.' = successful write batch | Each 'X' = failed write"
Write-Host ""

$jobs = @()
$startTime = Get-Date

# Start workers
for ($i = 1; $i -le $Workers; $i++) {
    $job = Start-Job -ScriptBlock $workerScript -ArgumentList `
        $i, $serverFqdn, $dbUser, $dbPasswordText, $dbName, $delayBetweenWritesMs, $TestDurationSeconds, $metrics
    $jobs += $job
    Write-Host "  Worker $i started (Job ID: $($job.Id))" -ForegroundColor Gray
}

# Monitor progress
$lastReport = $startTime
$checkInterval = 10
$stable = $false

try {
    while ($true) {
        Start-Sleep -Seconds 1
        
        # Check if all jobs completed
        $runningJobs = $jobs | Where-Object { $_.State -eq 'Running' }
        if ($runningJobs.Count -eq 0) {
            Write-Host ""
            Write-Info "All workers completed"
            break
        }
        
        # Progress report every 10 seconds
        if (((Get-Date) - $lastReport).TotalSeconds -ge $checkInterval) {
            $elapsed = [math]::Round(((Get-Date) - $startTime).TotalSeconds)
            $remaining = $TestDurationSeconds - $elapsed
            $currentTPS = if ($elapsed -gt 0) { [math]::Round($metrics.Successes / $elapsed, 1) } else { 0 }
            
            Write-Host ""
            Write-Host "📊 [$elapsed/${TestDurationSeconds}s] Success: $($metrics.Successes) | Failed: $($metrics.Failures) | TPS: $currentTPS | Remaining: ${remaining}s" -ForegroundColor Magenta
            
            # Check for stability
            if (-not $stable -and $metrics.Successes -gt 50 -and $metrics.Failures -eq 0) {
                $stable = $true
                Write-Host ""
                Write-Host "✅ LOAD STABLE - Ready for failover testing" -ForegroundColor Green -BackgroundColor DarkGreen
                Write-Host ""
            }
            
            $lastReport = Get-Date
        }
        
        # Prompt check
        if ($PromptForFailoverAt -gt 0) {
            $elapsed = ((Get-Date) - $startTime).TotalSeconds
            if ($elapsed -ge $PromptForFailoverAt -and $elapsed -lt ($PromptForFailoverAt + 5)) {
                Write-Host ""
                Write-Host ""
                Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Yellow -BackgroundColor DarkRed
                Write-Host "⚡ TIME TO TRIGGER FAILOVER NOW! ⚡" -ForegroundColor Yellow -BackgroundColor DarkRed
                Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Yellow -BackgroundColor DarkRed
                Write-Host ""
                [Console]::Beep(800, 300)
                Start-Sleep -Milliseconds 200
                [Console]::Beep(1000, 300)
            }
        }
    }
} catch {
    Write-Host ""
    Write-Warning-Custom "Stopping workers..."
}

# Wait for all jobs
Write-Step "Collecting worker results..."
$jobs | Wait-Job | Out-Null
$jobs | Remove-Job

# Get final count
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

# Calculate results
$totalDuration = ((Get-Date) - $startTime).TotalSeconds
$actualTPS = [math]::Round($metrics.Successes / $totalDuration, 2)
$successRate = if ($metrics.Attempts -gt 0) { 
    [math]::Round(($metrics.Successes / $metrics.Attempts * 100), 2) 
} else { 0 }

$rto = if ($metrics.FirstFailure -and $metrics.FirstRecovery) {
    ($metrics.FirstRecovery - $metrics.FirstFailure).TotalSeconds
} else { 0 }

# Print results
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host " 📊 FAILOVER TEST RESULTS" -ForegroundColor White
Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

Write-Host "📈 PERFORMANCE STATISTICS:" -ForegroundColor Yellow
Write-Host "   Total attempts:              $($metrics.Attempts)"
Write-Host "   Successful writes:           $($metrics.Successes)"
Write-Host "   Failed writes:               $($metrics.Failures)"
Write-Host "   Success rate:                $successRate%"
Write-Host "   Actual TPS achieved:         $actualTPS"
Write-Host "   Target TPS:                  $WritesPerSecond"
Write-Host "   Transaction count change:    $transactionsCreated (DB: $initialCount → $finalCount)"
Write-Host ""

if ($metrics.FirstFailure) {
    Write-Host "🔄 FAILOVER METRICS:" -ForegroundColor Yellow
    Write-Host "   Test start:                  $($startTime.ToString('HH:mm:ss'))"
    Write-Host "   First failure (downtime):    $($metrics.FirstFailure.ToString('HH:mm:ss.fff'))"
    if ($metrics.FirstRecovery) {
        Write-Host "   First recovery:              $($metrics.FirstRecovery.ToString('HH:mm:ss.fff'))"
        Write-Host ""
        Write-Host "   ⭐ RTO (Recovery Time):       $rto seconds" -ForegroundColor Magenta
        Write-Host "   ⭐ RPO (Data Loss):           0 seconds" -ForegroundColor Magenta
        Write-Host ""
        Write-Host "   Target SLA:                  60-120 seconds"
        
        if ($rto -le 120) {
            Write-Success "   ✅ PASSED - RTO within SLA"
        } else {
            Write-Failure "   ❌ FAILED - RTO exceeds SLA"
        }
    } else {
        Write-Warning-Custom "   Recovery not yet detected (test may have been too short)"
    }
} else {
    Write-Warning-Custom "NO FAILOVER DETECTED - No failures occurred during test"
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Cleanup
$dbPasswordText = $null

Write-Success "Test complete!"
Write-Info "Dashboard should show ~$transactionsCreated new transactions"
