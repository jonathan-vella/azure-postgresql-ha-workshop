# PostgreSQL HA Performance Monitoring - Setup Complete ✅

**Date:** October 10, 2025  
**Server:** psql-saifpg-10081025  
**Current SKU:** Standard_D16ds_v5 (16 vCore, 64 GB RAM)  
**Target:** 8000 TPS sustained load testing

---

## ✅ What's Running Now

### Terminal Monitor (ACTIVE)
- **Status:** ✅ Running in background
- **Location:** Terminal ID `ada0c4f6-3364-4045-a1ed-6697159c5a6f`
- **Refresh Rate:** Every 10 seconds
- **Metrics Displayed:**
  - TPS (Transactions Per Second) - color-coded
  - IOPS % - shows disk utilization
  - Read/Write IOPS breakdown
  - CPU % and Memory %
  - Disk Read/Write throughput (MB/s)
  - Active connections
  - Replication lag (for HA)

**How to view:** Switch to that terminal or check the output above

---

## 📊 Azure Portal Dashboard Setup

### Quick Setup (2-3 minutes):

1. **Open Azure Portal**
   - Go to: https://portal.azure.com
   - Navigate to: `rg-saif-pgsql-swc-01` → `psql-saifpg-10081025`
   - Click: **"Monitoring"** → **"Metrics"**

2. **Add 6 Key Charts** (pin each to new dashboard):
   - ✅ Transactions Committed (TPS)
   - ✅ Disk IOPS Consumed % + Read/Write IOPS
   - ✅ CPU % + Memory %
   - ✅ Read/Write Throughput (MB/s)
   - ✅ Active Connections + Failed Connections
   - ✅ Replication Lag Seconds

3. **Save Dashboard**
   - Name: "PostgreSQL-HA-8K-TPS-Test"
   - Set time range: **Last 1 hour**

**See full instructions in:** `docs/DASHBOARD-QUICK-SETUP.md`

---

## ⚠️ Storage Upgrade Status

### Current Storage: 1024 GB (1 TB)
**Expected P70:** 8192-16384 GB (8-16 TB) with 15K IOPS

### To verify upgrade status:

```powershell
# Check storage details
az postgres flexible-server show `
    --resource-group "rg-saif-pgsql-swc-01" `
    --name "psql-saifpg-10081025" `
    --query "storage" -o table
```

### If upgrade is still in progress:
1. Go to Azure Portal → Server → **"Compute + Storage"**
2. Look for deployment notification
3. Upgrades typically take 5-10 minutes
4. No downtime during storage scaling!

### If upgrade hasn't started:
1. Portal → Server → **"Compute + Storage"**
2. Under **"Storage"**, increase to **8192 GB** (8 TB for P70)
3. This will give you:
   - **15,000 IOPS** (vs current ~7,500)
   - **500 MB/s** throughput
   - Expected: **8K-10K TPS** capability

---

## 🚀 Ready to Start Load Test

Once dashboard is set up and storage upgrade is confirmed, you're ready!

### Load Test Command:

```powershell
# Get password
$pgPasswordText = az keyvault secret show `
    --vault-name "kvsaifpg10081025" `
    --name "POSTGRES-ADMIN-PASSWORD" `
    --query "value" -o tsv

$pgPassword = ConvertTo-SecureString -String $pgPasswordText -AsPlainText -Force

# Deploy 8K TPS load generator
.\scripts\Deploy-LoadGenerator-ACI.ps1 -Action Deploy `
    -ResourceGroup "rg-saif-pgsql-swc-01" `
    -PostgreSQLServer "psql-saifpg-10081025" `
    -DatabaseName "saifdb" `
    -AdminUsername "saifadmin" `
    -PostgreSQLPassword $pgPassword `
    -TargetTPS 8000 `
    -WorkerCount 200 `
    -TestDuration 300 `
    -ContainerCPU 16 `
    -ContainerMemory 32
```

### Monitor During Test:

**Option 1: Terminal Monitor (Already Running!)**
- ✅ Currently active, showing real-time metrics
- Updates every 10 seconds
- Color-coded for quick assessment

**Option 2: Azure Portal Dashboard**
- Visual charts with historical data
- Zoom in/out on time ranges
- Export data for analysis

**Option 3: Container Monitor**
```powershell
# After deployment starts, monitor container + database
.\scripts\Monitor-LoadGenerator-Resilient.ps1 `
    -ResourceGroup "rg-saif-pgsql-swc-01" `
    -ContainerName "aci-loadgen-<timestamp>" `
    -PostgreSQLServer "psql-saifpg-10081025" `
    -DatabaseName "saifdb" `
    -AdminUser "saifadmin" `
    -AdminPassword $pgPasswordText
```

---

## 📈 Expected Results with Current Config

### With 1TB Disk (Current - P30):
- **IOPS**: ~7,500 max
- **Expected TPS**: ~5,500 (as tested earlier)
- **IOPS Utilization**: ~80-90% ⚠️

### With 8TB P70 Disk (After Upgrade):
- **IOPS**: 15,000 max
- **Expected TPS**: **8,000-10,000** ✅
- **IOPS Utilization**: **40-50%** 🟢 (excellent headroom)

---

## 🎯 Success Criteria

### For 8K TPS Target:
- ✅ TPS: 8000+ sustained (color: green in monitor)
- ✅ IOPS %: <50% (not disk-bound)
- ✅ CPU %: 50-70% (optimal utilization)
- ✅ Memory %: <60% (no pressure)
- ✅ Replication Lag: <1 second (HA ready for failover)
- ✅ Exit Code: 0 (100% success rate)

---

## 📝 Next Steps

1. ✅ **Terminal monitor is running** - check current baseline
2. 🔄 **Verify P70 upgrade completed** (check storage size)
3. 📊 **Create Azure Portal dashboard** (2-3 minutes)
4. 🚀 **Run 8K TPS load test** (5 minutes)
5. 📊 **Analyze results** - compare to 5.5K TPS baseline
6. 🧪 **Ready for failover testing** - test RTO under load

---

## 🆘 Troubleshooting

### If terminal monitor shows "N/A" for metrics:
- Wait 60 seconds - metrics have 1-minute lag
- Check Azure Monitor is enabled on the server
- Metrics appear after first data points arrive

### If dashboard doesn't show data:
- Set time range to "Last 1 hour"
- Refresh the page
- Ensure "Auto-refresh" is enabled (top right)

### If IOPS stays at 80%+ even after upgrade:
- Verify storage size increased: `az postgres flexible-server show...`
- Check "Compute + Storage" page for deployment status
- Contact Azure support if stuck

---

## 📚 Reference Files

- **Terminal Monitor**: `scripts/Monitor-PostgreSQL-Realtime.ps1`
- **Dashboard Creator**: `scripts/Create-PostgreSQL-Dashboard.ps1`
- **Load Generator**: `scripts/Deploy-LoadGenerator-ACI.ps1`
- **Container Monitor**: `scripts/Monitor-LoadGenerator-Resilient.ps1`
- **Quick Setup Guide**: `docs/DASHBOARD-QUICK-SETUP.md`
- **KQL Queries**: Will be generated in `postgresql-monitoring-queries-*.kql`

---

**Status:** ✅ Ready for dashboard creation and load testing!
