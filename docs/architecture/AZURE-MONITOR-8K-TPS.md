# Azure Monitor Dashboards & Queries for 8000 TPS Load Testing

**Purpose**: Monitor PostgreSQL performance, connection pooling, and failover metrics during high-TPS testing

---

## 📊 Quick Metrics Dashboard

### Key Performance Indicators (KPIs)

| Metric | Target | Warning | Critical |
|--------|--------|---------|----------|
| **TPS** | 8,000+ | < 6,000 | < 4,000 |
| **P95 Latency** | < 30ms | > 50ms | > 100ms |
| **Connection Pool Usage** | 60-80% | > 90% | > 95% |
| **CPU Usage** | < 70% | > 80% | > 90% |
| **Memory Usage** | < 80% | > 90% | > 95% |
| **Active Connections** | < 1500 | > 1800 | > 1900 |

---

## 🔍 Azure Monitor KQL Queries

### 1. Real-Time TPS Monitoring

```kql
// Real-time transactions per second over last 15 minutes
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.DBFORPOSTGRESQL"
| where ResourceType == "FLEXIBLESERVERS"
| where TimeGenerated > ago(15m)
| where Category == "PostgreSQLLogs"
| where Message contains "INSERT INTO transactions"
| summarize TPS = count() by bin(TimeGenerated, 1s)
| render timechart
```

### 2. Connection Pool Health

```kql
// Monitor active connections and pool usage
AzureMetrics
| where ResourceProvider == "MICROSOFT.DBFORPOSTGRESQL"
| where MetricName in ("active_connections", "connections_succeeded", "connections_failed")
| where TimeGenerated > ago(1h)
| summarize 
    ActiveConnections = avg(Maximum),
    SuccessfulConnections = sum(Total),
    FailedConnections = sum(Total)
    by bin(TimeGenerated, 1m), MetricName
| render timechart
```

### 3. PgBouncer Performance

```kql
// PgBouncer connection pooling metrics
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.DBFORPOSTGRESQL"
| where TimeGenerated > ago(1h)
| where Category == "PostgreSQLLogs"
| where Message contains "pgbouncer"
| project TimeGenerated, Message
| order by TimeGenerated desc
```

### 4. Query Performance (P50, P95, P99 Latency)

```kql
// Query latency percentiles
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.DBFORPOSTGRESQL"
| where TimeGenerated > ago(1h)
| where Category == "PostgreSQLLogs"
| where Message contains "duration:"
| extend Duration = extract(@"duration: ([\d.]+) ms", 1, Message, typeof(double))
| where isnotnull(Duration)
| summarize 
    P50 = percentile(Duration, 50),
    P95 = percentile(Duration, 95),
    P99 = percentile(Duration, 99),
    Max = max(Duration),
    Count = count()
    by bin(TimeGenerated, 1m)
| render timechart
```

### 5. CPU and Memory Usage

```kql
// PostgreSQL server resource utilization
AzureMetrics
| where ResourceProvider == "MICROSOFT.DBFORPOSTGRESQL"
| where MetricName in ("cpu_percent", "memory_percent", "io_consumption_percent")
| where TimeGenerated > ago(1h)
| summarize 
    AvgCPU = avg(Average),
    MaxCPU = max(Maximum),
    AvgMemory = avg(Average)
    by bin(TimeGenerated, 1m), MetricName
| render timechart
```

### 6. Failover Detection

```kql
// Detect failover events
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.DBFORPOSTGRESQL"
| where TimeGenerated > ago(24h)
| where Message contains "failover" or Message contains "replica" or Message contains "promoted"
| project TimeGenerated, Category, Message, Resource
| order by TimeGenerated desc
```

### 7. Error Rate Analysis

```kql
// Connection errors and timeouts
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.DBFORPOSTGRESQL"
| where TimeGenerated > ago(1h)
| where Message contains "ERROR" or Message contains "FATAL" or Message contains "timeout"
| summarize ErrorCount = count() by bin(TimeGenerated, 1m), ErrorType = extract(@"(ERROR|FATAL|timeout)", 1, Message)
| render timechart
```

### 8. Top Slow Queries

```kql
// Identify slow queries during load test
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.DBFORPOSTGRESQL"
| where TimeGenerated > ago(1h)
| where Category == "PostgreSQLLogs"
| where Message contains "duration:"
| extend Duration = extract(@"duration: ([\d.]+) ms", 1, Message, typeof(double))
| extend Query = extract(@"statement: (.+)", 1, Message)
| where Duration > 100  // Queries slower than 100ms
| top 20 by Duration desc
| project TimeGenerated, Duration, Query
```

### 9. Write Throughput (Transactions/sec)

```kql
// Calculate write throughput from transaction table
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.DBFORPOSTGRESQL"
| where TimeGenerated > ago(15m)
| where Message contains "INSERT" and Message contains "transactions"
| summarize InsertCount = count() by bin(TimeGenerated, 1s)
| extend TPS = InsertCount
| render timechart
```

### 10. Replication Lag (Zone-Redundant HA)

```kql
// Monitor replication lag between primary and standby
AzureMetrics
| where ResourceProvider == "MICROSOFT.DBFORPOSTGRESQL"
| where MetricName == "physical_replication_delay_in_seconds"
| where TimeGenerated > ago(1h)
| summarize 
    AvgLag = avg(Average),
    MaxLag = max(Maximum),
    P95Lag = percentile(Average, 95)
    by bin(TimeGenerated, 1m)
| render timechart
```

---

## 📈 Pre-Built Dashboard JSON

### Azure Portal Dashboard Configuration

Save this JSON and import it into Azure Portal:

```json
{
  "properties": {
    "lenses": {
      "0": {
        "order": 0,
        "parts": {
          "0": {
            "position": {
              "x": 0,
              "y": 0,
              "colSpan": 6,
              "rowSpan": 4
            },
            "metadata": {
              "type": "Extension/Microsoft_Azure_Monitoring/PartType/MetricsChartPart",
              "settings": {
                "content": {
                  "options": {
                    "chart": {
                      "metrics": [
                        {
                          "resourceMetadata": {
                            "id": "/subscriptions/{subscription-id}/resourceGroups/{resource-group}/providers/Microsoft.DBforPostgreSQL/flexibleServers/{server-name}"
                          },
                          "name": "active_connections",
                          "aggregationType": 4
                        }
                      ],
                      "title": "Active Connections",
                      "titleKind": 1,
                      "visualization": {
                        "chartType": 2
                      }
                    }
                  }
                }
              }
            }
          },
          "1": {
            "position": {
              "x": 6,
              "y": 0,
              "colSpan": 6,
              "rowSpan": 4
            },
            "metadata": {
              "type": "Extension/Microsoft_Azure_Monitoring/PartType/MetricsChartPart",
              "settings": {
                "content": {
                  "options": {
                    "chart": {
                      "metrics": [
                        {
                          "resourceMetadata": {
                            "id": "/subscriptions/{subscription-id}/resourceGroups/{resource-group}/providers/Microsoft.DBforPostgreSQL/flexibleServers/{server-name}"
                          },
                          "name": "cpu_percent",
                          "aggregationType": 4
                        }
                      ],
                      "title": "CPU Percentage",
                      "titleKind": 1,
                      "visualization": {
                        "chartType": 2
                      }
                    }
                  }
                }
              }
            }
          },
          "2": {
            "position": {
              "x": 0,
              "y": 4,
              "colSpan": 6,
              "rowSpan": 4
            },
            "metadata": {
              "type": "Extension/Microsoft_Azure_Monitoring/PartType/MetricsChartPart",
              "settings": {
                "content": {
                  "options": {
                    "chart": {
                      "metrics": [
                        {
                          "resourceMetadata": {
                            "id": "/subscriptions/{subscription-id}/resourceGroups/{resource-group}/providers/Microsoft.DBforPostgreSQL/flexibleServers/{server-name}"
                          },
                          "name": "memory_percent",
                          "aggregationType": 4
                        }
                      ],
                      "title": "Memory Percentage",
                      "titleKind": 1,
                      "visualization": {
                        "chartType": 2
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
```

---

## 🔔 Alert Rules

### 1. High TPS Drop Alert (Failover Detection)

```powershell
# Create alert rule for sudden TPS drop
az monitor metrics alert create \
  --name "PostgreSQL-TPS-Drop-Alert" \
  --resource-group "rg-saif-pgsql-swc-01" \
  --scopes "/subscriptions/{sub-id}/resourceGroups/rg-saif-pgsql-swc-01/providers/Microsoft.DBforPostgreSQL/flexibleServers/{server-name}" \
  --condition "avg connections_succeeded < 100" \
  --window-size 5m \
  --evaluation-frequency 1m \
  --description "Alert when TPS drops below 100 (possible failover)"
```

### 2. High CPU Usage Alert

```powershell
az monitor metrics alert create \
  --name "PostgreSQL-High-CPU-Alert" \
  --resource-group "rg-saif-pgsql-swc-01" \
  --scopes "/subscriptions/{sub-id}/resourceGroups/rg-saif-pgsql-swc-01/providers/Microsoft.DBforPostgreSQL/flexibleServers/{server-name}" \
  --condition "avg cpu_percent > 90" \
  --window-size 5m \
  --evaluation-frequency 1m \
  --description "Alert when CPU exceeds 90%"
```

### 3. Connection Pool Exhaustion Alert

```powershell
az monitor metrics alert create \
  --name "PostgreSQL-Connection-Pool-Exhaustion" \
  --resource-group "rg-saif-pgsql-swc-01" \
  --scopes "/subscriptions/{sub-id}/resourceGroups/rg-saif-pgsql-swc-01/providers/Microsoft.DBforPostgreSQL/flexibleServers/{server-name}" \
  --condition "avg active_connections > 1900" \
  --window-size 5m \
  --evaluation-frequency 1m \
  --description "Alert when connection pool is nearly exhausted"
```

### 4. High Replication Lag Alert

```powershell
az monitor metrics alert create \
  --name "PostgreSQL-High-Replication-Lag" \
  --resource-group "rg-saif-pgsql-swc-01" \
  --scopes "/subscriptions/{sub-id}/resourceGroups/rg-saif-pgsql-swc-01/providers/Microsoft.DBforPostgreSQL/flexibleServers/{server-name}" \
  --condition "avg physical_replication_delay_in_seconds > 10" \
  --window-size 5m \
  --evaluation-frequency 1m \
  --description "Alert when replication lag exceeds 10 seconds"
```

---

## 📱 PowerShell Monitoring Script

Create `scripts/Monitor-LoadTest.ps1`:

```powershell
<#
.SYNOPSIS
    Real-time monitoring dashboard for PostgreSQL load testing

.DESCRIPTION
    Displays real-time metrics from Azure Monitor during load tests

.PARAMETER ResourceGroup
    Resource group name

.PARAMETER ServerName
    PostgreSQL server name

.PARAMETER RefreshInterval
    Refresh interval in seconds (default: 5)

.EXAMPLE
    .\Monitor-LoadTest.ps1 -ResourceGroup "rg-saif-pgsql-swc-01" -ServerName "psql-saifpg-abc123"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroup,
    
    [Parameter(Mandatory=$true)]
    [string]$ServerName,
    
    [Parameter(Mandatory=$false)]
    [int]$RefreshInterval = 5
)

$resourceId = "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$ResourceGroup/providers/Microsoft.DBforPostgreSQL/flexibleServers/$ServerName"

Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "📊 REAL-TIME POSTGRESQL MONITORING DASHBOARD" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Resource: $ServerName" -ForegroundColor White
Write-Host "Refresh: Every $RefreshInterval seconds (Ctrl+C to exit)" -ForegroundColor Gray
Write-Host ""

while ($true) {
    $startTime = (Get-Date).AddMinutes(-5).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $endTime = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    
    # Fetch metrics
    $cpuMetric = az monitor metrics list \
        --resource $resourceId \
        --metric "cpu_percent" \
        --start-time $startTime \
        --end-time $endTime \
        --aggregation Average \
        --interval PT1M \
        --query "value[0].timeseries[0].data[-1].average" \
        --output tsv
    
    $memoryMetric = az monitor metrics list \
        --resource $resourceId \
        --metric "memory_percent" \
        --start-time $startTime \
        --end-time $endTime \
        --aggregation Average \
        --interval PT1M \
        --query "value[0].timeseries[0].data[-1].average" \
        --output tsv
    
    $connectionsMetric = az monitor metrics list \
        --resource $resourceId \
        --metric "active_connections" \
        --start-time $startTime \
        --end-time $endTime \
        --aggregation Average \
        --interval PT1M \
        --query "value[0].timeseries[0].data[-1].average" \
        --output tsv
    
    $timestamp = Get-Date -Format "HH:mm:ss"
    
    Clear-Host
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "📊 REAL-TIME POSTGRESQL MONITORING DASHBOARD" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "Resource: $ServerName" -ForegroundColor White
    Write-Host "Last Update: $timestamp" -ForegroundColor Gray
    Write-Host ""
    
    # Display metrics with color coding
    Write-Host "CPU Usage: " -NoNewline
    if ($cpuMetric -lt 70) {
        Write-Host "$([Math]::Round($cpuMetric, 1))%" -ForegroundColor Green
    } elseif ($cpuMetric -lt 90) {
        Write-Host "$([Math]::Round($cpuMetric, 1))%" -ForegroundColor Yellow
    } else {
        Write-Host "$([Math]::Round($cpuMetric, 1))%" -ForegroundColor Red
    }
    
    Write-Host "Memory Usage: " -NoNewline
    if ($memoryMetric -lt 80) {
        Write-Host "$([Math]::Round($memoryMetric, 1))%" -ForegroundColor Green
    } elseif ($memoryMetric -lt 90) {
        Write-Host "$([Math]::Round($memoryMetric, 1))%" -ForegroundColor Yellow
    } else {
        Write-Host "$([Math]::Round($memoryMetric, 1))%" -ForegroundColor Red
    }
    
    Write-Host "Active Connections: " -NoNewline
    if ($connectionsMetric -lt 1500) {
        Write-Host "$([Math]::Round($connectionsMetric, 0))" -ForegroundColor Green
    } elseif ($connectionsMetric -lt 1800) {
        Write-Host "$([Math]::Round($connectionsMetric, 0))" -ForegroundColor Yellow
    } else {
        Write-Host "$([Math]::Round($connectionsMetric, 0))" -ForegroundColor Red
    }
    
    Write-Host ""
    Write-Host "Press Ctrl+C to exit..." -ForegroundColor Gray
    
    Start-Sleep -Seconds $RefreshInterval
}
```

---

## 🎯 Monitoring Workflow

### Before Load Test
1. ✅ Enable diagnostic settings on PostgreSQL server
2. ✅ Create alert rules for critical metrics
3. ✅ Open Azure Portal monitoring dashboard
4. ✅ Start PowerShell monitoring script

### During Load Test
1. 📊 Monitor real-time TPS via KQL queries
2. 🔍 Watch for connection pool exhaustion
3. ⚠️ Track CPU/Memory usage
4. 📈 Observe latency percentiles (P95, P99)

### After Failover
1. ⏱️ Calculate RTO from metrics
2. 📉 Analyze connection drop/recovery
3. 📊 Export metrics to CSV
4. 📝 Document results

---

## 🔗 Quick Links

| Resource | URL |
|----------|-----|
| **Azure Portal Metrics** | https://portal.azure.com/#blade/Microsoft_Azure_Monitoring/AzureMonitoringBrowseBlade/metrics |
| **Log Analytics** | https://portal.azure.com/#blade/Microsoft_Azure_Monitoring/AzureMonitoringBrowseBlade/logs |
| **Azure Monitor Docs** | https://learn.microsoft.com/azure/postgresql/flexible-server/concepts-monitoring |

---

## 📚 Related Documentation

- [HIGH-PERFORMANCE-8000TPS-ARCHITECTURE.md](./HIGH-PERFORMANCE-8000TPS-ARCHITECTURE.md) - Architecture guide
- [QUICK-REFERENCE-8K-TPS.md](./QUICK-REFERENCE-8K-TPS.md) - Quick commands
- [Azure PostgreSQL Monitoring](https://learn.microsoft.com/azure/postgresql/flexible-server/concepts-monitoring)
