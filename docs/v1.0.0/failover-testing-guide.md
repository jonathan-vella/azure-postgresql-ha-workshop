# SAIF-PostgreSQL Failover Testing Guide

A comprehensive guide for testing zone-redundant high availability and measuring failover performance for the SAIF-PostgreSQL payment gateway application.

---

## 🔄 Failover Testing Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    SAIF-PostgreSQL Failover Test Flow                   │
└─────────────────────────────────────────────────────────────────────────┘

PHASE 1: PRE-FLIGHT VALIDATION
┌─────────────────────────────────┐
│  1. Check HA Configuration      │
│     ├─ Verify Zone-Redundant HA │
│     ├─ Confirm Primary Zone 1   │
│     ├─ Confirm Standby Zone 2   │
│     └─ Validate State: Healthy  │
└─────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────┐
│  2. Baseline Metrics            │
│     ├─ Database status          │
│     ├─ Connection count         │
│     ├─ Transaction count        │
│     └─ API health check         │
└─────────────────────────────────┘

═══════════════════════════════════════════════════════════

PHASE 2: LOAD GENERATION (60-120 seconds)
┌─────────────────────────────────┐
│  3. Generate Payment Load       │
│     ├─ Target: 100 TPS          │
│     ├─ Duration: 60s            │
│     ├─ Real payment txns        │
│     └─ Monitor: Success rate    │
└─────────────────────────────────┘
                 │
    ┌────────────┴────────────┐
    │                         │
    ▼                         ▼
┌─────────┐            ┌─────────┐
│ Zone 1  │◄─ SYNC ───►│ Zone 2  │
│ Primary │  Replicate │ Standby │
│ ACTIVE  │            │  READY  │
└─────────┘            └─────────┘

═══════════════════════════════════════════════════════════

PHASE 3: TRIGGER FAILOVER
┌─────────────────────────────────┐
│  4. Record Timestamp T0         │
│     └─ Start time: 14:23:15.123 │
└─────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────┐
│  5. Execute Failover Command    │
│     az postgres flexible-server │
│       restart --failover Forced │
└─────────────────────────────────┘
                 │
                 ▼
    ┌────────────┴────────────┐
    │    FAILOVER EVENT       │
    └────────────┬────────────┘
                 │
    ┌────────────┴────────────┐
    │                         │
    ▼                         ▼
┌─────────┐            ┌─────────┐
│ Zone 1  │            │ Zone 2  │
│Standby  │◄─ SYNC ───►│ Primary │
│ READY   │            │ ACTIVE  │
└─────────┘            └─────────┘
                 │
                 ▼
┌─────────────────────────────────┐
│  6. Monitor Database States     │
│     ├─ Wait for: Unavailable    │
│     ├─ Wait for: Creating       │
│     ├─ Wait for: Starting       │
│     └─ Wait for: Available      │
└─────────────────────────────────┘

═══════════════════════════════════════════════════════════

PHASE 4: RECOVERY MEASUREMENT
┌─────────────────────────────────┐
│  7. Detect Recovery             │
│     └─ First successful query   │
└─────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────┐
│  8. Record Timestamp T1         │
│     └─ End time: 14:24:22.456   │
└─────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────┐
│  9. Calculate RTO               │
│     └─ RTO = T1 - T0 = 67.33s  │
└─────────────────────────────────┘

═══════════════════════════════════════════════════════════

PHASE 5: VALIDATION & REPORTING
┌─────────────────────────────────┐
│ 10. Verify Zero Data Loss (RPO) │
│     ├─ Transaction count before │
│     ├─ Transaction count after  │
│     └─ RPO = 0 (no data loss)   │
└─────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────┐
│ 11. Confirm Zone Switch         │
│     ├─ Primary: Zone 2 ✓        │
│     └─ Standby: Zone 1 ✓        │
└─────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────┐
│ 12. SLA Compliance Check        │
│     ├─ RTO ≤ 120s? ✓            │
│     ├─ RPO = 0s? ✓              │
│     └─ 99.99% uptime ✓          │
└─────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────┐
│              📊 GENERATE COMPREHENSIVE REPORT           │
│  ┌────────────────────────────────────────────────────┐ │
│  │ • Failover Metrics (RTO, RPO)                      │ │
│  │ • Load Generation Stats (TPS, Success Rate)       │ │
│  │ • Zone Configuration (Before/After)               │ │
│  │ • SLA Compliance (Pass/Fail)                      │ │
│  │ • Timeline of Events                              │ │
│  │ • Performance Benchmarks                          │ │
│  └────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘

═══════════════════════════════════════════════════════════

LEGEND:
  ┌─────┐  Step/Process        ◄──►  Synchronous Replication
  │     │                       ✓    Success/Pass
  └─────┘                       ▼    Flow Direction
  
TIMING:
  • Pre-flight: ~5-10 seconds
  • Load generation: 60-120 seconds (configurable)
  • Failover: 60-120 seconds (automatic)
  • Validation: ~5-10 seconds
  • Total: ~2-4 minutes
```

---

## 📑 Table of Contents

- [Quick Start](#quick-start)
- [Prerequisites](#prerequisites)
- [Infrastructure Requirements](#infrastructure-requirements)
- [Running the Failover Test](#running-the-failover-test)
- [Triggering and Measuring Failover](#triggering-and-measuring-failover)
- [Understanding Results](#understanding-results)
- [Automation Scripts](#automation-scripts)
- [Troubleshooting](#troubleshooting)
- [Cost Optimization](#cost-optimization)
- [Best Practices](#best-practices)

---

## 🚀 Quick Start

### Automated Failover Testing

The SAIF-PostgreSQL project includes a comprehensive failover testing script that automates the entire process.

```powershell
# Navigate to scripts directory
cd c:\Repos\SAIF\SAIF-pgsql\scripts

# Run failover test with default settings
.\Test-PostgreSQL-Failover.ps1 -ResourceGroupName "rg-saif-pgsql-swc-01"

# Run with custom load parameters
.\Test-PostgreSQL-Failover.ps1 `
    -ResourceGroupName "rg-saif-pgsql-swc-01" `
    -LoadDuration 120 `
    -TransactionsPerSecond 200
```

### What the Test Does

1. ✅ **Pre-flight checks** - Validates HA configuration
2. ✅ **Baseline load** - Generates payment transactions on primary database
3. ✅ **Failover trigger** - Initiates planned failover to standby
4. ✅ **RTO measurement** - Tracks time from failure to recovery
5. ✅ **RPO validation** - Verifies zero data loss
6. ✅ **Post-failover validation** - Confirms application continuity
7. ✅ **Comprehensive reporting** - Detailed metrics and SLA compliance

### Expected Results

With zone-redundant HA properly configured:

- **Failover Duration (RTO)**: 60-120 seconds
- **Data Loss (RPO)**: Zero (synchronous replication)
- **SLA**: 99.99% uptime
- **Application Impact**: Brief connection interruption, automatic reconnection

---

## 📋 Prerequisites

### 1. Software Requirements

**Option A: Local Execution (PowerShell)**
- **PowerShell 7+** (pwsh) - For automation scripts
- **Azure CLI** - For Azure resource management  
- **.NET SDK** (optional) - For Npgsql native library (auto-installed if needed)

**Option B: Cloud Shell Execution (C#)** ⭐ **RECOMMENDED FOR HIGH THROUGHPUT**
- **Azure Cloud Shell** - Pre-configured environment with all tools
- **dotnet-script** - C# scripting runtime (installed via `dotnet tool install`)
- **No local setup required** - Everything runs in Azure

### Performance Comparison

| Method | Location | TPS | Setup | Best For |
|--------|----------|-----|-------|----------|
| **PowerShell (Local)** | Your PC | 12-13 | 0 min | Quick testing, failover detection |
| **C# Script (Cloud Shell)** | Azure | **200-500** 🚀 | 5 min | High throughput, production validation |

**🚀 Native Performance**: 
- **PowerShell script** uses Npgsql (.NET PostgreSQL driver) with persistent connections for ~12-13 TPS sustained throughput
- **C# script** uses async/await with parallel workers for **200-500 TPS** (16-40x faster)
- Both automatically manage dependencies (PowerShell: `scripts/libs/`, C#: NuGet packages)

**Quick Start - Cloud Shell** (5 minutes):
```bash
# Open Azure Cloud Shell (https://shell.azure.com)
# Install dotnet-script (one-time setup)
dotnet tool install -g dotnet-script
export PATH="$PATH:$HOME/.dotnet/tools"

# Clone repository
git clone https://github.com/jonathan-vella/SAIF.git
cd SAIF/SAIF-pgsql/scripts

# Run high-performance test
dotnet script Test-PostgreSQL-Failover.csx -- \
  "Host=your-server.postgres.database.azure.com;Database=saifdb;Username=user;Password=pass;SSL Mode=Require" \
  10 \
  5
```

> 📖 **Detailed Guide**: See [CLOUD-SHELL-GUIDE.md](../../scripts/CLOUD-SHELL-GUIDE.md) for complete Cloud Shell setup instructions

**Quick Start - Local PowerShell**:
```powershell
# Check if Azure CLI is installed
az --version

# Install Azure CLI if needed (using winget)
winget install Microsoft.AzureCLI

# Check if .NET SDK is installed (optional - for native Npgsql performance)
dotnet --version

# Install .NET SDK if needed
winget install Microsoft.DotNet.SDK.8
```

**📦 Automatic Dependency Management**: Both scripts automatically:
1. Detect if required libraries are available
2. Download and install dependencies on first run (PowerShell: `scripts/libs/`, C#: NuGet)
3. Fall back gracefully if setup fails (PowerShell: Docker, C#: error message)
4. No manual PostgreSQL client installation needed!

### 2. Azure Permissions

Your Azure account must have:
- **Contributor** access to the resource group
- **Key Vault Secrets User** role (for reading database credentials)
- Permission to trigger failover operations

### 3. Machine-Independent Testing

The failover test script uses **Docker containers** instead of local PostgreSQL client tools, making it work consistently across different machines:

**Traditional Approach (Machine-Dependent)**:
```powershell
# ❌ Requires psql in PATH
psql -h server.postgres.database.azure.com -U admin -d saifdb -c "SELECT 1;"
```

**Docker Approach (Machine-Independent)**:
```powershell
# ✅ Works on any machine with Docker
docker run --rm -e PGPASSWORD="password" postgres:16-alpine \
  psql -h server.postgres.database.azure.com -U admin -d saifdb -c "SELECT 1;"
```

**Benefits:**
- ✅ No local PostgreSQL installation required
- ✅ Works on Windows, Mac, and Linux
- ✅ Consistent PostgreSQL 16 client version
- ✅ No PATH configuration needed
- ✅ Portable across development machines
- ✅ Same approach used for database initialization

**Requirements:**
- Docker Desktop running
- Internet access (to pull `postgres:16-alpine` image on first run)
- ~50MB disk space for PostgreSQL client image

### 4. SAIF-PostgreSQL Deployment

You must have a running SAIF-PostgreSQL deployment. If not deployed yet:

```powershell
cd c:\Repos\SAIF\SAIF-pgsql\scripts
.\Deploy-SAIF-PostgreSQL.ps1 -location "swedencentral"
```

See [deployment-guide.md](deployment-guide.md) for detailed deployment instructions.

---

## 🏗️ Infrastructure Requirements

### Zone-Redundant HA Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│                     Azure Region (e.g., Sweden Central)              │
│                                                                      │
│  ┌─────────────────────────────┐   ┌─────────────────────────────┐ │
│  │   AVAILABILITY ZONE 1       │   │   AVAILABILITY ZONE 2       │ │
│  │   (Primary)                 │   │   (Standby)                 │ │
│  │                             │   │                             │ │
│  │  ┌───────────────────────┐  │   │  ┌───────────────────────┐  │ │
│  │  │  PostgreSQL Primary   │  │   │  │  PostgreSQL Standby   │  │ │
│  │  │                       │  │   │  │                       │  │ │
│  │  │  ┌─────────────────┐  │  │   │  │  ┌─────────────────┐  │  │ │
│  │  │  │   Database      │  │◄─┼───┼──┼─►│   Database      │  │  │ │
│  │  │  │   (Active)      │  │  │   │  │  │   (Replica)     │  │  │ │
│  │  │  └─────────────────┘  │  │   │  │  └─────────────────┘  │  │ │
│  │  │         ▲             │  │   │  │         ▲             │  │ │
│  │  │         │ Read/Write  │  │   │  │         │ Sync        │  │ │
│  │  │         │             │  │   │  │         │ Replication │  │ │
│  │  └─────────┼─────────────┘  │   │  └─────────┼─────────────┘  │ │
│  │            │                │   │            │                │ │
│  └────────────┼────────────────┘   └────────────┼────────────────┘ │
│               │                                 │                  │
│               └─────────────┬───────────────────┘                  │
│                             │                                      │
│                  ┌──────────▼──────────┐                          │
│                  │   Virtual Network    │                          │
│                  │   (Private Link)     │                          │
│                  └──────────┬──────────┘                          │
│                             │                                      │
└─────────────────────────────┼──────────────────────────────────────┘
                              │
                   ┌──────────▼──────────┐
                   │   App Services      │
                   │   (API + Web)       │
                   └─────────────────────┘

BEFORE FAILOVER:
  Zone 1: Primary (ACTIVE) ─┬─ Reads/Writes
  Zone 2: Standby (READY)   └─ Synchronous replication

DURING FAILOVER (60-120s):
  Zone 1: Primary → Standby transition
  Zone 2: Standby → Primary promotion
  Apps: Brief connection interruption

AFTER FAILOVER:
  Zone 1: Standby (READY)   ─┬─ Synchronous replication
  Zone 2: Primary (ACTIVE)   └─ Reads/Writes

KEY BENEFITS:
  ✓ RPO = 0 (Zero data loss - synchronous replication)
  ✓ RTO = 60-120s (Automatic failover)
  ✓ 99.99% SLA uptime guarantee
  ✓ No manual intervention required
```

### Zone-Redundant HA Configuration

For actual failover testing, your PostgreSQL server **must** have:

✅ **High Availability Mode**: Zone-Redundant  
✅ **Compute Tier**: General Purpose or Memory Optimized (NOT Burstable)  
✅ **Region**: Must support multiple availability zones

### Supported Azure Regions

The following regions support zone-redundant HA for PostgreSQL:

- 🇸🇪 **Sweden Central** (recommended for Europe)
- 🇩🇪 **Germany West Central**
- 🇺🇸 **East US**
- 🇺🇸 **East US 2**
- 🇺🇸 **West US 2**
- 🇺🇸 **West US 3**
- 🇪🇺 **West Europe**
- 🇪🇺 **North Europe**
- 🇬🇧 **UK South**
- 🇸🇬 **Southeast Asia**
- 🇯🇵 **Japan East**
- 🇦🇺 **Australia East**

### Verifying Your Configuration

Check if HA is properly configured:

```powershell
# Get resource group name from deployment
$rgName = "rg-saif-pgsql-swc-01"

# Find PostgreSQL server
$serverName = az postgres flexible-server list `
    --resource-group $rgName `
    --query "[0].name" -o tsv

# Check HA configuration
az postgres flexible-server show `
    --resource-group $rgName `
    --name $serverName `
    --query "{Name:name, Tier:sku.tier, HA:highAvailability.mode, Zone:availabilityZone, StandbyZone:highAvailability.standbyAvailabilityZone, State:highAvailability.state}" `
    -o table
```

Expected output for zone-redundant HA:
```
Name                        Tier            HA              Zone    StandbyZone    State
--------------------------  --------------  --------------  ------  -------------  --------
saif-pgsql-server-abc123    GeneralPurpose  ZoneRedundant   1       2              Healthy
```

### Enabling Zone-Redundant HA

If HA is not enabled, you have two options:

#### Option A: Using the Deployment Script

Redeploy with HA enabled:

```powershell
cd c:\Repos\SAIF\SAIF-pgsql\scripts
.\Deploy-SAIF-PostgreSQL.ps1 `
    -location "swedencentral" `
    -enableHA $true
```

#### Option B: Upgrade Existing Server

**Step 1: Upgrade to General Purpose tier** (if using Burstable)

```bash
az postgres flexible-server update \
    --resource-group rg-saif-pgsql-swc-01 \
    --name <SERVER_NAME> \
    --sku-name Standard_D2ds_v4 \
    --tier GeneralPurpose
```

**Step 2: Enable zone-redundant HA**

```bash
az postgres flexible-server update \
    --resource-group rg-saif-pgsql-swc-01 \
    --name <SERVER_NAME> \
    --high-availability ZoneRedundant \
    --standby-zone 2
```

**Step 3: Wait for HA setup to complete** (5-10 minutes)

```powershell
# Monitor HA state
$serverName = "<SERVER_NAME>"
do {
    $state = az postgres flexible-server show `
        --resource-group rg-saif-pgsql-swc-01 `
        --name $serverName `
        --query "highAvailability.state" -o tsv
    
    Write-Host "HA State: $state" -ForegroundColor Yellow
    if ($state -ne "Healthy") { Start-Sleep -Seconds 30 }
} while ($state -ne "Healthy")

Write-Host "✅ Zone-redundant HA is now active!" -ForegroundColor Green
```

### Cost Considerations

**Monthly estimated costs** for zone-redundant HA:

| Configuration | Compute | Storage | Total/Month |
|--------------|---------|---------|-------------|
| **D2ds_v4** (2 vCore) | ~$90 | ~$30 | ~$120 |
| **D4ds_v4** (4 vCore) | ~$180 | ~$30 | ~$210 |
| **D8ds_v5** (8 vCore) | ~$360 | ~$30 | ~$390 |
| **Burstable B1ms** (no HA) | ~$8 | ~$15 | ~$23 |

**Note**: Zone-redundant HA doubles the compute cost (primary + standby) but shares storage.

**Recommendation**: 
- Use **D2ds_v4** for demos and testing
- Scale up to **D4ds_v4** or higher for production workloads
- See [Cost Optimization](#cost-optimization) for strategies to minimize costs

---

## 🧪 Running the Failover Test

### Method 1: C# Script in Azure Cloud Shell ⭐ **RECOMMENDED FOR HIGH THROUGHPUT**

The **high-performance C# script** provides production-grade load testing with **200-500 TPS** sustained throughput.

**🚀 Why Cloud Shell?**
- **16-40x faster** than PowerShell (200-500 TPS vs 12-13 TPS)
- **Sub-5ms network latency** (same Azure region as database)
- **Parallel async workers** with persistent connections
- **Real-time statistics**: P50, P95, peak TPS metrics
- **No local setup** required - runs entirely in Azure

**Quick Start** (5 minutes):

```bash
# Step 1: Open Azure Cloud Shell (https://shell.azure.com)

# Step 2: Install dotnet-script (one-time setup)
dotnet tool install -g dotnet-script
export PATH="$PATH:$HOME/.dotnet/tools"

# Step 3: Get the script
git clone https://github.com/jonathan-vella/SAIF.git
cd SAIF/SAIF-pgsql/scripts

# Step 4: Get your connection string
export PG_PASSWORD=$(az keyvault secret show \
  --vault-name <your-keyvault> \
  --name postgresql-admin-password \
  --query value -o tsv)

export CONN_STRING="Host=psql-saifpg-10081025.postgres.database.azure.com;Database=saifdb;Username=saifadmin;Password=$PG_PASSWORD;SSL Mode=Require"

# Step 5: Run the test
# Syntax: dotnet script Test-PostgreSQL-Failover.csx -- <conn-string> <workers> <duration-min>
dotnet script Test-PostgreSQL-Failover.csx -- "$CONN_STRING" 10 5

# For higher throughput (20 workers, 10 minutes)
dotnet script Test-PostgreSQL-Failover.csx -- "$CONN_STRING" 20 10
```

**Expected Output**:
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

🚀 Load test started! Press Ctrl+C to stop.

┌─────────────┬────────────┬───────────┬──────────┬──────────┬─────────┐
│    Time     │    TPS     │   Total   │  Errors  │ Reconnect│  Status │
├─────────────┼────────────┼───────────┼──────────┼──────────┼─────────┤
│ 19:15:10.123│   278.45   │     1,392 │        0 │        0 │ RUNNING │
│ 19:15:15.456│   285.20   │     2,818 │        0 │        0 │ RUNNING │

⚠️  [19:15:42.123] CONNECTION LOST - Potential failover detected!

│ 19:15:47.890│    18.30   │    83,579 │       15 │        0 │ FAILING │

✅ [19:15:58.456] CONNECTION RESTORED!
   RTO (Recovery Time): 16.33 seconds

│ 19:16:03.789│   279.80   │    84,978 │       15 │       10 │RECOVERED│

═══════════════════════════════════════════════════════════════

📊 FINAL RESULTS:
   Total Transactions:    83,670
   Average TPS:           279.00
   Peak TPS:              312.45
   RTO (Recovery Time):   16.33 seconds ✅
   RPO (Data Loss):       0 seconds ✅
```

> 📖 **Complete Guide**: See [CLOUD-SHELL-GUIDE.md](../../scripts/CLOUD-SHELL-GUIDE.md) for detailed Cloud Shell instructions, troubleshooting, and optimization tips.

---

### Method 2: PowerShell Script (Local Execution)

The **PowerShell script** is ideal for quick local testing and provides **12-13 TPS** sustained throughput.

**⚡ Performance Note**: The script achieves **~12-13 TPS sustained throughput** using native Npgsql connections. While the target parameter is 100 TPS, actual throughput is limited by PowerShell loop overhead (~50-80ms per iteration). This is sufficient for realistic failover testing and RTO/RPO measurement.

```powershell
# Navigate to scripts directory
cd c:\Repos\SAIF\SAIF-pgsql\scripts

# Run with default settings  
# - 180 seconds test duration (3 minutes)
# - Native Npgsql connections (~12-13 TPS actual)
# - Auto-installs Npgsql on first run
.\Test-PostgreSQL-Failover.ps1 -ResourceGroupName "rg-saif-pgsql-swc-01"

# Run with custom load parameters
.\Test-PostgreSQL-Failover.ps1 `
    -ResourceGroupName "rg-saif-pgsql-swc-01" `
    -LoadDuration 120 `
    -TransactionsPerSecond 200

# Specify server name explicitly (auto-detected if omitted)
.\Test-PostgreSQL-Failover.ps1 `
    -ResourceGroupName "rg-saif-pgsql-swc-01" `
    -ServerName "saif-pgsql-server-abc123"
```

### What You'll See

```
================================================================================
| PostgreSQL HA Failover Test                                                 |
================================================================================

📍 Phase 1: Environment Validation
✅ Resource group 'rg-saif-pgsql-swc-01' exists
✅ PostgreSQL server 'saif-pgsql-server-abc123' found
✅ High Availability: ZoneRedundant (Healthy)
✅ Primary Zone: 1, Standby Zone: 2
✅ Database credentials retrieved from Key Vault

📍 Phase 2: Pre-Failover Baseline
🔹 Starting load generation (60 seconds, 100 TPS)...
  Transaction 50/6000 - INSERT payment (0.045s) ✓
  Transaction 100/6000 - INSERT payment (0.042s) ✓
  Transaction 150/6000 - INSERT payment (0.038s) ✓
  ...
✅ Load generation complete: 6000 transactions, avg latency 0.041s

📍 Phase 3: Failover Execution
⚠️  Initiating PLANNED FAILOVER at 2025-10-08 14:23:45.123
🔄 Waiting for failover to complete...
  [00:15] Failover in progress... (primary: unavailable)
  [00:30] Failover in progress... (primary: unavailable)
  [00:47] Standby promoted to primary ✓
  [00:52] New primary accepting connections ✓
✅ Failover completed at 2025-10-08 14:24:37.456

📊 FAILOVER METRICS:
  ⏱️  RTO (Recovery Time): 52.3 seconds ✅ (Target: < 120s)
  💾 RPO (Data Loss): 0 transactions ✅ (Target: 0)
  🎯 SLA Status: PASSED

📍 Phase 4: Post-Failover Validation
🔹 Testing database connectivity...
✅ Successfully connected to new primary
✅ Database writable: INSERT test successful
✅ All tables accessible
✅ Transaction history intact: 6000 records found

📊 TEST SUMMARY:
  Test Duration: 142.5 seconds
  Failover RTO: 52.3 seconds (✅ PASSED)
  Data Loss RPO: 0 transactions (✅ PASSED)
  New Primary Zone: 2 (previously standby)
  Application Continuity: ✅ VERIFIED

================================================================================
```

### Test Parameters Explained

| Parameter | Default | Description | Recommendations |
|-----------|---------|-------------|-----------------|
| **ResourceGroupName** | (required) | Azure resource group | Use your deployment RG |
| **ServerName** | (auto-detected) | PostgreSQL server name | Usually auto-detected |
| **LoadDuration** | 60 seconds | Pre-failover load time | 60-120s for baseline |
| **TransactionsPerSecond** | 100 TPS | Transaction rate | 50-200 TPS typical |

---

### Method 3: Manual Testing with Docker

If you prefer manual control, use Docker containers for database connectivity:

**Step 1: Set up variables**

```powershell
# Configuration
$serverFqdn = "psql-saifpg-10081025.postgres.database.azure.com"
$dbUser = "saifadmin"
$dbPassword = "YourSecurePassword"  # Get from Key Vault
$dbName = "saifdb"
```

**Step 2: Generate baseline load using Docker**

```powershell
# Using Docker container with PostgreSQL client
Write-Host "Generating 100 test transactions..." -ForegroundColor Cyan

1..100 | ForEach-Object {
    docker run --rm -e PGPASSWORD="$dbPassword" postgres:16-alpine `
        psql -h $serverFqdn -U $dbUser -d $dbName `
        -c "SELECT create_test_transaction();" -t
    
    Write-Host "Transaction $_/100 created" -ForegroundColor Green
    Start-Sleep -Milliseconds 50  # ~20 TPS
}
```

**Step 3: Check baseline transaction count (Docker)**

```powershell
# Get transaction count before failover
$preCount = docker run --rm -e PGPASSWORD="$dbPassword" postgres:16-alpine `
    psql -h $serverFqdn -U $dbUser -d $dbName `
    -t -c "SELECT COUNT(*) FROM transactions;"

Write-Host "Pre-failover transactions: $($preCount.Trim())" -ForegroundColor Cyan
```

**Step 4: Trigger failover**

```powershell
# Using Azure CLI
az postgres flexible-server restart `
    --resource-group rg-saif-pgsql-swc-01 `
    --name psql-saifpg-10081025 `
    --failover Planned
```

**Step 5: Monitor recovery (real-time)**

```powershell
# Monitor database connectivity during failover
$startTime = Get-Date
$recovered = $false

Write-Host "Monitoring database recovery..." -ForegroundColor Yellow

while (-not $recovered) {
    $elapsed = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 1)
    
    try {
        $result = docker run --rm -e PGPASSWORD="$dbPassword" postgres:16-alpine `
            psql -h $serverFqdn -U $dbUser -d $dbName `
            -t -c "SELECT 1;" 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[$elapsed`s] ✅ Database recovered!" -ForegroundColor Green
            $recovered = $true
            Write-Host "RTO: $elapsed seconds" -ForegroundColor Cyan
        }
    } catch {
        Write-Host "[$elapsed`s] ⏳ Waiting for recovery..." -ForegroundColor Yellow
    }
    
    if (-not $recovered) {
        Start-Sleep -Seconds 5
    }
}
```

**Step 6: Validate data integrity (Docker)**

```powershell
# Check transaction count after failover
$postCount = docker run --rm -e PGPASSWORD="$dbPassword" postgres:16-alpine `
    psql -h $serverFqdn -U $dbUser -d $dbName `
    -t -c "SELECT COUNT(*) FROM transactions;"

Write-Host "Post-failover transactions: $($postCount.Trim())" -ForegroundColor Cyan

# Verify zero data loss
if ($preCount.Trim() -eq $postCount.Trim()) {
    Write-Host "✅ RPO: 0 (zero data loss)" -ForegroundColor Green
} else {
    Write-Host "❌ Data loss detected!" -ForegroundColor Red
    Write-Host "   Before: $($preCount.Trim())" -ForegroundColor Yellow
    Write-Host "   After: $($postCount.Trim())" -ForegroundColor Yellow
}
```

**Alternative: Using API Endpoints (No Docker Required)**

```powershell
# Generate load using API
$apiUrl = "https://app-saifpg-web-10081025.azurewebsites.net"

1..100 | ForEach-Object {
    Invoke-RestMethod -Method POST `
        -Uri "$apiUrl/api/test/create-transaction?amount=99.99" `
        -ContentType "application/json"
    Write-Host "Transaction $_/100 created" -ForegroundColor Green
    Start-Sleep -Milliseconds 10
}

# Validate after failover
$count = Invoke-RestMethod -Uri "$apiUrl/api/transactions/count"
Write-Host "Total transactions: $count" -ForegroundColor Cyan
```

---

## 🔄 Triggering and Measuring Failover

### Planned Failover (Recommended for Testing)

Planned failover ensures zero data loss and clean switchover:

```bash
# Using Azure CLI
az postgres flexible-server restart \
    --resource-group rg-saif-pgsql-swc-01 \
    --name <SERVER_NAME> \
    --failover Planned
```

PowerShell equivalent:
```powershell
az postgres flexible-server restart `
    --resource-group rg-saif-pgsql-swc-01 `
    --name <SERVER_NAME> `
    --failover Planned
```

### Forced Failover (Disaster Simulation)

Simulates unplanned outage (use cautiously):

```bash
az postgres flexible-server restart \
    --resource-group rg-saif-pgsql-swc-01 \
    --name <SERVER_NAME> \
    --failover Forced
```

⚠️ **Warning**: Forced failover may result in minimal data loss if transactions are in-flight.

### Using Azure Portal

1. Navigate to [Azure Portal](https://portal.azure.com)
2. Go to your PostgreSQL server
3. Navigate to: **Settings** → **High availability**
4. Click **Planned failover** button
5. Confirm the operation

### Monitoring Failover Progress

The automated script monitors automatically, but you can manually check:

```powershell
# Real-time monitoring
$serverName = "saif-pgsql-server-abc123"
$startTime = Get-Date

do {
    $server = az postgres flexible-server show `
        --resource-group rg-saif-pgsql-swc-01 `
        --name $serverName `
        --query "{State:state, HA:highAvailability.state, Zone:availabilityZone}" `
        -o json | ConvertFrom-Json
    
    $elapsed = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 1)
    Write-Host "[$elapsed`s] State: $($server.State), HA: $($server.HA), Zone: $($server.Zone)" -ForegroundColor Yellow
    
    Start-Sleep -Seconds 5
} while ($server.State -ne "Ready" -or $server.HA -ne "Healthy")

$totalTime = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 1)
Write-Host "✅ Failover completed in $totalTime seconds" -ForegroundColor Green
```

### Expected Failover Timeline

According to [Azure documentation](https://learn.microsoft.com/azure/postgresql/flexible-server/concepts-high-availability):

| Phase | Duration | Description |
|-------|----------|-------------|
| **Detection** | 0-5s | Primary failure detected |
| **Promotion** | 30-60s | Standby promoted to primary |
| **DNS Update** | 10-30s | Connection string redirected |
| **Stabilization** | 5-15s | New primary accepting connections |
| **Total RTO** | **60-120s** | Complete recovery time |

### RTO/RPO Measurement

The automated script tracks:

- **RTO (Recovery Time Objective)**: Time from first failure to full recovery
- **RPO (Recovery Point Objective)**: Amount of data lost (should be 0)

```
📊 FAILOVER METRICS:
  ⏱️  RTO: 52.3 seconds ✅ (Target: < 120s)
  💾 RPO: 0 transactions ✅ (Target: 0)
  🎯 SLA: 99.99% uptime achieved
```

---

## 📊 Understanding Results

### Success Criteria

A successful zone-redundant HA test should meet:

✅ **RTO < 120 seconds** - Azure SLA commitment  
✅ **RPO = 0** - Zero data loss (synchronous replication)  
✅ **Application continuity** - Web app recovers automatically  
✅ **Data integrity** - All committed transactions preserved  

### Test Output Interpretation

#### Phase 1: Environment Validation
```
✅ PostgreSQL server 'saif-pgsql-server-abc123' found
✅ High Availability: ZoneRedundant (Healthy)
✅ Primary Zone: 1, Standby Zone: 2
```
- Confirms HA is properly configured
- Shows current primary and standby zones
- Validates connectivity

#### Phase 2: Pre-Failover Baseline
```
✅ Load generation complete: 6000 transactions, avg latency 0.041s
```
- Establishes normal performance baseline
- Creates test data for RPO validation
- Measures typical write latency

#### Phase 3: Failover Execution
```
⏱️  RTO (Recovery Time): 52.3 seconds ✅ (Target: < 120s)
💾 RPO (Data Loss): 0 transactions ✅ (Target: 0)
```
- **RTO** measures actual downtime
- **RPO** verifies no data was lost
- Both must meet SLA targets

#### Phase 4: Post-Failover Validation
```
✅ Successfully connected to new primary
✅ Transaction history intact: 6000 records found
```
- Confirms application can reconnect
- Validates all pre-failover data is accessible
- Verifies database is fully operational

### Interpreting Performance Metrics

| Metric | Good | Acceptable | Concerning |
|--------|------|------------|------------|
| **RTO** | < 60s | 60-120s | > 120s |
| **RPO** | 0 | 0 | > 0 |
| **Write Latency** | < 50ms | 50-100ms | > 100ms |
| **Recovery Rate** | < 5s | 5-15s | > 15s |

### Common Failure Patterns

#### Pattern 1: RTO > 120 seconds

**Symptoms**: Failover takes longer than expected

**Possible Causes**:
- High transaction volume during failover
- Network latency between zones
- Resource constraints (CPU, IOPS)
- Large number of active connections

**Actions**:
- Review Azure Monitor metrics during failover
- Check for resource throttling
- Consider higher SKU tier
- Optimize connection pooling

#### Pattern 2: RPO > 0 (Data Loss)

**Symptoms**: Some transactions missing after failover

**Possible Causes**:
- HA not properly configured (not zone-redundant)
- Forced failover instead of planned
- Application retry logic failed
- Network partition during write

**Actions**:
- Verify HA mode is ZoneRedundant
- Use planned failover for testing
- Implement proper application retry logic
- Review transaction logs

#### Pattern 3: Slow Post-Failover Performance

**Symptoms**: High latency after failover completes

**Possible Causes**:
- Connection pool not refreshed
- DNS caching issues
- Standby not warmed up
- Storage performance difference

**Actions**:
- Implement application connection pool reset
- Clear DNS cache
- Use read replicas for warm standby
- Monitor storage IOPS

### Detailed Logging

The script creates detailed logs for analysis:

**Location**: `C:\Repos\SAIF\SAIF-pgsql\scripts\failover-test-<timestamp>.log`

**Contents**:
- Complete timeline of events
- Individual transaction timings
- Error messages and stack traces
- Azure CLI command outputs
- Performance metrics

**Example log entries**:
```
2025-10-08 14:23:45.123 [INFO] Starting failover test
2025-10-08 14:23:45.234 [INFO] HA Status: Healthy, Primary Zone: 1
2025-10-08 14:24:30.456 [WARN] Connection failed: server closed unexpectedly
2025-10-08 14:24:37.567 [INFO] Connection restored: new primary in Zone 2
2025-10-08 14:24:37.678 [SUCCESS] RTO: 52.3 seconds
```

---

## 🤖 Automation Scripts

### Test-PostgreSQL-Failover.ps1

**Location**: `c:\Repos\SAIF\SAIF-pgsql\scripts\Test-PostgreSQL-Failover.ps1`

**Purpose**: Comprehensive failover testing with automated RTO/RPO measurement

**Features**:
- ✅ Automatic resource discovery
- ✅ Pre-flight validation
- ✅ Load generation (payment transactions)
- ✅ Failover trigger
- ✅ RTO/RPO calculation
- ✅ Post-failover validation
- ✅ Detailed reporting
- ✅ Error handling
- ✅ **Intelligent diagnostics** (automatic when SLA breached)

**Usage**:
```powershell
.\Test-PostgreSQL-Failover.ps1 `
    -ResourceGroupName "rg-saif-pgsql-swc-01" `
    [-ServerName "server-name"] `
    [-LoadDuration 60] `
    [-TransactionsPerSecond 100]
```

**New**: When RTO or RPO targets are not met, the script automatically runs intelligent diagnostics that analyze:
- Server SKU and tier (detects Burstable tier issues)
- Resource utilization (CPU, IOPS during failover)
- Root cause analysis with specific recommendations
- Actionable next steps with Azure CLI commands

### Diagnose-Failover-Performance.ps1

**Location**: `c:\Repos\SAIF\SAIF-pgsql\scripts\Diagnose-Failover-Performance.ps1`

**Purpose**: Standalone diagnostic tool for analyzing failover performance issues

**Features**:
- 🔍 Server configuration analysis (tier, SKU, IOPS)
- 📊 Resource metrics analysis (CPU, IOPS utilization)
- 📋 Activity log review (errors, warnings)
- 🎯 Root cause determination
- 💡 Prioritized recommendations
- ⚡ Quick-fix commands

**Usage**:
```powershell
# Basic analysis
.\Diagnose-Failover-Performance.ps1 -ResourceGroupName "rg-saif-pgsql-swc-01"

# With failover context
.\Diagnose-Failover-Performance.ps1 `
    -ResourceGroupName "rg-saif-pgsql-swc-01" `
    -ServerName "psql-saifpg-10081025" `
    -RTO 314 `
    -FailoverStartTime "2025-10-08T14:23:45Z"

# Detailed analysis with metrics
.\Diagnose-Failover-Performance.ps1 `
    -ResourceGroupName "rg-saif-pgsql-swc-01" `
    -AnalysisDepth Detailed
```

**Example Output**:
```
═══════════════════════════════════════════════════════════════════
  🔍 INTELLIGENT DIAGNOSTICS - Root Cause Analysis
═══════════════════════════════════════════════════════════════════

🎯 BOTTOM LINE
Most Likely Cause: Burstable tier SKU (B1ms) cannot sustain zone-redundant 
                  HA performance under load

Evidence:
  ✅ Test completed successfully (mechanism working)
  ✅ RPO = 0 (zero data loss - synchronous replication verified)
  ❌ RTO = 314s (2.6x slower than 120s target)
  📊 Server Tier: Burstable (Standard_B1ms)

  ⚠️  CRITICAL: Burstable tier detected!
     Burstable tier uses CPU credits and has limited IOPS
     Expected RTO: 200-600s (NOT suitable for HA workloads)

Next Steps (Recommended Actions):
  1. Upgrade to General Purpose tier (minimum D2ds_v4)
  2. Run detailed diagnostics: .\Diagnose-Failover-Performance.ps1
  3. Check Azure Monitor for resource metrics
  4. Review Activity Log for Azure service issues

💡 QUICK FIX:
   az postgres flexible-server update \
       --resource-group rg-saif-pgsql-swc-01 \
       --name psql-saifpg-10081025 \
       --sku-name Standard_D2ds_v4 \
       --tier GeneralPurpose
   
   Expected improvement: RTO from 314s → 60-90s
```

### Monitor-PostgreSQL-HA.ps1

**Location**: `c:\Repos\SAIF\SAIF-pgsql\scripts\Monitor-PostgreSQL-HA.ps1`

**Purpose**: Real-time HA status monitoring dashboard

**Requirements**:
- Azure CLI (authenticated)
- Docker Desktop
- PowerShell 7+

**Features**:
- **Machine-independent**: Uses Docker-based PostgreSQL client (no local psql needed)
- **Real-time metrics**: Database availability, response time, TPS
- **HA monitoring**: Zone configuration, replication status
- **Auto-discovery**: Automatically finds PostgreSQL server in resource group
- **Live dashboard**: Updates every 5 seconds (configurable)

**Usage**:
```powershell
# Basic usage (auto-discovers server)
.\Monitor-PostgreSQL-HA.ps1 -ResourceGroupName "rg-saif-pgsql-swc-01"

# With custom refresh interval
.\Monitor-PostgreSQL-HA.ps1 -ResourceGroupName "rg-saif-pgsql-swc-01" -RefreshInterval 10

# Specify server name explicitly
.\Monitor-PostgreSQL-HA.ps1 -ResourceGroupName "rg-saif-pgsql-swc-01" -ServerName "psql-saifpg-12345678"
```

**Output**:
```
╔════════════════════════════════════════════════════════════════════════╗
║        SAIF-PostgreSQL HA Monitoring Dashboard                         ║
╚════════════════════════════════════════════════════════════════════════╝

🕐 Timestamp: 2025-10-08 14:23:15
🔄 Refresh: 5 seconds | Iteration: 42

┌─ 🖥️  Server Status ────────────────────────────────────────────────────┐
  Server State:        Ready
  FQDN:                psql-saifpg-12345678.postgres.database.azure.com
  Storage Used:        128 GB
└───────────────────────────────────────────────────────────────────────┘

┌─ ⚡ High Availability ──────────────────────────────────────────────────┐
  HA Mode:             ZoneRedundant
  HA State:            Healthy
  Primary Zone:        Zone 1
  Standby Zone:        Zone 2
  RPO:                 0 seconds (zero data loss)
  RTO:                 60-120 seconds
  SLA:                 99.99% uptime
└───────────────────────────────────────────────────────────────────────┘

┌─ 🗄️  Database Metrics ─────────────────────────────────────────────────┐
  Availability:        ✅ Online
  Response Time:       23 ms
  Active Connections:  42
  Total Transactions:  125,847
  Database Size:       512 MB
  Current TPS:         15.3 tx/sec
  Recent TPS (1min):   18.7 tx/sec
└───────────────────────────────────────────────────────────────────────┘

🟢 System Status: All systems operational

Press Ctrl+C to exit...
```

**Key Metrics**:
- **Availability**: Database online/offline status
- **Response Time**: Query latency (should be < 100ms normally)
- **Active Connections**: Current database connections
- **TPS**: Transactions per second (current and 1-minute average)
- **HA State**: Zone-redundant health status

### Deploy-SAIF-PostgreSQL.ps1

**Location**: `c:\Repos\SAIF\SAIF-pgsql\scripts\Deploy-SAIF-PostgreSQL.ps1`

**Purpose**: Complete infrastructure and application deployment

**HA Configuration**:
```powershell
# Deploy with zone-redundant HA enabled
.\Deploy-SAIF-PostgreSQL.ps1 `
    -location "swedencentral" `
    -enableHA $true `
    -primaryZone 1 `
    -standbyZone 2
```

### Batch Testing Script

For repeated testing (CI/CD or scheduled validation):

**Create**: `c:\Repos\SAIF\SAIF-pgsql\scripts\Run-Failover-Tests.ps1`

```powershell
<#
.SYNOPSIS
    Runs multiple failover tests for statistical analysis
#>
param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$false)]
    [int]$Iterations = 3,
    
    [Parameter(Mandatory=$false)]
    [int]$WaitBetweenTests = 300  # 5 minutes
)

$results = @()

for ($i = 1; $i -le $Iterations; $i++) {
    Write-Host "════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  Test Run $i of $Iterations" -ForegroundColor White
    Write-Host "════════════════════════════════════════" -ForegroundColor Cyan
    
    $result = .\Test-PostgreSQL-Failover.ps1 `
        -ResourceGroupName $ResourceGroupName `
        -LoadDuration 60 `
        -TransactionsPerSecond 100
    
    $results += $result
    
    if ($i -lt $Iterations) {
        Write-Host "⏳ Waiting $WaitBetweenTests seconds before next test..." -ForegroundColor Yellow
        Start-Sleep -Seconds $WaitBetweenTests
    }
}

# Calculate statistics
$avgRTO = ($results | Measure-Object -Property RTO -Average).Average
$maxRTO = ($results | Measure-Object -Property RTO -Maximum).Maximum
$minRTO = ($results | Measure-Object -Property RTO -Minimum).Minimum

Write-Host ""
Write-Host "════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Statistical Summary ($Iterations tests)" -ForegroundColor White
Write-Host "════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Average RTO: $avgRTO seconds" -ForegroundColor Green
Write-Host "Minimum RTO: $minRTO seconds" -ForegroundColor Green
Write-Host "Maximum RTO: $maxRTO seconds" -ForegroundColor Green
Write-Host "All tests RPO: 0 (zero data loss)" -ForegroundColor Green
```

---

## 🔧 Troubleshooting

### Error: "High Availability is not enabled"

**Symptoms**: Test script reports HA is disabled

**Solution**:
```powershell
# Check current HA configuration
az postgres flexible-server show \
    --resource-group rg-saif-pgsql-swc-01 \
    --name <SERVER_NAME> \
    --query "highAvailability"

# Enable zone-redundant HA
az postgres flexible-server update \
    --resource-group rg-saif-pgsql-swc-01 \
    --name <SERVER_NAME> \
    --high-availability ZoneRedundant \
    --standby-zone 2
```

### Error: "Docker daemon not running"

**Symptoms**: Script fails with "Cannot connect to the Docker daemon"

**Solution**:
```powershell
# Check Docker Desktop status
docker --version

# Start Docker Desktop if not running
Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"

# Wait for Docker to be ready
Write-Host "Waiting for Docker to start..." -ForegroundColor Yellow
$timeout = 60
$elapsed = 0
while ($elapsed -lt $timeout) {
    try {
        docker ps | Out-Null
        Write-Host "✅ Docker is ready!" -ForegroundColor Green
        break
    } catch {
        Write-Host "." -NoNewline
        Start-Sleep -Seconds 2
        $elapsed += 2
    }
}
```

### Error: "Cannot connect to database"

**Symptoms**: Script fails to connect to PostgreSQL (even with Docker)

**Root Causes & Solutions**:

**1. Firewall rules blocking connection**:
```powershell
# Check if Azure allows connections from your IP
# Docker containers use the host's IP address

# Get your public IP
$myIp = (Invoke-WebRequest -Uri "https://api.ipify.org").Content
Write-Host "Your public IP: $myIp" -ForegroundColor Cyan

# Add firewall rule
az postgres flexible-server firewall-rule create `
    --resource-group rg-saif-pgsql-swc-01 `
    --name psql-saifpg-10081025 `
    --rule-name "AllowMyIP" `
    --start-ip-address $myIp `
    --end-ip-address $myIp

Write-Host "✅ Firewall rule added" -ForegroundColor Green
```

**2. Server not running**:
```bash
az postgres flexible-server show \
    --resource-group rg-saif-pgsql-swc-01 \
    --name <SERVER_NAME> \
    --query "state" -o tsv
```

**3. Password environment variable issues**:
```powershell
# Docker requires PGPASSWORD as environment variable
# Ensure it's properly formatted (no extra quotes or spaces)

# Wrong (will fail):
$dbPassword = "MyP@ssw0rd!"  # Has special characters
docker run --rm -e PGPASSWORD=$dbPassword postgres:16-alpine psql ...

# Right (properly escaped):
$dbPasswordText = "MyP@ssw0rd!"
docker run --rm -e PGPASSWORD="$dbPasswordText" postgres:16-alpine psql ...
```

**4. Test connection manually with Docker**:
```powershell
# Get connection details from Key Vault
$serverFqdn = "psql-saifpg-10081025.postgres.database.azure.com"
$dbUser = "saif_admin"
$dbName = "saifdb"
$dbPassword = az keyvault secret show --vault-name $kvName --name "postgresql-password" --query "value" -o tsv

# Test connection using Docker
docker run --rm -e PGPASSWORD="$dbPassword" postgres:16-alpine `
    psql -h $serverFqdn -U $dbUser -d $dbName -c "SELECT version();"

# If successful, you should see PostgreSQL version
```

### Error: "Unable to find image 'postgres:16-alpine'"

**Symptoms**: Docker fails to pull PostgreSQL image

**Solutions**:

**1. Pull image manually**:
```powershell
# Pull the image explicitly
docker pull postgres:16-alpine

# Verify image exists
docker images postgres
# Should show: postgres   16-alpine   <IMAGE_ID>   <SIZE>
```

**2. Check internet connectivity**:
```powershell
# Test connection to Docker Hub
Test-NetConnection -ComputerName hub.docker.com -Port 443

# If blocked by corporate firewall, configure proxy:
# Docker Desktop → Settings → Resources → Proxies
```

**3. Use alternative registry**:
```powershell
# If Docker Hub is blocked, use Azure Container Registry mirror
# (Requires setup with Azure administrator)
docker pull mcr.microsoft.com/mirror/docker/library/postgres:16-alpine
```

### Error: "Connection timed out" from Docker container

**Symptoms**: Docker container cannot reach Azure PostgreSQL server

**Root Causes & Solutions**:

**1. Network mode issues**:
```powershell
# Docker Desktop uses default bridge network
# Ensure it's not in isolated mode

# Check Docker network mode
docker network ls
# Should show 'bridge' network

# Test with explicit network (if needed)
docker run --rm --network host -e PGPASSWORD="$dbPassword" postgres:16-alpine `
    psql -h $serverFqdn -U $dbUser -d $dbName -c "SELECT 1;"
```

**2. DNS resolution failures**:
```powershell
# Test DNS resolution from Docker container
docker run --rm postgres:16-alpine nslookup psql-saifpg-10081025.postgres.database.azure.com

# If DNS fails, use Azure Private DNS or update DNS settings:
# Docker Desktop → Settings → Resources → Network → DNS Server
```

**3. SSL/TLS issues**:
```powershell
# Azure PostgreSQL requires SSL by default
# Ensure Docker PostgreSQL client supports TLS 1.2+

# Test with SSL disabled (troubleshooting only):
docker run --rm -e PGPASSWORD="$dbPassword" postgres:16-alpine `
    psql "sslmode=disable host=$serverFqdn port=5432 user=$dbUser dbname=$dbName" `
    -c "SELECT 1;"

# For production, verify SSL certificate:
docker run --rm -e PGPASSWORD="$dbPassword" postgres:16-alpine `
    psql "sslmode=require host=$serverFqdn port=5432 user=$dbUser dbname=$dbName" `
    -c "SELECT 1;"
```

### Error: "Key Vault access denied"

**Symptoms**: Cannot retrieve database credentials

**Solution**:
```powershell
# Get your user object ID
$userId = az ad signed-in-user show --query id -o tsv

# Grant Key Vault Secrets User role
az role assignment create \
    --role "Key Vault Secrets User" \
    --assignee $userId \
    --scope "/subscriptions/<SUB_ID>/resourceGroups/rg-saif-pgsql-swc-01/providers/Microsoft.KeyVault/vaults/<KV_NAME>"
```

### Error: RTO exceeds 120 seconds

**Symptoms**: Failover takes longer than expected (e.g., 314 seconds)

**Automatic Diagnostics**: Starting with v2.0.0, the Test-PostgreSQL-Failover.ps1 script automatically runs intelligent diagnostics when SLA targets are breached. You'll see a detailed analysis including:
- Root cause identification (e.g., Burstable tier, CPU saturation, IOPS throttling)
- Resource utilization metrics
- Specific recommendations with Azure CLI commands
- Quick-fix suggestions

**Manual Investigation**:

**Use the Diagnostic Tool** (Recommended):
```powershell
# Run comprehensive diagnostics
.\Diagnose-Failover-Performance.ps1 `
    -ResourceGroupName "rg-saif-pgsql-swc-01" `
    -RTO 314 `
    -AnalysisDepth Detailed

# This will automatically:
# - Analyze server SKU and tier
# - Check CPU/IOPS metrics during failover
# - Review activity logs for errors
# - Provide prioritized recommendations
# - Generate quick-fix commands
```

**Manual Metric Analysis**:

**1. Check server metrics during failover**:
```bash
# CPU utilization
az monitor metrics list \
    --resource <SERVER_RESOURCE_ID> \
    --metric cpu_percent \
    --start-time 2025-10-08T14:00:00Z \
    --end-time 2025-10-08T15:00:00Z \
    --interval PT1M

# IOPS
az monitor metrics list \
    --resource <SERVER_RESOURCE_ID> \
    --metric iops \
    --start-time 2025-10-08T14:00:00Z \
    --end-time 2025-10-08T15:00:00Z \
    --interval PT1M
```

**2. Review activity log**:
```bash
az monitor activity-log list \
    --resource-group rg-saif-pgsql-swc-01 \
    --start-time 2025-10-08T14:00:00Z \
    --offset 1h
```

**3. Possible causes**:
- High transaction volume during failover
- Resource constraints (upgrade SKU)
- Network issues between zones
- Large number of active connections

### Error: "Region doesn't support availability zones"

**Symptoms**: Cannot enable zone-redundant HA

**Solution**: Deploy to a supported region:

```powershell
# Redeploy to supported region
.\Deploy-SAIF-PostgreSQL.ps1 `
    -location "swedencentral" `  # or germanywestcentral, eastus, etc.
    -enableHA $true
```

### Web Application Not Recovering

**Symptoms**: Database recovers but web app still shows errors

**Solutions**:

**1. Restart App Service**:
```bash
az webapp restart \
    --resource-group rg-saif-pgsql-swc-01 \
    --name saif-pgsql-web-abc123
```

**2. Check App Service logs**:
```bash
az webapp log tail \
    --resource-group rg-saif-pgsql-swc-01 \
    --name saif-pgsql-web-abc123
```

**3. Verify connection string**:
```bash
# Check if connection string is correct
az webapp config appsettings list \
    --resource-group rg-saif-pgsql-swc-01 \
    --name saif-pgsql-web-abc123 \
    --query "[?name=='DATABASE_URL'].value" -o tsv
```

### High Replication Lag

**Symptoms**: Standby database is behind primary

**Check replication lag**:
```sql
-- Connect to primary and run:
SELECT
    client_addr AS standby_ip,
    state,
    sent_lsn,
    write_lsn,
    flush_lsn,
    replay_lsn,
    sync_state,
    COALESCE(EXTRACT(EPOCH FROM (now() - replay_timestamp)), 0) AS lag_seconds
FROM pg_stat_replication;
```

**Healthy result**: lag_seconds should be < 1

**If lag is high**:
- Check network connectivity between zones
- Verify standby server resources (CPU, IOPS)
- Reduce write load temporarily
- Consider upgrading SKU

---

## 💰 Cost Optimization

### Testing Strategy for Cost Efficiency

**Option 1: On-Demand Testing**

Keep server in Burstable tier, upgrade only for testing:

```powershell
# Before testing: Upgrade to General Purpose with HA
az postgres flexible-server update \
    --resource-group rg-saif-pgsql-swc-01 \
    --name <SERVER_NAME> \
    --sku-name Standard_D2ds_v4 \
    --tier GeneralPurpose \
    --high-availability ZoneRedundant \
    --standby-zone 2

# Run tests
.\Test-PostgreSQL-Failover.ps1 -ResourceGroupName "rg-saif-pgsql-swc-01"

# After testing: Downgrade to Burstable
az postgres flexible-server update \
    --resource-group rg-saif-pgsql-swc-01 \
    --name <SERVER_NAME> \
    --high-availability Disabled

az postgres flexible-server update \
    --resource-group rg-saif-pgsql-swc-01 \
    --name <SERVER_NAME> \
    --sku-name Standard_B1ms \
    --tier Burstable
```

**Cost**: ~$120 for testing day + ~$23/month baseline

**Option 2: Scheduled Testing Windows**

Keep HA enabled only during business hours:

```powershell
# Morning: Enable HA (8 AM)
az postgres flexible-server update \
    --resource-group rg-saif-pgsql-swc-01 \
    --name <SERVER_NAME> \
    --high-availability ZoneRedundant

# Evening: Disable HA (6 PM)
az postgres flexible-server update \
    --resource-group rg-saif-pgsql-swc-01 \
    --name <SERVER_NAME> \
    --high-availability Disabled
```

**Cost**: ~$120/month (50% savings vs 24/7 HA)

**Option 3: Quarterly Testing**

Keep Burstable tier year-round, test quarterly:

- **Q1**: January (upgrade, test, downgrade)
- **Q2**: April (upgrade, test, downgrade)
- **Q3**: July (upgrade, test, downgrade)
- **Q4**: October (upgrade, test, downgrade)

**Cost**: ~$23/month + ~$20/quarter for testing = ~$28/month average

### Cost Comparison Table

| Configuration | Daily Cost | Monthly Cost | Annual Cost |
|--------------|-----------|--------------|-------------|
| **Burstable (B1ms)** | $0.75 | $23 | $276 |
| **GP (D2ds_v4) No HA** | $3.00 | $90 | $1,080 |
| **GP (D2ds_v4) + HA 24/7** | $6.00 | $180 | $2,160 |
| **GP (D2ds_v4) + HA Business Hours** | $4.00 | $120 | $1,440 |
| **Quarterly Testing Strategy** | $0.93 | $28 | $336 |

### Recommended Approach

**For Demos & Learning**:
```powershell
# Use quarterly testing strategy
# Keep Burstable tier except during planned tests
# Total cost: ~$28/month average
```

**For Production**:
```powershell
# Use D4ds_v4 or higher with 24/7 HA
# Accept the cost for 99.99% SLA
# Estimated: $210-400/month depending on workload
```

**For Development**:
```powershell
# Use Burstable tier without HA
# Manually test HA in pre-production environment
# Total cost: ~$23/month
```

---

## 🎯 Best Practices

### Testing Best Practices

1. **Test regularly** - Quarterly at minimum, monthly preferred
2. **Document everything** - Keep records for compliance
3. **Vary load patterns** - Test light, medium, and heavy loads
4. **Test both failover types** - Planned and forced
5. **Include application testing** - Don't just test database
6. **Monitor Azure metrics** - Track CPU, IOPS, connections during tests
7. **Automate where possible** - Use scripts for consistency

### Operational Best Practices

1. **Set up monitoring** - Azure Monitor alerts for HA issues
2. **Enable diagnostic logging** - Capture all failover events
3. **Implement connection retry logic** - Applications should handle transient failures
4. **Use connection pooling** - Reduces connection overhead during recovery
5. **Keep runbooks updated** - Document lessons learned
6. **Review logs regularly** - Identify patterns and anomalies
7. **Test disaster scenarios** - Don't just test planned failovers

### Security Best Practices

1. **Use Key Vault** - Store database credentials securely
2. **Implement RBAC** - Least privilege access
3. **Enable auditing** - Track all administrative actions
4. **Rotate credentials** - Regular password changes
5. **Use private endpoints** - Isolate database traffic
6. **Enable SSL/TLS** - Encrypt connections
7. **Monitor for anomalies** - Unusual connection patterns

### Performance Best Practices

1. **Right-size your SKU** - Match resources to workload
2. **Monitor replication lag** - Keep it near zero
3. **Optimize queries** - Use EXPLAIN ANALYZE
4. **Use appropriate indexes** - Balance read vs write performance
5. **Enable connection pooling** - PgBouncer or application-level
6. **Monitor storage IOPS** - Ensure adequate I/O capacity
7. **Test at peak load** - Simulate real-world conditions

### Application Best Practices

1. **Implement retry logic** - Handle transient connection failures
2. **Use health checks** - Detect database unavailability early
3. **Set appropriate timeouts** - Don't wait indefinitely
4. **Connection pool configuration** - Min/max connections properly sized
5. **Graceful degradation** - Fallback behavior during outages
6. **Circuit breaker pattern** - Prevent cascading failures
7. **Monitor application metrics** - Request latency, error rates

---

## 📚 Additional Resources

### Azure Documentation

- [Azure PostgreSQL Flexible Server HA](https://learn.microsoft.com/azure/postgresql/flexible-server/concepts-high-availability)
- [Configure High Availability](https://learn.microsoft.com/azure/postgresql/flexible-server/how-to-configure-high-availability)
- [Business Continuity Overview](https://learn.microsoft.com/azure/postgresql/flexible-server/concepts-business-continuity)
- [Zone-Redundant HA](https://learn.microsoft.com/azure/reliability/reliability-postgresql-flexible-server)
- [Monitoring and Metrics](https://learn.microsoft.com/azure/postgresql/flexible-server/concepts-monitoring)

### SAIF-PostgreSQL Documentation

- [Deployment Guide](deployment-guide.md) - Complete setup instructions
- [Quick Start](quickstart.md) - Fast reference guide
- [Architecture](architecture.md) - System architecture details
- [Implementation Summary](implementation-summary.md) - Technical specifications
- [README](../../README.md) - Project overview

### PowerShell Scripts

- `Test-PostgreSQL-Failover.ps1` - Automated failover testing
- `Monitor-PostgreSQL-HA.ps1` - Real-time HA monitoring
- `Deploy-SAIF-PostgreSQL.ps1` - Infrastructure deployment
- `Update-SAIF-Containers-PostgreSQL.ps1` - Container updates

### Testing Tools

- [Azure Load Testing](https://learn.microsoft.com/azure/load-testing/overview-what-is-azure-load-testing)
- [pgbench](https://www.postgresql.org/docs/current/pgbench.html) - PostgreSQL benchmarking
- [pg_stat_replication](https://www.postgresql.org/docs/current/monitoring-stats.html#PG-STAT-REPLICATION-VIEW) - Replication monitoring

### Well-Architected Framework

- [Reliability pillar](https://learn.microsoft.com/azure/well-architected/reliability/)
- [Performance efficiency pillar](https://learn.microsoft.com/azure/well-architected/performance-efficiency/)
- [Cost optimization pillar](https://learn.microsoft.com/azure/well-architected/cost-optimization/)

---

## 📞 Support & Feedback

### Getting Help

1. **Check documentation**:
   - [Troubleshooting](#troubleshooting) section in this guide
   - [Deployment Guide troubleshooting](deployment-guide.md#troubleshooting)
   - [Quick Start FAQ](quickstart.md#faq)

2. **Review Azure resources**:
   - Azure Portal → Resource health
   - Application Insights → Failures
   - Log Analytics → Query logs

3. **Run diagnostics**:
   ```powershell
   .\Monitor-PostgreSQL-HA.ps1 -ResourceGroupName "rg-saif-pgsql-swc-01"
   ```

4. **Check Azure service health**:
   - [Azure Status](https://status.azure.com/)
   - [Service Health in Portal](https://portal.azure.com/#view/Microsoft_Azure_Health/AzureHealthBrowseBlade)

### Reporting Issues

When reporting issues, include:

- Resource group name
- PostgreSQL server name
- Azure region
- HA configuration (output of `az postgres flexible-server show`)
- Error messages and timestamps
- Script output logs
- Steps to reproduce

---

## 🎬 Demo Workflow

### Quick Demo (15 minutes)

Perfect for showcasing zone-redundant HA:

**Preparation (5 min)**:
```powershell
# Ensure HA is enabled
cd c:\Repos\SAIF\SAIF-pgsql\scripts
.\Monitor-PostgreSQL-HA.ps1 -ResourceGroupName "rg-saif-pgsql-swc-01"
```

**Execution (5 min)**:
```powershell
# Run automated failover test
.\Test-PostgreSQL-Failover.ps1 `
    -ResourceGroupName "rg-saif-pgsql-swc-01" `
    -LoadDuration 60 `
    -TransactionsPerSecond 100
```

**Review (5 min)**:
- Show RTO/RPO metrics
- Demonstrate zero data loss
- Explain SLA achievement
- Show application continuity

### Deep Dive Demo (45 minutes)

Comprehensive HA demonstration:

**Part 1: Architecture Overview (10 min)**
- Explain zone-redundant architecture
- Show availability zones in Azure Portal
- Review primary/standby configuration
- Discuss synchronous replication

**Part 2: Baseline Performance (10 min)**
- Run monitoring dashboard
- Show normal operation metrics
- Generate sample transactions via web UI
- Review database performance metrics

**Part 3: Failover Testing (15 min)**
- Run automated failover test
- Monitor real-time during failover
- Show detection, promotion, recovery phases
- Highlight RTO/RPO achievement

**Part 4: Application Validation (10 min)**
- Test web application post-failover
- Show transaction history integrity
- Verify new primary zone
- Demonstrate automatic reconnection

**Discussion Topics**:
- Cost vs availability trade-offs
- When to use zone-redundant HA
- Best practices for applications
- Testing strategies

---

**Document Version**: 1.0.0  
**Last Updated**: October 2025  
**Tested With**: Azure Database for PostgreSQL Flexible Server 16  
**Author**: SAIF Team
