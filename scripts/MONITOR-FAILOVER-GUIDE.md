# Monitor-Failover-Azure.ps1 - User Guide

## Overview

This script monitors Azure PostgreSQL Flexible Server failover by tracking **Azure's internal state transitions** (not application connectivity). It provides the most accurate RTO measurement from Azure's perspective.

## What Gets Displayed When You Ctrl+C

The script has **three display modes** depending on when you interrupt it:

### 1. ✅ Complete Failover (Full RTO)

**When**: Script captures both failover start AND recovery completion

**Display Example**:
```
═══════════════════════════════════════════════════════════════════
 📊 STATE TRANSITION SUMMARY
═══════════════════════════════════════════════════════════════════

Timestamp       Transition              Duration (s)
-----------     -------------------     ------------
17:24:48.980    Ready → Updating        0
17:25:32.145    Updating → Ready        43.17

⭐ TOTAL AZURE RTO: 43.17 seconds
   SLA Target: 60-120 seconds
   ✅ PASSED SLA
```

### 2. ⚠️ Interrupted Mid-Failover (Partial RTO)

**When**: You press Ctrl+C **after** failover starts but **before** recovery completes

**Display Example**:
```
⚠️  Monitoring stopped (Ctrl+C detected)
📍 Getting final server state...
   Current State: Updating
   HA State: FailingOver
   Primary Zone: 1

═══════════════════════════════════════════════════════════════════
 📊 STATE TRANSITION SUMMARY
═══════════════════════════════════════════════════════════════════

Timestamp       Transition              Duration (s)
-----------     -------------------     ------------
17:24:48.980    Ready → Updating        0

⚠️  PARTIAL RTO MEASUREMENT (interrupted before recovery):
   Failover started: 17:24:48.980
   Monitoring stopped: 17:25:05.234
   Elapsed downtime: 16.25 seconds (still in failover)

   💡 TIP: Let the script run until recovery completes to get full RTO
```

### 3. ℹ️ No Failover Detected

**When**: You Ctrl+C before any failover is triggered

**Display**: Just shows "Monitoring stopped" with current healthy state

## Usage Scenarios

### Scenario A: Measure Complete RTO ⭐ RECOMMENDED

```powershell
# Terminal 1: Start monitoring
.\Monitor-Failover-Azure.ps1 -ResourceGroupName 'rg-saif-pgsql-swc-01'

# Terminal 2: Trigger failover (after monitoring starts)
az postgres flexible-server restart `
  --resource-group rg-saif-pgsql-swc-01 `
  --name psql-saifpg-10081025 `
  --failover Planned

# Terminal 1: Wait for "✅ [FAILOVER END] Recovered at..." message
# THEN press Ctrl+C to see full RTO summary
```

**Result**: Full RTO displayed (e.g., "43.17 seconds")

### Scenario B: Check Progress Mid-Failover

```powershell
# If failover is taking longer than expected, press Ctrl+C
# The script will show:
# - How long the failover has been running
# - Current server state (Updating, etc.)
# - Current HA state (FailingOver, etc.)
```

**Result**: Partial RTO showing elapsed downtime so far

## Key Differences from Application-Level Testing

| Metric | Monitor-Failover-Azure.ps1 | Test-PostgreSQL-Failover.ps1 |
|--------|----------------------------|------------------------------|
| **Measures** | Azure internal state transitions | Application write capability |
| **Start Point** | Azure state changes from "Ready" | First failed write attempt |
| **End Point** | Azure state returns to "Ready" | First successful write |
| **Typical RTO** | 30-50 seconds | 40-60 seconds |
| **Purpose** | Azure platform perspective | End-user experience |

## Expected RTO Values

### Azure State RTO (This Script)
- **Light Load**: 30-45 seconds
- **Heavy Load**: 40-60 seconds
- **SLA Target**: 60-120 seconds

### Application-Level RTO (Write-Based Test)
- **Light Load**: 35-50 seconds
- **Heavy Load**: 40-70 seconds
- **Cloud Shell**: +5-15 seconds (detection lag)

## Why RTO Differs Between Scripts

**Azure State RTO < Application RTO** is normal because:

1. **Detection Lag**: Application must attempt writes to detect failure
2. **Connection Pool**: Application must drain/reconnect connections
3. **PgBouncer Overhead**: Port 6432 adds pooler handshake time
4. **DNS Propagation**: Minimal delay for DNS updates
5. **Network Latency**: Cloud Shell → Azure adds 5-15ms

**Example Timeline**:
```
00:00 - Failover triggered
00:15 - Azure detects primary failure
00:20 - Standby begins WAL recovery
00:43 - Azure state: "Ready" ← This script measures UP TO HERE
00:45 - PgBouncer accepts connections
00:48 - First application write succeeds ← Write-based test measures TO HERE
```

## Troubleshooting

### Issue: Script exits immediately with error

**Cause**: Azure CLI not authenticated or server not found

**Solution**:
```powershell
az login
az account set --subscription "your-subscription-name"
```

### Issue: Shows "Partial RTO" but failover completed

**Cause**: You pressed Ctrl+C between the last poll and recovery

**Solution**: Wait 2-4 more seconds before pressing Ctrl+C to catch the "Ready" state transition

### Issue: No state transitions detected

**Cause**: Failover not triggered yet, or monitoring started too late

**Solution**: Start this script BEFORE triggering failover in another terminal

## Best Practices

1. **Start monitoring BEFORE triggering failover**
2. **Let script run until you see "✅ [FAILOVER END]"** for complete RTO
3. **Run alongside write-based test** to compare Azure vs application perspective
4. **Check HA state is "Healthy"** before starting
5. **Use 2-second poll interval** (default) for accurate timing

## Related Scripts

- **Test-PostgreSQL-Failover.ps1**: Application-level RTO (write-based)
- **Check-WAL-Settings.ps1**: Analyze factors affecting RTO
- **Monitor-PostgreSQL-HA.ps1**: Continuous HA health monitoring

## Quick Reference

| Command | Purpose |
|---------|---------|
| `.\Monitor-Failover-Azure.ps1 -ResourceGroupName 'rg-name'` | Start monitoring |
| Press Ctrl+C **AFTER** "✅ [FAILOVER END]" | Get complete RTO |
| Press Ctrl+C **DURING** failover | Get partial RTO + current state |
| Poll interval: 2 seconds | Configured in script (line 167) |

## Output Files

This script does **not** create output files. All results are displayed in the terminal.

To save results:
```powershell
.\Monitor-Failover-Azure.ps1 -ResourceGroupName 'rg-name' | Tee-Object -FilePath "failover-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
```

---

**Version**: 1.0.0  
**Last Updated**: October 9, 2025  
**Author**: SAIF Team
