<#
.SYNOPSIS
    Diagnoses PostgreSQL failover performance issues and provides recommendations.

.DESCRIPTION
    Analyzes Azure PostgreSQL Flexible Server configuration, resource metrics,
    activity logs, and replication status to identify root causes of slow RTO
    or RPO violations. Provides actionable recommendations for improvement.
    
    This script can be run standalone or is automatically triggered by
    Test-PostgreSQL-Failover.ps1 when SLA targets are not met.

.PARAMETER ResourceGroupName
    The resource group containing the PostgreSQL server.

.PARAMETER ServerName
    Optional. PostgreSQL server name. Auto-discovered if not specified.

.PARAMETER FailoverStartTime
    Optional. Start time of failover to analyze metrics (UTC).
    Defaults to 1 hour ago.

.PARAMETER RTO
    Optional. Actual RTO observed (in seconds) for context.

.PARAMETER AnalysisDepth
    Analysis depth: Basic, Standard, or Detailed.
    Default is Standard.

.EXAMPLE
    .\Diagnose-Failover-Performance.ps1 -ResourceGroupName "rg-saif-pgsql-swc-01"

.EXAMPLE
    .\Diagnose-Failover-Performance.ps1 `
        -ResourceGroupName "rg-saif-pgsql-swc-01" `
        -ServerName "psql-saifpg-10081025" `
        -RTO 314 `
        -FailoverStartTime "2025-10-08T14:23:45Z"

.EXAMPLE
    .\Diagnose-Failover-Performance.ps1 `
        -ResourceGroupName "rg-saif-pgsql-swc-01" `
        -AnalysisDepth Detailed

.NOTES
    Author: SAIF Team
    Version: 1.0.0
    Requires: Azure CLI, PowerShell 7+
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$false)]
    [string]$ServerName,
    
    [Parameter(Mandatory=$false)]
    [DateTime]$FailoverStartTime = (Get-Date).AddHours(-1),
    
    [Parameter(Mandatory=$false)]
    [double]$RTO = 0,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("Basic", "Standard", "Detailed")]
    [string]$AnalysisDepth = "Standard"
)

$ErrorActionPreference = "Stop"

#region Helper Functions

function Show-Banner {
    param([string]$message)
    $border = "=" * 70
    Write-Host ""
    Write-Host $border -ForegroundColor Cyan
    Write-Host "  $message" -ForegroundColor White
    Write-Host $border -ForegroundColor Cyan
    Write-Host ""
}

function Write-DiagnosticSection {
    param([string]$title)
    Write-Host ""
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
    Write-Host "  $title" -ForegroundColor Cyan
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
}

#endregion

#region Main Script

Show-Banner "🔍 PostgreSQL Failover Performance Diagnostics"

Write-Host "Analysis Depth: $AnalysisDepth" -ForegroundColor Gray
Write-Host "Failover Window: $($FailoverStartTime.ToString('yyyy-MM-dd HH:mm:ss')) UTC → Now" -ForegroundColor Gray
Write-Host ""

# Check Azure CLI
Write-Host "Checking Azure CLI authentication..." -ForegroundColor Yellow
try {
    $currentAccount = az account show --query "{name:name, user:user.name}" -o json | ConvertFrom-Json
    Write-Host "✅ Logged in as: $($currentAccount.user)" -ForegroundColor Green
} catch {
    Write-Host "❌ Please run 'az login' first" -ForegroundColor Red
    exit 1
}

# Discover PostgreSQL server if not specified
if (-not $ServerName) {
    Write-Host "Discovering PostgreSQL server..." -ForegroundColor Yellow
    $servers = az postgres flexible-server list `
        --resource-group $ResourceGroupName `
        --query "[?contains(name, 'saif')].{name:name, ha:highAvailability.mode}" `
        --output json | ConvertFrom-Json
    
    if ($servers.Count -eq 0) {
        Write-Host "❌ No PostgreSQL servers found in resource group" -ForegroundColor Red
        exit 1
    }
    
    if ($servers.Count -gt 1) {
        Write-Host "⚠️  Multiple servers found. Using first: $($servers[0].name)" -ForegroundColor Yellow
        $ServerName = $servers[0].name
    } else {
        $ServerName = $servers[0].name
        Write-Host "✅ Found server: $ServerName" -ForegroundColor Green
    }
}

#region 1. Server Configuration Analysis

Write-DiagnosticSection "1️⃣  Server Configuration Analysis"

$server = az postgres flexible-server show `
    --resource-group $ResourceGroupName `
    --name $ServerName `
    --output json | ConvertFrom-Json

$serverTier = $server.sku.tier
$serverSKU = $server.sku.name
$vCores = 1
if ($serverSKU -match 'D(\d+)') { $vCores = [int]$Matches[1] }
$storageSize = $server.storage.storageSizeGB
$storageIOPS = $server.storage.iops
$haMode = $server.highAvailability.mode
$haState = $server.highAvailability.state

Write-Host "Server Details:" -ForegroundColor Cyan
Write-Host "  Name: $ServerName" -ForegroundColor White
Write-Host "  Tier: " -NoNewline -ForegroundColor White
if ($serverTier -eq "Burstable") {
    Write-Host "$serverTier ⚠️" -ForegroundColor Red
} else {
    Write-Host "$serverTier ✓" -ForegroundColor Green
}
Write-Host "  SKU: $serverSKU ($vCores vCores)" -ForegroundColor White
Write-Host "  Storage: ${storageSize}GB" -ForegroundColor White
Write-Host "  IOPS: $storageIOPS" -ForegroundColor White
Write-Host "  HA Mode: $haMode" -ForegroundColor White
Write-Host "  HA State: $haState" -ForegroundColor $(if ($haState -eq 'Healthy') { 'Green' } else { 'Yellow' })
Write-Host "  Primary Zone: $($server.availabilityZone)" -ForegroundColor White
Write-Host "  Standby Zone: $($server.highAvailability.standbyAvailabilityZone)" -ForegroundColor White

# Tier Assessment
Write-Host ""
Write-Host "Tier Assessment:" -ForegroundColor Cyan
if ($serverTier -eq "Burstable") {
    Write-Host "  🔴 CRITICAL: Burstable tier detected" -ForegroundColor Red
    Write-Host "     • Not recommended for HA production workloads" -ForegroundColor Yellow
    Write-Host "     • Expected RTO: 200-600 seconds (vs 60-120s target)" -ForegroundColor Yellow
    Write-Host "     • CPU credits deplete under sustained load" -ForegroundColor Yellow
    Write-Host "     • Limited IOPS for synchronous replication" -ForegroundColor Yellow
    Write-Host "     • This explains slow failover performance" -ForegroundColor Yellow
} elseif ($serverTier -eq "GeneralPurpose" -and $vCores -lt 4) {
    Write-Host "  🟡 MARGINAL: General Purpose with low vCores" -ForegroundColor Yellow
    Write-Host "     • Minimum configuration for HA" -ForegroundColor White
    Write-Host "     • May experience slower RTO under high load" -ForegroundColor White
    Write-Host "     • Consider D4ds_v4+ for better performance" -ForegroundColor White
} else {
    Write-Host "  🟢 GOOD: Appropriate tier for HA workloads" -ForegroundColor Green
    Write-Host "     • Should achieve 60-120s RTO under normal conditions" -ForegroundColor White
}

# IOPS Assessment
Write-Host ""
Write-Host "Storage IOPS Assessment:" -ForegroundColor Cyan
if ($storageIOPS -lt 5000) {
    Write-Host "  🟡 LOW: ${storageIOPS} IOPS" -ForegroundColor Yellow
    Write-Host "     • May bottleneck under high write load" -ForegroundColor White
    Write-Host "     • Synchronous replication requires consistent IOPS" -ForegroundColor White
} elseif ($storageIOPS -lt 10000) {
    Write-Host "  🟢 ADEQUATE: ${storageIOPS} IOPS" -ForegroundColor Green
    Write-Host "     • Sufficient for moderate workloads" -ForegroundColor White
} else {
    Write-Host "  🟢 EXCELLENT: ${storageIOPS} IOPS" -ForegroundColor Green
    Write-Host "     • High IOPS capacity for demanding workloads" -ForegroundColor White
}

#endregion

#region 2. Resource Metrics Analysis

if ($AnalysisDepth -in @("Standard", "Detailed")) {
    Write-DiagnosticSection "2️⃣  Resource Metrics Analysis"
    
    Write-Host "Querying Azure Monitor metrics..." -ForegroundColor Yellow
    
    $resourceId = $server.id
    $endTime = Get-Date
    $startTime = $FailoverStartTime
    
    try {
        # CPU Metrics
        Write-Host "  Analyzing CPU utilization..." -ForegroundColor Gray
        $cpuMetrics = az monitor metrics list `
            --resource $resourceId `
            --metric cpu_percent `
            --start-time $startTime.ToString("yyyy-MM-ddTHH:mm:ssZ") `
            --end-time $endTime.ToString("yyyy-MM-ddTHH:mm:ssZ") `
            --interval PT1M `
            --output json 2>$null | ConvertFrom-Json
        
        if ($cpuMetrics.value.Count -gt 0) {
            $cpuData = $cpuMetrics.value[0].timeseries[0].data | Where-Object { $_.average -ne $null }
            if ($cpuData.Count -gt 0) {
                $avgCPU = ($cpuData | Measure-Object -Property average -Average).Average
                $maxCPU = ($cpuData | Measure-Object -Property average -Maximum).Maximum
                
                Write-Host ""
                Write-Host "CPU Utilization:" -ForegroundColor Cyan
                Write-Host "  Average: $([Math]::Round($avgCPU, 1))%" -ForegroundColor White
                Write-Host "  Peak: $([Math]::Round($maxCPU, 1))%" -ForegroundColor $(if ($maxCPU -gt 80) { 'Red' } elseif ($maxCPU -gt 60) { 'Yellow' } else { 'Green' })
                
                if ($maxCPU -gt 80) {
                    Write-Host "  🔴 HIGH: CPU saturation detected" -ForegroundColor Red
                    Write-Host "     • Impacts failover performance" -ForegroundColor Yellow
                    Write-Host "     • Consider upgrading to higher vCore SKU" -ForegroundColor Yellow
                } elseif ($maxCPU -gt 60) {
                    Write-Host "  🟡 MODERATE: CPU under pressure" -ForegroundColor Yellow
                } else {
                    Write-Host "  🟢 NORMAL: CPU within healthy range" -ForegroundColor Green
                }
            }
        }
        
        # IOPS Metrics
        Write-Host ""
        Write-Host "  Analyzing IOPS..." -ForegroundColor Gray
        $iopsMetrics = az monitor metrics list `
            --resource $resourceId `
            --metric iops `
            --start-time $startTime.ToString("yyyy-MM-ddTHH:mm:ssZ") `
            --end-time $endTime.ToString("yyyy-MM-ddTHH:mm:ssZ") `
            --interval PT1M `
            --output json 2>$null | ConvertFrom-Json
        
        if ($iopsMetrics.value.Count -gt 0) {
            $iopsData = $iopsMetrics.value[0].timeseries[0].data | Where-Object { $_.average -ne $null }
            if ($iopsData.Count -gt 0) {
                $avgIOPS = ($iopsData | Measure-Object -Property average -Average).Average
                $maxIOPS = ($iopsData | Measure-Object -Property average -Maximum).Maximum
                
                Write-Host "IOPS Utilization:" -ForegroundColor Cyan
                Write-Host "  Average: $([Math]::Round($avgIOPS, 0)) IOPS" -ForegroundColor White
                Write-Host "  Peak: $([Math]::Round($maxIOPS, 0)) IOPS" -ForegroundColor White
                Write-Host "  Capacity: $storageIOPS IOPS" -ForegroundColor White
                
                $iopsPercent = ($maxIOPS / $storageIOPS) * 100
                Write-Host "  Utilization: $([Math]::Round($iopsPercent, 1))%" -ForegroundColor $(if ($iopsPercent -gt 90) { 'Red' } elseif ($iopsPercent -gt 70) { 'Yellow' } else { 'Green' })
                
                if ($iopsPercent -gt 90) {
                    Write-Host "  🔴 CRITICAL: IOPS throttling likely" -ForegroundColor Red
                    Write-Host "     • Storage performance bottleneck" -ForegroundColor Yellow
                    Write-Host "     • Increase storage size for more IOPS" -ForegroundColor Yellow
                } elseif ($iopsPercent -gt 70) {
                    Write-Host "  🟡 HIGH: Approaching IOPS limits" -ForegroundColor Yellow
                }
            }
        }
        
    } catch {
        Write-Host "  ⚠️  Could not retrieve metrics: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

#endregion

#region 3. Activity Log Analysis

if ($AnalysisDepth -in @("Standard", "Detailed")) {
    Write-DiagnosticSection "3️⃣  Activity Log Analysis"
    
    Write-Host "Checking for warnings and errors..." -ForegroundColor Yellow
    
    try {
        $activityLog = az monitor activity-log list `
            --resource-group $ResourceGroupName `
            --start-time $startTime.ToString("yyyy-MM-ddTHH:mm:ssZ") `
            --offset 2h `
            --output json | ConvertFrom-Json
        
        $relevantEvents = $activityLog | Where-Object {
            $_.resourceId -like "*$ServerName*" -and
            $_.level -in @("Warning", "Error", "Critical")
        }
        
        if ($relevantEvents.Count -gt 0) {
            Write-Host ""
            Write-Host "⚠️  Found $($relevantEvents.Count) warning/error events:" -ForegroundColor Yellow
            
            foreach ($event in $relevantEvents | Select-Object -First 5) {
                $timestamp = [DateTime]::Parse($event.eventTimestamp).ToString("HH:mm:ss")
                Write-Host "  [$timestamp] $($event.level): $($event.operationName.localizedValue)" -ForegroundColor Gray
                if ($event.status.localizedValue) {
                    Write-Host "              Status: $($event.status.localizedValue)" -ForegroundColor DarkGray
                }
            }
            
            if ($relevantEvents.Count -gt 5) {
                Write-Host "  ... and $($relevantEvents.Count - 5) more events" -ForegroundColor DarkGray
            }
        } else {
            Write-Host "  ✅ No warnings or errors found" -ForegroundColor Green
        }
        
    } catch {
        Write-Host "  ⚠️  Could not retrieve activity log: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

#endregion

#region 4. Recommendations

Write-DiagnosticSection "📋 Recommendations"

$recommendations = @()

# Tier-based recommendations
if ($serverTier -eq "Burstable") {
    $recommendations += @{
        Priority = "CRITICAL"
        Category = "Server Tier"
        Issue = "Burstable tier cannot meet HA SLA targets"
        Action = "Upgrade to General Purpose D2ds_v4 (minimum)"
        Command = "az postgres flexible-server update --resource-group $ResourceGroupName --name $ServerName --sku-name Standard_D2ds_v4 --tier GeneralPurpose"
        Impact = "RTO improvement: ~${RTO}s → 60-90s"
        Cost = "~`$97/month increase (~`$120/month total)"
    }
} elseif ($serverTier -eq "GeneralPurpose" -and $vCores -lt 4 -and $RTO -gt 120) {
    $recommendations += @{
        Priority = "HIGH"
        Category = "Server Tier"
        Issue = "Low vCore count may impact failover performance"
        Action = "Consider upgrading to D4ds_v4 (4 vCores)"
        Command = "az postgres flexible-server update --resource-group $ResourceGroupName --name $ServerName --sku-name Standard_D4ds_v4"
        Impact = "Better RTO consistency under load"
        Cost = "~`$90/month increase (~`$210/month total)"
    }
}

# IOPS recommendations
if ($storageIOPS -lt 5000) {
    $recommendations += @{
        Priority = "MEDIUM"
        Category = "Storage Performance"
        Issue = "Low IOPS may bottleneck replication"
        Action = "Increase storage size for more IOPS (3 IOPS per GB)"
        Command = "az postgres flexible-server update --resource-group $ResourceGroupName --name $ServerName --storage-size 256"
        Impact = "More consistent replication performance"
        Cost = "~`$30/month for 256GB storage"
    }
}

# General recommendations
$recommendations += @{
    Priority = "LOW"
    Category = "Monitoring"
    Issue = "Ensure continuous monitoring"
    Action = "Set up Azure Monitor alerts for RTO/RPO metrics"
    Command = "Review Azure Monitor → Alerts in Portal"
    Impact = "Proactive issue detection"
    Cost = "Free tier available"
}

$recommendations += @{
    Priority = "LOW"
    Category = "Testing"
    Issue = "Regular failover testing needed"
    Action = "Schedule quarterly failover tests"
    Command = ".\Test-PostgreSQL-Failover.ps1 -ResourceGroupName $ResourceGroupName"
    Impact = "Validate HA configuration and SLA compliance"
    Cost = "No cost (planned failover)"
}

# Display recommendations
foreach ($rec in $recommendations | Sort-Object { 
    switch ($_.Priority) {
        "CRITICAL" { 1 }
        "HIGH" { 2 }
        "MEDIUM" { 3 }
        "LOW" { 4 }
    }
}) {
    Write-Host ""
    $color = switch ($rec.Priority) {
        "CRITICAL" { "Red" }
        "HIGH" { "Yellow" }
        "MEDIUM" { "Cyan" }
        "LOW" { "Gray" }
    }
    
    Write-Host "[$($rec.Priority)] $($rec.Category)" -ForegroundColor $color
    Write-Host "  Issue: $($rec.Issue)" -ForegroundColor White
    Write-Host "  Action: $($rec.Action)" -ForegroundColor White
    Write-Host "  Impact: $($rec.Impact)" -ForegroundColor Green
    if ($rec.Cost) {
        Write-Host "  Cost: $($rec.Cost)" -ForegroundColor Yellow
    }
    if ($rec.Command -and $AnalysisDepth -eq "Detailed") {
        Write-Host "  Command:" -ForegroundColor DarkGray
        Write-Host "    $($rec.Command)" -ForegroundColor DarkGray
    }
}

#endregion

#region 5. Summary

Show-Banner "📊 Diagnostic Summary"

if ($RTO -gt 0) {
    Write-Host "Observed RTO: ${RTO}s (target: 120s)" -ForegroundColor White
    if ($RTO -gt 120) {
        $multiplier = [Math]::Round($RTO / 120, 1)
        Write-Host "Performance: ${multiplier}x slower than target" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Key Findings:" -ForegroundColor Cyan

if ($serverTier -eq "Burstable") {
    Write-Host "  🔴 Burstable tier is primary bottleneck" -ForegroundColor Red
    Write-Host "  ⚡ Upgrade to General Purpose D2ds_v4+ recommended" -ForegroundColor Yellow
} else {
    Write-Host "  ✅ Server tier appropriate for HA" -ForegroundColor Green
}

if ($haState -eq "Healthy" -and $haMode -eq "ZoneRedundant") {
    Write-Host "  ✅ HA configuration correct" -ForegroundColor Green
} else {
    Write-Host "  ⚠️  Check HA configuration" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "  1. Review recommendations above" -ForegroundColor White
Write-Host "  2. Implement critical fixes first" -ForegroundColor White
Write-Host "  3. Re-run failover test after changes" -ForegroundColor White
Write-Host "  4. Monitor trends over multiple tests" -ForegroundColor White

Write-Host ""
Write-Host "For detailed guidance, see:" -ForegroundColor Gray
Write-Host "  docs/v1.0.0/failover-testing-guide.md#troubleshooting" -ForegroundColor DarkGray

Write-Host ""

#endregion

#endregion
