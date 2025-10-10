# 📊 Azure Workbook - Import Guide

## Quick Import (30 seconds!)

### Step 1: Copy the Workbook JSON

The workbook JSON is in: `azure-workbooks/PostgreSQL-HA-Performance-Workbook.json`

Open the file and **copy ALL content** (Ctrl+A, Ctrl+C)

---

### Step 2: Import into Azure Portal

**Option A: Direct URL (Fastest)**
1. Click: https://portal.azure.com/#view/AppInsightsExtension/UsageNotebookBlade/ComponentId/Azure%20Monitor/ConfigurationId/community-Workbooks%2FAzure%20Monitor%20-%20Workspaces%2FEmpty%20Gallery%20Template/Type/workbook/GalleryResourceType/microsoft.monitor%2Faccounts

**Option B: Navigate Manually**
1. Go to: https://portal.azure.com
2. Search for **"Azure Workbooks"** in top search bar
3. Click **"+ Create"** → **"+ New"**

---

### Step 3: Paste JSON and Save

1. Click the **"</>  Advanced Editor"** button (top toolbar)
2. **Delete** all existing JSON content
3. **Paste** the copied workbook JSON
4. Click **"Apply"**
5. Click **"Done Editing"** (top right)
6. Click **"Save"** icon (disk icon in toolbar)

**Save Settings:**
- **Title:** PostgreSQL HA Performance Monitor
- **Subscription:** Select your subscription
- **Resource Group:** rg-saif-pgsql-swc-01
- **Location:** Sweden Central (or your region)

7. Click **"Apply"**

---

### Step 4: View Your Dashboard

Your workbook is now ready with all 6 charts:

✅ **🚀 Transactions Per Second (TPS)**  
✅ **💾 Disk IOPS (P70: 15K max)**  
✅ **🖥️ CPU & Memory Utilization**  
✅ **📈 Disk Throughput (P70: 500 MB/s max)**  
✅ **🔌 Database Connections**  
✅ **⚡ Replication Lag (HA Standby)**

**Features:**
- Auto-refresh every 60 seconds
- Last 1 hour time range (adjustable)
- Performance targets table at bottom
- All metrics pre-configured for psql-saifpg-10081025

---

## 📱 Pin to Dashboard (Optional)

Want this on your Azure home screen?

1. Open the workbook
2. Click **"Pin"** icon (📌) on any chart
3. Select **"Pin to existing dashboard"** or create new
4. Choose dashboard: "PostgreSQL-HA-8K-TPS-Test"
5. Repeat for all 6 charts

---

## 🔗 Quick Access Link

After saving, bookmark the workbook URL (looks like):
```
https://portal.azure.com/#@/resource/subscriptions/.../resourceGroups/rg-saif-pgsql-swc-01/providers/microsoft.insights/workbooks/...
```

---

## 🎯 What You'll See

### During 8K TPS Load Test:

**Healthy Indicators:**
- TPS: **8000+** (line climbing to target)
- IOPS %: **40-50%** (well below red zone)
- CPU %: **50-70%** (optimal range)
- Memory %: **35-45%** (plenty of headroom)
- Replication Lag: **<1 second** (green)

**If Something's Wrong:**
- TPS stuck at **5500**: IOPS bottleneck (check if P70 upgrade completed)
- IOPS % at **80%+**: Disk saturation
- CPU % at **90%+**: Compute bottleneck
- Replication Lag **>5 sec**: HA issue

---

## 🆘 Troubleshooting

### Charts show "No data available"
- **Wait 60-90 seconds** - metrics have lag
- Check time range is "Last 1 hour"
- Verify server name is correct in JSON

### Workbook fails to save
- Ensure you have Contributor role on resource group
- Try different name if it exists
- Check subscription has workbook quota

### Want to customize?
- Click **"Edit"** mode
- Modify any chart
- Add/remove metrics
- Change time ranges
- Click **"Save"** when done

---

## 📊 Alternative: Use KQL Queries

If you prefer Log Analytics over Workbooks:

1. Go to: **psql-saifpg-10081025** → **"Logs"**
2. Use queries from: `postgresql-monitoring-queries-20251010-204421.kql`
3. Copy/paste any of the 10 pre-built queries
4. Click **"Run"**
5. Pin results to dashboard

---

**Ready!** Your comprehensive monitoring dashboard is set up in under 30 seconds! 🎉
