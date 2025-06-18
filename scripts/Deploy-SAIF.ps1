<#
.SYNOPSIS
    Deploys SAIF (Secure AI Foundations) to Azure App Service using Bicep.
.DESCRIPTION
    This script deploys the SAIF application to Azure using Bicep templates.
    It creates or uses an existing resource group, deploys the Bicep template,
    and builds and pushes container images to Azure Container Registry.
    
    The script will interactively prompt the user to:
    1. Select an Azure subscription from available options
    2. Confirm or change the deployment region
    3. Confirm deployment parameters before proceeding
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
    Version: 1.1.0
    Date: 2025-06-20
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

# Show subscription change animation
Write-Host -NoNewline "Switching subscription "
for ($i = 0; $i -lt 5; $i++) {
    Start-Sleep -Milliseconds 200
    Write-Host -NoNewline "." -ForegroundColor Cyan
}
Write-Host ""

az account set --subscription $selectedSubscription.id
if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to set subscription. Please verify your permissions and try again." -ForegroundColor Red
    exit 1
}
Write-Host "Subscription switched successfully!" -ForegroundColor Green

# Confirm the deployment region
Show-Banner "SAIF Deployment: Region Selection"

# Define available regions with additional information
$availableRegions = @{
    "swedencentral" = @{
        DisplayName = "Sweden Central";
        Description = "Sweden Central";
        ShortCode = "swc";
    };
    "germanywestcentral" = @{
        DisplayName = "Germany West Central";
        Description = "Germany West Central";
        ShortCode = "gwc";
    };
}

# Display region information with formatting
Write-Host "Currently selected region: " -NoNewline
Write-Host $location -ForegroundColor Yellow -BackgroundColor DarkGray
Write-Host "$($availableRegions[$location].DisplayName)" -ForegroundColor Cyan

Write-Host "`nAvailable deployment regions:" -ForegroundColor Green
Write-Host "----------------------------" -ForegroundColor DarkGray

$index = 1
foreach ($regionKey in $availableRegions.Keys) {
    $region = $availableRegions[$regionKey]
    $marker = if ($regionKey -eq $location) { "* " } else { "  " }
    $color = if ($regionKey -eq $location) { "Green" } else { "White" }
    
    Write-Host ("{0}[{1}] {2} ({3})" -f $marker, $index, $region.DisplayName, $regionKey) -ForegroundColor $color
    Write-Host ("     {0}" -f $region.Description) -ForegroundColor DarkGray
    $index++
}

Write-Host "----------------------------" -ForegroundColor DarkGray
$confirmRegion = Read-Host "Do you want to proceed with the current region? (Y/N)"

if ($confirmRegion.ToLower() -ne "y" -and $confirmRegion.ToLower() -ne "yes") {
    $regionChoice = Read-Host "Enter the number of your preferred region"
    
    switch ($regionChoice) {
        "1" { $location = "swedencentral" }
        "2" { $location = "germanywestcentral" }
        default {
            Write-Host "Invalid selection. Using default region: $location" -ForegroundColor Yellow
        }
    }
    
    # Update resource group name based on selected location if not explicitly provided
    if (-not $PSBoundParameters.ContainsKey('resourceGroupName')) {
        if ($location -eq "swedencentral") {
            $resourceGroupName = "rg-aiseclab-swc01"
        } else {
            $resourceGroupName = "rg-aiseclab-gwc01"
        }
        Write-Host "Resource group name updated to: $resourceGroupName" -ForegroundColor Cyan
    }
}

# Prompt for SQL Admin Password
Show-Banner "SAIF Deployment: SQL Configuration"
Write-Host "The deployment requires a secure SQL Administrator password." -ForegroundColor Cyan
Write-Host "Password requirements:" -ForegroundColor DarkGray
Write-Host "  - Minimum 12 characters" -ForegroundColor DarkGray
Write-Host "  - At least 1 uppercase letter" -ForegroundColor DarkGray
Write-Host "  - At least 1 lowercase letter" -ForegroundColor DarkGray
Write-Host "  - At least 1 number" -ForegroundColor DarkGray
Write-Host "  - At least 1 special character" -ForegroundColor DarkGray

$passwordValid = $false
$sqlAdminPasswordParam = $null

while (-not $passwordValid) {
    $sqlPassword = Read-Host "Enter SQL Administrator password" -AsSecureString
    
    # Convert SecureString to plain text temporarily for validation only
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($sqlPassword)
    $sqlPasswordPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    
    $passwordChecks = @{
        Length = $sqlPasswordPlain.Length -ge 12
        Uppercase = $sqlPasswordPlain -cmatch "[A-Z]"
        Lowercase = $sqlPasswordPlain -cmatch "[a-z]"
        Number = $sqlPasswordPlain -cmatch "[0-9]"
        Special = $sqlPasswordPlain -match "[^a-zA-Z0-9]"
    }
    
    $allChecksPassed = $true
    foreach ($check in $passwordChecks.GetEnumerator()) {
        if (-not $check.Value) {
            $allChecksPassed = $false
            $requirement = switch ($check.Name) {
                "Length" { "at least 12 characters" }
                "Uppercase" { "at least one uppercase letter" }
                "Lowercase" { "at least one lowercase letter" }
                "Number" { "at least one number" }
                "Special" { "at least one special character" }
            }
            Write-Host "Password must contain $requirement" -ForegroundColor Red
        }
    }
    
    if ($allChecksPassed) {
        $passwordValid = $true
        # Store the SQL admin password parameter for Bicep
        $sqlAdminPasswordParam = "sqlAdminPassword=$sqlPasswordPlain"
        Write-Host "Password validation successful" -ForegroundColor Green
    }
    
    # Clear the plain text password from memory
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
    $sqlPasswordPlain = $null
    [System.GC]::Collect()
}

Show-Banner "SAIF Deployment: Configuration Summary"

# Get current time for estimated completion time
$startTime = Get-Date
$estimatedMinutes = 15
$estimatedCompletionTime = $startTime.AddMinutes($estimatedMinutes)

Write-Host "Deployment Configuration:" -ForegroundColor Green
Write-Host "------------------------" -ForegroundColor DarkGray
Write-Host "Subscription:   " -ForegroundColor White -NoNewline
Write-Host $selectedSubscription.name -ForegroundColor Cyan
Write-Host "Region:         " -ForegroundColor White -NoNewline
Write-Host "$location ($($availableRegions[$location].DisplayName))" -ForegroundColor Cyan
Write-Host "Resource Group: " -ForegroundColor White -NoNewline
Write-Host $resourceGroupName -ForegroundColor Cyan
Write-Host "Environment:    " -ForegroundColor White -NoNewline
Write-Host $environmentName -ForegroundColor Cyan
Write-Host "SQL Password:   " -ForegroundColor White -NoNewline
Write-Host "******** (Securely stored)" -ForegroundColor Cyan
Write-Host "------------------------" -ForegroundColor DarkGray

Write-Host "`nDeployment Process:" -ForegroundColor Green
Write-Host "1. Create/verify resource group" -ForegroundColor White
Write-Host "2. Deploy Bicep infrastructure" -ForegroundColor White
Write-Host "3. Build and push container images" -ForegroundColor White
Write-Host "4. Configure App Services" -ForegroundColor White
Write-Host "5. Restart services and finalize deployment" -ForegroundColor White

Write-Host "`nEstimated completion time: " -NoNewline
Write-Host "$($estimatedCompletionTime.ToString("HH:mm:ss"))" -ForegroundColor Yellow
Write-Host "(approximately $estimatedMinutes minutes from now)" -ForegroundColor DarkGray

Write-Host "`nReady to deploy SAIF to Azure" -ForegroundColor Cyan
$confirmStart = Read-Host "Start deployment? (Y/N)"

if ($confirmStart.ToLower() -ne "y" -and $confirmStart.ToLower() -ne "yes") {
    Write-Host "`nDeployment cancelled by user." -ForegroundColor Red
    exit 0
}

# Show deployment start banner
Show-Banner "SAIF Deployment: Starting Deployment Process"

# Step 1: Create resource group if it doesn't exist
Write-Host "`n[Step 1/5] " -ForegroundColor White -BackgroundColor DarkBlue -NoNewline
Write-Host " Verifying resource group..." -ForegroundColor Cyan

Write-Host "Checking if resource group '$resourceGroupName' exists..." -ForegroundColor DarkGray
$rgExists = az group exists --name $resourceGroupName
if ($rgExists -eq "false") {
    Write-Host "Resource group not found. Creating new resource group..." -ForegroundColor Yellow
    Write-Host "  Name: $resourceGroupName" -ForegroundColor DarkGray
    Write-Host "  Location: $location" -ForegroundColor DarkGray
    
    $rgResult = az group create --name $resourceGroupName --location $location --query "properties.provisioningState" -o tsv
    
    if ($rgResult -eq "Succeeded") {
        Write-Host "✓ Resource group created successfully" -ForegroundColor Green
    } else {
        Write-Host "✗ Failed to create resource group" -ForegroundColor Red
        Write-Host "Please check your permissions and try again." -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "✓ Resource group '$resourceGroupName' already exists" -ForegroundColor Green
}

# Step 2: Deploy the Bicep template
Write-Host "`n[Step 2/5] " -ForegroundColor White -BackgroundColor DarkBlue -NoNewline
Write-Host " Deploying infrastructure with Bicep..." -ForegroundColor Cyan

# Verify that the Bicep file exists
$bicepPath = Join-Path -Path $PSScriptRoot -ChildPath "..\infra\main.bicep"
if (-not (Test-Path $bicepPath)) {
    Write-Host "✗ Bicep template not found at: $bicepPath" -ForegroundColor Red
    Write-Host "Please ensure you are running this script from the correct directory" -ForegroundColor Yellow
    exit 1
}

Write-Host "Deploying Bicep template from: $bicepPath" -ForegroundColor DarkGray
Write-Host "Parameters:" -ForegroundColor DarkGray
Write-Host "  - environmentName: $environmentName" -ForegroundColor DarkGray
Write-Host "  - location: $location" -ForegroundColor DarkGray
Write-Host ""

Write-Host "Starting deployment (this may take several minutes)..." -ForegroundColor Yellow

# Create the parameter string for the deployment
$deployParams = "environmentName=$environmentName location=$location $sqlAdminPasswordParam"

# Show progress indicator during deployment
$job = Start-Job -ScriptBlock { 
    param($resourceGroupName, $templateFile, $parameterString)
    
    $result = $null
    try {
        # Use the parameter string with command 
        $deployCommand = "az deployment group create --resource-group $resourceGroupName --template-file '$templateFile' --parameters $parameterString --output json"
        $result = Invoke-Expression $deployCommand
    }
    catch {
        return "ERROR: $_"
    }
    
    return $result
} -ArgumentList $resourceGroupName, $bicepPath, $deployParams

# Display progress while waiting for the job to complete
$spinner = @('|', '/', '-', '\')
$spinnerPos = 0
while ($job.State -eq "Running") {
    Write-Host "`r$($spinner[$spinnerPos]) Deploying infrastructure... " -NoNewline -ForegroundColor Yellow
    $spinnerPos = ($spinnerPos + 1) % $spinner.Length
    Start-Sleep -Milliseconds 200
}

$deploymentResult = Receive-Job -Job $job
Remove-Job -Job $job

# Process deployment result
try {
    $deployment = $deploymentResult | ConvertFrom-Json
    if (-not $deployment) {
        throw "Empty deployment result"
    }
    
    # Check if deployment was successful
    $provisioningState = $deployment.properties.provisioningState
    if ($provisioningState -ne "Succeeded") {
        throw "Deployment failed with state: $provisioningState"
    }
    
    Write-Host "`r✓ Bicep deployment completed successfully             " -ForegroundColor Green
      # Extract information from deployment outputs
    Write-Host "Extracting deployment outputs..." -ForegroundColor DarkGray
    $acrLoginServer = $deployment.properties.outputs.acrLoginServer.value
    $acrName = $deployment.properties.outputs.acrName.value
    $apiAppServiceName = $deployment.properties.outputs.apiAppServiceName.value
    $webAppServiceName = $deployment.properties.outputs.webAppServiceName.value
    $keyVaultName = $deployment.properties.outputs.keyVaultName.value
    
    Write-Host "  - ACR Name: $acrName" -ForegroundColor DarkGray
    Write-Host "  - ACR Login Server: $acrLoginServer" -ForegroundColor DarkGray
    Write-Host "  - API App Service: $apiAppServiceName" -ForegroundColor DarkGray
    Write-Host "  - Web App Service: $webAppServiceName" -ForegroundColor DarkGray
    Write-Host "  - Key Vault: $keyVaultName" -ForegroundColor DarkGray
}
catch {
    Write-Host "`r✗ Bicep deployment failed                            " -ForegroundColor Red
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host "Please check the Azure Portal for detailed error messages." -ForegroundColor Yellow
    exit 1
}

# Step 3: Build and push container images to ACR
Write-Host "`n[Step 3/5] " -ForegroundColor White -BackgroundColor DarkBlue -NoNewline
Write-Host " Building and pushing images to ACR..." -ForegroundColor Cyan

# Verify that the Dockerfile paths exist
$apiDockerfilePath = Join-Path -Path $PSScriptRoot -ChildPath "..\api\Dockerfile"
$webDockerfilePath = Join-Path -Path $PSScriptRoot -ChildPath "..\web\Dockerfile"

if (-not (Test-Path $apiDockerfilePath)) {
    Write-Host "⚠️ API Dockerfile not found at: $apiDockerfilePath" -ForegroundColor Yellow
    Write-Host "Please verify the path and file existence" -ForegroundColor Yellow
    $continue = Read-Host "Do you want to continue anyway? (Y/N)"
    if ($continue.ToLower() -ne "y" -and $continue.ToLower() -ne "yes") {
        exit 1
    }
}

if (-not (Test-Path $webDockerfilePath)) {
    Write-Host "⚠️ Web Dockerfile not found at: $webDockerfilePath" -ForegroundColor Yellow
    Write-Host "Please verify the path and file existence" -ForegroundColor Yellow
    $continue = Read-Host "Do you want to continue anyway? (Y/N)"
    if ($continue.ToLower() -ne "y" -and $continue.ToLower() -ne "yes") {
        exit 1
    }
}

# API image
Write-Host "Building and pushing API image to $acrName..." -ForegroundColor Yellow
Write-Host "  Source: ../api/" -ForegroundColor DarkGray
Write-Host "  Image: $acrLoginServer/saif/api:latest" -ForegroundColor DarkGray
$apiResult = az acr build --registry $acrName --image saif/api:latest --file ../api/Dockerfile ../api --query "provisioningState" -o tsv 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ API image built and pushed successfully" -ForegroundColor Green
} else {
    Write-Host "✗ Failed to build and push API image" -ForegroundColor Red
    Write-Host "Error: $apiResult" -ForegroundColor Red
    $continue = Read-Host "Do you want to continue anyway? (Y/N)"
    if ($continue.ToLower() -ne "y" -and $continue.ToLower() -ne "yes") {
        exit 1
    }
}

# Web image
Write-Host "`nBuilding and pushing Web image to $acrName..." -ForegroundColor Yellow
Write-Host "  Source: ../web/" -ForegroundColor DarkGray
Write-Host "  Image: $acrLoginServer/saif/web:latest" -ForegroundColor DarkGray
$webResult = az acr build --registry $acrName --image saif/web:latest --file ../web/Dockerfile ../web --query "provisioningState" -o tsv 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Web image built and pushed successfully" -ForegroundColor Green
} else {
    Write-Host "✗ Failed to build and push Web image" -ForegroundColor Red
    Write-Host "Error: $webResult" -ForegroundColor Red
    $continue = Read-Host "Do you want to continue anyway? (Y/N)"
    if ($continue.ToLower() -ne "y" -and $continue.ToLower() -ne "yes") {
        exit 1
    }
}

# Step 4: Update App Services with the latest container images
Write-Host "`n[Step 4/5] " -ForegroundColor White -BackgroundColor DarkBlue -NoNewline
Write-Host " Configuring App Services..." -ForegroundColor Cyan

# Update API App Service
Write-Host "Updating API App Service with the latest container image..." -ForegroundColor Yellow
Write-Host "  App Service: $apiAppServiceName" -ForegroundColor DarkGray
Write-Host "  Container: $acrLoginServer/saif/api:latest" -ForegroundColor DarkGray

$apiUpdateResult = az webapp config container set `
    --name $apiAppServiceName `
    --resource-group $resourceGroupName `
    --docker-custom-image-name "$acrLoginServer/saif/api:latest" `
    --docker-registry-server-url "https://$acrLoginServer" `
    --query "status" -o tsv 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ API App Service container configuration updated successfully" -ForegroundColor Green
} else {
    Write-Host "✗ Failed to update API App Service configuration" -ForegroundColor Red
    Write-Host "Error: $apiUpdateResult" -ForegroundColor Red
    $continue = Read-Host "Do you want to continue anyway? (Y/N)"
    if ($continue.ToLower() -ne "y" -and $continue.ToLower() -ne "yes") {
        exit 1
    }
}

# Update Web App Service
Write-Host "`nUpdating Web App Service with the latest container image..." -ForegroundColor Yellow
Write-Host "  App Service: $webAppServiceName" -ForegroundColor DarkGray
Write-Host "  Container: $acrLoginServer/saif/web:latest" -ForegroundColor DarkGray

$webUpdateResult = az webapp config container set `
    --name $webAppServiceName `
    --resource-group $resourceGroupName `
    --docker-custom-image-name "$acrLoginServer/saif/web:latest" `
    --docker-registry-server-url "https://$acrLoginServer" `
    --query "status" -o tsv 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Web App Service container configuration updated successfully" -ForegroundColor Green
} else {
    Write-Host "✗ Failed to update Web App Service configuration" -ForegroundColor Red
    Write-Host "Error: $webUpdateResult" -ForegroundColor Red
    $continue = Read-Host "Do you want to continue anyway? (Y/N)"
    if ($continue.ToLower() -ne "y" -and $continue.ToLower() -ne "yes") {
        exit 1
    }
}

# Step 5: Restart App Services to apply changes
Write-Host "`n[Step 5/5] " -ForegroundColor White -BackgroundColor DarkBlue -NoNewline
Write-Host " Restarting services and finalizing deployment..." -ForegroundColor Cyan

# Restart API App Service
Write-Host "Restarting API App Service..." -ForegroundColor Yellow
$apiRestartResult = az webapp restart --name $apiAppServiceName --resource-group $resourceGroupName 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ API App Service restarted successfully" -ForegroundColor Green
} else {
    Write-Host "⚠️ Warning: Failed to restart API App Service" -ForegroundColor Yellow
    Write-Host "Error: $apiRestartResult" -ForegroundColor DarkGray
    Write-Host "The service may restart automatically when the new container image is pulled." -ForegroundColor DarkGray
}

# Restart Web App Service
Write-Host "`nRestarting Web App Service..." -ForegroundColor Yellow
$webRestartResult = az webapp restart --name $webAppServiceName --resource-group $resourceGroupName 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Web App Service restarted successfully" -ForegroundColor Green
} else {
    Write-Host "⚠️ Warning: Failed to restart Web App Service" -ForegroundColor Yellow
    Write-Host "Error: $webRestartResult" -ForegroundColor DarkGray
    Write-Host "The service may restart automatically when the new container image is pulled." -ForegroundColor DarkGray
}

# Display the URLs for the deployed applications
$apiUrl = "https://$apiAppServiceName.azurewebsites.net"
$webUrl = "https://$webAppServiceName.azurewebsites.net"

# Calculate deployment duration
$endTime = Get-Date
$deploymentDuration = New-TimeSpan -Start $startTime -End $endTime
$durationFormatted = "{0:D2}:{1:D2}:{2:D2}" -f $deploymentDuration.Hours, $deploymentDuration.Minutes, $deploymentDuration.Seconds

Show-Banner "SAIF Deployment: Completed Successfully"

Write-Host "Deployment Summary:" -ForegroundColor Green
Write-Host "-------------------" -ForegroundColor DarkGray
Write-Host "Status:        " -ForegroundColor White -NoNewline
Write-Host "Completed Successfully" -ForegroundColor Green
Write-Host "Duration:      " -ForegroundColor White -NoNewline
Write-Host "$durationFormatted" -ForegroundColor Cyan
Write-Host "Subscription:  " -ForegroundColor White -NoNewline
Write-Host "$($selectedSubscription.name)" -ForegroundColor Cyan
Write-Host "Resource Group:" -ForegroundColor White -NoNewline
Write-Host " $resourceGroupName" -ForegroundColor Cyan
Write-Host "Region:        " -ForegroundColor White -NoNewline
Write-Host "$location" -ForegroundColor Cyan
Write-Host "Key Vault:     " -ForegroundColor White -NoNewline
Write-Host "$keyVaultName" -ForegroundColor Cyan

Write-Host "`nApplication Endpoints:" -ForegroundColor Green
Write-Host "-------------------" -ForegroundColor DarkGray
Write-Host "API URL: " -ForegroundColor White -NoNewline
Write-Host $apiUrl -ForegroundColor Yellow
Write-Host "Web URL: " -ForegroundColor White -NoNewline
Write-Host $webUrl -ForegroundColor Yellow

Write-Host "`nNext Steps:" -ForegroundColor Green
Write-Host "-------------------" -ForegroundColor DarkGray
Write-Host "1. Wait a few minutes for container initialization" -ForegroundColor White
Write-Host "2. Visit the Web URL to access the SAIF application" -ForegroundColor White
Write-Host "3. Test the API endpoint for proper functionality" -ForegroundColor White
Write-Host "4. Configure monitoring and alerts in Azure Portal" -ForegroundColor White
Write-Host "5. Review Key Vault permissions for app services" -ForegroundColor White
Write-Host "6. Update application security settings as needed" -ForegroundColor White

Write-Host "`nNote: " -ForegroundColor Yellow -NoNewline
Write-Host "It may take up to 5 minutes for the containers to fully start." -ForegroundColor Cyan
Write-Host "If you encounter any issues, check the logs in the Azure Portal." -ForegroundColor Cyan

Write-Host "`nThank you for deploying SAIF (Secure AI Foundations)!" -ForegroundColor Magenta
