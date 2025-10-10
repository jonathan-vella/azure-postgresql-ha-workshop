# SAIF-PostgreSQL Deployment Guide

Complete deployment guide for the SAIF Payment Gateway with Azure PostgreSQL Zone-Redundant High Availability.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Local Development](#local-development)
- [Azure Deployment](#azure-deployment)
- [Failover Testing](#failover-testing)
- [Monitoring](#monitoring)
- [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Tools

- **Azure CLI** 2.50.0 or later
  ```powershell
  az --version
  az login
  ```

- **PowerShell 7+**
  ```powershell
  $PSVersionTable.PSVersion
  ```

- **Docker Desktop** (for local development)
  ```powershell
  docker --version
  docker-compose --version
  ```

- **PostgreSQL Client Tools** (psql)
  ```powershell
  psql --version
  ```
  Download from: https://www.postgresql.org/download/

### Azure Subscription Requirements

- Active Azure subscription with sufficient quota
- Contributor or Owner role on subscription or resource group
- Available quota for:
  - Azure Database for PostgreSQL Flexible Server
  - App Services (B1 or higher)
  - Azure Container Registry
  - Key Vault
  - Application Insights

### Supported Regions

Zone-redundant HA requires regions with availability zones:

- **Recommended**: Sweden Central, Germany West Central
- **Also supported**: East US, East US 2, West US 2, West Europe, North Europe

Check availability zones:
```powershell
az vm list-skus --location swedencentral --zone --output table
```

---

## Local Development

### Quick Start

1. **Clone and Navigate**
   ```powershell
   cd c:\Repos\SAIF\SAIF-pgsql
   ```

2. **Start Services**
   ```powershell
   docker-compose up -d
   ```

3. **Verify Services**
   ```powershell
   # Check container status
   docker-compose ps
   
   # Check API health
   curl http://localhost:8000/api/healthcheck
   
   # Check Web frontend
   curl http://localhost:8080
   ```

4. **View Logs**
   ```powershell
   docker-compose logs -f api
   docker-compose logs -f web
   docker-compose logs -f postgres
   ```

5. **Stop Services**
   ```powershell
   docker-compose down
   
   # To remove volumes (delete all data)
   docker-compose down -v
   ```

### Local Testing Script

Use the provided test script:

```powershell
.\scripts\Test-SAIFLocal.ps1
```

This script:
- Validates Docker is running
- Starts containers
- Runs health checks
- Executes sample API calls
- Generates test transactions

---

## Azure Deployment

### Option 1: Automated Deployment (Recommended)

Use the comprehensive deployment script:

```powershell
cd c:\Repos\SAIF\SAIF-pgsql\scripts

# Basic deployment (will prompt for password)
.\Deploy-SAIF-PostgreSQL.ps1 -location "swedencentral"

# Automated deployment with password parameter
$password = ConvertTo-SecureString "YourSecurePassword123!" -AsPlainText -Force
.\Deploy-SAIF-PostgreSQL.ps1 `
    -location "swedencentral" `
    -postgresqlPassword $password `
    -autoApprove
```

**Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `-location` | String | `swedencentral` | Azure region for deployment |
| `-resourceGroupName` | String | Auto-generated | Custom resource group name (optional) |
| `-postgresqlPassword` | SecureString | Prompted | PostgreSQL admin password (12+ chars, mixed case, numbers) |
| `-postgresqlSku` | String | `Standard_D4ds_v5` | PostgreSQL compute SKU |
| `-disableHighAvailability` | Switch | `false` | Deploy without HA (not recommended for production) |
| `-skipContainers` | Switch | `false` | Skip container build/push (infrastructure only) |
| `-autoApprove` | Switch | `false` | Skip confirmation prompts (useful for CI/CD) |

**What the Script Does:**

The deployment script performs the following steps automatically:

1. **Validates Prerequisites** - Checks Azure CLI authentication and subscription access
2. **Creates Resource Group** - Sets up or validates the target resource group
3. **Deploys Infrastructure** - Uses Bicep templates to create all Azure resources (10-15 minutes)
4. **Retrieves Outputs** - Extracts deployment details with retry logic and timeout handling
5. **Initializes Database** - Creates schema and tables using `init-db.sql`
6. **Builds Containers** - Builds and pushes API and Web containers to ACR (10-15 minutes)
7. **Restarts App Services** - Pulls new container images and starts the applications
8. **Validates Deployment** - Tests API and Web endpoints to confirm everything works

**Key Features:**

- ✅ **Unique Resource Naming** - Uses timestamp-based suffixes to avoid conflicts with soft-deleted resources
- ✅ **Automatic Retry Logic** - Handles transient Azure API failures gracefully
- ✅ **Progress Indicators** - Shows clear status updates throughout 25-30 minute deployment
- ✅ **Container Verification** - Confirms images are pushed to ACR before restarting App Services
- ✅ **Comprehensive Validation** - Tests all endpoints and confirms HA status
- ✅ **Detailed Error Messages** - Provides troubleshooting commands when issues occur

**Examples:**

```powershell
# Interactive deployment (prompts for password and confirmation)
.\Deploy-SAIF-PostgreSQL.ps1 -location "swedencentral"

# Fully automated deployment
$password = ConvertTo-SecureString "YourSecurePassword123!" -AsPlainText -Force
.\Deploy-SAIF-PostgreSQL.ps1 `
    -location "swedencentral" `
    -postgresqlPassword $password `
    -autoApprove

# Deploy to Germany with specific resource group
$password = ConvertTo-SecureString "YourSecurePassword123!" -AsPlainText -Force
.\Deploy-SAIF-PostgreSQL.ps1 `
    -location "germanywestcentral" `
    -resourceGroupName "rg-saif-prod-01" `
    -postgresqlPassword $password `
    -autoApprove

# Deploy with smaller SKU for development
$password = ConvertTo-SecureString "DevPassword123!" -AsPlainText -Force
.\Deploy-SAIF-PostgreSQL.ps1 `
    -location "swedencentral" `
    -postgresqlSku "Standard_D2ds_v5" `
    -postgresqlPassword $password `
    -autoApprove

# Infrastructure only (no containers) - useful for testing IaC
$password = ConvertTo-SecureString "YourSecurePassword123!" -AsPlainText -Force
.\Deploy-SAIF-PostgreSQL.ps1 `
    -location "swedencentral" `
    -postgresqlPassword $password `
    -skipContainers `
    -autoApprove

# Deploy without High Availability (cost optimization for dev/test)
$password = ConvertTo-SecureString "DevPassword123!" -AsPlainText -Force
.\Deploy-SAIF-PostgreSQL.ps1 `
    -location "swedencentral" `
    -postgresqlPassword $password `
    -disableHighAvailability `
    -autoApprove
```

**Password Requirements:**
- Minimum 12 characters
- Must contain uppercase letters (A-Z)
- Must contain lowercase letters (a-z)
- Must contain numbers (0-9)
- Recommended: Include special characters

**What the Script Does:**

1. ✅ Validates Azure authentication
2. ✅ Creates resource group (if not exists)
3. ✅ Generates unique resource name suffix (timestamp-based)
4. ✅ Creates temporary parameters file (avoids Azure CLI issues)
5. ✅ Deploys Bicep infrastructure:
   - PostgreSQL Flexible Server (Zone-Redundant HA)
   - Azure Container Registry
   - Key Vault (with unique name to avoid soft-delete conflicts)
   - App Services (API + Web)
   - Application Insights
   - Log Analytics Workspace
6. ✅ Initializes database schema
7. ✅ Builds and pushes container images to ACR
8. ✅ Configures App Service environment variables
9. ✅ Restarts App Services to pull latest images
10. ✅ Validates deployment with health checks
11. ✅ Displays deployment summary with URLs

**Expected Duration:** 15-20 minutes

**Resource Naming Convention:**
- Key Vault: `kvsaifpg{timestamp}` (e.g., `kvsaifpg10081025`)
- ACR: `acrsaifpg{timestamp}`
- PostgreSQL: `psql-saifpg-{timestamp}`
- All resources include unique 8-character timestamp suffix to avoid conflicts

### Option 2: Manual Step-by-Step Deployment

#### Step 1: Create Resource Group

```powershell
$location = "swedencentral"
$resourceGroupName = "rg-saif-pgsql-swc-01"

az group create `
    --name $resourceGroupName `
    --location $location
```

#### Step 2: Deploy Infrastructure

```powershell
cd c:\Repos\SAIF\SAIF-pgsql

# Set PostgreSQL password
$postgresPassword = Read-Host "Enter PostgreSQL password" -AsSecureString
$postgresPasswordText = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($postgresPassword)
)

# Generate unique suffix to avoid conflicts
$timestamp = Get-Date -Format "MMddHHmm"
$uniqueSuffix = $timestamp.ToLower()

# Create parameters file to avoid Azure CLI issues
$tempParamsFile = [System.IO.Path]::GetTempFileName() + ".json"
$paramsObject = @{
    '$schema' = 'https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#'
    contentVersion = '1.0.0.0'
    parameters = @{
        location = @{ value = $location }
        uniqueSuffix = @{ value = $uniqueSuffix }
        postgresAdminPassword = @{ value = $postgresPasswordText }
    }
}
$paramsObject | ConvertTo-Json -Depth 10 | Set-Content -Path $tempParamsFile -Encoding UTF8

# Deploy Bicep template
$deploymentName = "main-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
az deployment group create `
    --resource-group $resourceGroupName `
    --template-file infra/main.bicep `
    --parameters $tempParamsFile `
    --name $deploymentName

# Clean up temp file
Remove-Item $tempParamsFile -Force -ErrorAction SilentlyContinue

# Clear sensitive data
$postgresPasswordText = $null
```

#### Step 3: Get Deployment Outputs

```powershell
$outputs = az deployment group show `
    --resource-group $resourceGroupName `
    --name $deploymentName `
    --query properties.outputs `
    --output json | ConvertFrom-Json

$acrName = $outputs.acrName.value
$postgresServerFqdn = $outputs.postgresServerFqdn.value
$apiAppName = $outputs.apiAppName.value
$webAppName = $outputs.webAppName.value
```

#### Step 4: Initialize Database

```powershell
# Using psql
$env:PGPASSWORD = $postgresPasswordText
psql -h $postgresServerFqdn `
     -U saifadmin `
     -d saifdb `
     -f init-db.sql

# Clear password
$env:PGPASSWORD = $null
```

#### Step 5: Build and Push Containers

```powershell
# Build API container
az acr build `
    --registry $acrName `
    --image saif/api:latest `
    --file api/Dockerfile `
    api/

# Build Web container
az acr build `
    --registry $acrName `
    --image saif/web:latest `
    --file web/Dockerfile `
    web/
```

#### Step 6: Restart App Services

```powershell
az webapp restart --name $apiAppName --resource-group $resourceGroupName
az webapp restart --name $webAppName --resource-group $resourceGroupName
```

#### Step 7: Verify Deployment

```powershell
# Get URLs
$apiUrl = "https://$apiAppName.azurewebsites.net"
$webUrl = "https://$webAppName.azurewebsites.net"

# Test API
Invoke-RestMethod -Uri "$apiUrl/api/healthcheck"

# Open Web UI
Start-Process $webUrl
```

---

## Failover Testing

### Automated Failover Test

Use the comprehensive failover testing script:

```powershell
cd c:\Repos\SAIF\SAIF-pgsql\scripts
.\Test-PostgreSQL-Failover.ps1 -ResourceGroupName "rg-saif-pgsql-swc-01"
```

**Parameters:**

- `-ResourceGroupName` - Resource group containing PostgreSQL server (required)
- `-ServerName` - PostgreSQL server name (auto-discovered if not specified)
- `-LoadDuration` - Duration in seconds to run load before failover (default: 60)
- `-TransactionsPerSecond` - Target TPS during load generation (default: 100)

**What the Script Does:**

1. ✅ Validates server HA configuration
2. ✅ Records baseline metrics
3. ✅ Generates realistic payment transactions
4. ✅ Triggers forced failover
5. ✅ Measures RTO (Recovery Time Objective)
6. ✅ Validates RPO (Recovery Point Objective) = 0
7. ✅ Confirms zone switch
8. ✅ Generates compliance report

**Example Output:**

```
🔄 Failover Metrics:
  Failover Start: 2025-01-08 14:23:15.123
  Failover End: 2025-01-08 14:24:22.456
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

### Manual Failover Testing

#### 1. Monitor Before Failover

```powershell
# Start monitoring dashboard
.\scripts\Monitor-PostgreSQL-HA.ps1 -ResourceGroupName "rg-saif-pgsql-swc-01"
```

#### 2. Trigger Failover

```powershell
# Forced failover
az postgres flexible-server restart `
    --resource-group "rg-saif-pgsql-swc-01" `
    --name $postgresServerName `
    --failover Forced
```

#### 3. Monitor Recovery

Watch the monitoring dashboard for:
- Database availability (goes offline, then recovers)
- Zone switch (Primary Zone 1 → Zone 2)
- HA state transitions
- Transaction count continuity

---

## Monitoring

### Real-Time Dashboard

Start the PowerShell monitoring dashboard:

```powershell
.\scripts\Monitor-PostgreSQL-HA.ps1 -ResourceGroupName "rg-saif-pgsql-swc-01"
```

**Features:**

- Real-time server status
- HA state and zone configuration
- Database availability and response time
- Active connections
- Transaction throughput (TPS)
- SLA metrics (RPO/RTO)

Press `Ctrl+C` to exit.

### Azure Portal Monitoring

1. **Navigate to PostgreSQL Server**
   - Azure Portal → Resource Group → PostgreSQL Server

2. **Key Metrics to Monitor**
   - **High Availability**: Overview blade shows HA status and zones
   - **Metrics**: CPU, Memory, Storage, Connections, IOPS
   - **Alerts**: Configure alerts for HA state changes
   - **Activity Log**: Track failover events

3. **Application Insights**
   - API response times
   - Dependency tracking (PostgreSQL calls)
   - Failed requests
   - Exception tracking

### Log Analytics Queries

```kusto
# Database connection failures
AppExceptions
| where TimeGenerated > ago(1h)
| where Message contains "PostgreSQL" or Message contains "database"
| project TimeGenerated, Message, SeverityLevel
| order by TimeGenerated desc

# API performance
AppRequests
| where TimeGenerated > ago(1h)
| summarize 
    Count=count(),
    AvgDuration=avg(DurationMs),
    P95Duration=percentile(DurationMs, 95)
    by Name
| order by Count desc
```

---

## Quick Scripts for Common Tasks

### Rebuild Containers Only

If you need to update application code without redeploying infrastructure:

```powershell
# Use the dedicated container rebuild script
cd c:\Repos\SAIF\SAIF-pgsql\scripts
.\Rebuild-SAIF-Containers.ps1 -resourceGroupName "rg-saif-pgsql-swc-01"
```

Or manually:

```powershell
# Get ACR name
$acrName = az acr list --resource-group "rg-saif-pgsql-swc-01" --query "[0].name" -o tsv

# Build and push both containers
az acr build --registry $acrName --image saif/api:latest --file api\Dockerfile api\
az acr build --registry $acrName --image saif/web:latest --file web\Dockerfile web\

# Restart App Services
$apiAppName = az webapp list --resource-group "rg-saif-pgsql-swc-01" --query "[?contains(name, 'api')].name" -o tsv
$webAppName = az webapp list --resource-group "rg-saif-pgsql-swc-01" --query "[?contains(name, 'web')].name" -o tsv

az webapp restart --name $apiAppName --resource-group "rg-saif-pgsql-swc-01"
az webapp restart --name $webAppName --resource-group "rg-saif-pgsql-swc-01"
```

### Quick Deployment (New Environment)

For rapid deployment of a complete environment:

```powershell
cd c:\Repos\SAIF\SAIF-pgsql\scripts

# Use the quick-start script
.\Quick-Deploy-SAIF.ps1 `
    -location "swedencentral" `
    -environmentName "dev"
```

This script automates:
- Password generation (or accepts custom password)
- Full infrastructure deployment
- Container builds
- Health checks
- Output summary with all URLs and credentials

### Update Existing Deployment

To update just the infrastructure (no container rebuild):

```powershell
cd c:\Repos\SAIF\SAIF-pgsql\scripts

$password = ConvertTo-SecureString "YourExistingPassword123!" -AsPlainText -Force
.\Deploy-SAIF-PostgreSQL.ps1 `
    -location "swedencentral" `
    -postgresqlPassword $password `
    -skipContainers `
    -autoApprove
```

---

## Troubleshooting

### Common Issues

#### 0. Deployment Errors - "Content Already Consumed"

**Symptoms:**
- Deployment fails with: `ERROR: The content for this response was already consumed`
- Occurs when passing password parameter to Azure CLI

**Solutions:**

The automated script (`Deploy-SAIF-PostgreSQL.ps1`) already handles this by using a temporary parameters file. If deploying manually, use the parameter file approach:

```powershell
# Instead of passing password directly:
# az deployment group create --parameters postgresAdminPassword=$password  # ❌ FAILS

# Use a parameters file:
$tempParamsFile = [System.IO.Path]::GetTempFileName() + ".json"
@{
    '$schema' = 'https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#'
    contentVersion = '1.0.0.0'
    parameters = @{
        postgresAdminPassword = @{ value = $password }
    }
} | ConvertTo-Json -Depth 10 | Set-Content $tempParamsFile -Encoding UTF8

az deployment group create --parameters $tempParamsFile  # ✅ WORKS
Remove-Item $tempParamsFile -Force
```

#### 1. Key Vault Conflicts - Soft Delete

**Symptoms:**
- Deployment fails with: `The property "enablePurgeProtection" cannot be set to false`
- Key Vault with same name exists in soft-deleted state

**Solutions:**

The automated script handles this with unique timestamp-based suffixes. If you encounter this:

```powershell
# List soft-deleted Key Vaults
az keyvault list-deleted --query "[].{Name:name, Location:properties.location}" -o table

# Option 1: Wait for soft-delete retention (7 days) or delete resource group completely
az group delete --name $resourceGroupName --yes --no-wait

# Option 2: Recover the vault (if same name is acceptable)
az keyvault recover --name $keyVaultName --location $location

# Option 3: Use the automated script which generates unique names
.\Deploy-SAIF-PostgreSQL.ps1 -location "swedencentral"  # Uses timestamp suffix
```

#### 2. Database Connection Failures

**Symptoms:**
- API health check fails
- "could not connect to server" errors

**Solutions:**

```powershell
# Check PostgreSQL firewall rules
az postgres flexible-server firewall-rule list `
    --resource-group $resourceGroupName `
    --name $postgresServerName

# Add your IP
$myIp = (Invoke-WebRequest -Uri "https://api.ipify.org").Content
az postgres flexible-server firewall-rule create `
    --resource-group $resourceGroupName `
    --name $postgresServerName `
    --rule-name "AllowMyIP" `
    --start-ip-address $myIp `
    --end-ip-address $myIp

# Verify connection
psql -h $postgresServerFqdn -U saifadmin -d saifdb -c "SELECT 1;"
```

#### 2. Container Build Failures

**Symptoms:**
- ACR build fails
- "no space left on device"

**Solutions:**

```powershell
# Check ACR quota
az acr show-usage --name $acrName --resource-group $resourceGroupName

# Clean up old images
az acr repository list --name $acrName
az acr repository delete --name $acrName --repository saif/api:old --yes

# Retry build with verbose logging
az acr build --registry $acrName --image saif/api:latest --file api/Dockerfile api/ --verbose
```

#### 3. App Service Not Starting / Container Issues

**Symptoms:**
- App Service shows "Service Unavailable"
- Container logs show `ImagePullFailure` or "manifest not found"
- Deployment succeeded but App Services won't start

**Root Cause:**
The deployment script builds containers AFTER creating App Services. If the script is interrupted or if you used `-skipContainers`, App Services will try to pull images that don't exist yet.

**Solutions:**

```powershell
# Method 1: Check if containers exist in ACR
az acr repository list --name <acrName> --output table

# Method 2: If containers missing, build them manually
cd c:\Repos\SAIF\SAIF-pgsql

az acr build --registry <acrName> --image saif/api:latest --file api\Dockerfile api\
az acr build --registry <acrName> --image saif/web:latest --file web\Dockerfile web\

# Method 3: Restart App Services after building containers
az webapp restart --name <apiAppName> --resource-group <resourceGroupName>
az webapp restart --name <webAppName> --resource-group <resourceGroupName>

# Wait 2-3 minutes for container startup, then test
Invoke-RestMethod -Uri "https://<apiAppName>.azurewebsites.net/api/healthcheck"

# Method 4: Check App Service logs for detailed errors
az webapp log tail --name $apiAppName --resource-group $resourceGroupName

# Method 5: Check environment variables are set correctly
az webapp config appsettings list `
    --name $apiAppName `
    --resource-group $resourceGroupName

# Method 6: Enable diagnostic logging for troubleshooting
az webapp log config `
    --name $apiAppName `
    --resource-group $resourceGroupName `
    --docker-container-logging filesystem
```

**Prevention:**
Always let the deployment script complete all steps. If you need to skip containers initially, use the container rebuild script (see Quick Scripts section) to build and deploy them later.

#### 4. HA Not Healthy

**Symptoms:**
- HA state shows "CreatingStandby" or "ReplicatingData" for extended period
- Failover test fails

**Solutions:**

```powershell
# Check HA status
az postgres flexible-server show `
    --resource-group $resourceGroupName `
    --name $postgresServerName `
    --query "{state:state, haMode:highAvailability.mode, haState:highAvailability.state, primaryZone:availabilityZone, standbyZone:highAvailability.standbyAvailabilityZone}"

# Check activity log
az monitor activity-log list `
    --resource-group $resourceGroupName `
    --resource-id "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.DBforPostgreSQL/flexibleServers/$postgresServerName" `
    --start-time (Get-Date).AddHours(-24) `
    --query "[?level=='Error' || level=='Warning'].{Time:eventTimestamp, Level:level, Message:properties.message}" `
    --output table

# If HA is stuck, contact Azure support
```

#### 5. High Costs

**Expected Costs:**
- **Development**: ~$250/month (HA disabled, B-series compute)
- **Production**: ~$910/month (Zone-redundant HA, D4ds_v5 compute)

**Cost Optimization:**

```powershell
# Stop when not in use (CAUTION: Downtime)
az postgres flexible-server stop `
    --resource-group $resourceGroupName `
    --name $postgresServerName

# Scale down compute
az postgres flexible-server update `
    --resource-group $resourceGroupName `
    --name $postgresServerName `
    --tier Burstable `
    --sku-name Standard_B2s

# Disable HA for development
az postgres flexible-server update `
    --resource-group $resourceGroupName `
    --name $postgresServerName `
    --high-availability Disabled

# Delete when not needed
az group delete --name $resourceGroupName --yes --no-wait
```

### Getting Help

- **Azure Support**: [https://azure.microsoft.com/support/](https://azure.microsoft.com/support/)
- **PostgreSQL Docs**: [https://docs.microsoft.com/azure/postgresql/](https://docs.microsoft.com/azure/postgresql/)
- **GitHub Issues**: Submit issues to the SAIF repository

---

## Security Considerations

⚠️ **IMPORTANT**: This application contains **intentional security vulnerabilities** for educational purposes.

### Known Vulnerabilities

1. **SQL Injection**: `/api/vulnerable/sql-version` endpoint
2. **SSRF**: `/api/vulnerable/curl-url` endpoint
3. **Information Disclosure**: `/api/vulnerable/print-env` endpoint
4. **Weak Authentication**: Hardcoded API keys
5. **Permissive CORS**: Allow-Origin set to *

### DO NOT USE IN PRODUCTION

- Never deploy with real customer data
- Never use in production environments
- Always use for educational/testing purposes only
- Change all passwords and secrets after testing

### Security Hardening (If Adapting for Production)

1. **Remove vulnerable endpoints**
2. **Implement proper authentication** (OAuth 2.0, Azure AD)
3. **Use parameterized queries** (already used in safe endpoints)
4. **Restrict CORS** to specific domains
5. **Enable SSL/TLS** everywhere
6. **Use Azure Key Vault** for secrets (infrastructure supports this)
7. **Enable Azure DDoS Protection**
8. **Implement rate limiting**
9. **Enable audit logging**
10. **Regular security audits**

---

## Next Steps

1. ✅ Deploy to Azure
2. ✅ Run failover test
3. ✅ Monitor HA status
4. ✅ Generate load and test performance
5. ✅ Explore educational vulnerabilities
6. ✅ Learn about PostgreSQL HA architecture
7. ✅ Understand RTO/RPO metrics

## Additional Resources

- [Azure PostgreSQL HA Documentation](https://learn.microsoft.com/azure/postgresql/flexible-server/concepts-high-availability)
- [Bicep Language Reference](https://learn.microsoft.com/azure/azure-resource-manager/bicep/)
- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [PostgreSQL 16 Documentation](https://www.postgresql.org/docs/16/)

---

**Questions or Issues?** Check the [main README](../../README.md) or [documentation index](../README.md) or create a GitHub issue.
