# 🚀 Load Testing Quick Reference

**Target:** 8000 TPS sustained for 5 minutes  
**Infrastructure:** D16ds_v5 (16 vCPU, 64 GB RAM) + P70 (8 TB, 15K IOPS)  
**Expected Result:** 2,400,000 transactions with >99% success rate

---

## 📋 Prerequisites

1. **Verify P70 Storage Upgrade:**
   ```powershell
   az postgres flexible-server show `
     --resource-group "rg-saif-pgsql-swc-01" `
     --name "psql-saifpg-10081025" `
     --query "{storage:storage.storageSizeGb, tier:storage.tier, iops:storage.iops}" `
     -o table
   ```
   **Expected:** `8192 GB`, `P70`, `15000 IOPS`

2. **Azure Workbook Imported:**
   - Navigate to: Azure Portal → Workbooks → "+ New"
   - Use workbook for visual monitoring during test

3. **Database Initialized:**
   ```powershell
   .\scripts\Initialize-Database.ps1 `
     -ResourceGroup "rg-saif-pgsql-swc-01" `
     -PostgreSQLServer "psql-saifpg-10081025" `
     -DatabaseName "saifdb" `
     -AdminUsername "saifadmin"
   ```

---

## 🎯 Option A: Full Scale 8000 TPS Test

### **Step 1: Deploy Load Generator (16 vCPU, 32 GB, 200 workers)**

```powershell
# Retrieve password from Key Vault
$pgPasswordText = az keyvault secret show `
  --vault-name "kvsaifpg10081025" `
  --name "POSTGRES-ADMIN-PASSWORD" `
  --query "value" -o tsv

$pgPassword = ConvertTo-SecureString -String $pgPasswordText -AsPlainText -Force

# Deploy container with 8000 TPS configuration
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

**Output:** Container name will be `aci-loadgen-YYYYMMDD-HHMMSS`

---

### **Step 2: Start Container Monitoring**

```powershell
# Monitor container logs + database metrics
.\scripts\Monitor-LoadGenerator-Resilient.ps1 `
    -ResourceGroup "rg-saif-pgsql-swc-01" `
    -ContainerName "aci-loadgen-<timestamp>" `
    -PostgreSQLServer "psql-saifpg-10081025" `
    -DatabaseName "saifdb" `
    -AdminUser "saifadmin" `
    -AdminPassword $pgPasswordText
```

**Replace `<timestamp>`** with the container name from Step 1.

---

### **Step 3: Watch Real-Time Metrics (Optional)**

```powershell
# Open new terminal window for live metrics
.\scripts\Monitor-PostgreSQL-Realtime.ps1 `
    -ResourceGroup "rg-saif-pgsql-swc-01" `
    -PostgreSQLServer "psql-saifpg-10081025"
```

**Displays:** TPS, IOPS%, CPU%, Memory%, Throughput, Connections, Replication Lag  
**Refresh:** Every 10 seconds  
**Color Coding:** Green (healthy), Yellow (warning), Red (critical)

---

## 📊 Expected Results

### **With P70 Disk (15K IOPS):**

| Metric | Target | Expected Range |
|--------|--------|----------------|
| **Total Transactions** | 2,400,000 | 2,350,000 - 2,500,000 |
| **Sustained TPS** | 8,000 | 7,800 - 9,000 |
| **Success Rate** | >99% | 99.5% - 100% |
| **IOPS Utilization** | <50% | 40% - 50% |
| **CPU Utilization** | 50-70% | 55% - 75% |
| **Memory Utilization** | <60% | 40% - 60% |
| **Replication Lag** | <1 sec | 0 - 0.5 sec |
| **Exit Code** | 0 | 0 (success) |
| **Test Duration** | 300 sec | 305 - 310 sec |

---

## 🎯 Option B: Small Test (Validation)

Use this for quick validation before full scale test:

```powershell
# 60-second test with 50 workers, 2000 TPS target
.\scripts\Deploy-LoadGenerator-ACI.ps1 -Action Deploy `
    -ResourceGroup "rg-saif-pgsql-swc-01" `
    -PostgreSQLServer "psql-saifpg-10081025" `
    -DatabaseName "saifdb" `
    -AdminUsername "saifadmin" `
    -PostgreSQLPassword $pgPassword `
    -TargetTPS 2000 `
    -WorkerCount 50 `
    -TestDuration 60 `
    -ContainerCPU 4 `
    -ContainerMemory 8
```

**Expected:** ~120,000 transactions, ~2000 TPS sustained

---

## 🔍 Monitoring During Test

### **What You'll See in Container Monitor:**

```
════════════════════════════════════════════════════════════════════
📦 AZURE CONTAINER INSTANCE MONITOR (RESILIENT)
════════════════════════════════════════════════════════════════════
Container: aci-loadgen-20251010-210000
Resource Group: rg-saif-pgsql-swc-01
Refresh: Every 10 seconds (Database: Every 10 seconds)

⏱️  [21:00:45] STATE: Running | EXIT CODE: - | RESTARTS: 0
📊 DATABASE METRICS: 125,847 transactions | Current TPS: 8,245 (↑)
─────────────────────────────────────────────────────────────────────
```

### **What You'll See in Real-Time Monitor:**

```
═══════════════════════════════════════════════════════════════
📊 POSTGRESQL REAL-TIME PERFORMANCE MONITOR
═══════════════════════════════════════════════════════════════

Time     TPS    IOPS%   R/W IOPS      CPU%   Mem%   Read MB/s  Write MB/s  Conns  RepLag
21:01:00 8245   45.2%   2156/4625    67.8%  52.1%  125.3      285.7       198    0.12s
21:01:10 8189   44.8%   2098/4589    66.5%  51.9%  122.1      278.4       200    0.09s
```

### **What You'll See in Azure Workbook:**

- **TPS Chart:** Blue line climbing to 8000+
- **IOPS Chart:** Green/blue lines at ~45% (excellent headroom!)
- **CPU Chart:** Blue line at 60-70% (optimal)
- **Throughput Chart:** Write throughput ~300 MB/s
- **Connections Chart:** Stable ~200 active connections
- **Replication Lag:** Near zero (<1 second)

---

## ✅ Success Criteria

**Test is successful when:**
- ✅ Exit code = 0
- ✅ Total transactions ≥ 2,350,000
- ✅ Success rate ≥ 99%
- ✅ IOPS% stays <60% (headroom for spikes)
- ✅ CPU% stays 50-75% (not maxed out)
- ✅ Replication lag <1 second (ready for failover)
- ✅ No container restarts

---

## ⚠️ Troubleshooting

### **If IOPS% reaches 90%+:**
- **Issue:** Storage bottleneck (P70 may not be applied)
- **Fix:** Verify storage upgrade completed
  ```powershell
  az postgres flexible-server show --resource-group "rg-saif-pgsql-swc-01" --name "psql-saifpg-10081025" --query "storage"
  ```

### **If CPU% reaches 90%+:**
- **Issue:** Compute bottleneck (need larger SKU)
- **Consider:** Upgrade to D32ds_v5 (32 vCPU) for 15K+ TPS

### **If Success Rate <95%:**
- **Issue:** Connection failures or timeouts
- **Check:** PgBouncer max_client_conn (should be 5000)
- **Check:** Container logs for error patterns

### **If Container Fails (Exit Code ≠ 0):**
- **Check logs:**
  ```powershell
  az container logs --resource-group "rg-saif-pgsql-swc-01" --name "aci-loadgen-<timestamp>" --tail 100
  ```
- **Common causes:**
  - Database connection issues
  - Insufficient container resources
  - Network connectivity problems

### **If Replication Lag >5 seconds:**
- **Issue:** HA standby falling behind
- **Impact:** Failover will have data loss risk
- **Check:** Network connectivity to standby region

---

## 🧹 Cleanup After Test

```powershell
# Remove container (optional, auto-deleted after completion)
az container delete `
  --resource-group "rg-saif-pgsql-swc-01" `
  --name "aci-loadgen-<timestamp>" `
  --yes
```

---

## 📈 Next Steps After Successful Test

1. **Run Failover Test Under Load:**
   ```powershell
   # Start load test, then trigger failover mid-test
   .\scripts\Test-PostgreSQL-Failover.ps1 -ResourceGroup "rg-saif-pgsql-swc-01" -PostgreSQLServer "psql-saifpg-10081025"
   ```

2. **Analyze Failover Impact:**
   - Transaction interruption duration
   - Connection recovery time
   - Data consistency verification
   - Replication lag recovery

3. **Document Results:**
   - Peak TPS achieved
   - Resource utilization patterns
   - Failover behavior under load
   - Cost per 1K TPS calculation

---

## 📚 Related Documentation

- **Container Build Guide:** `docs/guides/BUILD-CONTAINERS-GUIDE.md`
- **Failover Testing:** `docs/v1.0.0/failover-testing-guide.md`
- **Monitoring Setup:** `azure-workbooks/IMPORT-GUIDE.md`
- **Troubleshooting:** `docs/TROUBLESHOOTING.md`
- **Azure Workbook Import:** `azure-workbooks/IMPORT-GUIDE.md`

---

**Last Updated:** October 10, 2025  
**Version:** 1.0 (P70 Configuration)
