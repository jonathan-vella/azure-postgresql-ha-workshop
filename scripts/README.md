# SAIF-PostgreSQL Scripts Directory

This directory contains deployment and management scripts for SAIF-PostgreSQL with Azure PostgreSQL High Availability.

---

## 📜 Scripts Overview

### Deployment Scripts

| Script | Purpose | Time | Use Case |
|--------|---------|------|----------|
| **Deploy-SAIF-PostgreSQL.ps1** | Complete deployment | 25-30 min | Initial deployment, infrastructure changes |
| **Quick-Deploy-SAIF.ps1** | Simplified deployment | 25-30 min | Demos, testing, auto-password generation |
| **Rebuild-SAIF-Containers.ps1** | Container updates only | 5-10 min | Application code updates |

### Testing & Monitoring Scripts

| Script | Purpose | Time | Use Case |
|--------|---------|------|----------|
| **Test-PostgreSQL-Failover.csx** ⭐ | **C# high-performance failover testing (200-500 TPS)** | 1-10 min | **Production-grade load testing in Cloud Shell** |
| **Test-PostgreSQL-Failover.ps1** | PowerShell failover testing (Npgsql native, 12-13 TPS) | 1-5 min | Local testing, quick HA validation |
| **Monitor-PostgreSQL-HA.ps1** | Real-time HA monitoring | Continuous | Monitor HA status and metrics |
| **Test-SAIFLocal.ps1** | Local development testing | 2-5 min | Validate local Docker setup |
| **Update-LoadTestFunction.ps1** | Deploy test functions to DB | 2-3 min | Update database test transaction functions |
| **Initialize-Database.ps1** | Database schema initialization | 2-3 min | Initial DB setup or schema updates |

> 🚀 **Performance Tip**: Use `Test-PostgreSQL-Failover.csx` in Azure Cloud Shell for **16-40x higher throughput** (200-500 TPS vs 12-13 TPS). See [CLOUD-SHELL-GUIDE.md](CLOUD-SHELL-GUIDE.md) for setup instructions.

### Utility & Diagnostic Scripts

| Script | Purpose | Location |
|--------|---------|----------|
| **Diagnose-Failover-Performance.ps1** | Troubleshoot failover issues | `utils/` |
| **Build-SAIF-Containers.ps1** | Low-level container build | `utils/` |

### Archived Scripts

Obsolete scripts are preserved in `archive/` folder for reference. See `archive/README.md` for details.

**Archived versions include:**
- Old Docker-based failover tests (0.7-20 TPS variants)
- Legacy initialization scripts
- Superseded container update scripts

---

## 🚀 Quick Start

### First Time Deployment

```powershell
# Option 1: Quick start with auto-generated password
.\Quick-Deploy-SAIF.ps1 -environmentName "dev"

# Option 2: Full control
$password = ConvertTo-SecureString "YourPassword123!" -AsPlainText -Force
.\Deploy-SAIF-PostgreSQL.ps1 -location "swedencentral" -postgresqlPassword $password -autoApprove
```

### Update Application Code

```powershell
# Fast container rebuild (5-10 minutes)
.\Rebuild-SAIF-Containers.ps1 -resourceGroupName "rg-saif-pgsql-swc-01"
```

### Test High Availability

**Option 1: High-Performance Cloud Shell (200-500 TPS)** ⭐ **RECOMMENDED**
```bash
# Azure Cloud Shell
dotnet script Test-PostgreSQL-Failover.csx -- \
  "Host=psql-saifpg-10081025.postgres.database.azure.com;Database=saifdb;Username=saifadmin;Password=YourPass;SSL Mode=Require" \
  10 \
  5
```
> 📖 See [CLOUD-SHELL-GUIDE.md](CLOUD-SHELL-GUIDE.md) for complete setup

**Option 2: Local PowerShell (12-13 TPS)**
```powershell
# Trigger and monitor failover
.\Test-PostgreSQL-Failover.ps1 -ResourceGroupName "rg-saif-pgsql-swc-01"
```

---

## 📖 Detailed Script Documentation

### Deploy-SAIF-PostgreSQL.ps1

**Full-featured deployment script with all options.**

**Parameters:**
```powershell
-location               # Azure region (default: swedencentral)
-resourceGroupName      # Custom resource group name (optional)
-postgresqlPassword     # PostgreSQL admin password (SecureString)
-postgresqlSku          # PostgreSQL SKU (default: Standard_D4ds_v5)
-disableHighAvailability # Disable HA for cost savings
-skipContainers         # Skip container builds (infrastructure only)
-autoApprove            # Skip confirmation prompts
```

**Examples:**
```powershell
# Interactive deployment
.\Deploy-SAIF-PostgreSQL.ps1 -location "swedencentral"

# Automated deployment
$pwd = ConvertTo-SecureString "Password123!" -AsPlainText -Force
.\Deploy-SAIF-PostgreSQL.ps1 -location "swedencentral" -postgresqlPassword $pwd -autoApprove

# Dev environment without HA
$pwd = ConvertTo-SecureString "DevPassword!" -AsPlainText -Force
.\Deploy-SAIF-PostgreSQL.ps1 -location "swedencentral" -postgresqlPassword $pwd -disableHighAvailability -autoApprove
```

**What it does:**
1. Validates prerequisites and Azure authentication
2. Creates or validates resource group
3. Deploys infrastructure using Bicep (10-15 min)
4. Retrieves deployment outputs with retry logic
5. Initializes PostgreSQL database schema
6. Builds and pushes containers to ACR (10-15 min)
7. Restarts App Services and validates health

---

### Quick-Deploy-SAIF.ps1

**Simplified deployment with auto-generated passwords and environment presets.**

**Parameters:**
```powershell
-location               # Azure region (default: swedencentral)
-environmentName        # Environment: dev, test, staging, prod (default: dev)
-postgresqlPassword     # Optional password (auto-generated if not provided)
-skipContainers         # Skip container builds
-disableHighAvailability # Disable HA
```

**Examples:**
```powershell
# Quick demo deployment
.\Quick-Deploy-SAIF.ps1

# Production deployment in Germany
.\Quick-Deploy-SAIF.ps1 -location "germanywestcentral" -environmentName "prod"

# Test environment without HA
.\Quick-Deploy-SAIF.ps1 -environmentName "test" -disableHighAvailability
```

**Features:**
- 🔐 Auto-generates secure 16-character passwords
- 🎯 Environment-based SKU selection (dev→D2, prod→D4)
- 📝 Saves credentials to temp file with warnings
- 🏷️ Automatic resource naming by environment
- ✅ Calls main deployment script with optimized settings

---

### Rebuild-SAIF-Containers.ps1

**Fast container rebuilds without infrastructure changes (80% faster than full deployment).**

**Parameters:**
```powershell
-resourceGroupName      # Resource group name (required)
-buildApi               # Build API container only
-buildWeb               # Build Web container only
-skipRestart            # Build without restarting services
-tag                    # Custom image tag (default: latest)
```

**Examples:**
```powershell
# Rebuild both containers
.\Rebuild-SAIF-Containers.ps1 -resourceGroupName "rg-saif-pgsql-swc-01"

# Rebuild API only
.\Rebuild-SAIF-Containers.ps1 -resourceGroupName "rg-saif-pgsql-swc-01" -buildApi

# Build with custom tag
.\Rebuild-SAIF-Containers.ps1 -resourceGroupName "rg-saif-pgsql-swc-01" -tag "v1.2.0"

# Build without restart (for blue-green deployments)
.\Rebuild-SAIF-Containers.ps1 -resourceGroupName "rg-saif-pgsql-swc-01" -skipRestart
```

**What it does:**
1. Discovers ACR and App Services in resource group
2. Builds specified containers (API, Web, or both)
3. Pushes images to ACR with specified tag
4. Verifies images exist in registry
5. Restarts App Services to pull new images
6. Tests health endpoints

**When to use:**
- ✅ Application code changes
- ✅ Dependency updates (npm, pip packages)
- ✅ Configuration changes in Dockerfiles
- ❌ Infrastructure changes (use Deploy script)
- ❌ Database schema changes (manual migration)

---

### Test-PostgreSQL-Failover.csx ⭐ **HIGH PERFORMANCE**

**C# script for Azure Cloud Shell with 200-500 TPS throughput.**

**Prerequisites:**
```bash
# One-time setup in Cloud Shell
dotnet tool install -g dotnet-script
export PATH="$PATH:$HOME/.dotnet/tools"
```

**Usage:**
```bash
# Syntax: dotnet script Test-PostgreSQL-Failover.csx -- <connection-string> <workers> <duration-min>

# Standard test (10 workers, 5 minutes)
dotnet script Test-PostgreSQL-Failover.csx -- \
  "Host=psql-saifpg-10081025.postgres.database.azure.com;Database=saifdb;Username=saifadmin;Password=YourPass;SSL Mode=Require" \
  10 \
  5

# High-throughput test (20 workers, 10 minutes)
dotnet script Test-PostgreSQL-Failover.csx -- \
  "Host=psql-saifpg-10081025.postgres.database.azure.com;Database=saifdb;Username=saifadmin;Password=YourPass;SSL Mode=Require" \
  20 \
  10

# Using environment variable
export CONN_STRING="Host=...;Database=saifdb;..."
dotnet script Test-PostgreSQL-Failover.csx -- "$CONN_STRING" 10 5
```

**What it does:**
1. Spawns parallel async workers with persistent connections
2. Generates sustained high-throughput load (200-500 TPS)
3. Detects connection loss with millisecond precision
4. Automatically reconnects with exponential backoff
5. Measures RTO/RPO during failover
6. Reports comprehensive statistics (P50, P95, peak TPS)
7. Real-time monitoring with color-coded status

**Performance:**
- **200-300 TPS** (Cloud Shell 1 CPU)
- **400-500 TPS** (Cloud Shell 2 CPU)
- **80-100 TPS** (Local PC, network limited)

> 📖 **Complete Guide**: [CLOUD-SHELL-GUIDE.md](CLOUD-SHELL-GUIDE.md) - Setup, troubleshooting, optimization tips

---

### Test-PostgreSQL-Failover.ps1

**PowerShell script for local testing with 12-13 TPS throughput.**

**Parameters:**
```powershell
-ResourceGroupName      # Resource group name (required)
-ServerName             # PostgreSQL server name (auto-discovered if not provided)
-WaitForCompletion      # Wait for failover to complete
```

**Examples:**
```powershell
# Basic failover test
.\Test-PostgreSQL-Failover.ps1 -ResourceGroupName "rg-saif-pgsql-swc-01"

# Wait for completion
.\Test-PostgreSQL-Failover.ps1 -ResourceGroupName "rg-saif-pgsql-swc-01" -WaitForCompletion
```

**What it does:**
1. Validates HA is enabled (auto-discovers server)
2. Records pre-failover state (primary/standby zones)
3. Generates load using native Npgsql (12-13 TPS)
4. Detects connection loss and measures RTO
5. Validates zone swap and connectivity
6. Reports RTO (Recovery Time Objective) and RPO (0)

---

### Monitor-PostgreSQL-HA.ps1

**Real-time HA status monitoring.**

**Parameters:**
```powershell
-ResourceGroupName      # Resource group name (required)
-ServerName             # PostgreSQL server name (optional)
-RefreshInterval        # Refresh interval in seconds (default: 30)
```

**Examples:**
```powershell
# Monitor HA status
.\Monitor-PostgreSQL-HA.ps1 -ResourceGroupName "rg-saif-pgsql-swc-01"

# Custom refresh interval
.\Monitor-PostgreSQL-HA.ps1 -ResourceGroupName "rg-saif-pgsql-swc-01" -RefreshInterval 10
```

---

### Test-SAIFLocal.ps1

**Local Docker environment testing.**

**Parameters:**
```powershell
-SkipBuild              # Skip docker-compose build step
-Verbose                # Show detailed output
```

**Examples:**
```powershell
# Full test with build
.\Test-SAIFLocal.ps1

# Quick test (skip build)
.\Test-SAIFLocal.ps1 -SkipBuild
```

---

## 💡 Common Workflows

### New Development Environment
```powershell
# 1. Quick deployment
.\Quick-Deploy-SAIF.ps1 -environmentName "dev" -disableHighAvailability

# 2. Make code changes
# (edit files in api/ or web/)

# 3. Fast update
.\Rebuild-SAIF-Containers.ps1 -resourceGroupName "rg-saif-dev-swc-01"
```

### Production Deployment
```powershell
# 1. Initial deployment
$pwd = ConvertTo-SecureString "SecureP@ssw0rd!" -AsPlainText -Force
.\Deploy-SAIF-PostgreSQL.ps1 `
    -location "swedencentral" `
    -postgresqlPassword $pwd `
    -autoApprove

# 2. Test HA
.\Test-PostgreSQL-Failover.ps1 -ResourceGroupName "rg-saif-pgsql-swc-01" -WaitForCompletion

# 3. Rolling updates
.\Rebuild-SAIF-Containers.ps1 `
    -resourceGroupName "rg-saif-pgsql-swc-01" `
    -tag "v1.0.0"
```

### Continuous Monitoring
```powershell
# Terminal 1: Monitor HA status
.\Monitor-PostgreSQL-HA.ps1 -ResourceGroupName "rg-saif-pgsql-swc-01"

# Terminal 2: Watch App Service logs
az webapp log tail --name app-saifpg-api-10081025 --resource-group rg-saif-pgsql-swc-01
```

---

## 🔍 Troubleshooting

### Script Hangs During Deployment

**Solution:** The enhanced script now includes timeout and retry logic. If using an old version:
```powershell
git pull origin main
.\Deploy-SAIF-PostgreSQL.ps1 -location "swedencentral"
```

### Containers Not Building

**Check if script reached Step 6:**
```powershell
# Check deployment status
az deployment group list --resource-group <rgName> --output table

# Check if containers exist
az acr repository list --name <acrName>

# If missing, rebuild
.\Rebuild-SAIF-Containers.ps1 -resourceGroupName <rgName>
```

### App Services Won't Start

**Solution:**
```powershell
# Check if images exist
az acr repository list --name <acrName>

# If missing, rebuild
.\Rebuild-SAIF-Containers.ps1 -resourceGroupName <rgName>

# Check logs
az webapp log tail --name <appName> --resource-group <rgName>
```

### Permission Issues

**Solution:**
```powershell
# Check Azure CLI login
az account show

# Re-login if needed
az login

# Check permissions
az role assignment list --assignee $(az account show --query user.name -o tsv)
```

---

## 📚 Additional Documentation

- **Deployment Guide:** `../docs/v1.0.0/deployment-guide.md`
- **Quick Reference:** `../docs/v1.0.0/quick-reference.md`
- **Enhancement Summary:** `../docs/v1.0.0/deployment-enhancements-summary.md`
- **Migration Guide:** `../docs/v1.0.0/migration-guide.md`
- **Failover Testing:** `../docs/v1.0.0/failover-testing-guide.md`

---

## 🆘 Getting Help

### Script Help
```powershell
Get-Help .\Deploy-SAIF-PostgreSQL.ps1 -Full
Get-Help .\Quick-Deploy-SAIF.ps1 -Full
Get-Help .\Rebuild-SAIF-Containers.ps1 -Full
```

### Azure CLI Help
```powershell
az postgres flexible-server --help
az acr --help
az webapp --help
```

---

## 📊 Performance Comparison

| Task | Old Approach | New Approach | Time Savings |
|------|--------------|-------------|--------------|
| First deployment | 25-30 min | 25-30 min | Same (but more reliable) |
| Code update | 25-30 min redeploy | 5-10 min rebuild | 15-20 min (80% faster) |
| Infrastructure update | 25-30 min | 25-30 min | Same |
| New environment setup | Manual + 25-30 min | 1 command + 25-30 min | 15 min saved |

---

**Last Updated:** 2025-10-09  
**Version:** 2.0.0  
**Repository:** https://github.com/jonathan-vella/SAIF
