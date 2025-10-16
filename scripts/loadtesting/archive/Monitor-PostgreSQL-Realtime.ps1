<#
.SYNOPSIS
    Real-time PostgreSQL performance monitoring during load tests

.DESCRIPTION
    Monitors key metrics in real-time using Azure CLI:
    - TPS (Transactions Per Second)
    - IOPS utilization and absolute read/write IOPS
    - CPU and Memory %
    - Disk throughput
    - Active connections
    - Replication lag

.PARAMETER ResourceGroup
    Azure resource group name

.PARAMETER PostgreSQLServer
    PostgreSQL Flexible Server name

.PARAMETER RefreshIntervalSeconds
    Seconds between metric refreshes (default: 10)

.EXAMPLE
    .\Monitor-PostgreSQL-Realtime.ps1 -ResourceGroup "rg-saif-pgsql-swc-01" -PostgreSQLServer "psql-saifpg-10081025"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroup,

    [Parameter(Mandatory=$true)]
    [string]$PostgreSQLServer,

    [Parameter(Mandatory=$false)]
    [int]$RefreshIntervalSeconds = 10
)

$ErrorActionPreference = "Continue"

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "📊 POSTGRESQL REAL-TIME PERFORMANCE MONITOR" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "Server: $PostgreSQLServer" -ForegroundColor Gray
Write-Host "Refresh: Every $RefreshIntervalSeconds seconds" -ForegroundColor Gray
Write-Host "Press Ctrl+C to stop" -ForegroundColor Gray
Write-Host ""

# Get resource ID
$server = az postgres flexible-server show `
    --resource-group $ResourceGroup `
    --name $PostgreSQLServer `
    --query "{id:id,sku:sku.name,storage:storage.storageSizeGb}" `
    -o json | ConvertFrom-Json

$resourceId = $server.id

Write-Host "✅ Connected to server" -ForegroundColor Green
Write-Host "   SKU: $($server.sku)" -ForegroundColor Gray
Write-Host "   Storage: $($server.storage) GB" -ForegroundColor Gray
Write-Host ""

# Header
function Write-Header {
    Write-Host "─────────────────────────────────────────────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host ("{0,-12} {1,-8} {2,-10} {3,-10} {4,-8} {5,-8} {6,-12} {7,-12} {8,-6} {9,-8}" -f `
        "Time", "TPS", "IOPS%", "R/W IOPS", "CPU%", "Mem%", "Read MB/s", "Write MB/s", "Conns", "RepLag") -ForegroundColor Yellow
    Write-Host "─────────────────────────────────────────────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
}

function Get-Metric {
    param(
        [string]$MetricName,
        [string]$Aggregation = "Average",
        [int]$Timespan = 60  # seconds
    )
    
    try {
        $endTime = (Get-Date).ToUniversalTime()
        $startTime = $endTime.AddSeconds(-$Timespan)
        
        $result = az monitor metrics list `
            --resource $resourceId `
            --metric $MetricName `
            --aggregation $Aggregation `
            --start-time $startTime.ToString("yyyy-MM-ddTHH:mm:ssZ") `
            --end-time $endTime.ToString("yyyy-MM-ddTHH:mm:ssZ") `
            --interval PT1M `
            -o json 2>$null | ConvertFrom-Json
        
        if ($result.value -and $result.value[0].timeseries -and $result.value[0].timeseries[0].data) {
            $dataPoints = $result.value[0].timeseries[0].data | Where-Object { $null -ne $_.$Aggregation }
            if ($dataPoints) {
                return ($dataPoints | Select-Object -Last 1).$Aggregation
            }
        }
        return $null
    }
    catch {
        return $null
    }
}

Write-Header
$iteration = 0

while ($true) {
    $iteration++
    $now = Get-Date
    
    # Fetch all metrics
    $tps = Get-Metric -MetricName "xact_commit" -Aggregation "Average"
    $iopsPercent = Get-Metric -MetricName "disk_iops_consumed_percentage" -Aggregation "Average"
    $readIops = Get-Metric -MetricName "read_iops" -Aggregation "Average"
    $writeIops = Get-Metric -MetricName "write_iops" -Aggregation "Average"
    $cpu = Get-Metric -MetricName "cpu_percent" -Aggregation "Average"
    $memory = Get-Metric -MetricName "memory_percent" -Aggregation "Average"
    $readThroughput = Get-Metric -MetricName "read_throughput" -Aggregation "Average"
    $writeThroughput = Get-Metric -MetricName "write_throughput" -Aggregation "Average"
    $connections = Get-Metric -MetricName "active_connections" -Aggregation "Average"
    $replicationLag = Get-Metric -MetricName "physical_replication_delay_in_seconds" -Aggregation "Maximum"
    
    # Format values
    $tpsStr = if ($tps) { [math]::Round($tps, 0).ToString() } else { "N/A" }
    $iopsStr = if ($iopsPercent) { [math]::Round($iopsPercent, 1).ToString() + "%" } else { "N/A" }
    $rwIopsStr = if ($readIops -and $writeIops) { 
        [math]::Round($readIops, 0).ToString() + "/" + [math]::Round($writeIops, 0).ToString()
    } else { "N/A" }
    $cpuStr = if ($cpu) { [math]::Round($cpu, 1).ToString() + "%" } else { "N/A" }
    $memStr = if ($memory) { [math]::Round($memory, 1).ToString() + "%" } else { "N/A" }
    $readMBStr = if ($readThroughput) { 
        [math]::Round($readThroughput / 1024.0 / 1024.0, 1).ToString()
    } else { "N/A" }
    $writeMBStr = if ($writeThroughput) { 
        [math]::Round($writeThroughput / 1024.0 / 1024.0, 1).ToString()
    } else { "N/A" }
    $connsStr = if ($connections) { [math]::Round($connections, 0).ToString() } else { "N/A" }
    $repLagStr = if ($replicationLag) { [math]::Round($replicationLag, 2).ToString() + "s" } else { "N/A" }
    
    # Color coding for TPS
    $tpsColor = "White"
    if ($tps) {
        if ($tps -ge 8000) { $tpsColor = "Green" }
        elseif ($tps -ge 5000) { $tpsColor = "Yellow" }
        else { $tpsColor = "Red" }
    }
    
    # Color coding for IOPS
    $iopsColor = "White"
    if ($iopsPercent) {
        if ($iopsPercent -lt 50) { $iopsColor = "Green" }
        elseif ($iopsPercent -lt 80) { $iopsColor = "Yellow" }
        else { $iopsColor = "Red" }
    }
    
    # Color coding for CPU
    $cpuColor = "White"
    if ($cpu) {
        if ($cpu -lt 70) { $cpuColor = "Green" }
        elseif ($cpu -lt 90) { $cpuColor = "Yellow" }
        else { $cpuColor = "Red" }
    }
    
    # Print row
    Write-Host ("{0,-12} " -f $now.ToString("HH:mm:ss")) -NoNewline
    Write-Host ("{0,-8} " -f $tpsStr) -NoNewline -ForegroundColor $tpsColor
    Write-Host ("{0,-10} " -f $iopsStr) -NoNewline -ForegroundColor $iopsColor
    Write-Host ("{0,-10} " -f $rwIopsStr) -NoNewline
    Write-Host ("{0,-8} " -f $cpuStr) -NoNewline -ForegroundColor $cpuColor
    Write-Host ("{0,-8} " -f $memStr) -NoNewline
    Write-Host ("{0,-12} " -f $readMBStr) -NoNewline
    Write-Host ("{0,-12} " -f $writeMBStr) -NoNewline
    Write-Host ("{0,-6} " -f $connsStr) -NoNewline
    Write-Host ("{0,-8}" -f $repLagStr)
    
    # Print header every 20 rows
    if ($iteration % 20 -eq 0) {
        Write-Host ""
        Write-Header
    }
    
    Start-Sleep -Seconds $RefreshIntervalSeconds
}
