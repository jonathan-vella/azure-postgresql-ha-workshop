# PostgreSQL HA Workshop - Quick Reference Cheat Sheet

**Version**: 1.0.0  
**Last Updated**: October 16, 2025  
**Status**: Current

Quick commands for load testing, failover testing, and monitoring your PostgreSQL High Availability setup.

## 🚀 Load Testing Commands

### Check App Service Health

```powershell
curl -X GET https://app-loadgen-6wuso.azurewebsites.net/health
```

**Expected Response:** `"healthy"`

---

### Start Load Test

```powershell
curl -X POST https://app-loadgen-6wuso.azurewebsites.net/start
```

**Expected Response:** `202 Accepted`

---

### Check Load Test Status

```powershell
curl https://app-loadgen-6wuso.azurewebsites.net/status | ConvertFrom-Json | Format-List
```

**Sample Output:**
```
running               : True
status                : running
startTime             : 16/10/2025 14:30:00
transactionsCompleted : 125430
errors                : 12
uptime                : 00:02:15.123456
logs                  : {Starting load test..., ✓ Connected to PostgreSQL, Running...}
```

---

### Stop Load Test

```powershell
# Load test stops automatically after configured duration
# Or delete/restart the App Service
.\scripts\loadtesting\Deploy-LoadGenerator-AppService.ps1 -Action Delete
```

---

## 🎯 Failover Testing Commands

### Complete Failover Test with RTO/RPO Measurement

**Quick Test (2 minutes total):**
```powershell
.\scripts\loadtesting\Measure-Failover-RTO-RPO.ps1 `
    -AppServiceUrl "https://app-loadgen-6wuso.azurewebsites.net" `
    -ResourceGroup "rg-pgv2-usc01" `
    -ServerName "pg-cus" `
    -DatabaseName "saifdb" `
    -AdminUsername "jonathan" `
    -MaxMonitoringSeconds 90
```

**Standard Test (default - waits for full TPS recovery):**
```powershell
.\scripts\loadtesting\Measure-Failover-RTO-RPO.ps1 `
    -AppServiceUrl "https://app-loadgen-6wuso.azurewebsites.net" `
    -ResourceGroup "rg-pgv2-usc01" `
    -ServerName "pg-cus" `
    -DatabaseName "saifdb" `
    -AdminUsername "jonathan"
```

**What It Does:**
1. ✅ Starts load test (if not running)
2. ✅ Establishes 30-second baseline (TPS, transaction counts)
3. ⏸️ Prompts you to trigger manual failover
4. 🔄 Monitors connection loss and recovery (1-second probes)
5. 📊 Calculates RTO (recovery time) and RPO (data loss)
6. ✅ Validates against targets: RTO < 30s, RPO = 0
7. 📁 Exports CSV metrics and JSON summary

**Parameters:**
- `-MaxMonitoringSeconds 90` - Total monitoring time (default: waits for 80% TPS recovery)
- `-BaselineSeconds 30` - Baseline duration (default: 30)
- `-ProbeInterval 1` - Probe frequency in seconds (default: 1)
- `-RecoveryThreshold 0.8` - TPS recovery threshold as % of baseline (default: 0.8)

**Targets:**
- **RTO**: < 30 seconds ✅
- **RPO**: 0 transactions (zero data loss) ✅

**Total Duration:**
- With `-MaxMonitoringSeconds 90`: ~2 minutes (30s baseline + 90s monitoring)
- Without parameter: Until TPS recovers to 80% of baseline (varies)

---

### Trigger Manual Failover

**Option 1: Azure Portal**
```
1. Navigate to: Azure Portal → pg-cus → High availability
2. Click: "Forced failover"
3. Confirm the action
```

**Option 2: Azure CLI**
```powershell
az postgres flexible-server restart `
    --name pg-cus `
    --resource-group rg-pgv2-usc01 `
    --failover Forced
```

---

## 📊 Database Query Commands

### Check Transaction Count and TPS (Last 10 Minutes)

```sql
SELECT 
    COUNT(*) as total_transactions,
    EXTRACT(EPOCH FROM (MAX(transaction_date) - MIN(transaction_date))) as duration_seconds,
    ROUND(COUNT(*) / NULLIF(EXTRACT(EPOCH FROM (MAX(transaction_date) - MIN(transaction_date))), 0), 2) as tps
FROM transactions
WHERE transaction_date > NOW() - INTERVAL '10 minutes';
```

**Sample Output:**
```
 total_transactions | duration_seconds |   tps
--------------------+------------------+---------
             145230 |           600.50 | 1448.25
```

---

### Check Total Transaction Count

```sql
SELECT COUNT(*) as total_transactions FROM transactions;
```

---

### Check Recent Transactions (Last 100)

```sql
SELECT 
    transaction_id,
    customer_id,
    merchant_id,
    amount,
    status,
    transaction_date
FROM transactions
ORDER BY transaction_date DESC
LIMIT 100;
```

---

### Check Transactions by Status

```sql
SELECT 
    status,
    COUNT(*) as count,
    SUM(amount) as total_amount,
    AVG(amount) as avg_amount
FROM transactions
GROUP BY status
ORDER BY count DESC;
```

---

### Check Transaction Rate Over Time (5-Minute Buckets)

```sql
SELECT 
    DATE_TRUNC('minute', transaction_date) as time_bucket,
    COUNT(*) as transaction_count,
    COUNT(*) / 60.0 as tps
FROM transactions
WHERE transaction_date > NOW() - INTERVAL '1 hour'
GROUP BY time_bucket
ORDER BY time_bucket DESC;
```

---

## 🔧 Monitoring Commands

### Stream App Service Logs (Real-Time)

```powershell
.\scripts\loadtesting\Monitor-AppService-Logs.ps1
```

**What You'll See:**
- Load test startup messages
- PostgreSQL connection status
- TPS updates every few seconds
- Transaction counts
- Error messages (if any)

---

### Check App Service Status (Azure CLI)

```powershell
az webapp show `
    --name app-loadgen-6wuso `
    --resource-group rg-pgv2-usc01 `
    --query "{name:name, state:state, defaultHostName:defaultHostName}" `
    --output table
```

---

### Check PostgreSQL Server Status

```powershell
az postgres flexible-server show `
    --name pg-cus `
    --resource-group rg-pgv2-usc01 `
    --query "{name:name, state:state, version:version, haEnabled:highAvailability.mode}" `
    --output table
```

---

### Check PostgreSQL High Availability Status

```powershell
az postgres flexible-server show `
    --name pg-cus `
    --resource-group rg-pgv2-usc01 `
    --query "highAvailability" `
    --output json
```

---

## 📁 Deployment Commands

### Build Container Image

```powershell
.\scripts\loadtesting\Build-LoadGenerator-Docker.ps1
```

---

### Deploy App Service

```powershell
.\scripts\loadtesting\Deploy-LoadGenerator-AppService.ps1 -Action Deploy
```

---

### Update App Service Configuration

```powershell
.\scripts\loadtesting\Deploy-LoadGenerator-AppService.ps1 -Action Update
```

---

### Delete App Service

```powershell
.\scripts\loadtesting\Deploy-LoadGenerator-AppService.ps1 -Action Delete
```

---

## 🎨 PowerShell Quick Commands

### Check if Load Test is Running

```powershell
$status = Invoke-RestMethod -Uri "https://app-loadgen-6wuso.azurewebsites.net/status"
if ($status.running) {
    Write-Host "Load test is RUNNING" -ForegroundColor Green
    Write-Host "Transactions: $($status.transactionsCompleted)" -ForegroundColor Cyan
    Write-Host "Errors: $($status.errors)" -ForegroundColor Yellow
} else {
    Write-Host "Load test is NOT running" -ForegroundColor Red
    Write-Host "Status: $($status.status)" -ForegroundColor Yellow
}
```

---

### Calculate TPS from Status

```powershell
$status = Invoke-RestMethod -Uri "https://app-loadgen-6wuso.azurewebsites.net/status"
$uptime = [TimeSpan]::Parse($status.uptime)
$tps = [math]::Round($status.transactionsCompleted / $uptime.TotalSeconds, 2)
Write-Host "Current TPS: $tps" -ForegroundColor Green
```

---

### Start Test and Monitor Until Complete

```powershell
# Start test
Invoke-RestMethod -Uri "https://app-loadgen-6wuso.azurewebsites.net/start" -Method Post

# Monitor until complete
do {
    Start-Sleep -Seconds 10
    $status = Invoke-RestMethod -Uri "https://app-loadgen-6wuso.azurewebsites.net/status"
    $uptime = [TimeSpan]::Parse($status.uptime)
    $tps = [math]::Round($status.transactionsCompleted / $uptime.TotalSeconds, 2)
    
    Write-Host "[$($status.status)] Transactions: $($status.transactionsCompleted) | Errors: $($status.errors) | TPS: $tps" -ForegroundColor Cyan
} while ($status.running)

Write-Host "`n✅ Test Complete!" -ForegroundColor Green
Write-Host "Total Transactions: $($status.transactionsCompleted)" -ForegroundColor Cyan
Write-Host "Total Errors: $($status.errors)" -ForegroundColor Yellow
Write-Host "Total Duration: $($status.uptime)" -ForegroundColor Cyan
```

---

## 📖 Configuration Files

### Edit Configuration

```powershell
code scripts\loadtesting\LoadGenerator-Config.ps1
```

**Key Settings:**
- `$ResourceGroup` - Azure resource group
- `$PostgreSQL.Server` - PostgreSQL server name
- `$PostgreSQL.Database` - Database name
- `$LoadTest.TargetTPS` - Target transactions per second
- `$LoadTest.WorkerCount` - Number of parallel workers
- `$LoadTest.TestDuration` - Test duration in seconds

---

## 🆘 Troubleshooting

### Container Won't Start

```powershell
# Check logs
.\scripts\loadtesting\Monitor-AppService-Logs.ps1

# Redeploy with fresh managed identity
.\scripts\loadtesting\Deploy-LoadGenerator-AppService.ps1 -Action Update
```

---

### Load Test Not Running

```powershell
# Check health
curl -X GET https://app-loadgen-6wuso.azurewebsites.net/health

# Check App Service state
az webapp show --name app-loadgen-6wuso --resource-group rg-pgv2-usc01 --query state

# Restart App Service
az webapp restart --name app-loadgen-6wuso --resource-group rg-pgv2-usc01
```

---

### No Transactions in Database

```sql
-- Check if transactions table exists
SELECT COUNT(*) FROM transactions;

-- Check recent inserts
SELECT MAX(transaction_date) as last_transaction FROM transactions;

-- Check transaction rate
SELECT COUNT(*) FROM transactions WHERE transaction_date > NOW() - INTERVAL '5 minutes';
```

---

### Database Connection Issues

```powershell
# Check PostgreSQL server state
az postgres flexible-server show `
    --name pg-cus `
    --resource-group rg-pgv2-usc01 `
    --query state

# Check firewall rules
az postgres flexible-server firewall-rule list `
    --name pg-cus `
    --resource-group rg-pgv2-usc01 `
    --output table
```

---

## 🎯 Quick Test Workflow

**Complete end-to-end test:**

```powershell
# 1. Check health
curl -X GET https://app-loadgen-6wuso.azurewebsites.net/health

# 2. Start load test
curl -X POST https://app-loadgen-6wuso.azurewebsites.net/start

# 3. Wait 30 seconds for baseline
Start-Sleep -Seconds 30

# 4. Run failover test (2-minute quick test)
.\scripts\loadtesting\Measure-Failover-RTO-RPO.ps1 `
    -AppServiceUrl "https://app-loadgen-6wuso.azurewebsites.net" `
    -ResourceGroup "rg-pgv2-usc01" `
    -ServerName "pg-cus" `
    -DatabaseName "saifdb" `
    -AdminUsername "jonathan" `
    -MaxMonitoringSeconds 90

# 5. When prompted, trigger failover in another window:
az postgres flexible-server restart `
    --name pg-cus `
    --resource-group rg-pgv2-usc01 `
    --failover Forced

# 6. Review results (completes in ~2 minutes: 30s baseline + 90s monitoring)
# - RTO < 30 seconds? ✅/❌
# - RPO = 0? ✅/❌
# - CSV and JSON files generated
```

---

## 📚 Documentation Links

- **[Load Testing Guide](./load-testing-guide.md)** - Comprehensive guide (~1000 lines)
- **[Failover Testing Quick Reference](./failover-testing-quick-reference.md)** - RTO/RPO guide (~300 lines)
- **[Scripts README](../../scripts/loadtesting/README.md)** - File structure and quick start

---

## 🔑 Environment Variables

**App Service Environment Variables** (configured automatically by deploy script):

```bash
POSTGRESQL_SERVER=pg-cus.postgres.database.azure.com
POSTGRESQL_PORT=5432
POSTGRESQL_DATABASE=saifdb
POSTGRESQL_USERNAME=jonathan
POSTGRESQL_PASSWORD=*** (from Key Vault or parameter)
TARGET_TPS=1000
WORKER_COUNT=200
TEST_DURATION=300
```

---

## 📊 Expected Performance Metrics

**Baseline Performance:**
- **Target TPS**: 1,000 TPS
- **Expected Actual**: 1,400-1,500 TPS (140-150% of target)
- **Error Rate**: < 1%
- **RTO Target**: < 30 seconds
- **RPO Target**: 0 transactions (zero data loss)

**Recent Test Results:**
- Transactions: 2,269,565
- Duration: 26 min 7 sec
- Actual TPS: ~1,448 TPS
- Errors: 2,873 (0.13%)
- Achievement: 145% of target ✅

---

## 🎓 Quick Tips

1. **Always check health** before starting tests
2. **Wait for baseline** (30+ seconds) before triggering failover
3. **Use PowerShell** for better JSON parsing than curl
4. **Monitor logs** in real-time during tests
5. **Validate in database** to confirm actual transaction persistence
6. **Export results** - CSV and JSON files are saved automatically
7. **Clean up** after tests to avoid unnecessary costs

---

**Last Updated:** October 16, 2025  
**Workshop:** Azure PostgreSQL High Availability with SAIF Framework  
**Repository:** [azure-postgresql-ha-workshop](https://github.com/jonathan-vella/azure-postgresql-ha-workshop)
