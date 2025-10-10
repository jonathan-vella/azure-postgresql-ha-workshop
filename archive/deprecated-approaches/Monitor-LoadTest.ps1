<#
.SYNOPSIS
    Real-time monitoring dashboard for PostgreSQL load testing

.DESCRIPTION
    Displays real-time metrics from Azure Monitor during load tests.
    Shows CPU, memory, connections, TPS, and latency in a live dashboard.

.PARAMETER ResourceGroup
    Resource group name

.PARAMETER ServerName
    PostgreSQL server name (without .postgres.database.azure.com)

.PARAMETER RefreshInterval
    Refresh interval in seconds (default: 5)

.PARAMETER ShowDetailedMetrics
    Show additional detailed metrics (storage, IOPS, etc.)

.EXAMPLE
    .\Monitor-LoadTest.ps1 -ResourceGroup "rg-saif-pgsql-swc-01" -ServerName "psql-saifpg-abc123"

.EXAMPLE
    .\Monitor-LoadTest.ps1 -ResourceGroup "rg-saif-pgsql-swc-01" -ServerName "psql-saifpg-abc123" -RefreshInterval 10 -ShowDetailedMetrics

.NOTES
    Author: Azure Principal Architect Agent
    Version: 1.0.0
    Requires: Azure CLI
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroup,
    
    [Parameter(Mandatory=$true)]
    [string]$ServerName,
    
    [Parameter(Mandatory=$false)]
    [int]$RefreshInterval = 5,
    
    [Parameter(Mandatory=$false)]
    [switch]$ShowDetailedMetrics
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

function Get-MetricValue {
    param(
        [string]$ResourceId,
        [string]$MetricName,
        [string]$Aggregation = "Average"
    )
    
    $startTime = (Get-Date).AddMinutes(-5).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $endTime = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    
    try {
        $result = az monitor metrics list `
            --resource $ResourceId `
            --metric $MetricName `
            --start-time $startTime `
            --end-time $endTime `
            --aggregation $Aggregation `
            --interval PT1M `
            --query "value[0].timeseries[0].data[-1].$($Aggregation.ToLower())" `
            --output tsv 2>$null
        
        if ($result -and $result -ne "" -and $result -ne "null") {
            return [double]$result
        }
        return $null
    }
    catch {
        return $null
    }
}

function Get-ColorForValue {
    param(
        [double]$Value,
        [double]$GoodThreshold,
        [double]$WarningThreshold,
        [bool]$Inverse = $false
    )
    
    if ($Inverse) {
        # For metrics where lower is better (e.g., latency)
        if ($Value -le $GoodThreshold) { return "Green" }
        elseif ($Value -le $WarningThreshold) { return "Yellow" }
        else { return "Red" }
    }
    else {
        # For metrics where higher is worse (e.g., CPU %)
        if ($Value -lt $GoodThreshold) { return "Green" }
        elseif ($Value -lt $WarningThreshold) { return "Yellow" }
        else { return "Red" }
    }
}

function Format-ProgressBar {
    param(
        [double]$Value,
        [double]$Max = 100,
        [int]$Width = 50
    )
    
    $percentage = [Math]::Min($Value / $Max, 1.0)
    $filled = [int]($percentage * $Width)
    $empty = $Width - $filled
    
    $bar = "█" * $filled + "░" * $empty
    return "[$bar] $([Math]::Round($Value, 1))"
}

# ============================================================================
# INITIALIZATION
# ============================================================================

Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "📊 INITIALIZING POSTGRESQL MONITORING DASHBOARD" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Check Azure CLI
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Azure CLI not found. Please install from https://aka.ms/InstallAzureCLIDirect" -ForegroundColor Red
    exit 1
}

# Check if logged in
$account = az account show 2>$null | ConvertFrom-Json
if (-not $account) {
    Write-Host "❌ Not logged into Azure CLI. Run 'az login' first." -ForegroundColor Red
    exit 1
}

Write-Host "✅ Azure CLI authenticated" -ForegroundColor Green
Write-Host "   Subscription: $($account.name)" -ForegroundColor Gray
Write-Host ""

# Build resource ID
Write-Host "🔍 Resolving PostgreSQL server..." -ForegroundColor Yellow
$resourceId = "/subscriptions/$($account.id)/resourceGroups/$ResourceGroup/providers/Microsoft.DBforPostgreSQL/flexibleServers/$ServerName"

# Verify server exists
$serverInfo = az postgres flexible-server show `
    --resource-group $ResourceGroup `
    --name $ServerName `
    --output json 2>$null | ConvertFrom-Json

if (-not $serverInfo) {
    Write-Host "❌ PostgreSQL server not found: $ServerName" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Server found: $($serverInfo.fullyQualifiedDomainName)" -ForegroundColor Green
Write-Host "   SKU: $($serverInfo.sku.name) ($($serverInfo.sku.tier))" -ForegroundColor Gray
Write-Host "   HA: $($serverInfo.highAvailability.mode)" -ForegroundColor Gray
Write-Host ""

Write-Host "🚀 Starting monitoring dashboard..." -ForegroundColor Green
Write-Host "   Refresh interval: $RefreshInterval seconds" -ForegroundColor Gray
Write-Host "   Press Ctrl+C to exit" -ForegroundColor Gray
Write-Host ""
Start-Sleep -Seconds 2

# ============================================================================
# MONITORING LOOP
# ============================================================================

$iteration = 0
$history = @{
    CPU = [System.Collections.Generic.List[double]]::new()
    Memory = [System.Collections.Generic.List[double]]::new()
    Connections = [System.Collections.Generic.List[double]]::new()
}

while ($true) {
    $timestamp = Get-Date -Format "HH:mm:ss"
    $iteration++
    
    # Fetch metrics
    $cpu = Get-MetricValue -ResourceId $resourceId -MetricName "cpu_percent"
    $memory = Get-MetricValue -ResourceId $resourceId -MetricName "memory_percent"
    $connections = Get-MetricValue -ResourceId $resourceId -MetricName "active_connections"
    $networkIn = Get-MetricValue -ResourceId $resourceId -MetricName "network_bytes_ingress" -Aggregation "Total"
    $networkOut = Get-MetricValue -ResourceId $resourceId -MetricName "network_bytes_egress" -Aggregation "Total"
    $iops = Get-MetricValue -ResourceId $resourceId -MetricName "iops"
    $storage = Get-MetricValue -ResourceId $resourceId -MetricName "storage_percent"
    
    # Store history (last 60 samples)
    if ($cpu) {
        $history.CPU.Add($cpu)
        if ($history.CPU.Count > 60) { $history.CPU.RemoveAt(0) }
    }
    if ($memory) {
        $history.Memory.Add($memory)
        if ($history.Memory.Count > 60) { $history.Memory.RemoveAt(0) }
    }
    if ($connections) {
        $history.Connections.Add($connections)
        if ($history.Connections.Count > 60) { $history.Connections.RemoveAt(0) }
    }
    
    # Clear screen
    Clear-Host
    
    # ============================================================================
    # DASHBOARD HEADER
    # ============================================================================
    
    Write-Host "═══════════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "📊 POSTGRESQL REAL-TIME MONITORING DASHBOARD" -ForegroundColor Cyan -NoNewline
    Write-Host " [$timestamp]" -ForegroundColor White
    Write-Host "═══════════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "Server: " -NoNewline -ForegroundColor Gray
    Write-Host "$ServerName " -NoNewline -ForegroundColor White
    Write-Host "($($serverInfo.sku.name))" -ForegroundColor Gray
    Write-Host "Update: #$iteration every $RefreshInterval sec | " -NoNewline -ForegroundColor Gray
    Write-Host "History: $($history.CPU.Count) samples" -ForegroundColor Gray
    Write-Host ""
    
    # ============================================================================
    # CORE METRICS
    # ============================================================================
    
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
    Write-Host "⚡ CORE METRICS" -ForegroundColor Yellow
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
    Write-Host ""
    
    # CPU
    Write-Host "CPU Usage:        " -NoNewline
    if ($cpu -ne $null) {
        $cpuColor = Get-ColorForValue -Value $cpu -GoodThreshold 70 -WarningThreshold 90
        Write-Host (Format-ProgressBar -Value $cpu -Max 100) -NoNewline -ForegroundColor $cpuColor
        Write-Host "%" -ForegroundColor $cpuColor
        if ($history.CPU.Count -gt 5) {
            $cpuAvg = ($history.CPU | Measure-Object -Average).Average
            Write-Host "                  Avg (5m): $([Math]::Round($cpuAvg, 1))% | " -NoNewline -ForegroundColor DarkGray
            $cpuMax = ($history.CPU | Measure-Object -Maximum).Maximum
            Write-Host "Max: $([Math]::Round($cpuMax, 1))%" -ForegroundColor DarkGray
        }
    } else {
        Write-Host "N/A" -ForegroundColor Gray
    }
    Write-Host ""
    
    # Memory
    Write-Host "Memory Usage:     " -NoNewline
    if ($memory -ne $null) {
        $memColor = Get-ColorForValue -Value $memory -GoodThreshold 80 -WarningThreshold 90
        Write-Host (Format-ProgressBar -Value $memory -Max 100) -NoNewline -ForegroundColor $memColor
        Write-Host "%" -ForegroundColor $memColor
        if ($history.Memory.Count -gt 5) {
            $memAvg = ($history.Memory | Measure-Object -Average).Average
            Write-Host "                  Avg (5m): $([Math]::Round($memAvg, 1))% | " -NoNewline -ForegroundColor DarkGray
            $memMax = ($history.Memory | Measure-Object -Maximum).Maximum
            Write-Host "Max: $([Math]::Round($memMax, 1))%" -ForegroundColor DarkGray
        }
    } else {
        Write-Host "N/A" -ForegroundColor Gray
    }
    Write-Host ""
    
    # Connections
    Write-Host "Connections:      " -NoNewline
    if ($connections -ne $null) {
        $maxConn = 2000  # Based on our configuration
        $connPercent = ($connections / $maxConn) * 100
        $connColor = Get-ColorForValue -Value $connPercent -GoodThreshold 75 -WarningThreshold 90
        Write-Host "$([Math]::Round($connections, 0)) / $maxConn " -NoNewline -ForegroundColor $connColor
        Write-Host "($([Math]::Round($connPercent, 1))%)" -ForegroundColor $connColor
        if ($history.Connections.Count -gt 5) {
            $connAvg = ($history.Connections | Measure-Object -Average).Average
            Write-Host "                  Avg (5m): $([Math]::Round($connAvg, 0)) | " -NoNewline -ForegroundColor DarkGray
            $connMax = ($history.Connections | Measure-Object -Maximum).Maximum
            Write-Host "Max: $([Math]::Round($connMax, 0))" -ForegroundColor DarkGray
        }
    } else {
        Write-Host "N/A" -ForegroundColor Gray
    }
    Write-Host ""
    
    # ============================================================================
    # DETAILED METRICS (if requested)
    # ============================================================================
    
    if ($ShowDetailedMetrics) {
        Write-Host ""
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
        Write-Host "📈 DETAILED METRICS" -ForegroundColor Yellow
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
        Write-Host ""
        
        # Storage
        Write-Host "Storage:          " -NoNewline
        if ($storage -ne $null) {
            $storageColor = Get-ColorForValue -Value $storage -GoodThreshold 80 -WarningThreshold 90
            Write-Host "$([Math]::Round($storage, 1))%" -ForegroundColor $storageColor
        } else {
            Write-Host "N/A" -ForegroundColor Gray
        }
        
        # IOPS
        Write-Host "IOPS:             " -NoNewline
        if ($iops -ne $null) {
            Write-Host "$([Math]::Round($iops, 0))" -ForegroundColor White
        } else {
            Write-Host "N/A" -ForegroundColor Gray
        }
        
        # Network
        Write-Host "Network In:       " -NoNewline
        if ($networkIn -ne $null) {
            $networkInMB = $networkIn / 1MB
            Write-Host "$([Math]::Round($networkInMB, 2)) MB/min" -ForegroundColor White
        } else {
            Write-Host "N/A" -ForegroundColor Gray
        }
        
        Write-Host "Network Out:      " -NoNewline
        if ($networkOut -ne $null) {
            $networkOutMB = $networkOut / 1MB
            Write-Host "$([Math]::Round($networkOutMB, 2)) MB/min" -ForegroundColor White
        } else {
            Write-Host "N/A" -ForegroundColor Gray
        }
        
        Write-Host ""
    }
    
    # ============================================================================
    # STATUS INDICATORS
    # ============================================================================
    
    Write-Host ""
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
    Write-Host "🚦 SYSTEM STATUS" -ForegroundColor Yellow
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
    Write-Host ""
    
    # Overall health
    $healthStatus = "🟢 HEALTHY"
    $healthColor = "Green"
    
    if ($cpu -and $cpu -gt 90) {
        $healthStatus = "🔴 CRITICAL: High CPU"
        $healthColor = "Red"
    }
    elseif ($memory -and $memory -gt 90) {
        $healthStatus = "🔴 CRITICAL: High Memory"
        $healthColor = "Red"
    }
    elseif ($connections -and $connections -gt 1900) {
        $healthStatus = "🔴 CRITICAL: Connection Pool Exhausted"
        $healthColor = "Red"
    }
    elseif ($cpu -and $cpu -gt 80) {
        $healthStatus = "🟡 WARNING: Elevated CPU"
        $healthColor = "Yellow"
    }
    elseif ($memory -and $memory -gt 80) {
        $healthStatus = "🟡 WARNING: Elevated Memory"
        $healthColor = "Yellow"
    }
    elseif ($connections -and $connections -gt 1500) {
        $healthStatus = "🟡 WARNING: High Connection Count"
        $healthColor = "Yellow"
    }
    
    Write-Host "Overall Status: " -NoNewline
    Write-Host $healthStatus -ForegroundColor $healthColor
    Write-Host ""
    
    # ============================================================================
    # FOOTER
    # ============================================================================
    
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
    Write-Host "Next update in $RefreshInterval seconds... " -NoNewline -ForegroundColor Gray
    Write-Host "Press Ctrl+C to exit" -ForegroundColor Gray
    Write-Host "═══════════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    
    Start-Sleep -Seconds $RefreshInterval
}
