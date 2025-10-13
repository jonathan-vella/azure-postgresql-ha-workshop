# Quick Reference: PostgreSQL 8K TPS Deployment

## 🚀 Quick Deploy Commands

### Option 1: Deploy with New Defaults (Recommended)
```powershell
# Standard_E4ds_v5 (4 vCore, 32 GB RAM) + PgBouncer enabled
az deployment group create `
  --resource-group rg-saif-pgsql-swc-01 `
  --template-file infra/main.bicep `
  --parameters postgresAdminPassword='YourSecurePassword123!'
```

### Option 2: Deploy with High-Performance SKU
```powershell
# Standard_D16ds_v5 (16 vCore, 64 GB RAM) for maximum TPS
az deployment group create `
  --resource-group rg-saif-pgsql-swc-01 `
  --template-file infra/main.bicep `
  --parameters postgresqlSku='Standard_D16ds_v5' `
               postgresAdminPassword='YourSecurePassword123!'
```

### Option 3: Keep Existing SKU (Get PgBouncer Only)
```powershell
# Standard_D4ds_v5 with new PgBouncer settings
az deployment group create `
  --resource-group rg-saif-pgsql-swc-01 `
  --template-file infra/main.bicep `
  --parameters postgresqlSku='Standard_D4ds_v5' `
               postgresAdminPassword='YourSecurePassword123!'
```

---

## 📊 SKU Comparison

| SKU | vCores | RAM | max_conn | Cost/Month* | Expected TPS |
|-----|--------|-----|----------|-------------|--------------|
| Standard_D4ds_v5 | 4 | 16 GB | 2000 | ~$524 | 3,000-5,000 |
| **Standard_E4ds_v5** ⭐ | 4 | 32 GB | 2000 | ~$612 | **8,000-12,000** |
| Standard_D16ds_v5 | 16 | 64 GB | 5000 | ~$1,080 | 15,000-20,000 |
| Standard_E8ds_v5 | 8 | 64 GB | 5000 | ~$1,224 | 15,000-20,000 |

*Zone-Redundant HA pricing (Sweden Central)

---

## 🔌 Connection Strings

### PgBouncer (Port 6432) - RECOMMENDED for High TPS
```bash
# psql
psql "host=psql-saifpg-xxxxx.postgres.database.azure.com port=6432 dbname=saifdb user=saifadmin sslmode=require"

# C# (Npgsql)
Host=psql-saifpg-xxxxx.postgres.database.azure.com;Port=6432;Database=saifdb;Username=saifadmin;Password=xxx;SSL Mode=Require;Pooling=true;Maximum Pool Size=500
```

### Direct (Port 5432) - Legacy
```bash
# psql
psql "host=psql-saifpg-xxxxx.postgres.database.azure.com port=5432 dbname=saifdb user=saifadmin sslmode=require"

# C# (Npgsql)
Host=psql-saifpg-xxxxx.postgres.database.azure.com;Port=5432;Database=saifdb;Username=saifadmin;Password=xxx;SSL Mode=Require
```

---

## ✅ Verification Commands

### Check SKU
```powershell
az postgres flexible-server show `
  --resource-group rg-saif-pgsql-swc-01 `
  --name psql-saifpg-xxxxx `
  --query "{SKU:sku.name, Tier:sku.tier, vCores:sku.capacity, Storage:storage.storageSizeGb}" `
  --output table
```

### Check PgBouncer Status
```powershell
az postgres flexible-server parameter show `
  --resource-group rg-saif-pgsql-swc-01 `
  --server-name psql-saifpg-xxxxx `
  --name pgbouncer.enabled `
  --query value `
  --output tsv
```

### Check max_connections
```powershell
az postgres flexible-server parameter show `
  --resource-group rg-saif-pgsql-swc-01 `
  --server-name psql-saifpg-xxxxx `
  --name max_connections `
  --query value `
  --output tsv
```

### Test PgBouncer Connection
```powershell
# Should succeed on port 6432
psql "host=psql-saifpg-xxxxx.postgres.database.azure.com port=6432 dbname=saifdb user=saifadmin sslmode=require" -c "SELECT version();"
```

---

## 🎯 Performance Tuning Quick Reference

### PgBouncer Settings (Auto-Applied)
- ✅ `pgbouncer.enabled` = `true`
- ✅ `pgbouncer.pool_mode` = `transaction`
- ✅ `pgbouncer.max_client_conn` = `5000`
- ✅ `pgbouncer.default_pool_size` = `100`
- ✅ `pgbouncer.min_pool_size` = `25`

### PostgreSQL Settings (Auto-Applied)
- ✅ `max_connections` = `2000`
- ✅ `shared_buffers` = `8GB` (E4ds_v5)
- ✅ `effective_cache_size` = `24GB` (E4ds_v5)
- ✅ `work_mem` = `16MB`
- ✅ `wal_buffers` = `16MB`
- ✅ `max_wal_size` = `4GB`
- ✅ `random_page_cost` = `1.1` (SSD)
- ✅ `effective_io_concurrency` = `200`

---

## 🧪 Load Test Quick Start

### 1. Deploy Load Generator to ACI
```powershell
$RG = "rg-saif-pgsql-swc-01"
$SERVER = "psql-saifpg-xxxxx"
$PASSWORD = "YourSecurePassword123!"

$CONN_STRING = "Host=$SERVER.postgres.database.azure.com;Port=6432;Database=saifdb;Username=saifadmin;Password=$PASSWORD;SSL Mode=Require;Pooling=true;Maximum Pool Size=500"

az container create `
  --resource-group $RG `
  --name "aci-loadgen-$(Get-Date -Format 'yyyyMMdd-HHmmss')" `
  --image mcr.microsoft.com/dotnet/sdk:8.0 `
  --cpu 16 `
  --memory 32 `
  --restart-policy Never `
  --environment-variables `
    POSTGRES_CONNECTION_STRING="$CONN_STRING" `
    TARGET_TPS=8000 `
    WORKER_COUNT=200 `
    TEST_DURATION=300 `
  --command-line "/bin/bash"
```

### 2. Monitor Load Test
```powershell
# Follow logs
az container logs --resource-group $RG --name aci-loadgen-xxxxx --follow
```

### 3. Expected Results
- **Target TPS**: 8,000
- **Expected TPS**: 8,000-12,000 (Standard_E4ds_v5)
- **P50 Latency**: 5-10ms
- **P95 Latency**: 20-30ms
- **Failover RTO**: 60-90 seconds

---

## 📚 Related Files

| File | Purpose |
|------|---------|
| `infra/main.bicep` | Main infrastructure template (UPDATED) |
| `infra/modules/database/postgresql.bicep` | PostgreSQL module (UPDATED) |
| `docs/architecture/HIGH-PERFORMANCE-8000TPS-ARCHITECTURE.md` | Complete architecture guide |
| `docs/architecture/BICEP-UPDATES-8K-TPS.md` | Detailed change log |

---

## 🆘 Troubleshooting

### Issue: Can't connect on port 6432
```powershell
# Verify PgBouncer is enabled
az postgres flexible-server parameter show `
  --resource-group rg-saif-pgsql-swc-01 `
  --server-name psql-saifpg-xxxxx `
  --name pgbouncer.enabled

# If false, enable it
az postgres flexible-server parameter set `
  --resource-group rg-saif-pgsql-swc-01 `
  --server-name psql-saifpg-xxxxx `
  --name pgbouncer.enabled `
  --value true
```

### Issue: Low TPS (<1000)
```powershell
# Check SKU (should be E4ds_v5 or higher)
az postgres flexible-server show --name psql-saifpg-xxxxx --query sku.name

# Check max_connections (should be 2000)
az postgres flexible-server parameter show --name max_connections --query value

# Verify using PgBouncer port (6432, not 5432)
echo $POSTGRES_CONNECTION_STRING | grep 6432
```

### Issue: Connection pool exhausted
```powershell
# Increase PgBouncer pool size
az postgres flexible-server parameter set `
  --resource-group rg-saif-pgsql-swc-01 `
  --server-name psql-saifpg-xxxxx `
  --name pgbouncer.default_pool_size `
  --value 200
```

---

## 🎓 Key Changes Summary

| What | Old | New |
|------|-----|-----|
| **Default SKU** | Standard_D4ds_v5 (4 vCore, 16 GB) | Standard_E4ds_v5 (4 vCore, 32 GB) ⭐ |
| **max_connections** | 200 | 2000 |
| **PgBouncer** | ❌ Disabled | ✅ Enabled (port 6432) |
| **shared_buffers** | Default (~1GB) | 8GB (optimized) |
| **Expected TPS** | 1,000-2,000 | **8,000-12,000** |

---

**Next Steps**: Deploy → Test → Celebrate 🎉
