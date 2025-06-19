<#
.SYNOPSIS
    Deploys SAIF (Secure AI Foundations) to Azure using Bicep.
.DESCRIPTION
    This script deploys the SAIF application to Azure using Bicep templates.
    It creates or uses an existing resource group, deploys the Bicep template,
    and builds and pushes container images to Azure Container Registry.
.PARAMETER location
    The Azure region to deploy resources to. Default is 'swedencentral'.
.PARAMETER deployContainers
    Whether to build and deploy container images. Default is $true.
.EXAMPLE
    .\Deploy-SAIF.ps1 -location "swedencentral"
.EXAMPLE
    .\Deploy-SAIF.ps1 -location "germanywestcentral" -deployContainers $false
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
    [bool]$deployContainers = $true
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

# Ensure the user is logged in to Azure
Show-Banner "SAIF Deployment: Authentication Check"
Write-Host "Checking Azure login status..." -ForegroundColor Cyan
try {
    $currentUser = az account show --query "user.name" -o tsv 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Not logged in"
    }
    Write-Host "Currently logged in as: $currentUser" -ForegroundColor Green
} 
catch {
    Write-Host "Please log in to Azure to continue" -ForegroundColor Yellow
    az login
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Login failed. Please run 'az login' manually and try again." -ForegroundColor Red
        exit 1
    }
    $currentUser = az account show --query "user.name" -o tsv
    Write-Host "Successfully logged in as: $currentUser" -ForegroundColor Green
}

# List available subscriptions and prompt user to select one
Show-Banner "SAIF Deployment: Subscription Selection"

# Get current subscription if already set
$currentSub = az account show --query "{name:name, id:id}" -o json 2>$null | ConvertFrom-Json
$currentSubMessage = if ($currentSub) { "Current subscription: $($currentSub.name)" } else { "No subscription currently selected" }
Write-Host $currentSubMessage -ForegroundColor Yellow

Write-Host "Fetching available subscriptions..." -ForegroundColor Cyan
$subscriptions = az account list --query "[].{name:name, id:id, state:state}" -o json | ConvertFrom-Json
$activeSubscriptions = $subscriptions | Where-Object { $_.state -eq "Enabled" }

if ($activeSubscriptions.Length -eq 0) {
    Write-Host "No enabled subscriptions found. Please verify your Azure account has active subscriptions." -ForegroundColor Red
    exit 1
}

Write-Host "Available subscriptions:" -ForegroundColor Green
Write-Host "------------------------" -ForegroundColor DarkGray
for ($i = 0; $i -lt $activeSubscriptions.Length; $i++) {
    $subName = $activeSubscriptions[$i].name
    $subId = $activeSubscriptions[$i].id
    
    # Format subscription ID for better readability
    $formattedId = $subId.Substring(0, 8) + "..." + $subId.Substring($subId.Length - 4)
    
    # Mark current subscription if applicable
    $indicator = if ($currentSub -and $currentSub.id -eq $subId) { "* " } else { "  " }
    $color = if ($currentSub -and $currentSub.id -eq $subId) { "Green" } else { "White" }
    
    Write-Host ("{0}[{1}] {2}" -f $indicator, $i, $subName) -ForegroundColor $color
    Write-Host "     ID: $formattedId" -ForegroundColor DarkGray
}
Write-Host "------------------------" -ForegroundColor DarkGray

# Default to current subscription index if one is selected
$defaultIndex = -1
if ($currentSub) {
    for ($i = 0; $i -lt $activeSubscriptions.Length; $i++) {
        if ($activeSubscriptions[$i].id -eq $currentSub.id) {
            $defaultIndex = $i
            break
        }
    }
}

$promptMessage = if ($defaultIndex -ge 0) {
    "Enter subscription number (or press Enter to keep current): "
} else {
    "Enter subscription number: "
}

$subscriptionIndex = Read-Host $promptMessage

# Use default if user just presses Enter
if ([string]::IsNullOrWhiteSpace($subscriptionIndex) -and $defaultIndex -ge 0) {
    $subscriptionIndex = $defaultIndex
}

try {
    $subscriptionIndex = [int]$subscriptionIndex
    if ($subscriptionIndex -lt 0 -or $subscriptionIndex -ge $activeSubscriptions.Length) {
        throw "Invalid subscription index"
    }
} catch {
    Write-Host "Invalid selection. Please enter a valid number." -ForegroundColor Red
    exit 1
}

$selectedSubscription = $activeSubscriptions[$subscriptionIndex]
Write-Host "Setting active subscription to: " -ForegroundColor Cyan -NoNewline
Write-Host $selectedSubscription.name -ForegroundColor White

az account set --subscription $selectedSubscription.id
if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to set subscription. Please verify your permissions and try again." -ForegroundColor Red
    exit 1
}
Write-Host "Subscription switched successfully!" -ForegroundColor Green

# Determine resource group name based on location
if ($location -eq "swedencentral") {
    $resourceGroupName = "rg-saif-swc01"
} else {
    $resourceGroupName = "rg-saif-gwc01"
}

# Region and Resource Group Confirmation
Show-Banner "SAIF Deployment: Region & Resource Group"
Write-Host "Selected configuration:" -ForegroundColor Cyan
Write-Host "Region: $location" -ForegroundColor White
Write-Host "Resource Group: $resourceGroupName" -ForegroundColor White

$confirmConfig = Read-Host "Proceed with this configuration? (Y/N)"
if ($confirmConfig.ToLower() -ne "y" -and $confirmConfig.ToLower() -ne "yes") {
    Write-Host "Deployment cancelled." -ForegroundColor Red
    exit 0
}

# Check if resource group exists and what's in it
$rgExists = az group exists --name $resourceGroupName
Write-Host "Resource group '$resourceGroupName' exists: $rgExists" -ForegroundColor $(if($rgExists -eq "true") {"Yellow"} else {"Green"})

if ($rgExists -eq "true") {
    $resources = az resource list --resource-group $resourceGroupName --query "[].{Name:name, Type:type}" --output json | ConvertFrom-Json
    if ($resources.Count -eq 0) {
        Write-Host "Resource group is empty - ready for deployment!" -ForegroundColor Green
    } else {
        Write-Host "Resource group contains $($resources.Count) existing resources:" -ForegroundColor Yellow
        $resources | Format-Table Name, Type -AutoSize
        
        Write-Host "Options:" -ForegroundColor Cyan
        Write-Host "1. Continue deployment (Bicep is idempotent - existing resources will be updated)" -ForegroundColor White
        Write-Host "2. Delete all resources in the resource group first" -ForegroundColor White
        Write-Host "3. Cancel deployment" -ForegroundColor White
        
        $choice = Read-Host "Enter your choice (1-3)"
        switch ($choice) {
            "1" {
                Write-Host "Continuing with existing resources..." -ForegroundColor Green
            }
            "2" {
                Write-Host "Deleting all resources in $resourceGroupName..." -ForegroundColor Yellow
                az group delete --name $resourceGroupName --yes --no-wait
                Write-Host "Resource group deletion initiated. Creating new resource group..." -ForegroundColor Yellow
                az group create --name $resourceGroupName --location $location
                Write-Host "New resource group created." -ForegroundColor Green
            }
            "3" {
                Write-Host "Deployment cancelled." -ForegroundColor Red
                exit 0
            }
            default {
                Write-Host "Invalid choice. Continuing with existing resources..." -ForegroundColor Yellow
            }
        }
    }
} else {
    Write-Host "Creating resource group '$resourceGroupName'..." -ForegroundColor Yellow
    az group create --name $resourceGroupName --location $location
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Resource group created successfully." -ForegroundColor Green
    } else {
        Write-Host "Failed to create resource group." -ForegroundColor Red
        exit 1
    }
}

# Get SQL Admin Password
Show-Banner "SAIF Deployment: SQL Configuration"
Write-Host "SQL Admin Username: saifadmin" -ForegroundColor White
Write-Host "Please enter the SQL Administrator password (minimum 12 characters):" -ForegroundColor Yellow

$passwordValid = $false
while (-not $passwordValid) {
    $sqlPassword = Read-Host "SQL Password" -AsSecureString
    $sqlPasswordText = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sqlPassword))
    
    if ($sqlPasswordText.Length -lt 12) {
        Write-Host "Password must be at least 12 characters long!" -ForegroundColor Red
    } else {
        $passwordValid = $true
        Write-Host "Password accepted." -ForegroundColor Green
    }
}

# Final Confirmation
Show-Banner "SAIF Deployment: Final Confirmation"
Write-Host "Ready to deploy SAIF with the following configuration:" -ForegroundColor Cyan
Write-Host "Subscription: $($selectedSubscription.name)" -ForegroundColor White
Write-Host "Region: $location" -ForegroundColor White
Write-Host "Resource Group: $resourceGroupName" -ForegroundColor White
Write-Host "Deploy Containers: $deployContainers" -ForegroundColor White

$finalConfirm = Read-Host "Start deployment? (Y/N)"
if ($finalConfirm.ToLower() -ne "y" -and $finalConfirm.ToLower() -ne "yes") {
    Write-Host "Deployment cancelled." -ForegroundColor Red
    exit 0
}

# Step 1: Deploy Infrastructure
Show-Banner "SAIF Deployment: Infrastructure Deployment"
Write-Host "Deploying Bicep template..." -ForegroundColor Cyan

$bicepPath = Join-Path -Path $PSScriptRoot -ChildPath "..\infra\main.bicep"
if (-not (Test-Path $bicepPath)) {
    Write-Host "Bicep template not found at: $bicepPath" -ForegroundColor Red
    exit 1
}

Write-Host "Deploying infrastructure (this may take several minutes)..." -ForegroundColor Yellow
$deploymentResult = az deployment group create `
    --resource-group $resourceGroupName `
    --template-file $bicepPath `
    --parameters location=$location sqlAdminPassword="$sqlPasswordText" `
    --output json

if ($LASTEXITCODE -ne 0) {
    Write-Host "Infrastructure deployment failed!" -ForegroundColor Red
    exit 1
}

$deployment = $deploymentResult | ConvertFrom-Json
Write-Host "Infrastructure deployment completed successfully!" -ForegroundColor Green

# Extract deployment outputs
$outputs = $deployment.properties.outputs
$acrName = $outputs.acrName.value
$acrLoginServer = $outputs.acrLoginServer.value
$apiUrl = $outputs.apiUrl.value
$webUrl = $outputs.webUrl.value

Write-Host "Deployment outputs:" -ForegroundColor Cyan
Write-Host "Container Registry: $acrName" -ForegroundColor White
Write-Host "API URL: $apiUrl" -ForegroundColor White
Write-Host "Web URL: $webUrl" -ForegroundColor White

# Step 2: Build and Deploy Containers (if requested)
if ($deployContainers) {
    Show-Banner "SAIF Deployment: Container Build & Push"
    
    # Verify Docker context paths
    $apiPath = Join-Path -Path $PSScriptRoot -ChildPath "..\api"
    $webPath = Join-Path -Path $PSScriptRoot -ChildPath "..\web"
    
    if (-not (Test-Path $apiPath)) {
        Write-Host "API directory not found at: $apiPath" -ForegroundColor Red
        Write-Host "Skipping container deployment." -ForegroundColor Yellow
    } elseif (-not (Test-Path $webPath)) {
        Write-Host "Web directory not found at: $webPath" -ForegroundColor Red
        Write-Host "Skipping container deployment." -ForegroundColor Yellow
    } else {
        # Build and push API container
        Write-Host "Building and pushing API container..." -ForegroundColor Yellow
        az acr build --registry $acrName --image saif/api:latest --file "$apiPath/Dockerfile" $apiPath
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "API container built and pushed successfully!" -ForegroundColor Green
        } else {
            Write-Host "Failed to build/push API container!" -ForegroundColor Red
        }
        
        # Build and push Web container
        Write-Host "Building and pushing Web container..." -ForegroundColor Yellow
        az acr build --registry $acrName --image saif/web:latest --file "$webPath/Dockerfile" $webPath
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Web container built and pushed successfully!" -ForegroundColor Green
        } else {
            Write-Host "Failed to build/push Web container!" -ForegroundColor Red
        }
        
        # Restart App Services to pull new images
        Write-Host "Restarting App Services to pull new container images..." -ForegroundColor Yellow
        az webapp restart --name $outputs.apiAppServiceName.value --resource-group $resourceGroupName
        az webapp restart --name $outputs.webAppServiceName.value --resource-group $resourceGroupName
        Write-Host "App Services restarted!" -ForegroundColor Green
    }
} else {
    Write-Host "Container deployment skipped (use -deployContainers $true to include)." -ForegroundColor Yellow
}

# Final Summary
Show-Banner "SAIF Deployment: Complete!"
Write-Host "SAIF has been successfully deployed to Azure!" -ForegroundColor Green
Write-Host ""
Write-Host "Access your applications:" -ForegroundColor Cyan
Write-Host "API URL: $apiUrl" -ForegroundColor White
Write-Host "Web URL: $webUrl" -ForegroundColor White
Write-Host ""
Write-Host "Container Registry: $acrName" -ForegroundColor White
Write-Host "Resource Group: $resourceGroupName" -ForegroundColor White
Write-Host ""
Write-Host "To update containers separately, run:" -ForegroundColor Yellow
Write-Host "  az acr build --registry $acrName --image saif/api:latest --file ./api/Dockerfile ./api" -ForegroundColor DarkGray
Write-Host "  az acr build --registry $acrName --image saif/web:latest --file ./web/Dockerfile ./web" -ForegroundColor DarkGray
Write-Host ""
Write-Host "Happy hacking! 🎯" -ForegroundColor Magenta

# Clean up password from memory
$sqlPasswordText = $null
[System.GC]::Collect()
