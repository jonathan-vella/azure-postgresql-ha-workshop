# PostgreSQL HA Performance Dashboard - Quick Setup Guide

## 📊 Manual Dashboard Creation in Azure Portal

Since the P70 disk upgrade may still be processing, here's how to quickly create your monitoring dashboard:

---

## Option 1: Quick Metrics View (Fastest - 2 minutes)

### Step 1: Open Metrics Explorer
1. Go to Azure Portal: https://portal.azure.com
2. Navigate to: **Resource Groups** → **rg-saif-pgsql-swc-01** → **psql-saifpg-10081025**
3. In left menu, click **"Monitoring"** → **"Metrics"**

### Step 2: Add Key Metrics (Pin Each to Dashboard)

**Chart 1: TPS (Transactions Per Second)**
- Click "+ New chart"
- Metric: `Transactions Committed` (xact_commit)
- Aggregation: `Average`
- Click "Pin to dashboard" → Create new dashboard: "PostgreSQL-HA-Performance"

**Chart 2: IOPS Utilization**
- Click "+ New chart"
- Metric: `Disk IOPS Consumed Percentage`
- Aggregation: `Average`
- Click "Add metric" → `Read IOPS` (Average)
- Click "Add metric" → `Write IOPS` (Average)
- Click "Pin to dashboard" → Select "PostgreSQL-HA-Performance"

**Chart 3: CPU & Memory**
- Click "+ New chart"
- Metric: `CPU percent`
- Aggregation: `Average`
- Click "Add metric" → `Memory percent` (Average)
- Click "Pin to dashboard" → Select "PostgreSQL-HA-Performance"

**Chart 4: Disk Throughput**
- Click "+ New chart"
- Metric: `Read Throughput` (bytes/s)
- Aggregation: `Average`
- Click "Add metric" → `Write Throughput` (Average)
- Click "Add metric" → `Disk Bandwidth Consumed Percentage` (Average)
- Click "Pin to dashboard" → Select "PostgreSQL-HA-Performance"

**Chart 5: Connections**
- Click "+ New chart"
- Metric: `Active Connections`
- Aggregation: `Average`
- Click "Add metric" → `Failed Connections` (Total)
- Click "Pin to dashboard" → Select "PostgreSQL-HA-Performance"

**Chart 6: Replication Lag**
- Click "+ New chart"
- Metric: `Replication Lag Seconds`
- Aggregation: `Max`
- Click "Pin to dashboard" → Select "PostgreSQL-HA-Performance"

### Step 3: View Dashboard
- Click "Dashboard" in top menu
- Select "PostgreSQL-HA-Performance"
- All your metrics will update in real-time!

---

## Option 2: Pre-Built Workbook (Recommended - 5 minutes)

### Step 1: Create Azure Monitor Workbook
1. Go to: **psql-saifpg-10081025** → **"Monitoring"** → **"Workbooks"**
2. Click **"+ New"**
3. Click **"+ Add"** → **"Add metric"**

### Step 2: Configure Workbook

**Add these metric sections:**

```json
Resource: psql-saifpg-10081025
Time Range: Last hour
Metrics to Add:
1. Transactions Committed (xact_commit) - Line chart
2. Disk IOPS Consumed Percentage - Line chart
3. Read IOPS + Write IOPS - Multi-line chart
4. CPU percent + Memory percent - Multi-line chart
5. Read Throughput + Write Throughput - Multi-line chart
6. Active Connections - Area chart
7. Replication Lag Seconds - Line chart
```

### Step 3: Save Workbook
- Click **"Done Editing"**
- Click **"Save As"** → Name: "PostgreSQL HA Performance Monitor"
- Location: Select "rg-saif-pgsql-swc-01"
- Click **"Apply"**

---

## Option 3: Verify Storage Upgrade Status

### Check if P70 upgrade completed:

```powershell
# Check current storage configuration
az postgres flexible-server show `
    --resource-group "rg-saif-pgsql-swc-01" `
    --name "psql-saifpg-10081025" `
    --query "{storage:storage,sku:sku}" `
    -o json
```

**Expected P70 values:**
- `storageSizeGb`: **16384** (16 TB) or **8192** (8 TB)
- `tier`: **Premium_SSD**
- `iops`: **15000**

**If still showing 1024 GB:**
1. Check Azure Portal → Server → "Compute + Storage"
2. Look for "Deployment in progress" notification
3. P70 upgrades can take 5-10 minutes

---

## 🚀 Quick Access URLs

### Direct Links (replace with your subscription ID):

**Metrics View:**
```
https://portal.azure.com/#@/resource/subscriptions/00858ffc-dded-4f0f-8bbf-e17fff0d47d9/resourceGroups/rg-saif-pgsql-swc-01/providers/Microsoft.DBforPostgreSQL/flexibleServers/psql-saifpg-10081025/metrics
```

**Compute + Storage Settings:**
```
https://portal.azure.com/#@/resource/subscriptions/00858ffc-dded-4f0f-8bbf-e17fff0d47d9/resourceGroups/rg-saif-pgsql-swc-01/providers/Microsoft.DBforPostgreSQL/flexibleServers/psql-saifpg-10081025/computeAndStorage
```

---

## 📊 What to Watch During Load Test

### 🟢 Healthy Indicators:
- **TPS**: 8000+ (green zone)
- **IOPS %**: <50% (excellent headroom with P70)
- **CPU %**: 50-70% (optimal)
- **Memory %**: <60% (good)
- **Replication Lag**: <1 second

### 🟡 Warning Indicators:
- **TPS**: 5000-7999 (close to target)
- **IOPS %**: 50-80% (monitor closely)
- **CPU %**: 70-90% (approaching limit)
- **Memory %**: 60-80% (watch for pressure)
- **Replication Lag**: 1-5 seconds

### 🔴 Critical Indicators:
- **TPS**: <5000 (investigate bottleneck)
- **IOPS %**: >80% (disk bottleneck)
- **CPU %**: >90% (compute bottleneck)
- **Memory %**: >80% (memory pressure)
- **Replication Lag**: >5 seconds (HA issue)

---

## 📈 Expected P70 Performance

With your upgraded **8TB P70 disk**:
- **15,000 IOPS** capacity
- **500 MB/s** throughput
- At **8K TPS**: ~40-50% IOPS utilization ✅
- **50%+ headroom** for bursts and failover

---

## Next Step: Start Real-Time Monitor

Once dashboard is ready, start the terminal monitor:

```powershell
# Terminal 1: Real-time metrics (run this!)
.\scripts\Monitor-PostgreSQL-Realtime.ps1 `
    -ResourceGroup "rg-saif-pgsql-swc-01" `
    -PostgreSQLServer "psql-saifpg-10081025"
```

This will show live TPS, IOPS, CPU, Memory, and throughput every 10 seconds in your terminal!
