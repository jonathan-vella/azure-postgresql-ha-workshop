# Connection RTO Measurement - Troubleshooting Guide

## Common Issues and Solutions

### Issue 1: "Cannot connect to database" - RecreatingStandby State

**Symptom:**
```
HA State:         RecreatingStandby
❌ Cannot connect to database. Please check credentials and server status.
```

**Cause:** 
Server is recovering from a previous failover. The standby replica is being rebuilt.

**Solution:**
1. **Wait 5-10 minutes** for standby to rebuild
2. Check status:
   ```powershell
   az postgres flexible-server show `
     --resource-group rg-saif-pgsql-swc-01 `
     --name psql-saifpg-10081025 `
     --query "{state:state, haState:highAvailability.state}"
   ```
3. Wait for `haState: "Healthy"` before testing
4. Microsoft recommendation: **Wait 15-20 minutes between failovers**

### Issue 2: "Npgsql not available"

**Symptom:**
```
ℹ️  Npgsql not available, using psql command-line tool
```

**Cause:** 
Npgsql DLLs not installed in scripts/libs folder.

**Solution:**
Run the Test-PostgreSQL-Failover.ps1 script once to auto-install:
```powershell
cd C:\Repos\azure-postgresql-ha-workshop\scripts
.\Test-PostgreSQL-Failover.ps1 -ResourceGroupName 'rg-saif-pgsql-swc-01'
```

This will download and install Npgsql to the `libs/` folder.

### Issue 3: Connection Timeout

**Symptom:**
```
Error: Timeout during connection attempt
```

**Cause:**
- Firewall rules blocking connection
- Server is in maintenance mode
- Network connectivity issue

**Solution:**
1. Check your IP is allowed:
   ```powershell
   az postgres flexible-server firewall-rule list `
     --resource-group rg-saif-pgsql-swc-01 `
     --name psql-saifpg-10081025
   ```

2. Add your IP if needed:
   ```powershell
   az postgres flexible-server firewall-rule create `
     --resource-group rg-saif-pgsql-swc-01 `
     --name psql-saifpg-10081025 `
     --rule-name "MyIP" `
     --start-ip-address <YOUR_IP> `
     --end-ip-address <YOUR_IP>
   ```

### Issue 4: Authentication Failed

**Symptom:**
```
Error: password authentication failed for user "saifadmin"
```

**Cause:**
Incorrect password or username.

**Solution:**
1. Verify username (default: `saifadmin`)
2. Get password from Key Vault:
   ```powershell
   az keyvault secret show `
     --vault-name <keyvault-name> `
     --name postgresql-admin-password `
     --query value -o tsv
   ```

### Issue 5: Can't Find Server

**Symptom:**
```
❌ No PostgreSQL servers found
```

**Cause:**
Wrong resource group or server doesn't exist.

**Solution:**
1. List all PostgreSQL servers:
   ```powershell
   az postgres flexible-server list --output table
   ```

2. Check resource group name:
   ```powershell
   az group list --query "[].name" -o table
   ```

### Issue 6: Port 6432 Not Accepting Connections

**Symptom:**
Works with port 5432, fails with port 6432

**Cause:**
PgBouncer not enabled or not accepting connections.

**Solution:**
1. Check PgBouncer status:
   ```powershell
   az postgres flexible-server parameter show `
     --resource-group rg-saif-pgsql-swc-01 `
     --server-name psql-saifpg-10081025 `
     --name pgbouncer.enabled
   ```

2. Use port 5432 temporarily (edit script line 162):
   ```powershell
   $port = 5432  # Direct connection
   ```

## Best Practices to Avoid Issues

### 1. Wait Between Failovers
**Rule:** Wait 15-20 minutes between failover tests

**Why:** Standby needs time to:
- Rebuild in new zone
- Sync WAL logs
- Establish steady replication state

**Check before testing:**
```powershell
az postgres flexible-server show `
  --resource-group rg-saif-pgsql-swc-01 `
  --name psql-saifpg-10081025 `
  --query "highAvailability.state" -o tsv
```
Expected: `Healthy`

### 2. Pre-Flight Checklist

Before running failover test:
- ✅ Server state: `Ready`
- ✅ HA state: `Healthy`
- ✅ Standby zone: Different from primary
- ✅ Can connect manually: `SELECT 1`
- ✅ Npgsql installed in libs folder

### 3. Cloud Shell vs Local Execution

**Cloud Shell (Recommended for testing):**
- ✅ Closer to Azure (lower latency)
- ✅ No firewall rules needed
- ✅ Consistent network environment
- ❌ Slower PowerShell execution

**Local (Better for monitoring):**
- ✅ Faster PowerShell execution
- ✅ Better terminal experience
- ❌ Requires firewall rule for your IP
- ❌ Network latency varies

## Understanding HA States

| HA State | Meaning | Can Test Failover? |
|----------|---------|-------------------|
| **Healthy** | Primary + Standby both operational | ✅ Yes |
| **Initializing** | Setting up HA for first time | ❌ Wait |
| **ReplicatingData** | Standby catching up | ❌ Wait |
| **FailingOver** | Failover in progress | ❌ In progress |
| **RecreatingStandby** | Rebuilding standby after failover | ❌ Wait 5-10 min |
| **RemovingStandby** | Disabling HA | ❌ No |
| **NotEnabled** | HA not configured | ❌ Enable first |

## Quick Diagnostics

### Run Full Diagnostic Check:
```powershell
Write-Host "🔍 PostgreSQL Server Diagnostic Check`n" -ForegroundColor Cyan

# 1. Server Status
Write-Host "1. Server Status:" -ForegroundColor Yellow
az postgres flexible-server show `
  --resource-group rg-saif-pgsql-swc-01 `
  --name psql-saifpg-10081025 `
  --query "{state:state, haMode:highAvailability.mode, haState:highAvailability.state, primaryZone:availabilityZone, standbyZone:highAvailability.standbyAvailabilityZone}" `
  -o table

# 2. PgBouncer Status
Write-Host "`n2. PgBouncer Status:" -ForegroundColor Yellow
az postgres flexible-server parameter show `
  --resource-group rg-saif-pgsql-swc-01 `
  --server-name psql-saifpg-10081025 `
  --name pgbouncer.enabled `
  --query "value" -o tsv

# 3. Connection Test
Write-Host "`n3. Testing Connection:" -ForegroundColor Yellow
$serverFqdn = (az postgres flexible-server show `
  --resource-group rg-saif-pgsql-swc-01 `
  --name psql-saifpg-10081025 `
  --query "fullyQualifiedDomainName" -o tsv)

Write-Host "   Server FQDN: $serverFqdn"

# 4. Firewall Rules
Write-Host "`n4. Firewall Rules:" -ForegroundColor Yellow
az postgres flexible-server firewall-rule list `
  --resource-group rg-saif-pgsql-swc-01 `
  --name psql-saifpg-10081025 `
  --query "[].{name:name, start:startIpAddress, end:endIpAddress}" `
  -o table

Write-Host "`n✅ Diagnostic Complete`n" -ForegroundColor Green
```

## Getting Help

If you continue to experience issues:

1. **Check Azure Portal**:
   - Navigate to your PostgreSQL server
   - View "Activity log" for recent operations
   - Check "Diagnose and solve problems"

2. **View Recent Operations**:
   ```powershell
   az monitor activity-log list `
     --resource-group rg-saif-pgsql-swc-01 `
     --resource-id /subscriptions/<sub-id>/resourceGroups/rg-saif-pgsql-swc-01/providers/Microsoft.DBforPostgreSQL/flexibleServers/psql-saifpg-10081025 `
     --query "[].{time:eventTimestamp, status:status.value, operation:operationName.value}" `
     -o table
   ```

3. **Contact Support**:
   - Azure Portal → Support + troubleshooting
   - Include: RTO measurements, HA state, error messages

---

**Version:** 1.0.0  
**Last Updated:** October 9, 2025  
**Author:** SAIF Team
