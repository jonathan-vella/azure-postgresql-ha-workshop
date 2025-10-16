#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Monitor PostgreSQL transactions in real-time using Docker psql client.

.DESCRIPTION
    This script provides continuous monitoring of transaction counts using psql inside Docker.
    No local PostgreSQL installation required - uses official postgres:16-alpine image.

.PARAMETER ServerName
    PostgreSQL server hostname (e.g., pg-cus.postgres.database.azure.com)

.PARAMETER Database
    Database name to monitor (default: saifdb)

.PARAMETER Username
    PostgreSQL username (default: jonathan)

.PARAMETER Port
    PostgreSQL port (default: 6432 for PgBouncer)

.PARAMETER Interval
    Refresh interval in seconds (default: 2)

.EXAMPLE
    .\Monitor-Transactions-Docker.ps1 -ServerName "pg-cus.postgres.database.azure.com" -Username "jonathan"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ServerName,
    
    [Parameter(Mandatory=$false)]
    [string]$Database = "saifdb",
    
    [Parameter(Mandatory=$false)]
    [string]$Username = "jonathan",
    
    [Parameter(Mandatory=$false)]
    [int]$Port = 6432,
    
    [Parameter(Mandatory=$false)]
    [int]$Interval = 2
)

# Get password securely
$securePassword = Read-Host -AsSecureString -Prompt "Enter PostgreSQL password"
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
$password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

Write-Host "`n=== PostgreSQL Transaction Monitor (Docker-based) ===" -ForegroundColor Cyan
Write-Host "Server: $ServerName" -ForegroundColor Gray
Write-Host "Database: $Database" -ForegroundColor Gray
Write-Host "Port: $Port" -ForegroundColor Gray
Write-Host "Refresh: Every $Interval seconds" -ForegroundColor Gray
Write-Host "Press Ctrl+C to exit`n" -ForegroundColor Yellow

# Pull postgres image if not present
Write-Host "Checking for postgres:16-alpine Docker image..." -ForegroundColor Gray
docker pull postgres:16-alpine | Out-Null

# Test connection
Write-Host "Testing database connection..." -ForegroundColor Gray
$testQuery = "SELECT COUNT(*) FROM transactions;"
$connectionString = "host=$ServerName port=$Port dbname=$Database user=$Username password=$password sslmode=require"

$testResult = docker run --rm postgres:16-alpine psql "$connectionString" -t -c "$testQuery" 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Connection test failed!" -ForegroundColor Red
    Write-Host $testResult -ForegroundColor Red
    exit 1
}

Write-Host "✅ Connection successful!`n" -ForegroundColor Green

# Display header
Write-Host ("{0,-12} | {1,-15} | {2,-10} | {3,-8} | {4,-25}" -f "Time", "Total Txns", "New Txns", "TPS", "Latest Transaction") -ForegroundColor Cyan
Write-Host ("{0}" -f ("-" * 90)) -ForegroundColor Gray

# Initialize tracking
$lastCount = 0
$lastTime = Get-Date
$currentTime = Get-Date
$firstRun = $true
$loopCount = 0

# Monitoring loop
try {
    while ($true) {
        $currentTime = Get-Date
        $loopCount++
        
        # Get current transaction count
        $countQuery = "SELECT COUNT(*) FROM transactions;"
        
        try {
            $result = docker run --rm postgres:16-alpine psql "$connectionString" -t -c "$countQuery" 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                # Handle array or string result
                if ($result -is [array]) {
                    $resultStr = ($result | Where-Object { $_ -match '\d' } | Select-Object -First 1).Trim()
                }
                else {
                    $resultStr = $result.Trim()
                }
                
                $currentCount = [int]$resultStr
            }
            else {
                Write-Host ("{0,-12} | ❌ Query failed (exit code: $LASTEXITCODE)" -f $currentTime.ToString("HH:mm:ss")) -ForegroundColor Red
                Start-Sleep -Seconds $Interval
                continue
            }
        }
        catch {
            Write-Host ("{0,-12} | ❌ Docker error: $($_.Exception.Message)" -f $currentTime.ToString("HH:mm:ss")) -ForegroundColor Red
            Start-Sleep -Seconds $Interval
            continue
        }
        
        if ($currentCount -ge 0) {
            
            # Calculate metrics
            if (-not $firstRun) {
                $newTxns = $currentCount - $lastCount
                $elapsed = ($currentTime - $lastTime).TotalSeconds
                $tps = if ($elapsed -gt 0) { [math]::Round($newTxns / $elapsed, 1) } else { 0 }
                
                # Get latest transaction timestamp
                $timeQuery = "SELECT MAX(transaction_date)::text FROM transactions;"
                $timeResult = docker run --rm postgres:16-alpine psql "$connectionString" -t -c "$timeQuery" 2>&1
                
                # Handle array or string result
                if ($timeResult -is [array]) {
                    $latestTime = ($timeResult | Where-Object { $_ -match '\S' } | Select-Object -First 1).Trim()
                }
                else {
                    $latestTime = $timeResult.Trim()
                }
                
                # Status indicator
                $status = if ($newTxns -gt 0) { "🟢" } else { "🔴" }
                
                # Format and display
                $timeStr = $currentTime.ToString("HH:mm:ss")
                $countStr = "{0,15:N0}" -f $currentCount
                $newStr = "{0,10:N0}" -f $newTxns
                $tpsStr = "{0,8:N1}" -f $tps
                
                Write-Host ("{0,-12} | {1} | {2} | {3} | {4,-25} {5}" -f $timeStr, $countStr, $newStr, $tpsStr, $latestTime, $status)
            }
            else {
                # First run - just show count
                $countStr = "{0,15:N0}" -f $currentCount
                Write-Host ("{0,-12} | {1} | {2,-10} | {3,-8} | {4,-25}" -f $currentTime.ToString("HH:mm:ss"), $countStr, "-", "-", "Initializing...")
                $firstRun = $false
            }
            
            $lastCount = $currentCount
            $lastTime = $currentTime
            
            Start-Sleep -Seconds $Interval
        }
    }
}
catch {
    Write-Host "`n`nMonitoring stopped by user or error." -ForegroundColor Yellow
    if ($_.Exception.Message) {
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
}
finally {
    $endTime = Get-Date
    $duration = ($endTime - $lastTime).TotalSeconds
    
    Write-Host "`nFinal Statistics:" -ForegroundColor Cyan
    Write-Host "  Total Transactions: $($lastCount.ToString('N0'))" -ForegroundColor White
    Write-Host "  Iterations completed: $loopCount" -ForegroundColor White
    if ($duration -gt 0) {
        Write-Host "  Session Duration: $([math]::Round($duration / 60, 1)) minutes" -ForegroundColor White
    }
}
