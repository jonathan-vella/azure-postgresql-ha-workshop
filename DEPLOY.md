# SAIF Deployment Guide

## 🚀 Quick Deploy to Azure

Deploy the complete SAIF hackathon environment with one click:

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fyour-username%2FSAIF%2Fmain%2Finfra%2Fazuredeploy.json)

[![Visualize](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/visualizebutton.svg?sanitize=true)](http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2Fyour-username%2FSAIF%2Fmain%2Finfra%2Fazuredeploy.json)

## 📋 What Gets Deployed

The one-click deployment creates:

### 🏗️ Infrastructure
- **Resource Group**: `rg-saif-swc01` (Sweden Central) or `rg-saif-gwc01` (Germany West Central)
- **Azure Container Registry**: Standard SKU for container images
- **App Service Plan**: Linux Basic B1 tier
- **API App Service**: For the Python FastAPI backend
- **Web App Service**: For the PHP frontend
- **Azure SQL Server**: With authentication configured
- **Azure SQL Database**: S1 tier, empty database ready for the application
- **Log Analytics Workspace**: For monitoring and diagnostics
- **Application Insights**: Connected to both App Services

### 🔐 Security Configuration
> **Note**: This environment is intentionally configured with minimal security for educational purposes

- Container Registry uses Azure AD authentication
- App Services have managed identities with ACR pull permissions
- SQL Server allows Azure services access
- SQL credentials are configured for educational vulnerability demonstration

## 🛠️ Deployment Options

### Option 1: One-Click Azure Portal Deploy
Use the "Deploy to Azure" button above for instant deployment through the Azure Portal.

### Option 2: PowerShell Script (Complete)
Deploy infrastructure and build containers in one command:

```powershell
# Clone the repository
git clone https://github.com/your-username/SAIF.git
cd SAIF

# Run complete deployment
.\scripts\Deploy-SAIF-Complete.ps1 -location "swedencentral"
```

### Option 3: PowerShell Script (Infrastructure Only)
Deploy just the infrastructure:

```powershell
.\scripts\Deploy-SAIF-Complete.ps1 -location "swedencentral" -skipContainers
```

### Option 4: Azure CLI
Manual deployment using Azure CLI:

```bash
# Create resource group
az group create --name rg-saif-swc01 --location swedencentral

# Deploy infrastructure
az deployment group create \
  --resource-group rg-saif-swc01 \
  --template-file infra/main.bicep \
  --parameters location=swedencentral sqlAdminPassword="YourSecurePassword123!"

# Build and push containers
ACR_NAME=$(az deployment group show --resource-group rg-saif-swc01 --name main --query properties.outputs.acrName.value -o tsv)
az acr build --registry $ACR_NAME --image saif/api:latest ./api
az acr build --registry $ACR_NAME --image saif/web:latest ./web

# Restart App Services
API_APP=$(az deployment group show --resource-group rg-saif-swc01 --name main --query properties.outputs.apiAppServiceName.value -o tsv)
WEB_APP=$(az deployment group show --resource-group rg-saif-swc01 --name main --query properties.outputs.webAppServiceName.value -o tsv)
az webapp restart --name $API_APP --resource-group rg-saif-swc01
az webapp restart --name $WEB_APP --resource-group rg-saif-swc01
```

## 🔄 Container Updates

After making changes to your application code, update just the containers:

```powershell
# Update both containers
.\scripts\Update-SAIF-Containers.ps1

# Update only API container
.\scripts\Update-SAIF-Containers.ps1 -buildApi

# Update only Web container  
.\scripts\Update-SAIF-Containers.ps1 -buildWeb
```

## 📍 Deployment Regions

Choose from supported regions:
- **Sweden Central** (`swedencentral`) - Default
- **Germany West Central** (`germanywestcentral`)

## 🔧 Prerequisites

### For One-Click Deploy:
- Azure subscription with Contributor access
- Browser access to Azure Portal

### For PowerShell Scripts:
- Azure CLI installed and logged in (`az login`)
- PowerShell 5.1 or PowerShell Core 7+
- Docker (for local testing)

### For Manual Deployment:
- Azure CLI 2.50.0+
- Bicep CLI (included with Azure CLI)

## 🎯 Post-Deployment

After successful deployment, you'll receive:

```
🎉 SAIF Deployment Complete!
Resource Group: rg-saif-swc01
API URL: https://app-saif-api-axxq5b.azurewebsites.net
Web URL: https://app-saif-web-axxq5b.azurewebsites.net
```

### Access Your Application
1. **Web Interface**: Visit the Web URL to access the diagnostic dashboard
2. **API Documentation**: Visit `{API_URL}/docs` for interactive API documentation
3. **Database**: SQL Server is accessible from the App Services using the configured credentials

### Verify Deployment
```powershell
# Test API health
Invoke-RestMethod -Uri "https://your-api-url.azurewebsites.net/health"

# Check App Service logs
az webapp log tail --name your-api-app --resource-group rg-saif-swc01
```

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
