# Cloud Shell Testing Guide

Complete step-by-step guide to test `Test-PostgreSQL-Failover.csx` in Azure Cloud Shell.

---

## 🚀 Quick Test (5 Minutes)

### Step 1: Run Setup Script

**For Bash:**
```bash
curl -sL https://raw.githubusercontent.com/jonathan-vella/SAIF/main/SAIF-pgsql/scripts/setup-cloudshell.sh | bash
```

**For PowerShell:**
```powershell
curl -sL https://raw.githubusercontent.com/jonathan-vella/SAIF/main/SAIF-pgsql/scripts/setup-cloudshell.ps1 | pwsh
```

**Or Manual Setup:**
```bash
# Install dotnet-script
dotnet tool install -g dotnet-script
export PATH="$PATH:$HOME/.dotnet/tools"

# Clone repository
git clone https://github.com/jonathan-vella/SAIF.git
cd SAIF/SAIF-pgsql/scripts
```

---

### Step 2: Get Your Connection String

**Option A: From Key Vault (Recommended)**
```bash
# Set your resource group and server name
RG_NAME="rg-saif-pgsql-swc-01"
SERVER_NAME="psql-saifpg-10081025"

# Find Key Vault
KV_NAME=$(az keyvault list --resource-group $RG_NAME --query "[0].name" -o tsv)

# Get password
PG_PASSWORD=$(az keyvault secret show \
  --vault-name $KV_NAME \
  --name postgresql-admin-password \
  --query value -o tsv)

# Build connection string
CONN_STRING="Host=${SERVER_NAME}.postgres.database.azure.com;Database=saifdb;Username=saifadmin;Password=${PG_PASSWORD};SSL Mode=Require"

echo "✅ Connection string ready"
```

**Option B: Manual Entry (if you know the password)**
```bash
# Replace with your actual values
export CONN_STRING="Host=psql-saifpg-10081025.postgres.database.azure.com;Database=saifdb;Username=saifadmin;Password=YourPassword;SSL Mode=Require"
```

---

### Step 3: Run the Test

**Basic Test (10 workers, 5 minutes):**
```bash
dotnet script Test-PostgreSQL-Failover.csx -- "$CONN_STRING" 10 5
```

**Quick Validation (5 workers, 2 minutes):**
```bash
dotnet script Test-PostgreSQL-Failover.csx -- "$CONN_STRING" 5 2
```

**High Throughput (20 workers, 10 minutes):**
```bash
dotnet script Test-PostgreSQL-Failover.csx -- "$CONN_STRING" 20 10
```

---

## 📊 Expected Output

### Successful Startup
```
╔══════════════════════════════════════════════════════════════╗
║     PostgreSQL Zone-Redundant HA Failover Load Test         ║
╚══════════════════════════════════════════════════════════════╝

🔧 Configuration:
   Server:           psql-saifpg-10081025.postgres.database.azure.com
   Database:         saifdb
   Parallel Workers: 10
   Test Duration:    5 minutes
   Expected TPS:     200-500 (Cloud Shell) / 80-100 (Local)

📋 Test Methodology:
   1. Establish 10 persistent connections
   2. Execute create_test_transaction() continuously
   3. Detect connection loss with millisecond precision
   4. Measure RTO (Recovery Time Objective)
   5. Validate RPO = 0 (zero data loss)

⏳ Initializing connections... ✓

🚀 Load test started! Press Ctrl+C to stop.

┌─────────────┬────────────┬───────────┬──────────┬──────────┬─────────┐
│    Time     │    TPS     │   Total   │  Errors  │ Reconnect│  Status │
├─────────────┼────────────┼───────────┼──────────┼──────────┼─────────┤
│ 19:15:05.123│   243.56   │     1,218 │        0 │        0 │ RUNNING │
│ 19:15:10.456│   278.92   │     2,818 │        0 │        0 │ RUNNING │
│ 19:15:15.789│   285.20   │     4,244 │        0 │        0 │ RUNNING │
```

### During Failover (if triggered)
```
│ 19:15:40.123│   292.10   │    58,420 │        0 │        0 │ RUNNING │

⚠️  [19:15:42.123] CONNECTION LOST - Potential failover detected!

│ 19:15:45.456│    18.30   │    58,435 │       15 │        0 │ FAILING │
│ 19:15:50.789│     0.00   │    58,435 │       30 │        0 │ FAILING │

✅ [19:15:58.456] CONNECTION RESTORED!
   RTO (Recovery Time): 16.33 seconds

│ 19:16:03.789│   265.80   │    59,764 │       32 │       10 │RECOVERED│
│ 19:16:08.123│   278.45   │    61,156 │       32 │       10 │RECOVERED│
```

### Final Results
```
╔══════════════════════════════════════════════════════════════╗
║                     FINAL RESULTS                            ║
╚══════════════════════════════════════════════════════════════╝

📊 Transaction Statistics:
   Total Transactions:    83,670
   Failed Transactions:   32
   Success Rate:          99.96%
   Test Duration:         05:00

⚡ Performance Metrics:
   Average TPS:           279.00
   Peak TPS:              312.45
   P50 TPS:               278.50
   P95 TPS:               298.20
   Min TPS:               18.30

🔄 Failover Metrics:
  Connection Lost:       2025-10-09 19:15:42.123
  Connection Restored:   2025-10-09 19:15:58.456

   ⏱️  RTO (Recovery Time):  16.33 seconds
   💾 RPO (Data Loss):      0 seconds (zero data loss)

📈 High Availability Assessment:
   ✅ EXCELLENT: RTO 16.3s is well below 60-120s spec
   ✅ RPO: Zero data loss validated
```

---

## 🧪 Test Scenarios

### Scenario 1: Baseline Performance Test (No Failover)
```bash
# Run for 5 minutes to establish baseline TPS
dotnet script Test-PostgreSQL-Failover.csx -- "$CONN_STRING" 10 5

# Expected: 200-300 TPS sustained
# No failover detected message
# All connections stable
```

### Scenario 2: Manual Failover Test
```bash
# Terminal 1: Start load test
dotnet script Test-PostgreSQL-Failover.csx -- "$CONN_STRING" 10 10

# Terminal 2: Trigger failover (after 2-3 minutes)
az postgres flexible-server restart \
  --resource-group rg-saif-pgsql-swc-01 \
  --name psql-saifpg-10081025 \
  --failover Forced

# Expected in Terminal 1:
# - CONNECTION LOST message
# - TPS drops to near zero
# - CONNECTION RESTORED after 16-18 seconds
# - TPS recovers to baseline
```

### Scenario 3: High-Throughput Stress Test
```bash
# Use maximum workers for your database vCores
# Rule: 2-4 workers per vCore

# For 4 vCore database:
dotnet script Test-PostgreSQL-Failover.csx -- "$CONN_STRING" 16 10

# For 8 vCore database:
dotnet script Test-PostgreSQL-Failover.csx -- "$CONN_STRING" 32 10

# Expected: 400-500 TPS or higher
```

### Scenario 4: Quick Health Check
```bash
# 2-minute quick test to verify everything works
dotnet script Test-PostgreSQL-Failover.csx -- "$CONN_STRING" 5 2

# Expected: ~100-150 TPS (lower due to fewer workers)
# Should complete successfully with no errors
```

---

## 🐛 Troubleshooting

### Issue 1: "dotnet-script: command not found"

**Solution:**
```bash
# Reinstall and add to PATH
dotnet tool install -g dotnet-script
export PATH="$PATH:$HOME/.dotnet/tools"

# Verify
which dotnet-script
dotnet-script --version
```

### Issue 2: "Failed to connect to server"

**Check 1: Verify server is running**
```bash
az postgres flexible-server show \
  --resource-group rg-saif-pgsql-swc-01 \
  --name psql-saifpg-10081025 \
  --query state -o tsv
# Should return: Ready
```

**Check 2: Test connection manually**
```bash
# Try psql connection
docker run --rm -e PGPASSWORD="$PG_PASSWORD" postgres:16-alpine \
  psql -h psql-saifpg-10081025.postgres.database.azure.com \
  -U saifadmin -d saifdb -c "SELECT 1;"
```

**Check 3: Verify firewall rules**
```bash
# Add Cloud Shell IP to firewall
CLOUD_SHELL_IP=$(curl -s https://api.ipify.org)
az postgres flexible-server firewall-rule create \
  --resource-group rg-saif-pgsql-swc-01 \
  --name psql-saifpg-10081025 \
  --rule-name AllowCloudShell \
  --start-ip-address $CLOUD_SHELL_IP \
  --end-ip-address $CLOUD_SHELL_IP
```

### Issue 3: Low TPS (<50)

**Possible Causes:**
1. **Insufficient workers** - Try increasing worker count
2. **Database throttling** - Check Azure Monitor for CPU/connection limits
3. **Network issues** - Verify Cloud Shell and DB are in same region

**Debug:**
```bash
# Check database metrics
az monitor metrics list \
  --resource $(az postgres flexible-server show -g rg-saif-pgsql-swc-01 -n psql-saifpg-10081025 --query id -o tsv) \
  --metric "cpu_percent,memory_percent,active_connections" \
  --start-time $(date -u -d '5 minutes ago' '+%Y-%m-%dT%H:%M:%SZ') \
  --end-time $(date -u '+%Y-%m-%dT%H:%M:%SZ') \
  --interval PT1M \
  --output table
```

### Issue 4: "create_test_transaction does not exist"

**Solution: Initialize database**
```bash
cd ../database
cat init-db.sql | docker run -i --rm -e PGPASSWORD="$PG_PASSWORD" postgres:16-alpine \
  psql -h psql-saifpg-10081025.postgres.database.azure.com -U saifadmin -d saifdb
```

### Issue 5: NuGet Package Download Fails

**Solution: Clear cache and retry**
```bash
# Clear dotnet cache
dotnet nuget locals all --clear

# Retry test
dotnet script Test-PostgreSQL-Failover.csx -- "$CONN_STRING" 10 5
```

### Issue 6: C# Compilation Warnings/Errors

**Issue:** `CS0168: variable declared but never used` or `CS8632: nullable annotations context`

**Solution:** Script has been updated with `#nullable enable` directive and proper exception handling.

```bash
# If you see these errors, update your local copy:
cd ~/SAIF/SAIF-pgsql
git pull origin main

# Or download directly:
curl -sL https://raw.githubusercontent.com/jonathan-vella/SAIF/main/SAIF-pgsql/scripts/Test-PostgreSQL-Failover.csx -o scripts/Test-PostgreSQL-Failover.csx
```

---

## 📈 Performance Benchmarking

### Cloud Shell Hardware Profile
```bash
# Check CPU cores
nproc

# Check memory
free -h

# Check network to Azure
ping -c 5 psql-saifpg-10081025.postgres.database.azure.com
```

### Expected TPS by Configuration

| Cloud Shell CPU | Workers | Expected TPS | Database vCores |
|----------------|---------|--------------|-----------------|
| 1 core         | 5       | 100-150      | 2 vCore         |
| 1 core         | 10      | 200-300      | 4 vCore         |
| 2 cores        | 10      | 300-400      | 4 vCore         |
| 2 cores        | 20      | 400-500      | 8 vCore         |

**Optimization Formula:**
- Workers = 2-4 × Database vCores
- More workers doesn't always help (connection limits)
- Balance workers with database capacity

---

## 🔐 Security Best Practices

### Use Environment Variables
```bash
# Store connection string securely
export CONN_STRING="Host=...;Database=saifdb;..."

# Use in commands
dotnet script Test-PostgreSQL-Failover.csx -- "$CONN_STRING" 10 5

# Clear after use
unset CONN_STRING
```

### Use Key Vault for All Credentials
```bash
# Never hardcode passwords
# Always retrieve from Key Vault
PG_PASSWORD=$(az keyvault secret show \
  --vault-name $KV_NAME \
  --name postgresql-admin-password \
  --query value -o tsv)
```

### Avoid Logging Sensitive Data
```bash
# Don't echo connection strings
# Don't commit credentials to git
# Don't share Cloud Shell output with passwords
```

---

## 📚 Related Documentation

- [CLOUD-SHELL-GUIDE.md](CLOUD-SHELL-GUIDE.md) - Complete Cloud Shell setup guide
- [failover-testing-guide.md](../docs/v1.0.0/failover-testing-guide.md) - Comprehensive testing guide
- [README.md](../README.md) - Project overview

---

## ✅ Test Checklist

- [ ] Installed dotnet-script in Cloud Shell
- [ ] Cloned SAIF repository
- [ ] Retrieved connection string from Key Vault
- [ ] Ran baseline performance test (no failover)
- [ ] Achieved 200+ TPS sustained throughput
- [ ] Triggered manual failover
- [ ] Observed CONNECTION LOST message
- [ ] Measured RTO (16-18 seconds expected)
- [ ] Validated RPO = 0 (zero data loss)
- [ ] Reviewed final statistics (P50, P95, peak TPS)

---

**Ready to test?** Start with Step 1 above! 🚀
