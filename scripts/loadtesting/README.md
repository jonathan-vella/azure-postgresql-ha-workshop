# Load Testing and Failover Testing

This folder contains all scripts and resources for App Service-based load testing and failover testing with RTO/RPO measurement for PostgreSQL High Availability.

## 📚 Documentation

**Start here for complete guides:**

- **[Load Testing Guide](../../docs/v1.0.0/load-testing-guide.md)** - Comprehensive guide for App Service load testing
- **[Failover Testing Quick Reference](../../docs/v1.0.0/failover-testing-quick-reference.md)** - RTO/RPO measurement guide

## 📁 File Structure

### Production Files (Active Use)

| File | Purpose |
|------|---------|
| `Dockerfile` | Multi-stage Docker build for .NET 8.0 web application |
| `Program.cs` | ASP.NET Core minimal API application with load testing logic |
| `LoadGeneratorWeb.csproj` | .NET 8.0 project file with Npgsql dependency |
| `LoadGenerator-Config.ps1` | Centralized configuration for all deployment scripts |
| `Build-LoadGenerator-Docker.ps1` | Build and push container image to Azure Container Registry |
| `Deploy-LoadGenerator-AppService.ps1` | Deploy, update, or delete App Service with load generator |
| `Monitor-AppService-Logs.ps1` | Stream real-time container logs from App Service |
| `Measure-Failover-RTO-RPO.ps1` | Measure RTO and RPO during manual PostgreSQL failover |

### Supporting Resources

| Folder/File | Purpose |
|-------------|---------|
| `archive/` | Superseded scripts and old versions (see [archive/README.md](archive/README.md)) |
| `libs/` | .NET libraries (Npgsql.dll, etc.) auto-installed by scripts |
| `loadtest-results/` | Output folder for test results (CSV, JSON files) |

## 🚀 Quick Start

### 1. Configure

Edit `LoadGenerator-Config.ps1` with your environment details:

```powershell
$ResourceGroup = "rg-pgv2-usc01"
$PostgreSQL = @{
    Server   = "pg-cus"
    Database = "saifdb"
    Username = "jonathan"
}
```

### 2. Build Container

```powershell
.\Build-LoadGenerator-Docker.ps1
```

### 3. Deploy App Service

```powershell
.\Deploy-LoadGenerator-AppService.ps1 -Action Deploy
```

### 4. Start Load Test

```powershell
# Via PowerShell
$appUrl = "https://app-loadgen-xxxxx.azurewebsites.net"
Invoke-RestMethod -Uri "$appUrl/start" -Method Post

# Via Browser
# Navigate to: https://app-loadgen-xxxxx.azurewebsites.net/start
```

### 5. Monitor Load Test

```powershell
# Stream logs
.\Monitor-AppService-Logs.ps1

# Check status
Invoke-RestMethod -Uri "$appUrl/status"
```

### 6. Measure Failover (Optional)

```powershell
.\Measure-Failover-RTO-RPO.ps1 `
    -AppServiceUrl $appUrl `
    -ResourceGroup "rg-pgv2-usc01" `
    -ServerName "pg-cus" `
    -DatabaseName "saifdb" `
    -AdminUsername "jonathan"
```

## 📊 Architecture

**App Service-Based Load Testing:**
- Azure App Service on Linux (P0V3 SKU)
- .NET 8.0 compiled web application
- ASP.NET Core minimal API with HTTP endpoints
- System-assigned Managed Identity for ACR authentication
- Application Insights for immediate telemetry (no LAW delay)
- PostgreSQL connections via Npgsql

**HTTP API Endpoints:**
- `GET /health` - Health check
- `GET /status` - Test status and metrics
- `POST /start` - Start load test
- `GET /logs` - Test execution logs

## 🎯 Key Features

### Load Testing
- **Target**: Configurable TPS (transactions per second)
- **Duration**: Configurable test duration
- **Workers**: Parallel worker count for concurrent connections
- **Monitoring**: Real-time metrics via HTTP API
- **Telemetry**: Immediate Application Insights logging
- **Database**: Real INSERT transactions with customer/merchant/amount data

### Failover Testing
- **RTO Measurement**: Time from connection loss to restoration (target: < 30 seconds)
- **RPO Measurement**: Data loss calculation (target: 0 transactions)
- **Probing**: 1-second interval connection tests
- **Reporting**: Real-time status table, CSV metrics, JSON summary
- **Pass/Fail**: Automated validation against targets

## 🔧 Configuration Reference

See `LoadGenerator-Config.ps1` for all configurable parameters:

- Resource Group and location
- PostgreSQL server details
- Container Registry settings
- App Service configuration (SKU, scaling)
- Load test parameters (TPS, workers, duration)
- Application Insights workspace

## 📖 Detailed Documentation

For complete step-by-step instructions, troubleshooting, and advanced usage:

1. **[Load Testing Guide](../../docs/v1.0.0/load-testing-guide.md)** (~1000 lines)
   - Prerequisites
   - Deployment steps
   - Running tests
   - Monitoring (App Insights, Portal, Log Analytics)
   - Database verification
   - Troubleshooting
   - Configuration reference

2. **[Failover Testing Quick Reference](../../docs/v1.0.0/failover-testing-quick-reference.md)** (~300 lines)
   - Quick start
   - Manual failover methods
   - Script parameters
   - Output interpretation
   - Troubleshooting
   - Advanced usage

## 🗂️ Archive

Old scripts and superseded files are in the `archive/` folder. See [archive/README.md](archive/README.md) for details on:
- What was archived and why
- Architecture evolution (ACI → App Service, scripts → compiled app)
- Version history

**Always use the production scripts above, not archived versions.**

## ⚙️ Requirements

- **Azure CLI**: Latest version
- **PowerShell**: 7.0 or higher
- **Docker** (optional): Only needed for local builds
- **Azure Resources**:
  - PostgreSQL Flexible Server with HA enabled
  - Container Registry (auto-created if needed)
  - Log Analytics Workspace
  - Resource Group

## 🆘 Troubleshooting

### Container Won't Start
```powershell
# Check logs
.\Monitor-AppService-Logs.ps1

# Common issue: Managed Identity permissions
# Solution: Redeploy to recreate identity and permissions
.\Deploy-LoadGenerator-AppService.ps1 -Action Update
```

### Load Test Not Running
```powershell
# Check status
Invoke-RestMethod -Uri "$appUrl/status"

# Check database connectivity from App Service
# Navigate to: https://portal.azure.com → App Service → SSH/Console
# Run: curl http://localhost/health
```

### No Transactions in Database
```powershell
# Verify transactions table exists
psql -h pg-cus.postgres.database.azure.com -U jonathan -d saifdb -c "SELECT COUNT(*) FROM transactions;"

# Check if actual INSERTs are happening (not just SELECT 1)
# Review Program.cs for: INSERT INTO transactions ...
```

For more troubleshooting, see the full guides linked above.

## 📝 Version History

- **2025-10-16**: Cleanup and consolidation
  - Moved Dockerfile into loadtesting folder
  - Archived superseded scripts
  - Created comprehensive documentation
  - Added RTO/RPO measurement script

- **2025-10-15**: App Service migration complete
  - Converted from C# scripts to compiled .NET 8.0 app
  - Fixed transaction INSERT logic
  - Validated 2.1M transactions, 0 errors
  - Added Application Insights integration

- **2025-10-09**: Initial App Service version
  - Migrated from ACI to App Service
  - Architecture change: console app → web service
  - .NET 6.0 → .NET 8.0 upgrade

---

**For questions or issues, refer to the comprehensive documentation guides above.**
