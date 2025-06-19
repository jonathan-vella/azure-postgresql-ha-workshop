<#
.SYNOPSIS
    Updates SAIF container images in Azure Container Registry.
.DESCRIPTION
    This script builds and pushes updated container images to Azure Container Registry
    and restarts the App Services to pull the new images.
.PARAMETER resourceGroupName
    The name of the resource group containing the SAIF deployment.
.PARAMETER acrName
    The name of the Azure Container Registry. If not provided, will auto-detect.
.PARAMETER buildApi
    Whether to build and push the API container. Default is $true.
.PARAMETER buildWeb
    Whether to build and push the Web container. Default is $true.
.EXAMPLE
    .\Update-SAIF-Containers.ps1 -resourceGroupName "rg-saif-swc01"
.EXAMPLE
    .\Update-SAIF-Containers.ps1 -resourceGroupName "rg-saif-swc01" -buildApi $false
.NOTES
    Author: SAIF Team
    Version: 1.0.0
    Date: 2025-06-19
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$resourceGroupName,
    
    [Parameter(Mandatory=$false)]
    [string]$acrName,
    
    [Parameter(Mandatory=$false)]
    [bool]$buildApi = $true,
    
    [Parameter(Mandatory=$false)]
    [bool]$buildWeb = $true
)

# Function to display a banner with a message
function Show-Banner {
    param([string]$message)
    $border = "=" * ($message.Length + 4)
    Write-Host ""
    Write-Host $border -ForegroundColor Magenta
    Write-Host "| $message |" -ForegroundColor White -BackgroundColor DarkBlue
    Write-Host $border -ForegroundColor Magenta
    Write-Host ""
}

Show-Banner "SAIF Container Update"

# Check if user is logged in to Azure
try {
    $currentUser = az account show --query "user.name" -o tsv 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Not logged in"
    }
    Write-Host "Logged in as: $currentUser" -ForegroundColor Green
} 
catch {
    Write-Host "Please log in to Azure first: az login" -ForegroundColor Red
    exit 1
}

# Verify resource group exists
Write-Host "Checking resource group '$resourceGroupName'..." -ForegroundColor Cyan
$rgExists = az group exists --name $resourceGroupName
if ($rgExists -eq "false") {
    Write-Host "Resource group '$resourceGroupName' not found!" -ForegroundColor Red
    exit 1
}
Write-Host "Resource group found." -ForegroundColor Green

# Auto-detect ACR name if not provided
if (-not $acrName) {
    Write-Host "Auto-detecting Azure Container Registry..." -ForegroundColor Cyan
    $acrs = az acr list --resource-group $resourceGroupName --query "[].name" -o tsv
    if (-not $acrs) {
        Write-Host "No Azure Container Registry found in resource group '$resourceGroupName'!" -ForegroundColor Red
        exit 1
    }
    
    # Take the first ACR if multiple exist
    $acrName = ($acrs -split "`n")[0]
    Write-Host "Using Container Registry: $acrName" -ForegroundColor Green
}

# Get App Service names for restart
Write-Host "Getting App Service names..." -ForegroundColor Cyan
$appServices = az webapp list --resource-group $resourceGroupName --query "[].name" -o tsv
$apiAppService = ($appServices -split "`n") | Where-Object { $_ -like "*api*" } | Select-Object -First 1
$webAppService = ($appServices -split "`n") | Where-Object { $_ -like "*web*" } | Select-Object -First 1

Write-Host "API App Service: $apiAppService" -ForegroundColor White
Write-Host "Web App Service: $webAppService" -ForegroundColor White

# Verify Docker context paths
$apiPath = Join-Path -Path $PSScriptRoot -ChildPath "..\api"
$webPath = Join-Path -Path $PSScriptRoot -ChildPath "..\web"

if ($buildApi -and -not (Test-Path $apiPath)) {
    Write-Host "API directory not found at: $apiPath" -ForegroundColor Red
    $buildApi = $false
}

if ($buildWeb -and -not (Test-Path $webPath)) {
    Write-Host "Web directory not found at: $webPath" -ForegroundColor Red
    $buildWeb = $false
}

# Build and push containers
if ($buildApi) {
    Write-Host "`nBuilding and pushing API container..." -ForegroundColor Yellow
    Write-Host "Registry: $acrName" -ForegroundColor DarkGray
    Write-Host "Image: saif/api:latest" -ForegroundColor DarkGray
    Write-Host "Source: $apiPath" -ForegroundColor DarkGray
    
    az acr build --registry $acrName --image saif/api:latest --file "$apiPath/Dockerfile" $apiPath
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ API container updated successfully!" -ForegroundColor Green
        
        if ($apiAppService) {
            Write-Host "Restarting API App Service..." -ForegroundColor Yellow
            az webapp restart --name $apiAppService --resource-group $resourceGroupName
            Write-Host "✓ API App Service restarted!" -ForegroundColor Green
        }
    } else {
        Write-Host "✗ Failed to update API container!" -ForegroundColor Red
    }
}

if ($buildWeb) {
    Write-Host "`nBuilding and pushing Web container..." -ForegroundColor Yellow
    Write-Host "Registry: $acrName" -ForegroundColor DarkGray
    Write-Host "Image: saif/web:latest" -ForegroundColor DarkGray
    Write-Host "Source: $webPath" -ForegroundColor DarkGray
    
    az acr build --registry $acrName --image saif/web:latest --file "$webPath/Dockerfile" $webPath
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Web container updated successfully!" -ForegroundColor Green
        
        if ($webAppService) {
            Write-Host "Restarting Web App Service..." -ForegroundColor Yellow
            az webapp restart --name $webAppService --resource-group $resourceGroupName
            Write-Host "✓ Web App Service restarted!" -ForegroundColor Green
        }
    } else {
        Write-Host "✗ Failed to update Web container!" -ForegroundColor Red
    }
}

Write-Host "`nContainer update process complete!" -ForegroundColor Cyan

# Show App Service URLs
if ($apiAppService) {
    Write-Host "API URL: https://$apiAppService.azurewebsites.net" -ForegroundColor White
}
if ($webAppService) {
    Write-Host "Web URL: https://$webAppService.azurewebsites.net" -ForegroundColor White
}
