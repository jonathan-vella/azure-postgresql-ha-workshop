# Load Testing & Failover Guide

**Last Updated:** October 13, 2025 | **Version:** 2.1.0

Comprehensive guide for high-performance load testing and PostgreSQL failover validation.

---

## 📋 Table of Contents

- [Part 1: High-Performance Load Testing (8K+ TPS)](#part-1-high-performance-load-testing-8k-tps)
- [Part 2: Failover Testing & HA Validation](#part-2-failover-testing--ha-validation)
- [Part 3: Performance Monitoring](#part-3-performance-monitoring)
- [Part 4: Troubleshooting & Best Practices](#part-4-troubleshooting--best-practices)

---

# Part 1: High-Performance Load Testing (8K+ TPS)

## 🎯 Load Testing Overview

**Target Performance:** 8000+ TPS sustained for 5 minutes  
**Infrastructure:** D16ds_v5 (16 vCPU, 64 GB RAM) + P60 (8 TB, 16K IOPS)  
**Expected Result:** 2,400,000+ transactions with >99% success rate  
**Validated Performance:** 12,600+ TPS (October 2025)

### Prerequisites for Load Testing

1. **Verify Infrastructure Configuration:**
   ```powershell
   az postgres flexible-server show `
     --resource-group "rg-saif-pgsql-swc-01" `
     --name "psql-saifpg-XXXXXXXX" `
     --query "{compute:sku.name, storage:storage.storageSizeGb, tier:storage.tier, iops:storage.iops}" `
     -o table
   ```
   **Expected:** `Standard_D16ds_v5`, `8192 GB`, `P60`, `16000 IOPS`

2. **Database Initialized:**
   ```powershell
   .\scripts\Initialize-Database.ps1 `
     -ResourceGroup "rg-saif-pgsql-swc-01" `
     -PostgreSQLServer "psql-saifpg-XXXXXXXX" `
     -DatabaseName "saifdb" `
     -AdminUsername "saifadmin"
   ```

### Deploy Production Load Generator

#### **Step 1: Deploy 8000 TPS Load Generator**

```powershell
# Retrieve password from Key Vault
$pgPasswordText = az keyvault secret show `
  --vault-name "kvsaifpgXXXXXXXX" `
  --name "POSTGRES-ADMIN-PASSWORD" `
  --query "value" -o tsv

$pgPassword = ConvertTo-SecureString -String $pgPasswordText -AsPlainText -Force

# Deploy container with 8000 TPS configuration
.\scripts\Deploy-LoadGenerator-ACI.ps1 -Action Deploy `
    -ResourceGroup "rg-saif-pgsql-swc-01" `
    -PostgreSQLServer "psql-saifpg-XXXXXXXX" `
    -DatabaseName "saifdb" `
    -AdminUsername "saifadmin" `
    -PostgreSQLPassword $pgPassword `
    -TargetTPS 8000 `
    -WorkerCount 200 `
    -TestDuration 300 `
    -ContainerCPU 16 `
    -ContainerMemory 32
```

#### **Step 2: Monitor Load Test Execution**

```powershell
# Monitor container logs + database metrics
.\scripts\Monitor-LoadGenerator-Resilient.ps1 `
    -ResourceGroup "rg-saif-pgsql-swc-01" `
    -ContainerName "aci-loadgen-<timestamp>" `
    -PostgreSQLServer "psql-saifpg-XXXXXXXX" `
    -DatabaseName "saifdb" `
    -AdminUser "saifadmin" `
    -AdminPassword $pgPasswordText
```

#### **Step 3: Real-Time Performance Monitoring**

```powershell
# Open new terminal for live metrics (10-second refresh)
.\scripts\Monitor-PostgreSQL-Realtime.ps1 `
    -ResourceGroup "rg-saif-pgsql-swc-01" `
    -PostgreSQLServer "psql-saifpg-XXXXXXXX"
```

### Expected Load Test Results

#### **High-Performance Configuration (D16ds_v5 + P60)**
- **TPS:** 8,000-12,600+ sustained
- **Transactions:** 2.4M-3.8M over 5 minutes
- **Success Rate:** >99%
- **CPU:** 50-70%
- **IOPS:** <12,000 (75% of 16K capacity)
- **Memory:** <80% utilization

#### **Cleanup After Load Test**

```powershell
# Remove load generator container
.\scripts\Deploy-LoadGenerator-ACI.ps1 -Action Remove `
    -ResourceGroup "rg-saif-pgsql-swc-01" `
    -ContainerName "aci-loadgen-<timestamp>"
```

---

# Part 2: Failover Testing & HA Validation

## 🔄 Failover Testing Overview

Test Azure PostgreSQL Flexible Server Zone-Redundant High Availability to validate:
- **RTO (Recovery Time Objective):** ≤120 seconds
- **RPO (Recovery Point Objective):** 0 seconds (zero data loss)
- **SLA:** 99.99% uptime

### Automated Failover Testing

#### **Basic Failover Test (12-13 TPS)**

```powershell
# Run automated failover test
cd scripts
.\Test-PostgreSQL-Failover.ps1 -ResourceGroupName "rg-saif-pgsql-swc-01"

# Run with custom parameters
.\Test-PostgreSQL-Failover.ps1 `
    -ResourceGroupName "rg-saif-pgsql-swc-01" `
    -LoadDuration 120 `
    -TransactionsPerSecond 100
```

#### **High-Performance Failover Test (300+ TPS)**

For Azure Cloud Shell C# script execution:

```bash
# Upload and run C# failover script
dotnet script scripts/Test-PostgreSQL-Failover.csx -- \
  "Host=psql-saifpg-XXXXXXXX.postgres.database.azure.com;Database=saifdb;Username=saifadmin;Password=XXXX;SSL Mode=Require" \
  10 \
  5
```

### Manual Failover Procedures

#### **Planned Failover (Recommended)**

```powershell
# Trigger planned failover
az postgres flexible-server restart `
  --resource-group "rg-saif-pgsql-swc-01" `
  --name "psql-saifpg-XXXXXXXX" `
  --failover "Forced"
```

#### **Monitor Failover Progress**

```powershell
# Real-time failover monitoring
.\scripts\Monitor-PostgreSQL-HA.ps1 -ResourceGroupName "rg-saif-pgsql-swc-01"
```

### Expected Failover Timeline

```
Phase 1: Preparation (5-10 seconds)
├─ Validate HA configuration
├─ Record baseline metrics
└─ Start load generation

Phase 2: Failover Execution (60-120 seconds)
├─ T0: Trigger failover command
├─ T+15s: Primary becomes unavailable
├─ T+45s: Standby promotion begins
├─ T+60s: New primary accepting connections
└─ T+67s: Full service restoration

Phase 3: Validation (5-10 seconds)  
├─ Verify zone switch (Zone 1 ↔ Zone 2)
├─ Confirm zero data loss (RPO = 0)
└─ Validate RTO compliance (<120s)
```

### Sample Failover Results

```
🔄 Failover Metrics:
  Failover Start: 2025-10-13 14:23:15.123
  Failover End: 2025-10-13 14:24:22.456
  RTO (Recovery Time): 67.33 seconds ✅
  RPO (Data Loss): 0.00 seconds ✅

📊 Load Generation:
  Duration: 60 seconds
  Target TPS: 100
  Actual TPS: 98.45
  Successful Transactions: 5907
  Failed Transactions: 0

🌐 Zone Configuration:
  Before: Primary Zone 1 / Standby Zone 2
  After:  Primary Zone 2 / Standby Zone 1

📈 SLA Compliance:
  RTO ≤ 120s: ✅ PASS (67.33 seconds)
  RPO = 0s: ✅ PASS (zero data loss)
  99.99% Uptime: ✅ PASS
```

---

# Part 3: Performance Monitoring

## 📊 Azure Workbook Monitoring

### Import Performance Workbook

1. **Navigate:** Azure Portal → Workbooks → "+ New"
2. **Import:** `azure-workbooks/PostgreSQL-HA-Performance-Workbook.json`
3. **Configure:** Select your PostgreSQL server and workspace

### Real-Time Command Line Monitoring

```powershell
# Live metrics (10-second refresh)
.\scripts\Monitor-PostgreSQL-Realtime.ps1 `
    -ResourceGroup "rg-saif-pgsql-swc-01" `
    -PostgreSQLServer "psql-saifpg-XXXXXXXX"
```

**Displays:**
- TPS with comma separators (12,600)
- IOPS absolute values (16,000 max capacity)
- CPU percentage (target: 50-70%)
- Memory utilization
- Connection count
- Replication lag

### Key Performance Targets

| Metric | Target | High-Performance |
|--------|--------|------------------|
| **TPS** | ≥300 | ≥8,000 |
| **IOPS** | <80% | <12,000 (of 16K) |
| **CPU** | 50-70% | 50-70% |
| **Memory** | <80% | <80% |
| **Connections** | <500 | <800 |
| **Replication Lag** | <100ms | <50ms |

---

# Part 4: Troubleshooting & Best Practices

## 🔧 Common Issues

### Load Testing Issues

**Issue:** Low TPS performance
```powershell
# Check resource utilization
.\scripts\Monitor-PostgreSQL-Realtime.ps1 -ResourceGroup "rg-saif-pgsql-swc-01"

# Verify P60 storage upgrade
az postgres flexible-server show --resource-group "rg-saif-pgsql-swc-01" --name "psql-saifpg-XXXXXXXX" --query "storage"
```

**Issue:** Container deployment fails
```powershell
# Check container status
az container show --resource-group "rg-saif-pgsql-swc-01" --name "aci-loadgen-XXXXXXXX"

# Review deployment logs
az container logs --resource-group "rg-saif-pgsql-swc-01" --name "aci-loadgen-XXXXXXXX"
```

### Failover Testing Issues

**Issue:** Failover takes longer than 120s
- **Cause:** High transaction volume during failover
- **Solution:** Reduce load or wait for quieter period

**Issue:** Connection strings fail after failover
- **Cause:** DNS caching
- **Solution:** Use server FQDN, not IP addresses

## 🎯 Best Practices

### Load Testing
1. **Start Small:** Begin with 1000 TPS, scale up gradually
2. **Monitor Resources:** Watch CPU, IOPS, and memory during tests
3. **Clean Environment:** Run on fresh database for consistent results
4. **Time Windows:** Avoid peak hours for production testing

### Failover Testing
1. **Planned Windows:** Schedule during maintenance windows
2. **Baseline First:** Record normal operation metrics before testing
3. **Multiple Tests:** Run 3-5 tests for average RTO calculation
4. **Documentation:** Record all test results for compliance

### Performance Optimization
1. **Connection Pooling:** Use pgBouncer for high-concurrency workloads
2. **Index Strategy:** Optimize indexes for transaction patterns
3. **Monitoring:** Set up alerts for key performance thresholds
4. **Capacity Planning:** Monitor IOPS usage trends over time

## 💰 Cost Optimization

### Load Testing Costs
- **Container Instances:** Pay-per-second billing
- **Storage IOPS:** P60 costs ~$800/month (delete after testing)
- **Compute:** D16ds_v5 costs ~$840/month (can scale down post-test)

### Cost-Effective Testing Strategies
1. **Scale Up/Down:** Upgrade for testing, downgrade after
2. **Test Duration:** 5-10 minute tests provide sufficient validation
3. **Cleanup:** Delete ACI containers immediately after tests
4. **Scheduling:** Use Azure Automation for off-hours testing

---

**Related Documentation:**
- [Architecture Guide](architecture.md) - System design and components
- [Deployment Guide](deployment-guide.md) - Setup and configuration  
- [Troubleshooting](TROUBLESHOOTING.md) - Common issues and solutions
- [Main README](../README.md) - Project overview