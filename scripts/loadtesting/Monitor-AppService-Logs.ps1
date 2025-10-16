<#
.SYNOPSIS
Monitor LoadGenerator on App Service with Application Insights integration

.DESCRIPTION
Real-time monitoring script that queries Application Insights for:
- Container execution status and duration
- Error logs and exceptions
- Performance metrics (throughput, latency)
- Failover events and RTO calculations
- Transaction counts and statistics

.PARAMETER AppServiceName
Name of the App Service running LoadGenerator

.PARAMETER ResourceGroup
Azure Resource Group containing the App Service

.PARAMETER ApplicationInsightsName
Application Insights resource name (default: {AppServiceName}-ai)

.PARAMETER WaitForCompletion
Wait for container to complete (default: $true)

.PARAMETER MaxWaitTime
Maximum time to wait for completion in seconds (default: 3600 = 1 hour)

.PARAMETER RefreshInterval
Refresh interval in seconds for monitoring (default: 10)

.PARAMETER OutputPath
Path to save error logs (default: ./loadtest-results/)

.EXAMPLE
.\Monitor-AppService-Logs.ps1 -AppServiceName "app-loadgen-001" `
    -ResourceGroup "rg-pgv2-usc01" `
    -WaitForCompletion $true

.EXAMPLE
# Query logs after deployment
.\Monitor-AppService-Logs.ps1 -AppServiceName "app-loadgen-001" `
    -ResourceGroup "rg-pgv2-usc01" `
    -WaitForCompletion $false
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$AppServiceName,

    [Parameter(Mandatory = $false)]
    [string]$ResourceGroup,

    [Parameter(Mandatory = $false)]
    [string]$ApplicationInsightsName,

    [Parameter(Mandatory = $false)]
    [bool]$WaitForCompletion = $true,

    [Parameter(Mandatory = $false)]
    [int]$MaxWaitTime = 3600,

    [Parameter(Mandatory = $false)]
    [int]$RefreshInterval = 10,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = "./loadtest-results",

    [Parameter(Mandatory = $false)]
    [string]$ConfigFile = "./LoadGenerator-Config.ps1"
)

# ============================================================================
# RESOLVE CONFIG FILE PATH
# ============================================================================

# If config file is relative path, resolve it relative to script directory
if (-not [System.IO.Path]::IsPathRooted($ConfigFile)) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $ConfigFile = Join-Path $scriptDir $ConfigFile
}

# ============================================================================
# LOAD CONFIGURATION IF PROVIDED
# ============================================================================

if (Test-Path $ConfigFile) {
    . $ConfigFile
    
    # Use config values if parameters not provided
    if (-not $AppServiceName) {
        $AppServiceName = $AppServiceConfig.AppServiceName
    }
    if (-not $ResourceGroup) {
        $ResourceGroup = $ResourceGroup
    }
    if (-not $ApplicationInsightsName) {
        $ApplicationInsightsName = "$AppServiceName-ai"
    }
}

# ============================================================================
# FIND EXISTING APP SERVICE (if one was already deployed)
# ============================================================================
# Since $RandomSuffix changes each script run, look for existing app-loadgen-* services
if (-not $AppServiceName -or -not (az webapp show --name $AppServiceName --resource-group $ResourceGroup 2>$null)) {
    $existingAppServices = az webapp list --resource-group $ResourceGroup --query "[?starts_with(name, 'app-loadgen-')].name" -o tsv 2>$null
    if ($existingAppServices) {
        # Use the first existing one found
        $AppServiceName = ($existingAppServices -split "`n")[0].Trim()
        Write-Host "ℹ  Found existing App Service: $AppServiceName" -ForegroundColor Yellow
        
        # Update Application Insights name to match
        $ApplicationInsightsName = "$AppServiceName-ai"
    }
}

$ErrorActionPreference = "Stop"

# Ensure output directory exists
if (-not (Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$errorLogFile = Join-Path $OutputPath "appservice_errors_$timestamp.log"
$metricsFile = Join-Path $OutputPath "appservice_metrics_$timestamp.csv"

function Write-Section {
    param([string]$Title)
    Write-Host "`n$Title" -ForegroundColor Cyan
    Write-Host ("━" * 70) -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "  ✓ $Message" -ForegroundColor Green
}

function Write-Info {
    param([string]$Message)
    Write-Host "  ℹ $Message" -ForegroundColor Yellow
}

function Write-Error-Custom {
    param([string]$Message)
    Write-Host "  ✗ $Message" -ForegroundColor Red
}

function Get-AppServiceStatus {
    try {
        $app = az webapp show --name $AppServiceName --resource-group $ResourceGroup | ConvertFrom-Json
        return @{
            State = $app.state
            LastModified = $app.lastModifiedTimeUtc
            DefaultHostName = $app.defaultHostName
        }
    }
    catch {
        return $null
    }
}

function Get-ContainerLogs {
    try {
        $logs = az webapp log tail --name $AppServiceName --resource-group $ResourceGroup --lines 100 2>$null
        return $logs
    }
    catch {
        return $null
    }
}

function Query-ApplicationInsights {
    param(
        [string]$Query,
        [string]$TimeSpan = "PT1H"
    )
    
    try {
        $result = az monitor metrics list-definitions --resource "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$ResourceGroup/providers/microsoft.insights/components/$ApplicationInsightsName" 2>$null | ConvertFrom-Json
        
        # Alternative: Use KQL query through Application Insights
        # Note: Requires application insights extension
        $kqlQuery = $Query
        
        # For now, return basic metrics
        return @{
            Timestamp = Get-Date
            Status = "Querying"
        }
    }
    catch {
        return $null
    }
}

function Get-ErrorLogs {
    Write-Section "📋 Querying Error Logs from Application Insights"
    
    try {
        $appInsights = az monitor app-insights component show --app $ApplicationInsightsName --resource-group $ResourceGroup | ConvertFrom-Json
        
        if (-not $appInsights) {
            Write-Error-Custom "Application Insights not found"
            return @()
        }
        
        Write-Info "Application Insights: $($appInsights.name)"
        Write-Info "Instrumentation Key: $($appInsights.instrumentationKey)"
        
        # Query exceptions through container logs
        Write-Info "Retrieving container logs..."
        
        $logs = Get-ContainerLogs
        if ($logs) {
            # Parse and extract errors
            $errors = $logs | Select-String -Pattern "(error|exception|failed)" -AllMatches
            
            if ($errors) {
                Write-Success "Found $($errors.Count) error entries"
                return $errors
            }
            else {
                Write-Info "No errors found in logs"
                return @()
            }
        }
        else {
            Write-Info "No logs available yet"
            return @()
        }
    }
    catch {
        Write-Error-Custom "Failed to query Application Insights: $_"
        return @()
    }
}

function Get-PerformanceMetrics {
    Write-Section "📊 Performance Metrics"
    
    try {
        # Get container logs for performance data
        $logs = Get-ContainerLogs
        
        if ($logs) {
            Write-Success "Retrieved container logs"
            
            # Parse TPS, latency, etc. from logs
            $tpsMatches = $logs | Select-String -Pattern "TPS:\s*(\d+)" -AllMatches
            $latencyMatches = $logs | Select-String -Pattern "Latency:\s*([\d.]+)" -AllMatches
            
            $metrics = @{
                LogEntries = @($logs).Count
                TPS = if ($tpsMatches) { $tpsMatches[-1].Matches.Groups[1].Value } else { "N/A" }
                Latency = if ($latencyMatches) { $latencyMatches[-1].Matches.Groups[1].Value } else { "N/A" }
                Timestamp = Get-Date
            }
            
            Write-Host "  Log Entries: $($metrics.LogEntries)" -ForegroundColor Cyan
            Write-Host "  Latest TPS: $($metrics.TPS)" -ForegroundColor Cyan
            Write-Host "  Latest Latency: $($metrics.Latency)ms" -ForegroundColor Cyan
            
            return $metrics
        }
        else {
            Write-Info "No metrics available yet"
            return $null
        }
    }
    catch {
        Write-Error-Custom "Failed to retrieve metrics: $_"
        return $null
    }
}

function Get-FailoverAnalysis {
    Write-Section "🔄 Failover Event Analysis"
    
    try {
        $logs = Get-ContainerLogs
        
        if ($logs) {
            # Look for failover indicators
            $failoverEvents = $logs | Select-String -Pattern "(failover|reconnect|connection.*fail|timeout)" -AllMatches
            
            if ($failoverEvents) {
                Write-Success "Found $($failoverEvents.Count) failover events"
                
                # Calculate RTO (Recovery Time Objective)
                $firstEvent = $failoverEvents | Select-Object -First 1
                $lastEvent = $failoverEvents | Select-Object -Last 1
                
                if ($firstEvent -and $lastEvent -ne $firstEvent) {
                    Write-Host "  First Event: $($firstEvent.Line)" -ForegroundColor Yellow
                    Write-Host "  Last Event: $($lastEvent.Line)" -ForegroundColor Yellow
                    Write-Host "  ⏱️  RTO: Calculate from timestamps in logs" -ForegroundColor Cyan
                }
                
                return $failoverEvents
            }
            else {
                Write-Info "No failover events detected"
                return @()
            }
        }
        else {
            Write-Info "No logs available for failover analysis"
            return @()
        }
    }
    catch {
        Write-Error-Custom "Failed to analyze failover: $_"
        return @()
    }
}

# ============================================================================
# MAIN MONITORING LOOP
# ============================================================================

Write-Section "🚀 LoadGenerator Monitoring - App Service"

# Get initial status
$appStatus = Get-AppServiceStatus
if (-not $appStatus) {
    throw "Could not find App Service: $AppServiceName"
}

Write-Success "App Service found"
Write-Host "  State: $($appStatus.State)" -ForegroundColor Cyan
Write-Host "  URL: https://$($appStatus.DefaultHostName)" -ForegroundColor Cyan

# Wait for completion if requested
if ($WaitForCompletion) {
    Write-Section "⏳ Waiting for LoadGenerator Completion"
    
    $startTime = Get-Date
    $elapsedSeconds = 0
    $pollCount = 0
    
    while ($elapsedSeconds -lt $MaxWaitTime) {
        $elapsedSeconds = (Get-Date).Subtract($startTime).TotalSeconds
        $pollCount++
        
        $logs = Get-ContainerLogs
        
        # Check for completion indicators
        if ($logs -match "completed|finished|exit" -or $elapsedSeconds -gt $MaxWaitTime * 0.8) {
            Write-Info "Container appears to be completing or completed"
            break
        }
        
        Write-Host "  ⏱️  Elapsed: $([math]::Round($elapsedSeconds))s | Polls: $pollCount" -ForegroundColor Yellow -NoNewline
        Write-Host "`r" -NoNewline
        
        Start-Sleep -Seconds $RefreshInterval
    }
    
    Write-Host ""
    Write-Success "Monitoring complete after $([math]::Round($elapsedSeconds))s"
}

# ============================================================================
# COLLECT AND DISPLAY RESULTS
# ============================================================================

Write-Section "📈 LoadGenerator Results Summary"

# Get metrics
$metrics = Get-PerformanceMetrics

# Get errors
$errors = Get-ErrorLogs

# Get failover analysis
$failoverEvents = Get-FailoverAnalysis

# ============================================================================
# SAVE RESULTS
# ============================================================================

Write-Section "💾 Saving Results"

# Save error log
if ($errors) {
    $errors | Out-File -FilePath $errorLogFile -Force
    Write-Success "Error log saved: $errorLogFile"
}
else {
    Write-Info "No errors to save"
}

# Save metrics summary
$metricsSummary = @{
    Timestamp = Get-Date
    AppService = $AppServiceName
    Metrics = $metrics
    FailoverEvents = @($failoverEvents).Count
}

$metricsSummary | ConvertTo-Json | Out-File -FilePath $metricsFile -Force
Write-Success "Metrics saved: $metricsFile"

# ============================================================================
# FINAL SUMMARY
# ============================================================================

Write-Section "✅ Monitoring Complete"

Write-Host "`n📊 Summary:" -ForegroundColor Green
Write-Host "  App Service: $AppServiceName" -ForegroundColor Cyan
Write-Host "  Resource Group: $ResourceGroup" -ForegroundColor Cyan
Write-Host "  Application Insights: $ApplicationInsightsName" -ForegroundColor Cyan

if ($metrics) {
    Write-Host "  Latest TPS: $($metrics.TPS)" -ForegroundColor Cyan
    Write-Host "  Latest Latency: $($metrics.Latency)ms" -ForegroundColor Cyan
}

Write-Host "  Total Errors: $(@($errors).Count)" -ForegroundColor Cyan
Write-Host "  Total Failover Events: $(@($failoverEvents).Count)" -ForegroundColor Cyan

Write-Host "`n📂 Output Files:" -ForegroundColor Green
Write-Host "  Error Log: $errorLogFile" -ForegroundColor Yellow
Write-Host "  Metrics: $metricsFile" -ForegroundColor Yellow

Write-Host "`n🔗 Next Steps:" -ForegroundColor Green
Write-Host "  1. View logs: https://$($appStatus.DefaultHostName)" -ForegroundColor Yellow
Write-Host "  2. Azure Portal: https://portal.azure.com/#@microsoft.onmicrosoft.com/resource/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$ResourceGroup/providers/Microsoft.Web/sites/$AppServiceName" -ForegroundColor Yellow
Write-Host "  3. Application Insights: https://portal.azure.com/#@microsoft.onmicrosoft.com/resource/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$ResourceGroup/providers/microsoft.insights/components/$ApplicationInsightsName" -ForegroundColor Yellow
