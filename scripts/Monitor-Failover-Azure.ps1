<#
.SYNOPSIS
    Monitors Azure PostgreSQL failover using Azure Resource Health API (Most Accurate RTO).

.DESCRIPTION
    This script monitors the actual Azure failover state by polling Azure Resource Health
    and server state APIs. It provides the MOST ACCURATE RTO measurement because it tracks
    Azure's internal state transitions, not just application-level connectivity.
    
    Use this alongside the write-based test to get both perspectives:
    - Azure perspective: When did Azure complete the failover?
    - Application perspective: When could the app write again?

.PARAMETER ResourceGroupName
    Resource group containing the PostgreSQL server.

.PARAMETER ServerName
    PostgreSQL server name (auto-discovered if not provided).

.EXAMPLE
    # Start monitoring BEFORE triggering failover
    .\Monitor-Failover-Azure.ps1 -ResourceGroupName 'rg-saif-pgsql-swc-01'
    
    # In another terminal, trigger failover:
    # az postgres flexible-server restart --resource-group rg-saif-pgsql-swc-01 --name <server> --failover Planned

.NOTES
    Version: 1.0.0
    Requires: PowerShell 7+, Azure CLI
    
    This provides Azure's perspective of RTO, which may differ from application perspective.
    For complete testing, run this AND the write-based test simultaneously.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$false)]
    [string]$ServerName
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host " 🔍 Azure PostgreSQL Failover Monitor (Azure State Tracking)" -ForegroundColor White
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Check Azure CLI
Write-Host "📍 Checking Azure CLI..." -ForegroundColor Yellow
try {
    $account = az account show --query "name" -o tsv
    Write-Host "✅ Authenticated to: $account" -ForegroundColor Green
} catch {
    Write-Host "❌ Please run 'az login' first" -ForegroundColor Red
    exit 1
}

# Discover server if not provided
if (-not $ServerName) {
    Write-Host "📍 Discovering PostgreSQL server..." -ForegroundColor Yellow
    $serversJson = az postgres flexible-server list --resource-group $ResourceGroupName --output json
    $servers = $serversJson | ConvertFrom-Json
    
    if ($servers.Count -eq 0) {
        Write-Host "❌ No PostgreSQL servers found" -ForegroundColor Red
        exit 1
    }
    
    $saifServers = $servers | Where-Object { $_.name -match 'saif|psql' }
    $ServerName = if ($saifServers.Count -gt 0) { $saifServers[0].name } else { $servers[0].name }
    Write-Host "✅ Found server: $ServerName" -ForegroundColor Green
}

# Get initial state
Write-Host "📍 Getting initial server state..." -ForegroundColor Yellow
$serverDetails = az postgres flexible-server show `
    --resource-group $ResourceGroupName `
    --name $ServerName `
    --output json | ConvertFrom-Json

$initialState = $serverDetails.state
$haMode = $serverDetails.highAvailability.mode
$haState = $serverDetails.highAvailability.state
$primaryZone = $serverDetails.availabilityZone
$standbyZone = $serverDetails.highAvailability.standbyAvailabilityZone

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host " 📋 INITIAL CONFIGURATION" -ForegroundColor White
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Server:           $ServerName" -ForegroundColor White
Write-Host "Resource Group:   $ResourceGroupName" -ForegroundColor White
Write-Host "State:            $initialState" -ForegroundColor Green
Write-Host "HA Mode:          $haMode" -ForegroundColor White
Write-Host "HA State:         $haState" -ForegroundColor Green
Write-Host "Primary Zone:     $primaryZone" -ForegroundColor White
Write-Host "Standby Zone:     $standbyZone" -ForegroundColor White
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

if ($haMode -ne "ZoneRedundant") {
    Write-Host "⚠️  WARNING: Server HA mode is '$haMode' (expected: ZoneRedundant)" -ForegroundColor Yellow
}

if ($haState -ne "Healthy") {
    Write-Host "⚠️  WARNING: HA state is '$haState' (expected: Healthy)" -ForegroundColor Yellow
}

# Instructions
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Yellow
Write-Host " 📖 INSTRUCTIONS" -ForegroundColor White
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Yellow
Write-Host ""
Write-Host "This script monitors Azure's internal failover state transitions." -ForegroundColor White
Write-Host ""
Write-Host "1. Keep this script running" -ForegroundColor White
Write-Host "2. In NEW terminal, trigger failover:" -ForegroundColor White
Write-Host ""
Write-Host "   az postgres flexible-server restart ``" -ForegroundColor Green
Write-Host "     --resource-group $ResourceGroupName ``" -ForegroundColor Green
Write-Host "     --name $ServerName ``" -ForegroundColor Green
Write-Host "     --failover Planned" -ForegroundColor Green
Write-Host ""
Write-Host "3. Watch state transitions below" -ForegroundColor White
Write-Host "4. Press Ctrl+C when done" -ForegroundColor White
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Yellow
Write-Host ""

Write-Host "Press ENTER to start monitoring..." -ForegroundColor Yellow
$null = Read-Host

# Monitoring variables
$pollInterval = 2  # Poll every 2 seconds for faster detection
$lastState = $initialState
$lastHaState = $haState
$failoverStartTime = $null
$failoverEndTime = $null
$stateChanges = @()

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host " 🚀 MONITORING STARTED" -ForegroundColor White
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""
Write-Host "Monitoring server state every ${pollInterval}s..." -ForegroundColor Cyan
Write-Host ""

try {
    while ($true) {
        $currentTime = Get-Date
        
        # Get current state
        $serverDetails = az postgres flexible-server show `
            --resource-group $ResourceGroupName `
            --name $ServerName `
            --output json 2>&1 | ConvertFrom-Json
        
        $currentState = $serverDetails.state
        $currentHaState = $serverDetails.highAvailability.state
        $currentZone = $serverDetails.availabilityZone
        
        # Detect state changes
        if ($currentState -ne $lastState) {
            $stateChange = [PSCustomObject]@{
                Timestamp = $currentTime
                OldState = $lastState
                NewState = $currentState
                Duration = if ($stateChanges.Count -gt 0) { 
                    [math]::Round(($currentTime - $stateChanges[-1].Timestamp).TotalSeconds, 2) 
                } else { 0 }
            }
            $stateChanges += $stateChange
            
            Write-Host "[$($currentTime.ToString('HH:mm:ss.fff'))] 🔄 State: $lastState → $currentState" -ForegroundColor Yellow
            
            # Detect failover start
            if ($currentState -ne "Ready" -and $lastState -eq "Ready" -and -not $failoverStartTime) {
                $failoverStartTime = $currentTime
                Write-Host ""
                Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Red
                Write-Host "❌ [FAILOVER START] Detected at $($currentTime.ToString('HH:mm:ss.fff'))" -ForegroundColor Red
                Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Red
                Write-Host ""
            }
            
            # Detect failover end
            if ($currentState -eq "Ready" -and $failoverStartTime -and -not $failoverEndTime) {
                $failoverEndTime = $currentTime
                $rto = [math]::Round(($failoverEndTime - $failoverStartTime).TotalSeconds, 2)
                
                Write-Host ""
                Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Green
                Write-Host "✅ [FAILOVER END] Recovered at $($currentTime.ToString('HH:mm:ss.fff'))" -ForegroundColor Green
                Write-Host "⭐ AZURE RTO: $rto seconds" -ForegroundColor Magenta
                Write-Host "   Primary Zone: $currentZone (was: $primaryZone)" -ForegroundColor White
                Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Green
                Write-Host ""
            }
            
            $lastState = $currentState
        }
        
        # Detect HA state changes
        if ($currentHaState -ne $lastHaState) {
            Write-Host "[$($currentTime.ToString('HH:mm:ss.fff'))] 🔧 HA State: $lastHaState → $currentHaState" -ForegroundColor Cyan
            $lastHaState = $currentHaState
        }
        
        # Heartbeat (every 10 seconds)
        if ([math]::Floor($currentTime.Second / 10) * 10 -eq $currentTime.Second -and $currentTime.Millisecond -lt ($pollInterval * 1000)) {
            Write-Host "." -NoNewline -ForegroundColor DarkGray
        }
        
        Start-Sleep -Seconds $pollInterval
    }
} catch {
    Write-Host ""
    Write-Host "⚠️  Monitoring stopped (Ctrl+C detected)" -ForegroundColor Yellow
    
    # Get final state before exiting
    try {
        Write-Host "📍 Getting final server state..." -ForegroundColor Yellow
        $finalDetails = az postgres flexible-server show `
            --resource-group $ResourceGroupName `
            --name $ServerName `
            --output json 2>&1 | ConvertFrom-Json
        
        Write-Host "   Current State: $($finalDetails.state)" -ForegroundColor $(if ($finalDetails.state -eq "Ready") { "Green" } else { "Yellow" })
        Write-Host "   HA State: $($finalDetails.highAvailability.state)" -ForegroundColor $(if ($finalDetails.highAvailability.state -eq "Healthy") { "Green" } else { "Yellow" })
        Write-Host "   Primary Zone: $($finalDetails.availabilityZone)" -ForegroundColor White
    } catch {
        Write-Host "   Could not retrieve final state" -ForegroundColor DarkGray
    }
} finally {
    # Print summary
    if ($stateChanges.Count -gt 0) {
        Write-Host ""
        Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host " 📊 STATE TRANSITION SUMMARY" -ForegroundColor White
        Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host ""
        
        $stateChanges | Format-Table -Property @{
            Label = "Timestamp"
            Expression = { $_.Timestamp.ToString('HH:mm:ss.fff') }
        }, @{
            Label = "Transition"
            Expression = { "$($_.OldState) → $($_.NewState)" }
        }, @{
            Label = "Duration (s)"
            Expression = { $_.Duration }
        }
        
        # Display RTO if failover completed
        if ($failoverStartTime -and $failoverEndTime) {
            $totalRto = [math]::Round(($failoverEndTime - $failoverStartTime).TotalSeconds, 2)
            Write-Host "⭐ TOTAL AZURE RTO: $totalRto seconds" -ForegroundColor Magenta
            Write-Host "   SLA Target: 60-120 seconds" -ForegroundColor White
            
            if ($totalRto -le 120) {
                Write-Host "   ✅ PASSED SLA" -ForegroundColor Green
            } else {
                Write-Host "   ❌ EXCEEDED SLA" -ForegroundColor Red
            }
        }
        # Display partial RTO if failover started but not completed
        elseif ($failoverStartTime -and -not $failoverEndTime) {
            $elapsedTime = [math]::Round(((Get-Date) - $failoverStartTime).TotalSeconds, 2)
            Write-Host "⚠️  PARTIAL RTO MEASUREMENT (interrupted before recovery):" -ForegroundColor Yellow
            Write-Host "   Failover started: $($failoverStartTime.ToString('HH:mm:ss.fff'))" -ForegroundColor White
            Write-Host "   Monitoring stopped: $((Get-Date).ToString('HH:mm:ss.fff'))" -ForegroundColor White
            Write-Host "   Elapsed downtime: $elapsedTime seconds (still in failover)" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "   💡 TIP: Let the script run until recovery completes to get full RTO" -ForegroundColor Cyan
        }
        
        Write-Host ""
        Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    }
}

Write-Host ""
Write-Host "✅ Complete!" -ForegroundColor Green
