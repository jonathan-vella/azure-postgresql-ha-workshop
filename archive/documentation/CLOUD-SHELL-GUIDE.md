# Azure Cloud Shell Load Testing - Quick Start Guide

This guide shows how to run high-performance PostgreSQL failover testing from Azure Cloud Shell using the native C# script.

## 🚀 Quick Start (60 seconds)

### Step 1: Open Azure Cloud Shell
1. Navigate to [Azure Portal](https://portal.azure.com)
2. Click the Cloud Shell icon (>_) in the top menu bar
3. Select **PowerShell** or **Bash** (both work)

### Step 2: Install .NET Script (One-Time Setup)
```bash
# Install dotnet-script tool globally
dotnet tool install -g dotnet-script

# Add to PATH (PowerShell)
$env:PATH += ":$HOME/.dotnet/tools"

# Or for Bash
export PATH="$PATH:$HOME/.dotnet/tools"
```

### Step 3: Upload the Script
```bash
# Option A: Clone from repository
git clone https://github.com/jonathan-vella/SAIF.git
cd SAIF/SAIF-pgsql/scripts

# Option B: Upload directly via Cloud Shell
# Click "Upload/Download files" button in Cloud Shell toolbar
# Select: Test-PostgreSQL-Failover.csx

# Option C: Create inline
cat > Test-PostgreSQL-Failover.csx << 'EOF'
# ... paste the script content ...
EOF
```

### Step 4: Get Your Connection String
```bash
# Retrieve server details
az postgres flexible-server show \
  --resource-group rg-saif-pgsql-swc-01 \
  --name psql-saifpg-10081025 \
  --query "{fqdn:fullyQualifiedDomainName,state:state}" \
  -o table
```

Build your connection string:
```
Host=<fqdn>;Database=saifdb;Username=<admin-user>;Password=<password>;SSL Mode=Require
```

### Step 5: Run the Test
```bash
# Basic test (10 workers, 5 minutes)
dotnet script Test-PostgreSQL-Failover.csx -- \
  "Host=psql-saifpg-10081025.postgres.database.azure.com;Database=saifdb;Username=saifadmin;Password=YourPassword;SSL Mode=Require" \
  10 \
  5

# High-throughput test (20 workers, 10 minutes)
dotnet script Test-PostgreSQL-Failover.csx -- \
  "Host=psql-saifpg-10081025.postgres.database.azure.com;Database=saifdb;Username=saifadmin;Password=YourPassword;SSL Mode=Require" \
  20 \
  10

# Quick validation test (5 workers, 2 minutes)
dotnet script Test-PostgreSQL-Failover.csx -- \
  "Host=psql-saifpg-10081025.postgres.database.azure.com;Database=saifdb;Username=saifadmin;Password=YourPassword;SSL Mode=Require" \
  5 \
  2
```

---

## 📊 Expected Performance

### Cloud Shell (Standard)
- **CPU**: 1 shared core
- **Memory**: ~1.7 GB
- **Expected TPS**: **200-300 TPS**
- **Network Latency**: 1-5ms (same region)

### Cloud Shell (with more resources)
If you have access to dedicated Cloud Shell containers:
- **CPU**: 2 cores
- **Memory**: 4 GB
- **Expected TPS**: **400-500 TPS**

---

## 🔄 Triggering a Failover Test

### Method 1: Manual Failover (Azure Portal)
1. Navigate to your PostgreSQL Flexible Server
2. Go to **Settings** → **High Availability**
3. Click **Forced Failover** button
4. Confirm the failover
5. Watch the test output for RTO measurement

### Method 2: Azure CLI Forced Failover
```bash
# Trigger failover while test is running
az postgres flexible-server restart \
  --resource-group rg-saif-pgsql-swc-01 \
  --name psql-saifpg-10081025 \
  --failover Forced
```

### Method 3: Availability Zone Simulation
For realistic testing, simulate zone failure:
1. Start the load test
2. Trigger forced failover via CLI
3. Observe:
   - Connection loss detection
   - RTO measurement (typically 16-18 seconds)
   - RPO = 0 validation (zero data loss)

---

## 📈 Interpreting Results

### Sample Output
```
╔══════════════════════════════════════════════════════════════╗
║                     FINAL RESULTS                            ║
╚══════════════════════════════════════════════════════════════╝

📊 Transaction Statistics:
   Total Transactions:    83,670
   Failed Transactions:   12
   Success Rate:          99.99%
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

### Key Metrics

| Metric | Good | Acceptable | Concerning |
|--------|------|------------|------------|
| **Average TPS** | >200 | 100-200 | <100 |
| **RTO** | <20s | 20-60s | >60s |
| **RPO** | 0s | 0s | >0s |
| **Success Rate** | >99.9% | 99-99.9% | <99% |

---

## 🎯 Optimization Tips

### 1. Adjust Worker Count Based on vCores
```bash
# For 2 vCore database
dotnet script Test-PostgreSQL-Failover.csx -- "<connstring>" 8 5

# For 4 vCore database
dotnet script Test-PostgreSQL-Failover.csx -- "<connstring>" 16 5

# For 8 vCore database
dotnet script Test-PostgreSQL-Failover.csx -- "<connstring>" 32 5
```

**Rule of thumb**: 2-4 workers per vCore for optimal throughput

### 2. Connection Pooling (Built-in)
The script uses persistent connections with automatic reconnection:
- **Initial connection**: Established once per worker
- **Transaction execution**: Continuous on same connection
- **Reconnection**: Automatic with exponential backoff
- **Failover detection**: 3 consecutive failures trigger alert

### 3. Network Optimization
Ensure Cloud Shell is in the **same region** as your database:
- **Same region**: 1-5ms latency ✅
- **Different region**: 20-100ms latency ⚠️

Check with:
```bash
# Get your Cloud Shell region
curl -s http://169.254.169.254/metadata/instance?api-version=2021-02-01 \
  -H "Metadata: true" | jq -r '.compute.location'

# Compare with database region
az postgres flexible-server show \
  --resource-group rg-saif-pgsql-swc-01 \
  --name psql-saifpg-10081025 \
  --query location -o tsv
```

---

## 🐛 Troubleshooting

### Issue 1: "dotnet-script: command not found"
**Solution**: Install and add to PATH
```bash
dotnet tool install -g dotnet-script
export PATH="$PATH:$HOME/.dotnet/tools"  # Bash
$env:PATH += ":$HOME/.dotnet/tools"      # PowerShell
```

### Issue 2: "Connection refused"
**Check firewall rules**:
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
**Possible causes**:
1. **Cloud Shell resource limits**: Try reducing workers
2. **Database throttling**: Check database metrics
3. **Network issues**: Verify same-region deployment

**Debug command**:
```bash
# Check database connection
psql "Host=psql-saifpg-10081025.postgres.database.azure.com;Database=saifdb;Username=saifadmin;Password=YourPassword" \
  -c "SELECT version();"
```

### Issue 4: Script timeout in Cloud Shell
Cloud Shell has 20-minute idle timeout. For longer tests:
```bash
# Keep session alive with periodic output
while true; do 
  dotnet script Test-PostgreSQL-Failover.csx -- "<connstring>" 10 5
  echo "Test completed at $(date)"
  sleep 60
done
```

---

## 📦 Alternative: Container-Based Testing

For sustained, production-grade testing, deploy as a container:

```bash
# Create container with test script
cat > Dockerfile << 'EOF'
FROM mcr.microsoft.com/dotnet/sdk:8.0
RUN dotnet tool install -g dotnet-script
ENV PATH="${PATH}:/root/.dotnet/tools"
COPY Test-PostgreSQL-Failover.csx /app/
WORKDIR /app
ENTRYPOINT ["dotnet", "script", "Test-PostgreSQL-Failover.csx", "--"]
EOF

# Build and run in Azure Container Instances
az acr build \
  --registry <your-acr> \
  --image saif/loadtest:latest \
  .

az container create \
  --resource-group rg-saif-pgsql-swc-01 \
  --name saif-loadtest \
  --image <your-acr>.azurecr.io/saif/loadtest:latest \
  --cpu 2 \
  --memory 4 \
  --restart-policy Never \
  --command-line 'dotnet script Test-PostgreSQL-Failover.csx -- "Host=psql-saifpg-10081025.postgres.database.azure.com;Database=saifdb;Username=saifadmin;Password=YourPassword;SSL Mode=Require" 20 30'
```

**Expected performance**: 500-1,000 TPS (2 CPU, 4GB RAM)

---

## 🔐 Security Best Practices

### Store Connection String in Environment Variable
```bash
# Set in Cloud Shell session
export PG_CONNECTION_STRING="Host=psql-saifpg-10081025.postgres.database.azure.com;Database=saifdb;Username=saifadmin;Password=YourPassword;SSL Mode=Require"

# Use in script
dotnet script Test-PostgreSQL-Failover.csx -- "$PG_CONNECTION_STRING" 10 5
```

### Retrieve Password from Key Vault
```bash
# Get password from Key Vault
export PG_PASSWORD=$(az keyvault secret show \
  --vault-name <your-keyvault> \
  --name postgresql-admin-password \
  --query value -o tsv)

# Build connection string
export PG_CONNECTION_STRING="Host=psql-saifpg-10081025.postgres.database.azure.com;Database=saifdb;Username=saifadmin;Password=$PG_PASSWORD;SSL Mode=Require"

# Run test
dotnet script Test-PostgreSQL-Failover.csx -- "$PG_CONNECTION_STRING" 10 5
```

---

## 📚 Related Documentation

- **Main README**: [../README.md](../README.md)
- **Failover Testing Guide**: [../docs/v1.0.0/failover-testing-guide.md](../docs/v1.0.0/failover-testing-guide.md)
- **PowerShell Script Version**: [Test-PostgreSQL-Failover.ps1](Test-PostgreSQL-Failover.ps1)
- **Database Scripts**: [../database/](../database/)

---

## 🎓 Performance Comparison

| Method | Location | TPS | Setup Time | Pros | Cons |
|--------|----------|-----|------------|------|------|
| **C# Script (Cloud Shell)** | Azure | 200-300 | 5 min | ✅ High TPS<br>✅ Free<br>✅ Same region | ⚠️ Session timeout<br>⚠️ Shared resources |
| **PowerShell (Local)** | Your PC | 12-13 | 0 min | ✅ No setup<br>✅ Familiar | ❌ Low TPS<br>❌ Network latency |
| **Container (ACI)** | Azure | 500-1,000 | 30 min | ✅ Highest TPS<br>✅ Persistent<br>✅ Dedicated resources | ⚠️ Cost (~$0.05/hr)<br>⚠️ More complex |

**Recommendation**: Start with C# script in Cloud Shell for best balance of performance, cost, and simplicity.
