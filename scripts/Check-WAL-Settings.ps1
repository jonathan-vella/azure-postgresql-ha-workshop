<#
.SYNOPSIS
    Checks PostgreSQL WAL and checkpoint settings that affect failover RTO.

.DESCRIPTION
    This script checks critical PostgreSQL parameters that impact failover recovery time:
    - checkpoint_timeout: How often WAL is checkpointed (affects recovery time)
    - max_wal_size: Maximum WAL size before checkpoint (affects recovery volume)
    - wal_level: Replication level
    
.PARAMETER ResourceGroupName
    Resource group containing the PostgreSQL server.

.PARAMETER ServerName
    PostgreSQL server name (auto-discovered if not provided).

.EXAMPLE
    .\Check-WAL-Settings.ps1 -ResourceGroupName 'rg-saif-pgsql-swc-01'
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
Write-Host " 🔍 PostgreSQL WAL & Checkpoint Configuration Checker" -ForegroundColor White
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Discover server
if (-not $ServerName) {
    Write-Host "📍 Discovering PostgreSQL server..." -ForegroundColor Yellow
    $serversJson = az postgres flexible-server list --resource-group $ResourceGroupName --output json
    $servers = $serversJson | ConvertFrom-Json
    $saifServers = $servers | Where-Object { $_.name -match 'saif|psql' }
    $ServerName = if ($saifServers.Count -gt 0) { $saifServers[0].name } else { $servers[0].name }
    Write-Host "✅ Found server: $ServerName" -ForegroundColor Green
}

Write-Host "📍 Checking server parameters..." -ForegroundColor Yellow

# Parameters to check
$params = @(
    "checkpoint_timeout",
    "max_wal_size",
    "wal_level",
    "synchronous_commit",
    "wal_buffers",
    "checkpoint_completion_target"
)

$results = @()
foreach ($param in $params) {
    try {
        $value = az postgres flexible-server parameter show `
            --resource-group $ResourceGroupName `
            --server-name $ServerName `
            --name $param `
            --query "value" -o tsv 2>$null
        
        $results += [PSCustomObject]@{
            Parameter = $param
            Value = $value
            Impact = switch ($param) {
                "checkpoint_timeout" { "Lower = faster recovery (default: 5min)" }
                "max_wal_size" { "Lower = less WAL to recover (default: 1GB)" }
                "wal_level" { "Should be 'replica' for HA" }
                "synchronous_commit" { "Should be 'on' for zero data loss" }
                "wal_buffers" { "Higher = better write performance" }
                "checkpoint_completion_target" { "Controls checkpoint spread (default: 0.9)" }
            }
        }
    } catch {
        Write-Host "⚠️  Could not retrieve: $param" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host " 📊 CURRENT CONFIGURATION" -ForegroundColor White
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

$results | Format-Table -Property Parameter, Value, Impact -Wrap

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host " 💡 RECOMMENDATIONS FOR FASTER FAILOVER RTO" -ForegroundColor White
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

Write-Host "1. checkpoint_timeout:" -ForegroundColor Yellow
Write-Host "   • Current default: 5 minutes" -ForegroundColor White
Write-Host "   • For faster RTO: Set to 1-2 minutes" -ForegroundColor Green
Write-Host "   • Trade-off: Slightly more I/O overhead" -ForegroundColor White
Write-Host ""

Write-Host "2. max_wal_size:" -ForegroundColor Yellow
Write-Host "   • Current default: 1GB (typical)" -ForegroundColor White
Write-Host "   • Recovery speed: ~40-200 MB/s depending on SKU" -ForegroundColor White
Write-Host "   • 1GB WAL at 40 MB/s = ~25 seconds recovery" -ForegroundColor Cyan
Write-Host "   • 1GB WAL at 200 MB/s = ~5 seconds recovery" -ForegroundColor Green
Write-Host ""

Write-Host "3. SKU Impact on RTO:" -ForegroundColor Yellow
Write-Host "   • D2ds_v4 (2 vCore): ~40 MB/s WAL recovery" -ForegroundColor White
Write-Host "   • D4ds_v5 (4 vCore): ~100 MB/s WAL recovery" -ForegroundColor Cyan
Write-Host "   • D8ds_v5+ (8+ vCore): ~200 MB/s WAL recovery" -ForegroundColor Green
Write-Host ""

Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host " ⚡ EXPECTED RTO BY SKU (Zone-Redundant HA)" -ForegroundColor White
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

$rtoEstimates = @(
    [PSCustomObject]@{ SKU = "D2ds_v4 (2vCore)"; WALRecovery = "~40 MB/s"; LightLoad = "30-45s"; HeavyLoad = "50-90s" }
    [PSCustomObject]@{ SKU = "D4ds_v5 (4vCore)"; WALRecovery = "~100 MB/s"; LightLoad = "25-35s"; HeavyLoad = "40-60s" }
    [PSCustomObject]@{ SKU = "D8ds_v5 (8vCore)"; WALRecovery = "~200 MB/s"; LightLoad = "20-30s"; HeavyLoad = "30-45s" }
)

$rtoEstimates | Format-Table -Property SKU, WALRecovery, @{
    Label = "RTO Light Load"
    Expression = { $_.LightLoad }
}, @{
    Label = "RTO Heavy Load"
    Expression = { $_.HeavyLoad }
}

Write-Host "Note: RTO includes detection time + WAL recovery + connection re-establishment" -ForegroundColor Cyan
Write-Host "SLA Target: 60-120 seconds for Zone-Redundant HA" -ForegroundColor White
Write-Host ""

Write-Host "✅ Complete!" -ForegroundColor Green
