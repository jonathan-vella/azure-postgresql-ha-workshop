<#
.SYNOPSIS
    Creates Azure Monitor dashboard for PostgreSQL Flexible Server performance monitoring

.DESCRIPTION
    Generates KQL queries and creates a comprehensive dashboard to monitor:
    - Transactions Per Second (TPS)
    - IOPS (Read/Write)
    - CPU and Memory utilization
    - WAL (Write-Ahead Log) metrics
    - Connection pool statistics
    - Disk throughput and latency

.PARAMETER ResourceGroup
    Azure resource group name

.PARAMETER PostgreSQLServer
    PostgreSQL Flexible Server name

.EXAMPLE
    .\Create-PostgreSQL-Dashboard.ps1 -ResourceGroup "rg-saif-pgsql-swc-01" -PostgreSQLServer "psql-saifpg-10081025"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroup,

    [Parameter(Mandatory=$true)]
    [string]$PostgreSQLServer
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "📊 POSTGRESQL PERFORMANCE DASHBOARD CREATOR" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Get resource details
Write-Host "▶ Getting resource details..." -ForegroundColor Yellow
$server = az postgres flexible-server show `
    --resource-group $ResourceGroup `
    --name $PostgreSQLServer `
    -o json | ConvertFrom-Json

$resourceId = $server.id
$subscriptionId = $resourceId -replace '^/subscriptions/([^/]+).*', '$1'
$location = $server.location

Write-Host "✅ Server found" -ForegroundColor Green
Write-Host "   Name: $PostgreSQLServer" -ForegroundColor Gray
Write-Host "   Location: $location" -ForegroundColor Gray
Write-Host "   SKU: $($server.sku.name) ($($server.sku.tier))" -ForegroundColor Gray
Write-Host "   Storage: $($server.storage.storageSizeGb) GB" -ForegroundColor Gray
Write-Host ""

# Create dashboard JSON
$dashboardName = "PostgreSQL-HA-Performance-$PostgreSQLServer"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

Write-Host "▶ Creating dashboard definition..." -ForegroundColor Yellow

$dashboard = @{
    location = $location
    properties = @{
        lenses = @{
            "0" = @{
                order = 0
                parts = @{
                    # TPS Metric
                    "0" = @{
                        position = @{ x = 0; y = 0; colSpan = 6; rowSpan = 4 }
                        metadata = @{
                            inputs = @(
                                @{
                                    name = "sharedTimeRange"
                                    isOptional = $true
                                }
                                @{
                                    name = "options"
                                    value = @{
                                        chart = @{
                                            metrics = @(
                                                @{
                                                    resourceMetadata = @{
                                                        id = $resourceId
                                                    }
                                                    name = "xact_commit"
                                                    aggregationType = 7
                                                    namespace = "microsoft.dbforpostgresql/flexibleservers"
                                                    metricVisualization = @{
                                                        displayName = "Transactions Committed"
                                                    }
                                                }
                                            )
                                            title = "🚀 Transactions Per Second (TPS)"
                                            titleKind = 2
                                            visualization = @{
                                                chartType = 2
                                            }
                                        }
                                    }
                                }
                            )
                            type = "Extension/HubsExtension/PartType/MonitorChartPart"
                        }
                    }
                    
                    # IOPS Metric
                    "1" = @{
                        position = @{ x = 6; y = 0; colSpan = 6; rowSpan = 4 }
                        metadata = @{
                            inputs = @(
                                @{
                                    name = "sharedTimeRange"
                                    isOptional = $true
                                }
                                @{
                                    name = "options"
                                    value = @{
                                        chart = @{
                                            metrics = @(
                                                @{
                                                    resourceMetadata = @{ id = $resourceId }
                                                    name = "disk_iops_consumed_percentage"
                                                    aggregationType = 4
                                                    namespace = "microsoft.dbforpostgresql/flexibleservers"
                                                    metricVisualization = @{
                                                        displayName = "Disk IOPS Consumed %"
                                                        color = "#47BDF5"
                                                    }
                                                }
                                                @{
                                                    resourceMetadata = @{ id = $resourceId }
                                                    name = "read_iops"
                                                    aggregationType = 4
                                                    namespace = "microsoft.dbforpostgresql/flexibleservers"
                                                    metricVisualization = @{
                                                        displayName = "Read IOPS"
                                                        color = "#7FBA00"
                                                    }
                                                }
                                                @{
                                                    resourceMetadata = @{ id = $resourceId }
                                                    name = "write_iops"
                                                    aggregationType = 4
                                                    namespace = "microsoft.dbforpostgresql/flexibleservers"
                                                    metricVisualization = @{
                                                        displayName = "Write IOPS"
                                                        color = "#F25022"
                                                    }
                                                }
                                            )
                                            title = "💾 Disk IOPS Utilization"
                                            titleKind = 2
                                            visualization = @{ chartType = 2 }
                                        }
                                    }
                                }
                            )
                            type = "Extension/HubsExtension/PartType/MonitorChartPart"
                        }
                    }
                    
                    # CPU and Memory
                    "2" = @{
                        position = @{ x = 0; y = 4; colSpan = 6; rowSpan = 4 }
                        metadata = @{
                            inputs = @(
                                @{
                                    name = "sharedTimeRange"
                                    isOptional = $true
                                }
                                @{
                                    name = "options"
                                    value = @{
                                        chart = @{
                                            metrics = @(
                                                @{
                                                    resourceMetadata = @{ id = $resourceId }
                                                    name = "cpu_percent"
                                                    aggregationType = 4
                                                    namespace = "microsoft.dbforpostgresql/flexibleservers"
                                                    metricVisualization = @{
                                                        displayName = "CPU %"
                                                        color = "#EC008C"
                                                    }
                                                }
                                                @{
                                                    resourceMetadata = @{ id = $resourceId }
                                                    name = "memory_percent"
                                                    aggregationType = 4
                                                    namespace = "microsoft.dbforpostgresql/flexibleservers"
                                                    metricVisualization = @{
                                                        displayName = "Memory %"
                                                        color = "#0078D4"
                                                    }
                                                }
                                            )
                                            title = "🖥️ CPU & Memory Utilization"
                                            titleKind = 2
                                            visualization = @{ chartType = 2 }
                                        }
                                    }
                                }
                            )
                            type = "Extension/HubsExtension/PartType/MonitorChartPart"
                        }
                    }
                    
                    # Disk Throughput
                    "3" = @{
                        position = @{ x = 6; y = 4; colSpan = 6; rowSpan = 4 }
                        metadata = @{
                            inputs = @(
                                @{
                                    name = "sharedTimeRange"
                                    isOptional = $true
                                }
                                @{
                                    name = "options"
                                    value = @{
                                        chart = @{
                                            metrics = @(
                                                @{
                                                    resourceMetadata = @{ id = $resourceId }
                                                    name = "disk_bandwidth_consumed_percentage"
                                                    aggregationType = 4
                                                    namespace = "microsoft.dbforpostgresql/flexibleservers"
                                                    metricVisualization = @{
                                                        displayName = "Disk Bandwidth %"
                                                        color = "#FF8C00"
                                                    }
                                                }
                                                @{
                                                    resourceMetadata = @{ id = $resourceId }
                                                    name = "read_throughput"
                                                    aggregationType = 4
                                                    namespace = "microsoft.dbforpostgresql/flexibleservers"
                                                    metricVisualization = @{
                                                        displayName = "Read Throughput (Bytes/s)"
                                                        color = "#00BCF2"
                                                    }
                                                }
                                                @{
                                                    resourceMetadata = @{ id = $resourceId }
                                                    name = "write_throughput"
                                                    aggregationType = 4
                                                    namespace = "microsoft.dbforpostgresql/flexibleservers"
                                                    metricVisualization = @{
                                                        displayName = "Write Throughput (Bytes/s)"
                                                        color = "#E81123"
                                                    }
                                                }
                                            )
                                            title = "📈 Disk Throughput"
                                            titleKind = 2
                                            visualization = @{ chartType = 2 }
                                        }
                                    }
                                }
                            )
                            type = "Extension/HubsExtension/PartType/MonitorChartPart"
                        }
                    }
                    
                    # Connections
                    "4" = @{
                        position = @{ x = 0; y = 8; colSpan = 6; rowSpan = 4 }
                        metadata = @{
                            inputs = @(
                                @{
                                    name = "sharedTimeRange"
                                    isOptional = $true
                                }
                                @{
                                    name = "options"
                                    value = @{
                                        chart = @{
                                            metrics = @(
                                                @{
                                                    resourceMetadata = @{ id = $resourceId }
                                                    name = "active_connections"
                                                    aggregationType = 4
                                                    namespace = "microsoft.dbforpostgresql/flexibleservers"
                                                    metricVisualization = @{
                                                        displayName = "Active Connections"
                                                        color = "#00188F"
                                                    }
                                                }
                                                @{
                                                    resourceMetadata = @{ id = $resourceId }
                                                    name = "connections_failed"
                                                    aggregationType = 1
                                                    namespace = "microsoft.dbforpostgresql/flexibleservers"
                                                    metricVisualization = @{
                                                        displayName = "Failed Connections"
                                                        color = "#E81123"
                                                    }
                                                }
                                            )
                                            title = "🔌 Database Connections"
                                            titleKind = 2
                                            visualization = @{ chartType = 2 }
                                        }
                                    }
                                }
                            )
                            type = "Extension/HubsExtension/PartType/MonitorChartPart"
                        }
                    }
                    
                    # Replication Lag
                    "5" = @{
                        position = @{ x = 6; y = 8; colSpan = 6; rowSpan = 4 }
                        metadata = @{
                            inputs = @(
                                @{
                                    name = "sharedTimeRange"
                                    isOptional = $true
                                }
                                @{
                                    name = "options"
                                    value = @{
                                        chart = @{
                                            metrics = @(
                                                @{
                                                    resourceMetadata = @{ id = $resourceId }
                                                    name = "physical_replication_delay_in_seconds"
                                                    aggregationType = 3
                                                    namespace = "microsoft.dbforpostgresql/flexibleservers"
                                                    metricVisualization = @{
                                                        displayName = "Replication Lag (seconds)"
                                                        color = "#FF8C00"
                                                    }
                                                }
                                            )
                                            title = "⚡ Replication Lag (HA Standby)"
                                            titleKind = 2
                                            visualization = @{ chartType = 2 }
                                        }
                                    }
                                }
                            )
                            type = "Extension/HubsExtension/PartType/MonitorChartPart"
                        }
                    }
                }
            }
        }
        metadata = @{
            model = @{
                timeRange = @{
                    value = @{
                        relative = @{
                            duration = 3600000  # 1 hour
                        }
                    }
                    type = "MsPortalFx.Composition.Configuration.ValueTypes.TimeRange"
                }
            }
        }
    }
    tags = @{
        "hidden-title" = $dashboardName
    }
}

$dashboardJson = $dashboard | ConvertTo-Json -Depth 100

# Save dashboard JSON
$outputFile = "postgresql-dashboard-$timestamp.json"
$dashboardJson | Out-File -FilePath $outputFile -Encoding UTF8

Write-Host "✅ Dashboard definition created" -ForegroundColor Green
Write-Host "   File: $outputFile" -ForegroundColor Gray
Write-Host ""

# Deploy dashboard
Write-Host "▶ Deploying dashboard to Azure..." -ForegroundColor Yellow

try {
    az portal dashboard create `
        --resource-group $ResourceGroup `
        --name $dashboardName `
        --input-path $outputFile `
        --location $location
    
    Write-Host "✅ Dashboard deployed successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "📊 Dashboard URL:" -ForegroundColor Cyan
    Write-Host "   https://portal.azure.com/#@/dashboard/arm$resourceId/dashboards/$dashboardName" -ForegroundColor White
}
catch {
    Write-Host "⚠️  Dashboard deployment failed: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "ℹ️  You can manually import the JSON file in Azure Portal" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Export KQL queries for Log Analytics
Write-Host "▶ Generating KQL queries for detailed analysis..." -ForegroundColor Yellow
Write-Host ""

$kqlQueries = @"
# ═══════════════════════════════════════════════════════════════
# POSTGRESQL PERFORMANCE MONITORING - KQL QUERIES
# ═══════════════════════════════════════════════════════════════
# Server: $PostgreSQLServer
# Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
#
# Use these queries in Azure Monitor Log Analytics workspace
# ═══════════════════════════════════════════════════════════════

# 1. TPS (Transactions Per Second) - Last Hour
# ────────────────────────────────────────────────────────────────
AzureMetrics
| where ResourceProvider == "MICROSOFT.DBFORPOSTGRESQL"
| where Resource == "$PostgreSQLServer"
| where MetricName == "xact_commit"
| where TimeGenerated > ago(1h)
| summarize TPS = avg(Average) by bin(TimeGenerated, 1m)
| render timechart 
    with (title="Transactions Per Second (TPS)")

# 2. IOPS Utilization - Current Status
# ────────────────────────────────────────────────────────────────
AzureMetrics
| where ResourceProvider == "MICROSOFT.DBFORPOSTGRESQL"
| where Resource == "$PostgreSQLServer"
| where MetricName in ("disk_iops_consumed_percentage", "read_iops", "write_iops")
| where TimeGenerated > ago(1h)
| summarize 
    IOPS_Consumed_Pct = avg(iif(MetricName == "disk_iops_consumed_percentage", Average, 0.0)),
    Read_IOPS = avg(iif(MetricName == "read_iops", Average, 0.0)),
    Write_IOPS = avg(iif(MetricName == "write_iops", Average, 0.0))
    by bin(TimeGenerated, 1m)
| render timechart 
    with (title="IOPS Utilization (P70: 15K IOPS max)")

# 3. CPU and Memory Usage
# ────────────────────────────────────────────────────────────────
AzureMetrics
| where ResourceProvider == "MICROSOFT.DBFORPOSTGRESQL"
| where Resource == "$PostgreSQLServer"
| where MetricName in ("cpu_percent", "memory_percent")
| where TimeGenerated > ago(1h)
| summarize 
    CPU = avg(iif(MetricName == "cpu_percent", Average, 0.0)),
    Memory = avg(iif(MetricName == "memory_percent", Average, 0.0))
    by bin(TimeGenerated, 1m)
| render timechart 
    with (title="CPU & Memory Utilization")

# 4. Disk Throughput (MB/s)
# ────────────────────────────────────────────────────────────────
AzureMetrics
| where ResourceProvider == "MICROSOFT.DBFORPOSTGRESQL"
| where Resource == "$PostgreSQLServer"
| where MetricName in ("read_throughput", "write_throughput", "disk_bandwidth_consumed_percentage")
| where TimeGenerated > ago(1h)
| extend ThroughputMB = Average / 1024.0 / 1024.0  // Convert bytes to MB
| summarize 
    Read_MB_s = avg(iif(MetricName == "read_throughput", ThroughputMB, 0.0)),
    Write_MB_s = avg(iif(MetricName == "write_throughput", ThroughputMB, 0.0)),
    Bandwidth_Pct = avg(iif(MetricName == "disk_bandwidth_consumed_percentage", Average, 0.0))
    by bin(TimeGenerated, 1m)
| render timechart 
    with (title="Disk Throughput (MB/s) - P70: 500 MB/s max")

# 5. Connection Statistics
# ────────────────────────────────────────────────────────────────
AzureMetrics
| where ResourceProvider == "MICROSOFT.DBFORPOSTGRESQL"
| where Resource == "$PostgreSQLServer"
| where MetricName in ("active_connections", "connections_failed")
| where TimeGenerated > ago(1h)
| summarize 
    Active = avg(iif(MetricName == "active_connections", Average, 0.0)),
    Failed = sum(iif(MetricName == "connections_failed", Total, 0.0))
    by bin(TimeGenerated, 1m)
| render timechart 
    with (title="Database Connections")

# 6. Replication Lag (HA Standby)
# ────────────────────────────────────────────────────────────────
AzureMetrics
| where ResourceProvider == "MICROSOFT.DBFORPOSTGRESQL"
| where Resource == "$PostgreSQLServer"
| where MetricName == "physical_replication_delay_in_seconds"
| where TimeGenerated > ago(1h)
| summarize ReplicationLag_Seconds = max(Maximum) by bin(TimeGenerated, 1m)
| render timechart 
    with (title="Replication Lag (Seconds)")

# 7. Performance Summary - Last 5 Minutes
# ────────────────────────────────────────────────────────────────
AzureMetrics
| where ResourceProvider == "MICROSOFT.DBFORPOSTGRESQL"
| where Resource == "$PostgreSQLServer"
| where TimeGenerated > ago(5m)
| summarize 
    Avg_TPS = round(avgif(Average, MetricName == "xact_commit"), 2),
    Avg_CPU_Pct = round(avgif(Average, MetricName == "cpu_percent"), 2),
    Avg_Memory_Pct = round(avgif(Average, MetricName == "memory_percent"), 2),
    Avg_IOPS_Pct = round(avgif(Average, MetricName == "disk_iops_consumed_percentage"), 2),
    Avg_Active_Connections = round(avgif(Average, MetricName == "active_connections"), 0),
    Max_Replication_Lag = round(maxif(Maximum, MetricName == "physical_replication_delay_in_seconds"), 2)
| project 
    TPS = Avg_TPS,
    CPU_Percent = Avg_CPU_Pct,
    Memory_Percent = Avg_Memory_Pct,
    IOPS_Consumed_Percent = Avg_IOPS_Pct,
    Active_Connections = Avg_Active_Connections,
    Max_Replication_Lag_Seconds = Max_Replication_Lag

# 8. WAL (Write-Ahead Log) Generation Rate
# ────────────────────────────────────────────────────────────────
# Note: WAL metrics require pg_stat_wal extension and query to pg_stat_wal view
# This query shows write throughput as a proxy for WAL activity
AzureMetrics
| where ResourceProvider == "MICROSOFT.DBFORPOSTGRESQL"
| where Resource == "$PostgreSQLServer"
| where MetricName == "write_throughput"
| where TimeGenerated > ago(1h)
| extend WAL_MB_s = Average / 1024.0 / 1024.0
| summarize Avg_WAL_Write_MB_s = avg(WAL_MB_s) by bin(TimeGenerated, 1m)
| render timechart 
    with (title="WAL Write Rate (MB/s estimate)")

# 9. Peak Performance Detection (Alert Candidates)
# ────────────────────────────────────────────────────────────────
AzureMetrics
| where ResourceProvider == "MICROSOFT.DBFORPOSTGRESQL"
| where Resource == "$PostgreSQLServer"
| where TimeGenerated > ago(1h)
| where MetricName in ("cpu_percent", "memory_percent", "disk_iops_consumed_percentage")
| where Average > 80  // Alert threshold
| summarize 
    MaxValue = max(Average),
    AvgValue = avg(Average),
    Count = count()
    by MetricName, bin(TimeGenerated, 5m)
| where Count > 2  // Multiple occurrences in 5-minute window
| order by TimeGenerated desc

# 10. Failover Detection (Replication Lag Spike)
# ────────────────────────────────────────────────────────────────
AzureMetrics
| where ResourceProvider == "MICROSOFT.DBFORPOSTGRESQL"
| where Resource == "$PostgreSQLServer"
| where MetricName == "physical_replication_delay_in_seconds"
| where TimeGenerated > ago(24h)
| where Maximum > 5  // Lag > 5 seconds indicates potential issues
| summarize 
    MaxLag = max(Maximum),
    AvgLag = avg(Average),
    TimeAboveThreshold = count()
    by bin(TimeGenerated, 1m)
| order by TimeGenerated desc

"@

$kqlFile = "postgresql-monitoring-queries-$timestamp.kql"
$kqlQueries | Out-File -FilePath $kqlFile -Encoding UTF8

Write-Host "✅ KQL queries exported" -ForegroundColor Green
Write-Host "   File: $kqlFile" -ForegroundColor Gray
Write-Host ""

Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "✅ SETUP COMPLETE" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "📊 Next Steps:" -ForegroundColor Yellow
Write-Host "   1. Open dashboard in Azure Portal" -ForegroundColor White
Write-Host "   2. Run load test: 8000 TPS for 5 minutes" -ForegroundColor White
Write-Host "   3. Monitor IOPS % (should stay below 50% with P70)" -ForegroundColor White
Write-Host "   4. Check TPS (expect 8K-10K sustained)" -ForegroundColor White
Write-Host ""
Write-Host "📈 Expected P70 Performance:" -ForegroundColor Yellow
Write-Host "   IOPS: 15,000 max (target: <50% = <7,500 IOPS used)" -ForegroundColor White
Write-Host "   Throughput: 500 MB/s max" -ForegroundColor White
Write-Host "   At 8K TPS: ~40-50% IOPS utilization" -ForegroundColor White
Write-Host ""
