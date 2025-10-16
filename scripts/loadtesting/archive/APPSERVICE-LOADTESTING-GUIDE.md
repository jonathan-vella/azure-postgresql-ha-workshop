# App Service LoadGenerator - Quick Reference Guide

## Overview
Complete load testing solution using Azure App Service with containerized LoadGenerator and Application Insights monitoring.

**Architecture:**
- Container Image: Stored in Azure Container Registry (ACR)
- Deployment: Azure App Service (P0 Linux)
- Monitoring: Application Insights (real-time logging)
- Database: Azure PostgreSQL HA (pg-cus.postgres.database.azure.com)

---

## Configuration

All deployment parameters are managed through `LoadGenerator-Config.ps1`:

```powershell
# Edit these values in LoadGenerator-Config.ps1
$AzureEnvironment = @{
    Region = "swedencentral"
    ResourceGroup = "rg-pgv2-usc01"
}

$AppServiceConfig = @{
    AppServiceName = "app-loadgen-001"
    AppServicePlan = "plan-loadgen-001"
    SKU = "P0"
    InstanceCount = 1
}

$ContainerRegistry = @{
    Name = "acrsaifpg10081025"
    ResourceGroup = "rg-saif-pgsql-swc-01"
    ImageName = "loadgenerator"
    ImageTag = "latest"
}

$PostgreSQLConfig = @{
    Server = "pg-cus.postgres.database.azure.com"
    Database = "saifdb"
    AdminUsername = "jonathan"
}

$LoadTestConfig = @{
    TargetTPS = 1000
    WorkerCount = 200
    TestDuration = 300
}
```

**To customize:**
1. Open `scripts/loadtesting/LoadGenerator-Config.ps1`
2. Update values for your environment
3. Scripts automatically load this configuration

---

## Prerequisites

✅ Azure CLI installed and authenticated
✅ Azure Container Registry: `acrsaifpg10081025` (Sweden Central)
✅ PostgreSQL HA environment configured
✅ Docker installed locally (for image testing)

---

## Step 1: Build LoadGenerator Docker Image

### Automatic (uses config file)

```powershell
.\scripts\loadtesting\Build-LoadGenerator-Docker.ps1
```

### Manual (override config)

```powershell
.\scripts\loadtesting\Build-LoadGenerator-Docker.ps1 `
    -ContainerRegistry "acrsaifpg10081025" `
    -ResourceGroup "rg-saif-pgsql-swc-01" `
    -ImageTag "1.0"
```

**Parameters:**
- `-ContainerRegistry`: ACR name (without .azurecr.io)
- `-ResourceGroup`: RG containing the ACR
- `-ImageTag`: Version tag (default: "latest")
- `-ImageName`: Image name in ACR (default: "loadgenerator")
- `-ConfigFile`: Config file path (default: "./LoadGenerator-Config.ps1")

**Output:**
- Image pushed to ACR
- Full image URI: `acrsaifpg10081025.azurecr.io/loadgenerator:1.0`

---

## Step 2: Deploy to App Service

### Automatic (uses config file)

```powershell
# Password will be prompted
.\scripts\loadtesting\Deploy-LoadGenerator-AppService.ps1 -Action Deploy
```

### Manual (override config)

```powershell
$password = Read-Host -AsSecureString -Prompt "PostgreSQL Password"

.\scripts\loadtesting\Deploy-LoadGenerator-AppService.ps1 `
    -Action Deploy `
    -ConfigFile "./LoadGenerator-Config.ps1"
```

**Actions:**
- `Deploy` - Create/configure App Service
- `Start` - Start container
- `Stop` - Stop container
- `Status` - Check deployment status
- `Delete` - Delete App Service

**What Deploy Does:**
1. ✅ Validates ACR and container image
2. ✅ Creates App Service Plan (configured SKU)
3. ✅ Creates Application Insights
4. ✅ Deploys App Service with container
5. ✅ Configures ACR authentication
6. ✅ Sets environment variables from config
7. ✅ Enables diagnostics logging
8. ✅ Scales App Service (if needed)

---

## Step 3: Monitor LoadGenerator

### Automatic (uses config file)

```powershell
.\scripts\loadtesting\Monitor-AppService-Logs.ps1
```

### Manual (override config)

```powershell
.\scripts\loadtesting\Monitor-AppService-Logs.ps1 `
    -AppServiceName "app-loadgen-001" `
    -ResourceGroup "rg-pgv2-usc01" `
    -WaitForCompletion $true
```

**Parameters:**
- `-AppServiceName`: App Service name
- `-ResourceGroup`: Azure Resource Group
- `-ApplicationInsightsName`: App Insights name (auto-generated if not provided)
- `-WaitForCompletion`: Wait for test to finish (default: $true)
- `-MaxWaitTime`: Max wait time in seconds (default: 3600)
- `-RefreshInterval`: Monitor refresh interval in seconds (default: 10)
- `-OutputPath`: Save results directory (default: ./loadtest-results)
- `-ConfigFile`: Config file path (default: "./LoadGenerator-Config.ps1")

**Output:**
- Real-time performance metrics (TPS, latency)
- Error logs and exceptions
- Failover event analysis
- RTO calculations
- Results saved to `loadtest-results/` folder

---

## App Service Actions

All actions use the config file automatically:

### Check Status
```powershell
.\scripts\loadtesting\Deploy-LoadGenerator-AppService.ps1 -Action Status
```

### Stop App Service
```powershell
.\scripts\loadtesting\Deploy-LoadGenerator-AppService.ps1 -Action Stop
```

### Start App Service
```powershell
.\scripts\loadtesting\Deploy-LoadGenerator-AppService.ps1 -Action Start
```

### Delete App Service
```powershell
.\scripts\loadtesting\Deploy-LoadGenerator-AppService.ps1 -Action Delete
```

---

## Environment Variables (Set Automatically)

These are configured in the App Service and passed to the container:

| Variable | Description | Example |
|----------|-------------|---------|
| POSTGRESQL_SERVER | PostgreSQL server FQDN | pg-cus.postgres.database.azure.com |
| POSTGRESQL_PORT | PostgreSQL port | 5432 |
| POSTGRESQL_DATABASE | Database name | saifdb |
| POSTGRESQL_USERNAME | Database username | jonathan |
| POSTGRESQL_PASSWORD | Database password | (from deployment) |
| TARGET_TPS | Target transactions/second | 1000 |
| WORKER_COUNT | Concurrent worker threads | 200 |
| TEST_DURATION | Test duration in seconds | 300 |
| APPLICATIONINSIGHTS_CONNECTION_STRING | App Insights connection | (automatic) |

---

## Output Files

Results are saved to `scripts/loadtesting/loadtest-results/`:

| File | Content |
|------|---------|
| `appservice_errors_TIMESTAMP.log` | Error logs and exceptions |
| `appservice_metrics_TIMESTAMP.csv` | Performance metrics |

---

## Performance Tuning

### Scale Up (More Resources)
```powershell
az appservice plan update `
    --name "plan-loadgen-001" `
    --resource-group "rg-pgv2-usc01" `
    --sku P0
```

### Scale Out (More Instances)
```powershell
az appservice plan update `
    --name "plan-loadgen-001" `
    --resource-group "rg-pgv2-usc01" `
    --number-of-workers 3
```

### Increase TPS/Workers
Modify environment variables in App Service:
```powershell
az webapp config appsettings set `
    --name "app-loadgen-001" `
    --resource-group "rg-pgv2-usc01" `
    --settings TARGET_TPS=2000 WORKER_COUNT=400
```

---

## Troubleshooting

### Container Not Starting
```powershell
# Check container logs
az webapp log tail --name "app-loadgen-001" --resource-group "rg-pgv2-usc01"

# Check diagnostics
az webapp diagnostic show --name "app-loadgen-001" --resource-group "rg-pgv2-usc01"
```

### Cannot Connect to PostgreSQL
- Verify PostgreSQL firewall allows App Service
- Check POSTGRESQL_PASSWORD is correct
- Verify POSTGRESQL_SERVER FQDN is correct

### Application Insights Not Collecting Logs
- Verify Application Insights is created
- Check connection string in app settings
- Ensure diagnostic logging is enabled

### ACR Authentication Failing
```powershell
# Re-enable ACR admin
az acr update --name "acrsaifpg10081025" --admin-enabled true

# Re-configure container settings
az webapp config container set `
    --name "app-loadgen-001" `
    --resource-group "rg-pgv2-usc01" `
    --docker-custom-image-name "acrsaifpg10081025.azurecr.io/loadgenerator:1.0" `
    --docker-registry-server-url "https://acrsaifpg10081025.azurecr.io" `
    --docker-registry-server-user $acrUser `
    --docker-registry-server-password $acrPassword
```

---

## Complete Workflow Example

```powershell
# 1. Build and push image (uses LoadGenerator-Config.ps1)
.\scripts\loadtesting\Build-LoadGenerator-Docker.ps1

# 2. Deploy to App Service (uses LoadGenerator-Config.ps1)
.\scripts\loadtesting\Deploy-LoadGenerator-AppService.ps1 -Action Deploy

# 3. Monitor in real-time (uses LoadGenerator-Config.ps1)
.\scripts\loadtesting\Monitor-AppService-Logs.ps1
```

**That's it!** All configuration is managed through `LoadGenerator-Config.ps1`.

---

## Using Custom Config File

```powershell
# Create your custom config
Copy-Item LoadGenerator-Config.ps1 LoadGenerator-Config-Custom.ps1

# Edit the custom config
notepad LoadGenerator-Config-Custom.ps1

# Use it with all scripts
.\scripts\loadtesting\Build-LoadGenerator-Docker.ps1 -ConfigFile ./LoadGenerator-Config-Custom.ps1
.\scripts\loadtesting\Deploy-LoadGenerator-AppService.ps1 -ConfigFile ./LoadGenerator-Config-Custom.ps1 -Action Deploy
.\scripts\loadtesting\Monitor-AppService-Logs.ps1 -ConfigFile ./LoadGenerator-Config-Custom.ps1
```

---

## Advantages Over ACI

| Feature | ACI | App Service |
|---------|-----|-------------|
| **Logging Delay** | 5-10 minutes | Immediate |
| **Scaling** | Manual container management | Auto-scaling available |
| **Monitoring** | Log Analytics (delayed) | Application Insights (real-time) |
| **Cost** | Per-second billing | Fixed + variable |
| **Ease of Use** | Simple but limited | Rich platform features |
| **Workshop Demo** | ✅ Works but requires wait | ✅ Immediate results |

---

## Related Documentation

- `CONNECTION-RTO-GUIDE.md` - RTO measurement methodology
- `Deploy-LoadGenerator-ACI.ps1` - ACI alternative (archived)
- `Run-LoadGenerator-Local.ps1` - Local Docker testing
- `Monitor-Transactions-Docker.ps1` - Real-time TPS monitoring
