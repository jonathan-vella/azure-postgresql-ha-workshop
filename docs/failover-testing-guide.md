# Failover Testing Quick Reference

## Measure RTO and RPO During Manual Failover

### Quick Start

```powershell
# Start the measurement script
.\scripts\loadtesting\Measure-Failover-RTO-RPO.ps1 `
    -AppServiceUrl "https://app-loadgen-6wuso.azurewebsites.net" `
    -ResourceGroup "rg-pgv2-usc01" `
    -ServerName "pg-cus" `
    -DatabaseName "saifdb" `
    -AdminUsername "jonathan"

# The script will:
# 1. Start load test (if not running)
# 2. Establish baseline
# 3. Prompt you to trigger manual failover
# 4. Measure RTO and RPO
# 5. Generate detailed report
```

### Manual Failover Methods

**Option 1: Azure Portal**
1. Navigate to PostgreSQL Flexible Server: `pg-cus`
2. Go to "High availability" blade
3. Click "Forced failover"
4. Confirm the failover

**Option 2: Azure CLI**
```powershell
az postgres flexible-server restart `
    --name pg-cus `
    --resource-group rg-pgv2-usc01 `
    --failover Forced
```

### Script Output

The script provides real-time monitoring:

```
Time        Elapsed   DB Conn   App Conn   App Trans     DB Trans      TPS     Status
────────────────────────────────────────────────────────────────────────────────────────
11:30:00    0.0s      OK        OK          150000       150000      5000    BASELINE
11:30:01    1.0s      OK        OK          155000       155000      5000    BASELINE
11:30:05    5.0s      LOST      LOST        ─────────   ─────────   ─────   CONNECTION LOST
11:30:06    6.0s      DOWN      DOWN        ─────────   ─────────   ─────   OUTAGE
11:30:25    25.0s     OK        OK          170000       170000      4850    RECOVERED
11:30:30    30.0s     OK        OK          175000       175000      5000    RECOVERING
```

### Final Report

```
═══════════════════════════════════════════════════════════════
  FAILOVER TEST RESULTS
═══════════════════════════════════════════════════════════════

⏱️  TIMING METRICS
─────────────────────────────────────────────────────────────────
  RTO (Recovery Time):        25.45 seconds    ✅
  Total Test Duration:        120.00 seconds
  Connection Lost At:         11:30:05.123
  Connection Restored At:     11:30:30.567
  Max Consecutive Failures:   20 probes (20 seconds)
  Total Failed Probes:        20 / 120 (16.67%)

📊 DATA CONSISTENCY METRICS
─────────────────────────────────────────────────────────────────
  RPO (Transactions Lost):    0 transactions   ✅
  Data Loss Percentage:       0.00%
  
  Pre-Failover App Count:     150000
  Pre-Failover DB Count:      150000
  Post-Failover App Count:    170000
  Post-Failover DB Count:     170000
  Final App Count:            200000
  Final DB Count:             200000
  Transactions During Failover: 50000

📈 PERFORMANCE METRICS
─────────────────────────────────────────────────────────────────
  Baseline TPS:               5000.00
  Final TPS:                  5000.00
  TPS Recovery:               100.00%
  Total Errors:               0

✅ PASS/FAIL CRITERIA
─────────────────────────────────────────────────────────────────
  RTO < 30 seconds:           ✅ PASS
  RPO = 0 (Zero Data Loss):  ✅ PASS

  🎉 OVERALL RESULT:          ✅ PASSED
```

### Targets

- **RTO Target**: < 30 seconds ⏱️
- **RPO Target**: 0 transactions (zero data loss) 📊

### Parameters

| Parameter | Description | Default | Example |
|-----------|-------------|---------|---------|
| `AppServiceUrl` | Load generator URL | Required | `https://app-loadgen-6wuso.azurewebsites.net` |
| `ResourceGroup` | Azure resource group | Required | `rg-pgv2-usc01` |
| `ServerName` | PostgreSQL server name | Required | `pg-cus` |
| `DatabaseName` | Database name | Required | `saifdb` |
| `AdminUsername` | Admin username | Required | `jonathan` |
| `AdminPassword` | Admin password | Prompted | (secure) |
| `ProbeInterval` | Seconds between checks | 1 | 1 |
| `RecoveryThreshold` | TPS recovery % | 0.8 | 0.8 |
| `BaselineSeconds` | Baseline duration | 30 | 30 |
| `OutputCsv` | Output file path | Auto-generated | `./failover_metrics.csv` |

### Output Files

1. **CSV Metrics** - Detailed time-series data
   ```
   failover_metrics_20251016_113000.csv
   ```

2. **JSON Summary** - Test results summary
   ```
   failover_metrics_20251016_113000_summary.json
   ```

### How It Works

#### 1. Baseline Phase (30 seconds)
- Starts load test if not running
- Establishes baseline TPS
- Records pre-failover transaction counts

#### 2. Failover Detection
- Waits for your manual failover trigger
- Detects connection loss via polling (every 1 second)
- Records exact time of connection loss

#### 3. Recovery Monitoring
- Continuously probes database and app service
- Records when connections are restored
- Monitors TPS recovery to baseline

#### 4. Metrics Calculation
- **RTO**: Time from connection loss to restoration
- **RPO**: Difference between app-counted and DB-persisted transactions
- **Data Loss %**: Percentage of transactions lost during failover

### Understanding RPO Measurement

```
App Service Transaction Counter:  2,105,328 ← What app thinks it wrote
Database Transaction Count:       2,105,328 ← What DB actually stored
                                  ─────────
RPO (Transactions Lost):                  0 ✅ Zero data loss
```

If there's data loss:
```
App Service Transaction Counter:  2,105,328 ← What app tried to write
Database Transaction Count:       2,105,200 ← What DB actually stored
                                  ─────────
RPO (Transactions Lost):                128 ❌ Data loss detected
```

### Complete Workflow Example

```powershell
# 1. Deploy load generator (if not already done)
.\scripts\loadtesting\Build-LoadGenerator-Docker.ps1
.\scripts\loadtesting\Deploy-LoadGenerator-AppService.ps1 -Action Deploy

# 2. Start failover measurement
.\scripts\loadtesting\Measure-Failover-RTO-RPO.ps1 `
    -AppServiceUrl "https://app-loadgen-6wuso.azurewebsites.net" `
    -ResourceGroup "rg-pgv2-usc01" `
    -ServerName "pg-cus" `
    -DatabaseName "saifdb" `
    -AdminUsername "jonathan"

# 3. Wait for prompt to trigger failover

# 4. Trigger manual failover:
#    Option A: Azure Portal (High availability → Forced failover)
#    Option B: Azure CLI
az postgres flexible-server restart `
    --name pg-cus `
    --resource-group rg-pgv2-usc01 `
    --failover Forced

# 5. Script automatically measures and reports results

# 6. Review generated files:
#    - CSV: Detailed metrics
#    - JSON: Summary report
```

### Troubleshooting

**Issue: "Cannot connect to PostgreSQL"**
```powershell
# Verify connection manually
$env:PGPASSWORD = "your-password"
psql -h pg-cus.postgres.database.azure.com -U jonathan -d saifdb -c "SELECT 1"

# Check firewall rules
az postgres flexible-server firewall-rule list --name pg-cus --resource-group rg-pgv2-usc01
```

**Issue: "App Service not healthy"**
```powershell
# Check health endpoint
curl https://app-loadgen-6wuso.azurewebsites.net/health

# Check logs
.\scripts\loadtesting\Monitor-AppService-Logs.ps1
```

**Issue: "Load test won't start"**
```powershell
# Check current status
curl https://app-loadgen-6wuso.azurewebsites.net/status

# Restart App Service if needed
az webapp restart --name app-loadgen-6wuso --resource-group rg-pgv2-usc01
```

**Issue: "Npgsql.dll not found"**
```powershell
# Script will auto-install from NuGet
# Or manually install:
Install-Package Npgsql -ProviderName NuGet -Force -Scope CurrentUser -MinimumVersion 8.0.0
```

### Advanced Usage

**Custom probe interval (faster detection):**
```powershell
.\scripts\loadtesting\Measure-Failover-RTO-RPO.ps1 `
    -AppServiceUrl "https://app-loadgen-6wuso.azurewebsites.net" `
    -ResourceGroup "rg-pgv2-usc01" `
    -ServerName "pg-cus" `
    -DatabaseName "saifdb" `
    -AdminUsername "jonathan" `
    -ProbeInterval 0.5  # Check every 500ms
```

**Custom recovery threshold:**
```powershell
.\scripts\loadtesting\Measure-Failover-RTO-RPO.ps1 `
    -AppServiceUrl "https://app-loadgen-6wuso.azurewebsites.net" `
    -ResourceGroup "rg-pgv2-usc01" `
    -ServerName "pg-cus" `
    -DatabaseName "saifdb" `
    -AdminUsername "jonathan" `
    -RecoveryThreshold 0.95  # Require 95% TPS recovery
```

**Longer baseline:**
```powershell
.\scripts\loadtesting\Measure-Failover-RTO-RPO.ps1 `
    -AppServiceUrl "https://app-loadgen-6wuso.azurewebsites.net" `
    -ResourceGroup "rg-pgv2-usc01" `
    -ServerName "pg-cus" `
    -DatabaseName "saifdb" `
    -AdminUsername "jonathan" `
    -BaselineSeconds 60  # 1 minute baseline
```

### Integration with CI/CD

```powershell
# Run as automated test (exits with code 0 if pass, 1 if fail)
$result = .\scripts\loadtesting\Measure-Failover-RTO-RPO.ps1 `
    -AppServiceUrl "https://app-loadgen-6wuso.azurewebsites.net" `
    -ResourceGroup "rg-pgv2-usc01" `
    -ServerName "pg-cus" `
    -DatabaseName "saifdb" `
    -AdminUsername "jonathan" `
    -AdminPassword (ConvertTo-SecureString "password" -AsPlainText -Force)

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Failover test passed"
} else {
    Write-Host "❌ Failover test failed"
    exit 1
}
```

### Best Practices

1. ✅ **Run baseline for 30+ seconds** - Ensures stable TPS measurement
2. ✅ **Trigger failover promptly** - Press key as soon as failover is initiated
3. ✅ **Monitor portal during test** - Watch High Availability blade for failover status
4. ✅ **Save CSV files** - Keep historical data for trend analysis
5. ✅ **Verify database count** - Cross-check with manual query after test
6. ✅ **Clean up test data** - Truncate transactions table between tests if needed

### Related Documentation

- Main Load Testing Guide: `docs/v1.0.0/load-testing-guide.md`
- App Service Deployment: `scripts/loadtesting/Deploy-LoadGenerator-AppService.ps1`
- Container Build: `scripts/loadtesting/Build-LoadGenerator-Docker.ps1`
- Configuration: `scripts/loadtesting/LoadGenerator-Config.ps1`
