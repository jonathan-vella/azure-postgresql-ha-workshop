# ============================================================================
# Measure-Failover-RTO-RPO.ps1
# 
# Measures RTO (Recovery Time Objective) and RPO (Recovery Point Objective)
# during PostgreSQL manual failover while App Service load test is running.
#
# Prerequisites:
# - App Service load generator deployed and running
# - PostgreSQL Flexible Server with HA enabled
# - Database must have transactions table
#
# Usage:
#   .\Measure-Failover-RTO-RPO.ps1 `
#       -AppServiceUrl "https://app-loadgen-xxxxx.azurewebsites.net" `
#       -ResourceGroup "rg-pgv2-usc01" `
#       -ServerName "pg-cus" `
#       -DatabaseName "saifdb" `
#       -AdminUsername "jonathan"
#
# The script will:
# 1. Start load test if not already running
# 2. Establish baseline metrics
# 3. Wait for manual failover trigger
# 4. Measure connection loss time
# 5. Measure recovery time
# 6. Calculate RPO (transactions lost)
# 7. Generate detailed report
# ============================================================================

param(
    [Parameter(Mandatory=$true)]
    [string]$AppServiceUrl,
    
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroup,
    
    [Parameter(Mandatory=$true)]
    [string]$ServerName,
    
    [Parameter(Mandatory=$true)]
    [string]$DatabaseName,
    
    [Parameter(Mandatory=$true)]
    [string]$AdminUsername,
    
    [Parameter(Mandatory=$false)]
    [SecureString]$AdminPassword,
    
    [Parameter(Mandatory=$false)]
    [int]$ProbeInterval = 1,
    
    [Parameter(Mandatory=$false)]
    [double]$RecoveryThreshold = 0.8,
    
    [Parameter(Mandatory=$false)]
    [int]$BaselineSeconds = 30,
    
    [Parameter(Mandatory=$false)]
    [string]$OutputCsv = "./failover_metrics_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
)

# ============================================================================
# FUNCTIONS
# ============================================================================

function Write-Banner {
    param([string]$Message, [string]$Color = "Cyan")
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor $Color
    Write-Host "  $Message" -ForegroundColor $Color
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor $Color
}

function Write-Step {
    param([string]$Step, [string]$Message)
    Write-Host ""
    Write-Host "$Step  $Message" -ForegroundColor Yellow
}

function Write-Metric {
    param([string]$Label, [string]$Value, [string]$Color = "White")
    Write-Host "  $Label`: " -NoNewline
    Write-Host $Value -ForegroundColor $Color
}

function Get-LoadTestStatus {
    try {
        $response = Invoke-RestMethod -Uri "$AppServiceUrl/status" -Method Get -TimeoutSec 5
        return $response
    } catch {
        return $null
    }
}

function Get-DatabaseTransactionCount {
    param([string]$ConnectionString)
    
    try {
        $conn = New-Object Npgsql.NpgsqlConnection($ConnectionString)
        $conn.Open()
        
        $cmd = $conn.CreateCommand()
        $cmd.CommandText = "SELECT COUNT(*) FROM transactions"
        $count = $cmd.ExecuteScalar()
        
        $conn.Close()
        $conn.Dispose()
        
        return [long]$count
    } catch {
        return $null
    }
}

function Test-DatabaseConnection {
    param([string]$ConnectionString)
    
    try {
        $conn = New-Object Npgsql.NpgsqlConnection($ConnectionString)
        $conn.Open()
        $conn.Close()
        $conn.Dispose()
        return $true
    } catch {
        return $false
    }
}

# ============================================================================
# VALIDATION
# ============================================================================

Write-Banner "PostgreSQL Failover RTO/RPO Measurement Tool"

Write-Host ""
Write-Host "Configuration:" -ForegroundColor Cyan
Write-Metric "App Service URL" $AppServiceUrl
Write-Metric "Resource Group" $ResourceGroup
Write-Metric "PostgreSQL Server" $ServerName
Write-Metric "Database" $DatabaseName
Write-Metric "Username" $AdminUsername
Write-Metric "Probe Interval" "$ProbeInterval seconds"
Write-Metric "Recovery Threshold" "$($RecoveryThreshold * 100)%"
Write-Metric "Output CSV" $OutputCsv

# Prompt for password if not provided
if (-not $AdminPassword) {
    $AdminPassword = Read-Host -AsSecureString -Prompt "`nEnter PostgreSQL password"
}

# Convert SecureString to plain text for connection string
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($AdminPassword)
$PlainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

# Build connection string
$ServerFqdn = "$ServerName.postgres.database.azure.com"
$ConnectionString = "Host=$ServerFqdn;Port=5432;Database=$DatabaseName;Username=$AdminUsername;Password=$PlainPassword;SSL Mode=Require;Timeout=5"

# Test prerequisites
Write-Host ""
Write-Host "Validating prerequisites..." -ForegroundColor Cyan

# Check if Npgsql is available
try {
    Add-Type -Path "$PSScriptRoot/libs/Npgsql.dll" -ErrorAction SilentlyContinue
} catch {
    Write-Host "⚠️  Warning: Npgsql.dll not found in libs folder. Installing from NuGet..." -ForegroundColor Yellow
    Install-Package Npgsql -ProviderName NuGet -Force -Scope CurrentUser -MinimumVersion 8.0.0 | Out-Null
    $npgsqlPath = (Get-Package Npgsql | Select-Object -First 1).Source
    Add-Type -Path (Join-Path (Split-Path $npgsqlPath) "lib/net8.0/Npgsql.dll")
}

# Verify App Service is reachable
Write-Host "  ✓ Checking App Service..." -NoNewline
try {
    $healthCheck = Invoke-RestMethod -Uri "$AppServiceUrl/health" -Method Get -TimeoutSec 5
    if ($healthCheck -eq "healthy") {
        Write-Host " OK" -ForegroundColor Green
    } else {
        Write-Host " FAILED" -ForegroundColor Red
        Write-Host "    Error: App Service is not healthy" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host " FAILED" -ForegroundColor Red
    Write-Host "    Error: Cannot reach App Service" -ForegroundColor Red
    exit 1
}

# Verify database connection
Write-Host "  ✓ Checking PostgreSQL connection..." -NoNewline
if (Test-DatabaseConnection -ConnectionString $ConnectionString) {
    Write-Host " OK" -ForegroundColor Green
} else {
    Write-Host " FAILED" -ForegroundColor Red
    Write-Host "    Error: Cannot connect to PostgreSQL" -ForegroundColor Red
    exit 1
}

# ============================================================================
# STEP 1: START LOAD TEST
# ============================================================================

Write-Step "1️⃣" "Starting Load Test"

$initialStatus = Get-LoadTestStatus
if ($initialStatus -and $initialStatus.running) {
    Write-Host "  ⚠️  Load test already running" -ForegroundColor Yellow
    Write-Metric "Start Time" $initialStatus.startTime
    Write-Metric "Current Transactions" $initialStatus.transactionsCompleted
} else {
    Write-Host "  Starting new load test..."
    try {
        Invoke-RestMethod -Uri "$AppServiceUrl/start" -Method Post -TimeoutSec 10 | Out-Null
        Start-Sleep -Seconds 5
        
        $checkStatus = Get-LoadTestStatus
        if ($checkStatus -and $checkStatus.running) {
            Write-Host "  ✅ Load test started successfully" -ForegroundColor Green
        } else {
            Write-Host "  ❌ Failed to start load test" -ForegroundColor Red
            exit 1
        }
    } catch {
        Write-Host "  ❌ Failed to start load test: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

# ============================================================================
# STEP 2: ESTABLISH BASELINE
# ============================================================================

Write-Step "2️⃣" "Establishing Baseline ($BaselineSeconds seconds)"

Start-Sleep -Seconds $BaselineSeconds

$baseline = Get-LoadTestStatus
if (-not $baseline) {
    Write-Host "  ❌ Failed to get baseline metrics" -ForegroundColor Red
    exit 1
}

$baselineTps = [math]::Round($baseline.transactionsCompleted / $baseline.uptime.TotalSeconds, 2)
$baselineDbCount = Get-DatabaseTransactionCount -ConnectionString $ConnectionString

Write-Host "  ✅ Baseline established" -ForegroundColor Green
Write-Metric "Load Test Transactions" $baseline.transactionsCompleted
Write-Metric "Database Transactions" $baselineDbCount
Write-Metric "Average TPS" $baselineTps
Write-Metric "Errors" $baseline.errors

# ============================================================================
# STEP 3: WAIT FOR MANUAL FAILOVER
# ============================================================================

Write-Step "3️⃣" "Ready for Manual Failover"

Write-Host ""
Write-Host "  Please trigger the failover manually using one of these methods:" -ForegroundColor Yellow
Write-Host ""
Write-Host "  Method 1: Azure Portal" -ForegroundColor Cyan
Write-Host "    1. Navigate to PostgreSQL Flexible Server: $ServerName"
Write-Host "    2. Go to 'High availability' blade"
Write-Host "    3. Click 'Forced failover'"
Write-Host "    4. Confirm the failover"
Write-Host ""
Write-Host "  Method 2: Azure CLI" -ForegroundColor Cyan
Write-Host "    az postgres flexible-server restart \"
Write-Host "      --name $ServerName \"
Write-Host "      --resource-group $ResourceGroup \"
Write-Host "      --failover Forced"
Write-Host ""
Write-Host "  Press ANY KEY when you've INITIATED the failover (not when complete)..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# ============================================================================
# STEP 4: MONITOR FAILOVER
# ============================================================================

Write-Step "4️⃣" "Monitoring Failover (RTO/RPO Measurement)"

# Initialize tracking variables
$failoverStartTime = Get-Date
$connectionLostTime = $null
$connectionRestoredTime = $null
$preFailoverDbCount = $baselineDbCount
$postFailoverDbCount = $null
$preFailoverAppCount = $baseline.transactionsCompleted
$postFailoverAppCount = $null
$maxConsecutiveFailures = 0
$currentConsecutiveFailures = 0
$totalProbes = 0
$failedProbes = 0

# Metrics collection
$metrics = @()

Write-Host ""
Write-Host "Time        Elapsed   DB Conn   App Conn   App Trans     DB Trans      TPS     Status" -ForegroundColor Gray
Write-Host "────────────────────────────────────────────────────────────────────────────────────────" -ForegroundColor Gray

$recovered = $false
$lastSuccessfulDbCount = $preFailoverDbCount
$lastSuccessfulAppCount = $preFailoverAppCount

while (-not $recovered) {
    Start-Sleep -Seconds $ProbeInterval
    
    $now = Get-Date
    $elapsed = ($now - $failoverStartTime).TotalSeconds
    $totalProbes++
    
    # Test database connection
    $dbConnected = Test-DatabaseConnection -ConnectionString $ConnectionString
    $dbCount = if ($dbConnected) { 
        Get-DatabaseTransactionCount -ConnectionString $ConnectionString 
    } else { 
        $null 
    }
    
    # Test app service connection
    $appStatus = Get-LoadTestStatus
    $appConnected = ($null -ne $appStatus)
    $appCount = if ($appConnected) { $appStatus.transactionsCompleted } else { $null }
    $appErrors = if ($appConnected) { $appStatus.errors } else { $null }
    
    # Calculate TPS
    $currentTps = if ($appConnected -and $appStatus.uptime.TotalSeconds -gt 0) {
        [math]::Round($appStatus.transactionsCompleted / $appStatus.uptime.TotalSeconds, 0)
    } else {
        0
    }
    
    # Track connection loss
    if (-not $dbConnected -or -not $appConnected) {
        $currentConsecutiveFailures++
        $failedProbes++
        
        if ($currentConsecutiveFailures -gt $maxConsecutiveFailures) {
            $maxConsecutiveFailures = $currentConsecutiveFailures
        }
        
        if ($null -eq $connectionLostTime) {
            $connectionLostTime = $now
            Write-Host "$($now.ToString('HH:mm:ss'))  $($elapsed.ToString('F1'))s     " -NoNewline
            Write-Host "LOST      LOST       " -ForegroundColor Red -NoNewline
            Write-Host "─────────   ─────────   ─────   " -NoNewline
            Write-Host "CONNECTION LOST" -ForegroundColor Red
        } else {
            Write-Host "$($now.ToString('HH:mm:ss'))  $($elapsed.ToString('F1'))s     " -NoNewline
            Write-Host "DOWN      DOWN       " -ForegroundColor Red -NoNewline
            Write-Host "─────────   ─────────   ─────   " -NoNewline
            Write-Host "OUTAGE" -ForegroundColor Red
        }
    } else {
        # Connection successful
        $currentConsecutiveFailures = 0
        
        # Update counts
        if ($null -ne $dbCount) { $lastSuccessfulDbCount = $dbCount }
        if ($null -ne $appCount) { $lastSuccessfulAppCount = $appCount }
        
        # Check if recovered
        if ($null -ne $connectionLostTime -and $null -eq $connectionRestoredTime) {
            $connectionRestoredTime = $now
            $postFailoverDbCount = $dbCount
            $postFailoverAppCount = $appCount
            
            Write-Host "$($now.ToString('HH:mm:ss'))  $($elapsed.ToString('F1'))s     " -NoNewline
            Write-Host "OK        OK         " -ForegroundColor Green -NoNewline
            Write-Host "$($appCount.ToString('N0').PadLeft(9))   $($dbCount.ToString('N0').PadLeft(9))   $($currentTps.ToString('N0').PadLeft(5))   " -NoNewline
            Write-Host "RECOVERED" -ForegroundColor Green
        } else {
            # Normal operation
            $statusColor = if ($null -eq $connectionLostTime) { "White" } else { "Yellow" }
            $statusText = if ($null -eq $connectionLostTime) { "BASELINE" } else { "RECOVERING" }
            
            Write-Host "$($now.ToString('HH:mm:ss'))  $($elapsed.ToString('F1'))s     " -NoNewline
            Write-Host "OK        OK         " -ForegroundColor Green -NoNewline
            Write-Host "$($appCount.ToString('N0').PadLeft(9))   $($dbCount.ToString('N0').PadLeft(9))   $($currentTps.ToString('N0').PadLeft(5))   " -NoNewline
            Write-Host $statusText -ForegroundColor $statusColor
        }
        
        # Check if fully recovered (TPS back to threshold)
        if ($null -ne $connectionRestoredTime -and $currentTps -ge ($baselineTps * $RecoveryThreshold)) {
            $recovered = $true
        }
    }
    
    # Record metrics
    $metrics += [PSCustomObject]@{
        Timestamp = $now
        ElapsedSeconds = [math]::Round($elapsed, 3)
        DatabaseConnected = $dbConnected
        AppServiceConnected = $appConnected
        AppTransactions = $appCount
        DatabaseTransactions = $dbCount
        TPS = $currentTps
        Errors = $appErrors
    }
    
    # Safety timeout (5 minutes)
    if ($elapsed -gt 300) {
        Write-Host ""
        Write-Host "⚠️  Safety timeout reached (5 minutes). Ending measurement." -ForegroundColor Yellow
        break
    }
}

$failoverEndTime = Get-Date

# ============================================================================
# STEP 5: CALCULATE METRICS
# ============================================================================

Write-Step "5️⃣" "Calculating RTO and RPO"

# Calculate RTO (Recovery Time Objective)
$rto = if ($connectionLostTime -and $connectionRestoredTime) {
    ($connectionRestoredTime - $connectionLostTime).TotalSeconds
} else {
    $null
}

# Calculate downtime
$totalDowntime = ($maxConsecutiveFailures * $ProbeInterval)

# Get final counts
$finalStatus = Get-LoadTestStatus
$finalDbCount = Get-DatabaseTransactionCount -ConnectionString $ConnectionString
$finalAppCount = if ($finalStatus) { $finalStatus.transactionsCompleted } else { $lastSuccessfulAppCount }
$finalErrors = if ($finalStatus) { $finalStatus.errors } else { 0 }

# Calculate RPO (Recovery Point Objective - transactions lost)
# RPO = App counted transactions - DB persisted transactions
$rpo = if ($null -ne $postFailoverAppCount -and $null -ne $postFailoverDbCount) {
    $postFailoverAppCount - $postFailoverDbCount
} else {
    $finalAppCount - $finalDbCount
}

# Calculate data loss
$transactionsDuringFailover = $finalAppCount - $preFailoverAppCount
$transactionsLost = [math]::Max(0, $rpo)
$dataLossPercentage = if ($transactionsDuringFailover -gt 0) {
    ($transactionsLost / $transactionsDuringFailover) * 100
} else {
    0
}

# ============================================================================
# STEP 6: GENERATE REPORT
# ============================================================================

Write-Banner "FAILOVER TEST RESULTS" "Green"

Write-Host ""
Write-Host "⏱️  TIMING METRICS" -ForegroundColor Cyan
Write-Host "─────────────────────────────────────────────────────────────────" -ForegroundColor Gray
if ($null -ne $rto) {
    $rtoColor = if ($rto -lt 30) { "Green" } elseif ($rto -lt 60) { "Yellow" } else { "Red" }
    Write-Host "  RTO (Recovery Time):        " -NoNewline
    Write-Host "$($rto.ToString('F2')) seconds" -ForegroundColor $rtoColor
} else {
    Write-Host "  RTO (Recovery Time):        " -NoNewline
    Write-Host "Not measured (no outage detected)" -ForegroundColor Yellow
}
Write-Metric "Total Test Duration" "$([math]::Round(($failoverEndTime - $failoverStartTime).TotalSeconds, 2)) seconds"
Write-Metric "Connection Lost At" $(if ($connectionLostTime) { $connectionLostTime.ToString('HH:mm:ss.fff') } else { "N/A" })
Write-Metric "Connection Restored At" $(if ($connectionRestoredTime) { $connectionRestoredTime.ToString('HH:mm:ss.fff') } else { "N/A" })
Write-Metric "Max Consecutive Failures" "$maxConsecutiveFailures probes ($totalDowntime seconds)"
Write-Metric "Total Failed Probes" "$failedProbes / $totalProbes ($([math]::Round(($failedProbes / $totalProbes) * 100, 2))%)"

Write-Host ""
Write-Host "📊 DATA CONSISTENCY METRICS" -ForegroundColor Cyan
Write-Host "─────────────────────────────────────────────────────────────────" -ForegroundColor Gray
$rpoColor = if ($transactionsLost -eq 0) { "Green" } elseif ($transactionsLost -lt 100) { "Yellow" } else { "Red" }
Write-Host "  RPO (Transactions Lost):    " -NoNewline
Write-Host "$transactionsLost transactions" -ForegroundColor $rpoColor
Write-Metric "Data Loss Percentage" "$($dataLossPercentage.ToString('F2'))%"
Write-Host ""
Write-Metric "Pre-Failover App Count" $preFailoverAppCount
Write-Metric "Pre-Failover DB Count" $preFailoverDbCount
Write-Metric "Post-Failover App Count" $(if ($postFailoverAppCount) { $postFailoverAppCount } else { "N/A" })
Write-Metric "Post-Failover DB Count" $(if ($postFailoverDbCount) { $postFailoverDbCount } else { "N/A" })
Write-Metric "Final App Count" $finalAppCount
Write-Metric "Final DB Count" $finalDbCount
Write-Metric "Transactions During Failover" $transactionsDuringFailover

Write-Host ""
Write-Host "📈 PERFORMANCE METRICS" -ForegroundColor Cyan
Write-Host "─────────────────────────────────────────────────────────────────" -ForegroundColor Gray
Write-Metric "Baseline TPS" $baselineTps
$finalTps = if ($finalStatus -and $finalStatus.uptime.TotalSeconds -gt 0) {
    [math]::Round($finalStatus.transactionsCompleted / $finalStatus.uptime.TotalSeconds, 2)
} else {
    0
}
Write-Metric "Final TPS" $finalTps
Write-Metric "TPS Recovery" "$([math]::Round(($finalTps / $baselineTps) * 100, 2))%"
Write-Metric "Total Errors" $finalErrors

Write-Host ""
Write-Host "✅ PASS/FAIL CRITERIA" -ForegroundColor Cyan
Write-Host "─────────────────────────────────────────────────────────────────" -ForegroundColor Gray

# RTO Target: < 30 seconds
$rtoPass = if ($null -ne $rto) { $rto -lt 30 } else { $false }
Write-Host "  RTO < 30 seconds:           " -NoNewline
if ($rtoPass) {
    Write-Host "✅ PASS" -ForegroundColor Green
} elseif ($null -ne $rto) {
    Write-Host "❌ FAIL ($($rto.ToString('F2'))s)" -ForegroundColor Red
} else {
    Write-Host "⚠️  NOT MEASURED" -ForegroundColor Yellow
}

# RPO Target: 0 transactions lost
$rpoPass = ($transactionsLost -eq 0)
Write-Host "  RPO = 0 (Zero Data Loss):  " -NoNewline
if ($rpoPass) {
    Write-Host "✅ PASS" -ForegroundColor Green
} else {
    Write-Host "❌ FAIL ($transactionsLost lost)" -ForegroundColor Red
}

# Overall result
Write-Host ""
if ($rtoPass -and $rpoPass) {
    Write-Host "  🎉 OVERALL RESULT:          " -NoNewline
    Write-Host "✅ PASSED" -ForegroundColor Green
} else {
    Write-Host "  ⚠️  OVERALL RESULT:          " -NoNewline
    Write-Host "❌ FAILED" -ForegroundColor Red
}

# ============================================================================
# STEP 7: EXPORT METRICS TO CSV
# ============================================================================

Write-Step "6️⃣" "Exporting Metrics to CSV"

try {
    $metrics | Export-Csv -Path $OutputCsv -NoTypeInformation
    Write-Host "  ✅ Metrics exported to: $OutputCsv" -ForegroundColor Green
    Write-Host "  Total data points: $($metrics.Count)"
} catch {
    Write-Host "  ❌ Failed to export CSV: $($_.Exception.Message)" -ForegroundColor Red
}

# Create summary JSON
$summaryFile = $OutputCsv -replace '\.csv$', '_summary.json'
$summary = @{
    TestDate = $failoverStartTime.ToString('yyyy-MM-dd HH:mm:ss')
    ServerName = $ServerName
    ResourceGroup = $ResourceGroup
    AppServiceUrl = $AppServiceUrl
    RTO_Seconds = $rto
    RTO_Pass = $rtoPass
    RPO_TransactionsLost = $transactionsLost
    RPO_Pass = $rpoPass
    OverallResult = if ($rtoPass -and $rpoPass) { "PASS" } else { "FAIL" }
    BaselineTPS = $baselineTps
    FinalTPS = $finalTps
    TotalTransactions = $finalAppCount
    TotalErrors = $finalErrors
    DataLossPercentage = $dataLossPercentage
    ConnectionLostTime = if ($connectionLostTime) { $connectionLostTime.ToString('yyyy-MM-dd HH:mm:ss.fff') } else { $null }
    ConnectionRestoredTime = if ($connectionRestoredTime) { $connectionRestoredTime.ToString('yyyy-MM-dd HH:mm:ss.fff') } else { $null }
    MaxConsecutiveFailures = $maxConsecutiveFailures
    TotalProbes = $totalProbes
    FailedProbes = $failedProbes
}

try {
    $summary | ConvertTo-Json -Depth 10 | Out-File -FilePath $summaryFile -Encoding UTF8
    Write-Host "  ✅ Summary exported to: $summaryFile" -ForegroundColor Green
} catch {
    Write-Host "  ⚠️  Warning: Failed to export summary JSON" -ForegroundColor Yellow
}

# ============================================================================
# COMPLETION
# ============================================================================

Write-Banner "FAILOVER TEST COMPLETE" "Green"

Write-Host ""
Write-Host "📁 Generated Files:" -ForegroundColor Cyan
Write-Host "  - Detailed Metrics: $OutputCsv"
Write-Host "  - Summary Report:   $summaryFile"
Write-Host ""

# Return exit code based on pass/fail
if ($rtoPass -and $rpoPass) {
    exit 0
} else {
    exit 1
}
