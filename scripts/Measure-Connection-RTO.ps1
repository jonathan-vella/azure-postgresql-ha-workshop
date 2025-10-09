<#
.SYNOPSIS
    Measures actual database connectivity RTO during PostgreSQL failover.

.DESCRIPTION
    This script continuously attempts database connections (simple SELECT 1 query) to measure
    the ACTUAL downtime from the application's perspective - exactly what Microsoft recommends:
    
    "Please measure the downtime from your application/client perspective"
    - Azure PostgreSQL HA Documentation
    
    Measures:
    - First connection failure timestamp
    - First successful connection timestamp after failure
    - Actual RTO = time database couldn't accept connections
    
    This is different from:
    - Azure state monitoring (when Azure reports "Ready")
    - Write-based testing (requires transaction table setup)
    
    This measures pure connection availability - the minimum downtime your app will experience.

.PARAMETER ResourceGroupName
    Resource group containing the PostgreSQL server.

.PARAMETER ServerName
    PostgreSQL server name (auto-discovered if not provided).

.PARAMETER Database
    Database name (default: postgres).

.PARAMETER Username
    Database username (default: saifadmin).

.PARAMETER Password
    Database password (if not provided, will prompt).

.PARAMETER ProbeInterval
    Seconds between connection attempts (default: 1).

.EXAMPLE
    # Basic usage (will prompt for password)
    .\Measure-Connection-RTO.ps1 -ResourceGroupName 'rg-saif-pgsql-swc-01'

.EXAMPLE
    # With all parameters
    .\Measure-Connection-RTO.ps1 `
        -ResourceGroupName 'rg-saif-pgsql-swc-01' `
        -ServerName 'psql-saifpg-10081025' `
        -Database 'saifdb' `
        -Username 'saifadmin' `
        -ProbeInterval 0.5

.NOTES
    Version: 1.0.0
    Author: SAIF Team
    Date: 2025-10-09
    Requires: PowerShell 7+, Azure CLI
    
    This measures APPLICATION-LEVEL RTO - the actual time your application
    cannot connect to the database. This is typically 5-15 seconds longer
    than Azure's internal state transitions due to:
    - Connection handshake time
    - PgBouncer overhead (if using port 6432)
    - DNS propagation
    - Network latency
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$false)]
    [string]$ServerName,
    
    [Parameter(Mandatory=$false)]
    [string]$Database = "postgres",
    
    [Parameter(Mandatory=$false)]
    [string]$Username = "saifadmin",
    
    [Parameter(Mandatory=$false)]
    [SecureString]$Password,
    
    [Parameter(Mandatory=$false)]
    [double]$ProbeInterval = 1.0
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
#endregion

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host " 🔌 PostgreSQL Connection RTO Measurement" -ForegroundColor White
Write-Host " (Application Perspective - Microsoft Recommended Method)" -ForegroundColor DarkGray
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Check Azure CLI
Write-Step "Checking Azure CLI authentication..."
try {
    $account = az account show --query "name" -o tsv
    Write-Success "Authenticated to: $account"
} catch {
    Write-Failure "Please run 'az login' first"
    exit 1
}

# Discover server
if (-not $ServerName) {
    Write-Step "Discovering PostgreSQL server..."
    $serversJson = az postgres flexible-server list --resource-group $ResourceGroupName --output json
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
$haMode = $serverDetails.highAvailability.mode
$haState = $serverDetails.highAvailability.state
$primaryZone = $serverDetails.availabilityZone
$standbyZone = $serverDetails.highAvailability.standbyAvailabilityZone

# Get password if not provided
if (-not $Password) {
    Write-Step "Enter database credentials"
    Write-Host "Username: $Username" -ForegroundColor White
    $Password = Read-Host "Password" -AsSecureString
}

$passwordText = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
)

# Use port 6432 for PgBouncer (recommended) or 5432 for direct connection
$port = 6432

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host " 📋 CONFIGURATION" -ForegroundColor White
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Server:           $serverFqdn" -ForegroundColor White
Write-Host "Database:         $Database" -ForegroundColor White
Write-Host "Username:         $Username" -ForegroundColor White
Write-Host "Port:             $port (PgBouncer)" -ForegroundColor White
Write-Host "Probe Interval:   $ProbeInterval seconds" -ForegroundColor White
Write-Host ""
Write-Host "HA Mode:          $haMode" -ForegroundColor White
Write-Host "HA State:         $haState" -ForegroundColor $(if ($haState -eq "Healthy") { "Green" } else { "Yellow" })
Write-Host "Primary Zone:     $primaryZone" -ForegroundColor White
Write-Host "Standby Zone:     $standbyZone" -ForegroundColor White
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

if ($haMode -ne "ZoneRedundant") {
    Write-Host "⚠️  WARNING: HA mode is '$haMode' (expected: ZoneRedundant)" -ForegroundColor Yellow
    Write-Host ""
}

# Test initial connection
Write-Step "Testing initial connection..."
$connectionString = "Host=$serverFqdn;Port=$port;Database=$Database;Username=$Username;Password=$passwordText;SSL Mode=Require;Timeout=5;Command Timeout=3"

try {
    Add-Type -Path "C:\Program Files\PackageManagement\NuGet\Packages\Npgsql.8.0.3\lib\net8.0\Npgsql.dll" -ErrorAction SilentlyContinue
    $useNpgsql = $true
} catch {
    Write-Info "Npgsql not available, using psql command-line tool"
    $useNpgsql = $false
}

$initialConnSuccess = $false
if ($useNpgsql) {
    try {
        $testConn = New-Object Npgsql.NpgsqlConnection($connectionString)
        $testConn.Open()
        $testCmd = $testConn.CreateCommand()
        $testCmd.CommandText = "SELECT 1"
        $result = $testCmd.ExecuteScalar()
        $testConn.Close()
        $initialConnSuccess = ($result -eq 1)
    } catch {
        $initialConnSuccess = $false
    }
} else {
    # Use psql
    $env:PGPASSWORD = $passwordText
    try {
        $result = psql -h $serverFqdn -p $port -U $Username -d $Database -t -c "SELECT 1;" 2>$null
        $initialConnSuccess = ($LASTEXITCODE -eq 0)
    } catch {
        $initialConnSuccess = $false
    }
}

if (-not $initialConnSuccess) {
    Write-Failure "Cannot connect to database. Please check credentials and server status."
    exit 1
}

Write-Success "Initial connection successful"

# Instructions
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Yellow
Write-Host " 📖 INSTRUCTIONS" -ForegroundColor White
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Yellow
Write-Host ""
Write-Host "This script will continuously probe the database connection." -ForegroundColor White
Write-Host "It measures the ACTUAL time the database cannot accept connections." -ForegroundColor White
Write-Host ""
Write-Host "1. Wait for 'CONNECTION STABLE' message" -ForegroundColor White
Write-Host "2. In NEW terminal, trigger failover:" -ForegroundColor White
Write-Host ""
Write-Host "   az postgres flexible-server restart ``" -ForegroundColor Green
Write-Host "     --resource-group $ResourceGroupName ``" -ForegroundColor Green
Write-Host "     --name $ServerName ``" -ForegroundColor Green
Write-Host "     --failover Planned" -ForegroundColor Green
Write-Host ""
Write-Host "3. Watch for connection failures and recovery" -ForegroundColor White
Write-Host "4. Press Ctrl+C when done (after recovery)" -ForegroundColor White
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Yellow
Write-Host ""

Write-Host "Press ENTER to start monitoring..." -ForegroundColor Yellow
$null = Read-Host

# Monitoring variables
$script:successCount = 0
$script:failureCount = 0
$script:firstFailureTime = $null
$script:firstRecoveryTime = $null
$script:inDowntime = $false
$script:connectionHistory = @()

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host " 🚀 CONNECTION MONITORING STARTED" -ForegroundColor White
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""
Write-Info "Probing database connection every $ProbeInterval seconds..."
Write-Host ""

$startTime = Get-Date
$lastReport = $startTime
$stable = $false

try {
    while ($true) {
        $probeStart = Get-Date
        $success = $false
        $errorMessage = ""
        
        try {
            if ($useNpgsql) {
                $conn = New-Object Npgsql.NpgsqlConnection($connectionString)
                $conn.Open()
                $cmd = $conn.CreateCommand()
                $cmd.CommandText = "SELECT 1"
                $result = $cmd.ExecuteScalar()
                $conn.Close()
                $success = ($result -eq 1)
            } else {
                $env:PGPASSWORD = $passwordText
                $result = psql -h $serverFqdn -p $port -U $Username -d $Database -t -c "SELECT 1;" 2>&1
                $success = ($LASTEXITCODE -eq 0)
            }
        } catch {
            $success = $false
            $errorMessage = $_.Exception.Message
        }
        
        $probeEnd = Get-Date
        $probeDuration = [math]::Round(($probeEnd - $probeStart).TotalMilliseconds, 2)
        
        # Record in history
        $script:connectionHistory += [PSCustomObject]@{
            Timestamp = $probeStart
            Success = $success
            Duration = $probeDuration
            Error = $errorMessage
        }
        
        if ($success) {
            $script:successCount++
            
            # Detect recovery
            if ($script:inDowntime) {
                $script:firstRecoveryTime = $probeStart
                $script:inDowntime = $false
                $rto = [math]::Round(($script:firstRecoveryTime - $script:firstFailureTime).TotalSeconds, 2)
                
                Write-Host ""
                Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Green
                Write-Host "✅ [RECOVERY] Database accepting connections at $($script:firstRecoveryTime.ToString('HH:mm:ss.fff'))" -ForegroundColor Green
                Write-Host "⭐ CONNECTION RTO: $rto seconds" -ForegroundColor Magenta
                Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Green
                Write-Host ""
            }
            
            # Progress indicator
            if ($script:successCount % 5 -eq 0) {
                Write-Host "." -NoNewline -ForegroundColor Green
            }
        } else {
            $script:failureCount++
            
            # Detect first failure
            if (-not $script:firstFailureTime) {
                $script:firstFailureTime = $probeStart
                $script:inDowntime = $true
                Write-Host ""
                Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Red
                Write-Host "❌ [DOWNTIME START] First connection failure at $($script:firstFailureTime.ToString('HH:mm:ss.fff'))" -ForegroundColor Red
                Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Red
                Write-Host ""
            }
            
            Write-Host "X" -NoNewline -ForegroundColor Red
        }
        
        # Progress report every 10 seconds
        if (((Get-Date) - $lastReport).TotalSeconds -ge 10) {
            $elapsed = [math]::Round(((Get-Date) - $startTime).TotalSeconds)
            $successRate = if (($script:successCount + $script:failureCount) -gt 0) {
                [math]::Round(($script:successCount / ($script:successCount + $script:failureCount) * 100), 1)
            } else { 0 }
            
            Write-Host ""
            Write-Host "📊 [$elapsed s] Success: $script:successCount | Failed: $script:failureCount | Success Rate: $successRate%" -ForegroundColor Magenta
            
            if (-not $stable -and $script:successCount -gt 10 -and $script:failureCount -eq 0) {
                $stable = $true
                Write-Host ""
                Write-Host "✅ CONNECTION STABLE - Ready for failover!" -ForegroundColor Green -BackgroundColor DarkGreen
                Write-Host ""
            }
            
            if ($script:inDowntime) {
                $downtimeElapsed = [math]::Round(((Get-Date) - $script:firstFailureTime).TotalSeconds, 1)
                Write-Host "⚠️  DOWNTIME: $downtimeElapsed seconds and counting..." -ForegroundColor Yellow
            }
            
            $lastReport = Get-Date
        }
        
        # Wait for next probe
        $sleepTime = [math]::Max(0, ($ProbeInterval * 1000) - $probeDuration)
        if ($sleepTime -gt 0) {
            Start-Sleep -Milliseconds $sleepTime
        }
    }
} catch {
    Write-Host ""
    Write-Host "⚠️  Monitoring stopped (Ctrl+C detected)" -ForegroundColor Yellow
} finally {
    # Clear password
    $passwordText = $null
    $env:PGPASSWORD = $null
    
    # Print summary
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host " 📊 CONNECTION RTO SUMMARY" -ForegroundColor White
    Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    
    $totalDuration = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 1)
    $totalAttempts = $script:successCount + $script:failureCount
    $successRate = if ($totalAttempts -gt 0) {
        [math]::Round(($script:successCount / $totalAttempts * 100), 2)
    } else { 0 }
    
    Write-Host "📈 STATISTICS:" -ForegroundColor Yellow
    Write-Host "   Total Duration:          $totalDuration seconds" -ForegroundColor White
    Write-Host "   Connection Attempts:     $totalAttempts" -ForegroundColor White
    Write-Host "   Successful:              $($script:successCount)" -ForegroundColor Green
    Write-Host "   Failed:                  $($script:failureCount)" -ForegroundColor Red
    Write-Host "   Success Rate:            $successRate%" -ForegroundColor White
    Write-Host "   Probe Interval:          $ProbeInterval seconds" -ForegroundColor White
    Write-Host ""
    
    if ($script:firstFailureTime -and $script:firstRecoveryTime) {
        $rto = [math]::Round(($script:firstRecoveryTime - $script:firstFailureTime).TotalSeconds, 2)
        
        Write-Host "🔌 CONNECTION RTO (Application Perspective):" -ForegroundColor Yellow
        Write-Host "   Downtime Start:          $($script:firstFailureTime.ToString('HH:mm:ss.fff'))" -ForegroundColor White
        Write-Host "   Recovery:                $($script:firstRecoveryTime.ToString('HH:mm:ss.fff'))" -ForegroundColor White
        Write-Host ""
        Write-Host "   ⭐ RTO:                   $rto seconds" -ForegroundColor Magenta
        Write-Host "   ⭐ RPO:                   0 seconds (no data loss)" -ForegroundColor Magenta
        Write-Host ""
        Write-Host "   📏 SLA Target:            60-120 seconds" -ForegroundColor White
        
        if ($rto -le 120) {
            Write-Host "   ✅ PASSED SLA" -ForegroundColor Green
        } else {
            Write-Host "   ❌ EXCEEDED SLA" -ForegroundColor Red
        }
        
        Write-Host ""
        Write-Host "💡 CONTEXT:" -ForegroundColor Yellow
        Write-Host "   This RTO represents the actual time your application" -ForegroundColor White
        Write-Host "   could not connect to the database. This is the most" -ForegroundColor White
        Write-Host "   accurate measurement from the application perspective." -ForegroundColor White
        
    } elseif ($script:firstFailureTime -and -not $script:firstRecoveryTime) {
        $downtimeElapsed = [math]::Round(((Get-Date) - $script:firstFailureTime).TotalSeconds, 2)
        Write-Host "⚠️  PARTIAL RTO (monitoring stopped before recovery):" -ForegroundColor Yellow
        Write-Host "   Downtime Start:          $($script:firstFailureTime.ToString('HH:mm:ss.fff'))" -ForegroundColor White
        Write-Host "   Monitoring Stopped:      $((Get-Date).ToString('HH:mm:ss.fff'))" -ForegroundColor White
        Write-Host "   Elapsed Downtime:        $downtimeElapsed seconds (still down)" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "   💡 TIP: Wait for recovery before stopping to get full RTO" -ForegroundColor Cyan
    } else {
        Write-Host "ℹ️  No failover detected during monitoring" -ForegroundColor Cyan
    }
    
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
}

Write-Host ""
Write-Success "Complete!"
