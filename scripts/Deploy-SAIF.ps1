<#
.SYNOPSIS
    Deploys SAIF (Secure AI Foundations) to Azure App Service using Bicep.
.DESCRIPTION
    This script deploys the SAIF application to Azure using Bicep templates.
    It creates or uses an existing resource group, deploys the Bicep template,
    and builds and pushes container images to Azure Container Registry.
.PARAMETER resourceGroupName
    Optional. The name of the resource group to deploy to. Defaults to region-specific naming convention.
.PARAMETER location
    The Azure region to deploy resources to. Default is 'swedencentral'.
.PARAMETER environmentName
    Optional. The name of the environment. Default is 'saif'.
.EXAMPLE
    .\Deploy-SAIF.ps1 -location "swedencentral"
.EXAMPLE
    .\Deploy-SAIF.ps1 -resourceGroupName "myrg-saif" -location "germanywestcentral"
.NOTES
    Author: SAIF Team
    Version: 1.0.0
    Date: 2025-06-18
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$resourceGroupName,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("swedencentral", "germanywestcentral")]
    [string]$location = "swedencentral",
    
    [Parameter(Mandatory=$false)]
    [string]$environmentName = "saif"
)

# Default resource group name based on location if not specified
if (-not $resourceGroupName) {
    if ($location -eq "swedencentral") {
        $resourceGroupName = "rg-aiseclab-swc01"
    } else {
        $resourceGroupName = "rg-aiseclab-gwc01"
    }
}

# Ensure the user is logged in to Azure
Write-Host "Checking Azure login status..." -ForegroundColor Cyan
$loginStatus = az account show --query name -o tsv 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "Please log in to Azure first using 'az login'" -ForegroundColor Yellow
    az login
}

# Create resource group if it doesn't exist
Write-Host "Checking if resource group exists..." -ForegroundColor Cyan
$rgExists = az group exists --name $resourceGroupName
if ($rgExists -eq "false") {
    Write-Host "Creating resource group $resourceGroupName in $location..." -ForegroundColor Green
    az group create --name $resourceGroupName --location $location
}

# Deploy the Bicep template
Write-Host "Deploying infrastructure with Bicep..." -ForegroundColor Cyan
$deployment = az deployment group create `
    --resource-group $resourceGroupName `
    --template-file ../infra/main.bicep `
    --parameters environmentName=$environmentName location=$location `
    --output json | ConvertFrom-Json

if ($LASTEXITCODE -ne 0) {
    Write-Error "Bicep deployment failed. Please check the error messages above."
    exit 1
}

# Extract information from deployment outputs
Write-Host "Extracting deployment outputs..." -ForegroundColor Cyan
$acrLoginServer = $deployment.properties.outputs.acrLoginServer.value
$acrName = $deployment.properties.outputs.acrName.value
$apiAppServiceName = $deployment.properties.outputs.apiAppServiceName.value
$webAppServiceName = $deployment.properties.outputs.webAppServiceName.value

# Build and push container images to ACR
Write-Host "Building and pushing images to ACR..." -ForegroundColor Cyan

# API image
Write-Host "Building and pushing API image..." -ForegroundColor Green
az acr build --registry $acrName --image saif/api:latest --file ../api/Dockerfile ../api

# Web image
Write-Host "Building and pushing Web image..." -ForegroundColor Green
az acr build --registry $acrName --image saif/web:latest --file ../web/Dockerfile ../web

# Update App Services with the latest container images
Write-Host "Updating API App Service with the latest container image..." -ForegroundColor Cyan
az webapp config container set `
    --name $apiAppServiceName `
    --resource-group $resourceGroupName `
    --docker-custom-image-name "$acrLoginServer/saif/api:latest" `
    --docker-registry-server-url "https://$acrLoginServer"

Write-Host "Updating Web App Service with the latest container image..." -ForegroundColor Cyan
az webapp config container set `
    --name $webAppServiceName `
    --resource-group $resourceGroupName `
    --docker-custom-image-name "$acrLoginServer/saif/web:latest" `
    --docker-registry-server-url "https://$acrLoginServer"

# Restart App Services to apply changes
Write-Host "Restarting App Services..." -ForegroundColor Cyan
az webapp restart --name $apiAppServiceName --resource-group $resourceGroupName
az webapp restart --name $webAppServiceName --resource-group $resourceGroupName

# Display the URLs for the deployed applications
$apiUrl = "https://$apiAppServiceName.azurewebsites.net"
$webUrl = "https://$webAppServiceName.azurewebsites.net"

Write-Host ""
Write-Host "Deployment completed successfully!" -ForegroundColor Green
Write-Host "API URL: $apiUrl" -ForegroundColor Yellow
Write-Host "Web URL: $webUrl" -ForegroundColor Yellow
Write-Host ""
Write-Host "Note: It may take a few minutes for the containers to start up." -ForegroundColor Cyan
