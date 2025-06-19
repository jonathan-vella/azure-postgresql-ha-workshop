<#
.SYNOPSIS
    Complete SAIF deployment including infrastructure and containers.
.DESCRIPTION
    This script deploys the complete SAIF application to Azure including:
    1. Infrastructure deployment using Bicep
    2. Container building and pushing to ACR
    3. App Service configuration and restart
.PARAMETER location
    The Azure region to deploy resources to. Default is 'swedencentral'.
.PARAMETER resourceGroupName
    Optional. The name of the resource group to deploy to. Defaults to region-specific naming.
.PARAMETER skipContainers
    Skip container building and pushing (infrastructure only).
.EXAMPLE
    .\Deploy-SAIF-Complete.ps1 -location "swedencentral"
.EXAMPLE
    .\Deploy-SAIF-Complete.ps1 -location "germanywestcentral" -skipContainers
.NOTES
    Author: SAIF Team
    Version: 2.0.0
    Date: 2025-06-19
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("swedencentral", "germanywestcentral")]
    [string]$location = "swedencentral",
    
    [Parameter(Mandatory=$false)]
    [string]$resourceGroupName,
    
    [Parameter(Mandatory=$false)]
    [switch]$skipContainers
)

# Set resource group name based on location if not specified
if (-not $resourceGroupName) {
    if ($location -eq "swedencentral") {
        $resourceGroupName = "rg-saif-swc01"
    } else {
        $resourceGroupName = "rg-saif-gwc01"
    }
}

# Function to display banner
function Show-Banner {
    param([string]$message)
    $border = "=" * ($message.Length + 4)
    Write-Host ""
    Write-Host $border -ForegroundColor Cyan
    Write-Host "| $message |" -ForegroundColor White -BackgroundColor DarkBlue
    Write-Host $border -ForegroundColor Cyan
    Write-Host ""
}

# Check Azure CLI login
Show-Banner "SAIF Complete Deployment"
Write-Host "Checking Azure CLI login..." -ForegroundColor Yellow

try {
    $currentAccount = az account show --query "{name:name, user:user.name, id:id}" -o json | ConvertFrom-Json
    Write-Host "✅ Logged in as: $($currentAccount.user)" -ForegroundColor Green
    Write-Host "✅ Current Subscription: $($currentAccount.name)" -ForegroundColor Green
    Write-Host "   Subscription ID: $($currentAccount.id)" -ForegroundColor Gray
} catch {
    Write-Host "❌ Please run 'az login' first" -ForegroundColor Red
    exit 1
}

# Interactive configuration if parameters not provided
if (-not $PSBoundParameters.ContainsKey('location') -or -not $PSBoundParameters.ContainsKey('resourceGroupName')) {
    Write-Host ""
    Write-Host "🔧 Interactive Configuration" -ForegroundColor Cyan
    Write-Host "Configure your SAIF deployment settings:" -ForegroundColor White
    Write-Host ""
    
    # Subscription confirmation
    Write-Host "Current subscription:" -ForegroundColor Yellow
    Write-Host "  Name: $($currentAccount.name)" -ForegroundColor White
    Write-Host "  ID: $($currentAccount.id)" -ForegroundColor Gray
    $useCurrentSub = Read-Host "Use this subscription? (Y/n)"
    
    if ($useCurrentSub -eq 'n' -or $useCurrentSub -eq 'N') {
        Write-Host ""
        Write-Host "Available subscriptions:" -ForegroundColor Yellow
        az account list --query "[].{Name:name, Id:id, State:state}" -o table
        Write-Host ""
        $subId = Read-Host "Enter subscription ID to use"
        try {
            az account set --subscription $subId
            $currentAccount = az account show --query "{name:name, user:user.name, id:id}" -o json | ConvertFrom-Json
            Write-Host "✅ Switched to: $($currentAccount.name)" -ForegroundColor Green
        } catch {
            Write-Host "❌ Failed to switch subscription" -ForegroundColor Red
            exit 1
        }
    }
    
    # Region selection if not provided
    if (-not $PSBoundParameters.ContainsKey('location')) {
        Write-Host ""
        Write-Host "Available regions for SAIF:" -ForegroundColor Yellow
        Write-Host "  1. Sweden Central (swedencentral) - Recommended" -ForegroundColor White
        Write-Host "  2. Germany West Central (germanywestcentral)" -ForegroundColor White
        $regionChoice = Read-Host "Select region (1-2) [1]"
        
        switch ($regionChoice) {
            "2" { $location = "germanywestcentral" }
            default { $location = "swedencentral" }
        }
    }
    
    # Resource group configuration
    if (-not $PSBoundParameters.ContainsKey('resourceGroupName')) {
        $defaultRgName = if ($location -eq "swedencentral") { "rg-saif-swc01" } else { "rg-saif-gwc01" }
        Write-Host ""
        Write-Host "Resource Group Configuration:" -ForegroundColor Yellow
        $rgChoice = Read-Host "Resource group name [$defaultRgName]"
        $resourceGroupName = if ([string]::IsNullOrWhiteSpace($rgChoice)) { $defaultRgName } else { $rgChoice }
    }
    
    # Container build option
    if (-not $PSBoundParameters.ContainsKey('skipContainers')) {
        Write-Host ""
        Write-Host "Container Build Options:" -ForegroundColor Yellow
        Write-Host "  1. Full deployment (infrastructure + containers) - Recommended" -ForegroundColor White
        Write-Host "  2. Infrastructure only (skip container build)" -ForegroundColor White
        $containerChoice = Read-Host "Select option (1-2) [1]"
        $skipContainers = ($containerChoice -eq "2")
    }
}

# Confirm deployment parameters
Write-Host ""
Write-Host "📋 Final Deployment Configuration:" -ForegroundColor Cyan
Write-Host "  Subscription: $($currentAccount.name)" -ForegroundColor White
Write-Host "  Subscription ID: $($currentAccount.id)" -ForegroundColor Gray
Write-Host "  Region: $location" -ForegroundColor White
Write-Host "  Resource Group: $resourceGroupName" -ForegroundColor White
Write-Host "  Container Build: $(if ($skipContainers) { 'Skip' } else { 'Include' })" -ForegroundColor White
Write-Host ""

$confirm = Read-Host "Proceed with deployment? (y/N)"
if ($confirm -ne 'y' -and $confirm -ne 'Y') {
    Write-Host "Deployment cancelled." -ForegroundColor Yellow
    exit 0
}

# Step 1: Infrastructure Deployment
Show-Banner "Step 1: Infrastructure Deployment"

# Check if resource group exists
Write-Host "Checking resource group..." -ForegroundColor Yellow
$rgExists = az group exists --name $resourceGroupName -o tsv

if ($rgExists -eq "false") {
    Write-Host "Creating resource group: $resourceGroupName" -ForegroundColor Green
    az group create --name $resourceGroupName --location $location
} else {
    Write-Host "✅ Resource group exists: $resourceGroupName" -ForegroundColor Green
    
    # Check for existing resources
    Write-Host "Checking for existing resources..." -ForegroundColor Yellow
    try {
        $resourceListJson = az resource list --resource-group $resourceGroupName --output json
        $resourceArray = $resourceListJson | ConvertFrom-Json
        $existingResources = $resourceArray.Count
    } catch {
        Write-Host "⚠️  Unable to check existing resources, continuing..." -ForegroundColor Yellow
        $existingResources = 0
    }
    
    if ($existingResources -gt 0) {
        Write-Host "⚠️  Resource group contains $existingResources existing resources" -ForegroundColor Yellow
        $action = Read-Host "Choose action: (c)ontinue with Bicep deployment (idempotent), (d)elete all resources first, or (a)bort"
        
        switch ($action.ToLower()) {
            'd' {
                Write-Host "🗑️  Deleting all resources in $resourceGroupName..." -ForegroundColor Red
                az resource delete --ids $(az resource list --resource-group $resourceGroupName --query "[].id" -o tsv)
                Write-Host "✅ Resources deleted" -ForegroundColor Green
            }
            'a' {
                Write-Host "Deployment aborted." -ForegroundColor Yellow
                exit 0
            }
            'c' {
                Write-Host "Continuing with deployment..." -ForegroundColor Green
            }
            default {
                Write-Host "Invalid choice. Aborting." -ForegroundColor Red
                exit 1
            }
        }
    }
}

# Get SQL admin password
$sqlPassword = Read-Host "Enter SQL Admin Password (min 12 characters)" -AsSecureString
$sqlPasswordText = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sqlPassword))

if ($sqlPasswordText.Length -lt 12) {
    Write-Host "❌ Password must be at least 12 characters long" -ForegroundColor Red
    exit 1
}

# Deploy infrastructure
Write-Host "🚀 Deploying infrastructure..." -ForegroundColor Green
$deploymentName = "main-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$deploymentResult = az deployment group create `
    --resource-group $resourceGroupName `
    --template-file "../infra/main.bicep" `
    --parameters location=$location sqlAdminPassword=$sqlPasswordText `
    --name $deploymentName `
    --query "properties.provisioningState" -o tsv

if ($deploymentResult -ne "Succeeded") {
    Write-Host "❌ Infrastructure deployment failed" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Infrastructure deployed successfully!" -ForegroundColor Green

# Get deployment outputs
Write-Host "Retrieving deployment outputs..." -ForegroundColor Yellow
try {
    $outputs = az deployment group show --resource-group $resourceGroupName --name $deploymentName --query properties.outputs -o json | ConvertFrom-Json
    $acrName = $outputs.acrName.value
    $apiAppName = $outputs.apiAppServiceName.value
    $webAppName = $outputs.webAppServiceName.value
    $apiUrl = $outputs.apiUrl.value
    $webUrl = $outputs.webUrl.value
} catch {
    Write-Host "❌ Failed to retrieve deployment outputs" -ForegroundColor Red
    Write-Host "Deployment name: $deploymentName" -ForegroundColor Gray
    exit 1
}

Write-Host ""
Write-Host "📊 Deployment Outputs:" -ForegroundColor Cyan
Write-Host "  ACR Name: $acrName" -ForegroundColor White
Write-Host "  API App: $apiAppName" -ForegroundColor White
Write-Host "  Web App: $webAppName" -ForegroundColor White
Write-Host "  API URL: $apiUrl" -ForegroundColor White
Write-Host "  Web URL: $webUrl" -ForegroundColor White

# Validate required outputs for container build
if (-not $skipContainers) {
    if ([string]::IsNullOrWhiteSpace($acrName)) {
        Write-Host "❌ ACR name not found in deployment outputs" -ForegroundColor Red
        Write-Host "Skipping container build..." -ForegroundColor Yellow
        $skipContainers = $true
    }
}

# Step 2: Container Build and Deployment
if (-not $skipContainers) {
    Show-Banner "Step 2: Container Build & Deployment"
      Write-Host "🔨 Building and pushing API container..." -ForegroundColor Green
    az acr build --registry $acrName --image saif/api:latest ../api
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ API container built and pushed" -ForegroundColor Green
    } else {
        Write-Host "❌ API container build failed" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "🔨 Building and pushing Web container..." -ForegroundColor Green
    az acr build --registry $acrName --image saif/web:latest ../web
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Web container built and pushed" -ForegroundColor Green
    } else {
        Write-Host "❌ Web container build failed" -ForegroundColor Red
        exit 1
    }
    
    # Restart App Services to pull new images
    Write-Host "🔄 Restarting App Services..." -ForegroundColor Green
    az webapp restart --name $apiAppName --resource-group $resourceGroupName
    az webapp restart --name $webAppName --resource-group $resourceGroupName
    Write-Host "✅ App Services restarted" -ForegroundColor Green
} else {
    Write-Host "⏭️  Skipping container build and deployment" -ForegroundColor Yellow
}

# Final Summary
Show-Banner "🎉 SAIF Deployment Complete!"
Write-Host "Resource Group: $resourceGroupName" -ForegroundColor Green
Write-Host "API URL: $apiUrl" -ForegroundColor Green
Write-Host "Web URL: $webUrl" -ForegroundColor Green
Write-Host ""
Write-Host "🔗 Test your deployment by visiting the URLs above" -ForegroundColor Cyan
Write-Host "🔄 To update containers only, use: .\Update-SAIF-Containers.ps1" -ForegroundColor Cyan

# Clear sensitive data
$sqlPasswordText = $null
$sqlPassword = $null
