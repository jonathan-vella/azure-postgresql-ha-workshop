# SAIF Deployment Guide

## 🚀 Fully Automated Deployment Options

SAIF provides **true 1-click deployment** with complete automation including infrastructure, container builds, and configuration.

### Option 1: PowerShell Script (🏆 Recommended - 100% Automated)

**Complete end-to-end deployment in one command:**

```powershell
# Clone and deploy everything
git clone https://github.com/jonathan-vella/SAIF.git
cd SAIF
.\scripts\Deploy-SAIF-Complete.ps1
```

**✅ What this automates:**
- ✅ Resource group creation
- ✅ All Azure infrastructure (ACR, App Services, SQL, Monitoring)
- ✅ Managed identities and RBAC permissions
- ✅ Application Insights configuration
- ✅ Container builds and pushes
- ✅ App Service restarts and validation
- ✅ P1v3 SKU and Always On configuration

**⏱️ Total time:** ~15-20 minutes

### Option 2: Deploy to Azure Button + Container Build

For Azure Portal enthusiasts:

**Step 1:** Deploy infrastructure via Azure Portal
[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fjonathan-vella%2FSAIF%2Fmain%2Finfra%2Fazuredeploy.json)

**Step 2:** Build and deploy containers
```powershell
git clone https://github.com/jonathan-vella/SAIF.git
cd SAIF
.\scripts\Update-SAIF-Containers.ps1
```

[![Visualize](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/visualizebutton.svg?sanitize=true)](http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2Fjonathan-vella%2FSAIF%2Fmain%2Finfra%2Fazuredeploy.json)

## 📋 What Gets Deployed (Fully Automated)

The automated deployment creates a complete hackathon environment:

### 🏗️ Infrastructure (All Automated)
- **Resource Group**: `rg-saif-swc01` (Sweden Central) or `rg-saif-gwc01` (Germany West Central)
- **Azure Container Registry**: Standard SKU with managed identity authentication
- **App Service Plan**: Linux Premium P1v3 tier with Always On enabled
- **API App Service**: Python FastAPI backend with managed identity
- **Web App Service**: PHP frontend with managed identity
- **Azure SQL Server**: With admin authentication configured
- **Azure SQL Database**: S1 tier, ready for application data
- **Log Analytics Workspace**: Centralized logging and monitoring
- **Application Insights**: Connected to both App Services with automatic instrumentation

### 🔐 Security Configuration (All Automated)
- **Managed Identities**: System-assigned identities for both App Services
- **RBAC Permissions**: AcrPull roles automatically assigned to managed identities
- **ACR Authentication**: Configured to use managed identity (no admin credentials)
- **Application Insights**: Connection strings automatically configured
- **SQL Authentication**: Configured for educational vulnerability demonstration

### 🐳 Container Deployment (Automated via PowerShell)
- **API Container**: Built from `./api` and pushed as `saif/api:latest`
- **Web Container**: Built from `./web` and pushed as `saif/web:latest`
- **App Service Configuration**: Containers automatically configured and started

## 🛠️ Available Scripts

### Primary Deployment Scripts

| Script | Purpose | Automation Level |
|--------|---------|------------------|
| **`Deploy-SAIF-Complete.ps1`** | Full deployment including containers | 🟢 **100% Automated** |
| **`Update-SAIF-Containers.ps1`** | Update containers only | 🟢 **100% Automated** |

### Script Examples

**Complete deployment:**
```powershell
# Deploy everything to Sweden Central
.\scripts\Deploy-SAIF-Complete.ps1

# Deploy to Germany West Central
.\scripts\Deploy-SAIF-Complete.ps1 -location "germanywestcentral"

# Deploy infrastructure only (skip containers)
.\scripts\Deploy-SAIF-Complete.ps1 -skipContainers
```

**Container updates only:**
```powershell
# Update both containers
.\scripts\Update-SAIF-Containers.ps1

# Update only API container
.\scripts\Update-SAIF-Containers.ps1 -buildApi

# Update only Web container  
.\scripts\Update-SAIF-Containers.ps1 -buildWeb

# Deploy to different region
.\scripts\Update-SAIF-Containers.ps1 -location "germanywestcentral"
```

## 🔄 Container Updates

After making changes to your application code, update containers easily:

```powershell
# Update both containers
.\scripts\Update-SAIF-Containers.ps1

# Update only API container
.\scripts\Update-SAIF-Containers.ps1 -buildApi

# Update only Web container  
.\scripts\Update-SAIF-Containers.ps1 -buildWeb
```

**What this automates:**
- ✅ Builds containers from source code
- ✅ Pushes to Azure Container Registry
- ✅ Restarts App Services to pull new images
- ✅ Validates deployment

## 📍 Deployment Regions

Choose from supported regions:
- **Sweden Central** (`swedencentral`) - Default
- **Germany West Central** (`germanywestcentral`)

## 🔧 Prerequisites

### For PowerShell Automation (Recommended):
- ✅ Azure CLI installed and logged in (`az login`)
- ✅ PowerShell 5.1+ or PowerShell Core 7+
- ✅ Docker (for container builds)
- ✅ Git (for repository cloning)

### For Deploy to Azure Button:
- ✅ Azure subscription with Contributor access
- ✅ Browser access to Azure Portal
- ✅ PowerShell + Azure CLI (for follow-up container build)

### Automatic Validation:
Both deployment methods include automatic prerequisite checking and clear error messages.

## 🎯 Post-Deployment

After successful deployment, you'll receive output like:

```
🎉 SAIF Deployment Complete!
Resource Group: rg-saif-swc01
API URL: https://app-saif-api-axxq5b.azurewebsites.net
Web URL: https://app-saif-web-axxq5b.azurewebsites.net
```

### ✅ Automatic Configuration Verification
- **Managed Identity Authentication**: ✅ Configured
- **Container Registry Access**: ✅ Verified
- **Application Insights**: ✅ Connected
- **Always On**: ✅ Enabled
- **P1v3 Performance Tier**: ✅ Configured

### 🌐 Access Your Application
1. **Web Interface**: Visit the Web URL for the diagnostic dashboard
2. **API Documentation**: Visit `{API_URL}/docs` for interactive API documentation
3. **Monitoring**: Application Insights automatically collects telemetry
4. **Database**: SQL Server accessible from App Services with pre-configured credentials

## 📊 Monitoring

Access monitoring data through:
- **Application Insights**: Performance and error tracking
- **Log Analytics**: Detailed logging and queries
- **Azure Portal**: Resource health and metrics

## 🧹 Cleanup

To remove all resources:

```powershell
# Delete entire resource group (WARNING: This deletes everything!)
az group delete --name rg-saif-swc01 --yes --no-wait
```

## 🔍 Troubleshooting

### Common Issues

**Container Build Fails**
```powershell
# Check Docker is running
docker version

# Verify Azure CLI login
az account show
```

**App Service Shows "Application Error"**
```powershell
# Check container logs
az webapp log tail --name your-app-name --resource-group rg-saif-swc01

# Verify container registry permissions
az role assignment list --assignee $(az webapp identity show --name your-app-name --resource-group rg-saif-swc01 --query principalId -o tsv)
```

**SQL Connection Issues**
- Verify firewall rules allow Azure services
- Check connection string configuration
- Confirm SQL admin credentials

### Support
For deployment issues, check:
1. [Azure Resource Group Activity Log](https://portal.azure.com)
2. Application Insights for runtime errors
3. Container Registry build history

## 📈 Scaling

The deployment uses Basic tier services suitable for development and training. For production use:

- Upgrade App Service Plan to Standard or Premium
- Consider Azure SQL Database scaling options
- Add Azure Front Door for global distribution
- Implement proper security configurations

---

**Ready to deploy?** Click the "Deploy to Azure" button at the top of this page!
