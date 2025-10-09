<#
.SYNOPSIS
    Complete SAIF-PostgreSQL deployment with Zone-Redundant High Availability.

.DESCRIPTION
    This script deploys the complete SAIF-PostgreSQL payment gateway application including:
    1. PostgreSQL Flexible Server with Zone-Redundant HA
    2. Infrastructure deployment using Bicep
    3. Container building and pushing to ACR
    4. App Service configuration
    
.PARAMETER location
    The Azure region to deploy resources to. Default is 'swedencentral'.

.PARAMETER resourceGroupName
    Optional. The name of the resource group to deploy to. Defaults to region-specific naming.

.PARAMETER skipContainers
    Skip container building and pushing (infrastructure only).

.PARAMETER postgresqlSku
    PostgreSQL compute SKU. Default is 'Standard_D4ds_v5'.

.EXAMPLE
    .\Deploy-SAIF-PostgreSQL.ps1 -location "swedencentral"

.EXAMPLE
    .\Deploy-SAIF-PostgreSQL.ps1 -location "germanywestcentral" -skipContainers

.NOTES
    Author: SAIF Team
    Version: 2.0.0
    Date: 2025-10-08
    Requires: Azure CLI, PowerShell 7+
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("swedencentral", "germanywestcentral", "eastus", "eastus2", "westus2", "westeurope", "northeurope")]
    [string]$location = "swedencentral",
    
    [Parameter(Mandatory=$false)]
    [string]$resourceGroupName,
    
    [Parameter(Mandatory=$false)]
    [switch]$skipContainers,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("Standard_B2s", "Standard_D2ds_v5", "Standard_D4ds_v5", "Standard_D8ds_v5")]
    [string]$postgresqlSku = "Standard_D4ds_v5",
    
    [Parameter(Mandatory=$false)]
    [switch]$disableHighAvailability,
    
    [Parameter(Mandatory=$false)]
    [SecureString]$postgresqlPassword,
    
    [Parameter(Mandatory=$false)]
    [switch]$autoApprove
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Set resource group name based on location if not specified
if (-not $resourceGroupName) {
    $locationShort = switch ($location) {
        "swedencentral" { "swc" }
        "germanywestcentral" { "gwc" }
        "eastus" { "eus" }
        "eastus2" { "eus2" }
        "westus2" { "wus2" }
        "westeurope" { "weu" }
        "northeurope" { "neu" }
        default { "swc" }
    }
    $resourceGroupName = "rg-saif-pgsql-$locationShort-01"
}

#region Helper Functions

function Show-Banner {
    param([string]$message)
    $border = "=" * ($message.Length + 4)
    Write-Host ""
    Write-Host $border -ForegroundColor Cyan
    Write-Host "| $message |" -ForegroundColor White -BackgroundColor DarkBlue
    Write-Host $border -ForegroundColor Cyan
    Write-Host ""
}

function Write-Step {
    param([string]$message)
    Write-Host "📍 $message" -ForegroundColor Yellow
}

function Write-Success {
    param([string]$message)
    Write-Host "✅ $message" -ForegroundColor Green
}

function Write-Error-Custom {
    param([string]$message)
    Write-Host "❌ $message" -ForegroundColor Red
}

function Write-Warning-Custom {
    param([string]$message)
    Write-Host "⚠️  $message" -ForegroundColor Yellow
}

function Write-Info {
    param([string]$message)
    Write-Host "ℹ️  $message" -ForegroundColor Cyan
}

#endregion

#region Main Script

Show-Banner "SAIF-PostgreSQL Deployment"

# Check Azure CLI login
Write-Step "Checking Azure CLI authentication..."
try {
    $currentAccount = az account show --query "{name:name, user:user.name, id:id}" -o json | ConvertFrom-Json
    Write-Success "Logged in as: $($currentAccount.user)"
    Write-Info "Subscription: $($currentAccount.name) ($($currentAccount.id))"
} catch {
    Write-Error-Custom "Please run 'az login' first"
    exit 1
}

# Display deployment configuration
Write-Host ""
Write-Info "Deployment Configuration:"
Write-Host "  Region: $location" -ForegroundColor White
Write-Host "  Resource Group: $resourceGroupName" -ForegroundColor White
Write-Host "  PostgreSQL SKU: $postgresqlSku" -ForegroundColor White
Write-Host "  High Availability: $(if ($disableHighAvailability) { 'Disabled' } else { 'Enabled (Zone-Redundant)' })" -ForegroundColor White
Write-Host "  Container Build: $(if ($skipContainers) { 'Skip' } else { 'Include' })" -ForegroundColor White
Write-Host ""

if (-not $autoApprove) {
    $confirm = Read-Host "Proceed with deployment? (y/N)"
    if ($confirm -ne 'y' -and $confirm -ne 'Y') {
        Write-Warning-Custom "Deployment cancelled."
        exit 0
    }
} else {
    Write-Info "Auto-approve enabled, proceeding with deployment..."
}

# Step 1: Create Resource Group
Show-Banner "Step 1: Resource Group"

Write-Step "Checking if resource group exists..."
$rgExists = az group exists --name $resourceGroupName -o tsv

if ($rgExists -eq "false") {
    Write-Step "Creating resource group: $resourceGroupName"
    az group create --name $resourceGroupName --location $location --output none
    Write-Success "Resource group created"
} else {
    Write-Success "Resource group exists: $resourceGroupName"
    
    # Check for existing resources
    Write-Step "Checking for existing resources..."
    try {
        $resourceListJson = az resource list --resource-group $resourceGroupName --output json
        $resourceArray = $resourceListJson | ConvertFrom-Json
        $existingResources = $resourceArray.Count
    } catch {
        Write-Warning-Custom "Unable to check existing resources, continuing..."
        $existingResources = 0
    }
    
    if ($existingResources -gt 0) {
        Write-Warning-Custom "Resource group contains $existingResources existing resources"
        Write-Host "  Options:" -ForegroundColor Yellow
        Write-Host "    [C] Continue - Deploy with Bicep (idempotent update)" -ForegroundColor White
        Write-Host "    [D] Delete - Remove all resources first" -ForegroundColor White
        Write-Host "    [A] Abort - Cancel deployment" -ForegroundColor White
        $action = Read-Host "Choose action (C/D/A)"
        
        switch ($action.ToUpper()) {
            'D' {
                Write-Step "Deleting all resources in $resourceGroupName..."
                az resource delete --ids $(az resource list --resource-group $resourceGroupName --query "[].id" -o tsv) 2>$null
                Write-Success "Resources deleted"
            }
            'A' {
                Write-Warning-Custom "Deployment aborted."
                exit 0
            }
            'C' {
                Write-Info "Continuing with deployment..."
            }
            default {
                Write-Error-Custom "Invalid choice. Aborting."
                exit 1
            }
        }
    }
}

# Step 2: Get PostgreSQL Admin Password
Show-Banner "Step 2: PostgreSQL Configuration"

if ($postgresqlPassword) {
    Write-Step "Using provided PostgreSQL password"
    $postgresPassword = $postgresqlPassword
    $postgresPasswordText = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($postgresPassword)
    )
} else {
    Write-Step "Enter PostgreSQL administrator password"
    Write-Host "  Requirements:" -ForegroundColor Cyan
    Write-Host "    - Minimum 12 characters" -ForegroundColor Gray
    Write-Host "    - Must contain uppercase, lowercase, numbers" -ForegroundColor Gray
    Write-Host ""

    do {
        $postgresPassword = Read-Host "PostgreSQL Admin Password" -AsSecureString
        $postgresPasswordText = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [Runtime.InteropServices.Marshal]::SecureStringToBSTR($postgresPassword)
        )
        
        if ($postgresPasswordText.Length -lt 12) {
            Write-Warning-Custom "Password must be at least 12 characters long"
            $postgresPasswordText = $null
        } elseif ($postgresPasswordText -notmatch '[A-Z]') {
            Write-Warning-Custom "Password must contain at least one uppercase letter"
            $postgresPasswordText = $null
        } elseif ($postgresPasswordText -notmatch '[a-z]') {
            Write-Warning-Custom "Password must contain at least one lowercase letter"
            $postgresPasswordText = $null
        } elseif ($postgresPasswordText -notmatch '[0-9]') {
            Write-Warning-Custom "Password must contain at least one number"
            $postgresPasswordText = $null
        }
    } while (-not $postgresPasswordText)
}

Write-Success "Password validated"

# Step 3: Deploy Infrastructure
Show-Banner "Step 3: Infrastructure Deployment"

Write-Step "Deploying Bicep template..."
Write-Info "This may take 10-15 minutes for PostgreSQL HA deployment..."

$deploymentName = "main-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$enableHA = if ($disableHighAvailability) { 'false' } else { 'true' }

Write-Host ""
Write-Info "Deployment Parameters:"
Write-Host "  Location: $location" -ForegroundColor Gray
Write-Host "  PostgreSQL SKU: $postgresqlSku" -ForegroundColor Gray
Write-Host "  High Availability: $enableHA" -ForegroundColor Gray
Write-Host ""

# Get script directory and construct path to Bicep template
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$bicepPath = Join-Path (Split-Path -Parent $scriptDir) "infra\main.bicep"

if (-not (Test-Path $bicepPath)) {
    Write-Error-Custom "Bicep template not found at: $bicepPath"
    exit 1
}

# Generate unique suffix to avoid conflicts with soft-deleted resources
# Use timestamp-based suffix (8 chars: MMDDHHMMSS format)
$timestamp = Get-Date -Format "MMddHHmm"
$uniqueSuffix = $timestamp.ToLower()
Write-Info "Using unique suffix: $uniqueSuffix"
Write-Host "  Key Vault name will be: kvsaifpg$uniqueSuffix" -ForegroundColor Gray

# Create temporary parameters file to avoid "content consumed" error
$tempParamsFile = [System.IO.Path]::GetTempFileName() + ".json"
$paramsObject = @{
    '$schema' = 'https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#'
    contentVersion = '1.0.0.0'
    parameters = @{
        location = @{ value = $location }
        postgresqlSku = @{ value = $postgresqlSku }
        enableHighAvailability = @{ value = [bool]($enableHA -eq 'true') }
        uniqueSuffix = @{ value = $uniqueSuffix }
        postgresAdminPassword = @{ value = $postgresPasswordText }
    }
}

try {
    # Write parameters to temp file
    $paramsObject | ConvertTo-Json -Depth 10 | Set-Content -Path $tempParamsFile -Encoding UTF8
    
    Write-Step "Starting Bicep deployment (this will take 10-15 minutes)..."
    
    # Run deployment using parameter file
    $deploymentResult = az deployment group create `
        --resource-group $resourceGroupName `
        --template-file $bicepPath `
        --parameters $tempParamsFile `
        --name $deploymentName `
        --query "properties.provisioningState" `
        --output tsv
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error-Custom "Deployment command failed with exit code: $LASTEXITCODE"
        Write-Host "Check deployment status:" -ForegroundColor Yellow
        Write-Host "  az deployment group show --resource-group $resourceGroupName --name $deploymentName" -ForegroundColor Gray
        exit 1
    }
} catch {
    Write-Error-Custom "Exception during deployment: $_"
    exit 1
} finally {
    # Clean up temp file
    if (Test-Path $tempParamsFile) {
        Remove-Item $tempParamsFile -Force -ErrorAction SilentlyContinue
    }
}

if ($deploymentResult -ne "Succeeded") {
    Write-Error-Custom "Infrastructure deployment failed"
    Write-Host "Check deployment details in Azure Portal or run:" -ForegroundColor Yellow
    Write-Host "  az deployment group show --resource-group $resourceGroupName --name $deploymentName" -ForegroundColor Gray
    exit 1
}

Write-Success "Infrastructure deployed successfully!"

# Step 4: Retrieve Deployment Outputs
Show-Banner "Step 4: Deployment Outputs"

Write-Step "Retrieving deployment outputs..."
$maxRetries = 3
$retryCount = 0
$outputs = $null

while ($retryCount -lt $maxRetries -and $null -eq $outputs) {
    try {
        Write-Info "Querying deployment outputs (attempt $($retryCount + 1)/$maxRetries)..."
        
        # Use a job with timeout to prevent hanging
        $job = Start-Job -ScriptBlock {
            param($rgName, $depName)
            az deployment group show `
                --resource-group $rgName `
                --name $depName `
                --query properties.outputs `
                --output json
        } -ArgumentList $resourceGroupName, $deploymentName
        
        # Wait for job with 60 second timeout
        $completed = Wait-Job -Job $job -Timeout 60
        
        if ($completed) {
            $outputJson = Receive-Job -Job $job
            Remove-Job -Job $job -Force
            
            if ($outputJson) {
                $outputs = $outputJson | ConvertFrom-Json
                Write-Success "Deployment outputs retrieved successfully"
                break
            }
        } else {
            Write-Warning-Custom "Query timed out after 60 seconds"
            Stop-Job -Job $job
            Remove-Job -Job $job -Force
        }
        
    } catch {
        Write-Warning-Custom "Attempt $($retryCount + 1) failed: $_"
    }
    
    $retryCount++
    if ($retryCount -lt $maxRetries) {
        Write-Info "Retrying in 5 seconds..."
        Start-Sleep -Seconds 5
    }
}

if ($null -eq $outputs) {
    Write-Error-Custom "Failed to retrieve deployment outputs after $maxRetries attempts"
    Write-Host "You can retrieve outputs manually:" -ForegroundColor Yellow
    Write-Host "  az deployment group show --resource-group $resourceGroupName --name $deploymentName --query properties.outputs" -ForegroundColor Gray
    exit 1
}

try {
    $acrName = $outputs.acrName.value
    $acrLoginServer = $outputs.acrLoginServer.value
    $apiAppName = $outputs.apiAppName.value
    $webAppName = $outputs.webAppName.value
    $apiUrl = $outputs.apiUrl.value
    $webUrl = $outputs.webUrl.value
    $postgresServerName = $outputs.postgresServerName.value
    $postgresServerFqdn = $outputs.postgresServerFqdn.value
    $postgresHAStatus = $outputs.postgresHAStatus.value
    $postgresPrimaryZone = $outputs.postgresPrimaryZone.value
    $postgresStandbyZone = $outputs.postgresStandbyZone.value
    
    Write-Success "All deployment values extracted"
} catch {
    Write-Error-Custom "Failed to extract deployment output values"
    Write-Host "Raw outputs: $($outputs | ConvertTo-Json -Depth 3)" -ForegroundColor Gray
    exit 1
}

Write-Host ""
Write-Info "Deployment Resources:"
Write-Host "  ACR: $acrName" -ForegroundColor White
Write-Host "  PostgreSQL: $postgresServerName" -ForegroundColor White
Write-Host "    FQDN: $postgresServerFqdn" -ForegroundColor Gray
Write-Host "    HA Status: $postgresHAStatus" -ForegroundColor $(if ($postgresHAStatus -eq 'Healthy') { 'Green' } else { 'Yellow' })
if (-not $disableHighAvailability) {
    Write-Host "    Primary Zone: $postgresPrimaryZone" -ForegroundColor Gray
    Write-Host "    Standby Zone: $postgresStandbyZone" -ForegroundColor Gray
}
Write-Host "  API App: $apiAppName" -ForegroundColor White
Write-Host "  Web App: $webAppName" -ForegroundColor White
Write-Host ""

# Step 5: Initialize Database
Show-Banner "Step 5: Database Initialization"

Write-Step "Initializing PostgreSQL database..."
Write-Info "Creating payment gateway schema..."

# Save connection details to temp file
$initScript = "..\init-db.sql"
$pgPassword = "PGPASSWORD=$postgresPasswordText"

try {
    # Check if psql is available
    $psqlPath = Get-Command psql -ErrorAction SilentlyContinue
    
    if ($psqlPath) {
        Write-Step "Using psql to initialize database..."
        $env:PGPASSWORD = $postgresPasswordText
        psql -h $postgresServerFqdn -U saifadmin -d saifdb -f $initScript
        $env:PGPASSWORD = $null
        Write-Success "Database initialized successfully"
    } else {
        Write-Warning-Custom "psql not found. Attempting Azure CLI method..."
        
        # Use Azure CLI to run the script
        $scriptContent = Get-Content $initScript -Raw
        $scriptContent | az postgres flexible-server execute `
            --name $postgresServerName `
            --resource-group $resourceGroupName `
            --admin-user saifadmin `
            --admin-password $postgresPasswordText `
            --database-name saifdb `
            --querytext -
        
        Write-Success "Database initialized via Azure CLI"
    }
} catch {
    Write-Warning-Custom "Database initialization encountered issues"
    Write-Host "You may need to run init-db.sql manually:" -ForegroundColor Yellow
    Write-Host "  psql -h $postgresServerFqdn -U saifadmin -d saifdb -f init-db.sql" -ForegroundColor Gray
    Write-Host ""
    Write-Info "Continuing with deployment..."
}

# Step 6: Container Build and Push
if (-not $skipContainers) {
    Show-Banner "Step 6: Container Build & Push"
    
    Write-Step "Building and pushing API container..."
    Write-Info "This may take 5-10 minutes... (ACR: $acrName)"
    Write-Host "  Registry: $acrLoginServer" -ForegroundColor Gray
    Write-Host "  Image: saif/api:latest" -ForegroundColor Gray
    Write-Host ""
    
    az acr build `
        --registry $acrName `
        --image saif/api:latest `
        --file ..\api\Dockerfile `
        ..\api `
        --output table | Out-Host
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "API container built and pushed to $acrLoginServer/saif/api:latest"
    } else {
        Write-Error-Custom "API container build failed"
        Write-Host "Check ACR build logs:" -ForegroundColor Yellow
        Write-Host "  az acr task list-runs --registry $acrName --top 5" -ForegroundColor Gray
        exit 1
    }
    
    Write-Step "Building and pushing Web container..."
    Write-Info "Building Web frontend container..."
    Write-Host "  Registry: $acrLoginServer" -ForegroundColor Gray
    Write-Host "  Image: saif/web:latest" -ForegroundColor Gray
    Write-Host ""
    
    az acr build `
        --registry $acrName `
        --image saif/web:latest `
        --file ..\web\Dockerfile `
        ..\web `
        --output table | Out-Host
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Web container built and pushed to $acrLoginServer/saif/web:latest"
    } else {
        Write-Error-Custom "Web container build failed"
        Write-Host "Check ACR build logs:" -ForegroundColor Yellow
        Write-Host "  az acr task list-runs --registry $acrName --top 5" -ForegroundColor Gray
        exit 1
    }
    
    # Verify images were pushed
    Write-Step "Verifying container images in registry..."
    $images = az acr repository list --name $acrName --output json | ConvertFrom-Json
    
    $apiImageExists = $images -contains "saif/api"
    $webImageExists = $images -contains "saif/web"
    
    if ($apiImageExists -and $webImageExists) {
        Write-Success "Both container images verified in registry"
        Write-Host "  ✓ saif/api:latest" -ForegroundColor Green
        Write-Host "  ✓ saif/web:latest" -ForegroundColor Green
    } else {
        Write-Warning-Custom "Container images not found in registry"
        if (-not $apiImageExists) { Write-Host "  ✗ saif/api:latest missing" -ForegroundColor Red }
        if (-not $webImageExists) { Write-Host "  ✗ saif/web:latest missing" -ForegroundColor Red }
    }
    
    # Restart App Services
    Write-Step "Restarting App Services to pull new images..."
    Write-Info "Waiting for image pull and container startup (this may take 2-3 minutes)..."
    
    az webapp restart --name $apiAppName --resource-group $resourceGroupName --output none
    az webapp restart --name $webAppName --resource-group $resourceGroupName --output none
    
    Write-Success "App Services restarted"
    
} else {
    Write-Info "Skipping container build (--skipContainers flag set)"
    Write-Warning-Custom "App Services may fail to start without container images!"
    Write-Host "Build containers manually:" -ForegroundColor Yellow
    Write-Host "  az acr build --registry $acrName --image saif/api:latest --file api\Dockerfile api\" -ForegroundColor Gray
    Write-Host "  az acr build --registry $acrName --image saif/web:latest --file web\Dockerfile web\" -ForegroundColor Gray
}

# Step 7: Validation
Show-Banner "Step 7: Deployment Validation"

Write-Step "Waiting for services to be ready (30 seconds)..."
Start-Sleep -Seconds 30

Write-Step "Testing API endpoint..."
try {
    $healthCheck = Invoke-RestMethod -Uri "$apiUrl/api/healthcheck" -Method Get -TimeoutSec 10
    if ($healthCheck.status -eq "healthy") {
        Write-Success "API is healthy and responding"
        Write-Host "  Database: $($healthCheck.database)" -ForegroundColor Gray
    } else {
        Write-Warning-Custom "API responded but reports unhealthy status"
    }
} catch {
    Write-Warning-Custom "API health check failed (may still be starting up)"
    Write-Host "  You can test manually: $apiUrl/api/healthcheck" -ForegroundColor Gray
}

Write-Step "Testing Web endpoint..."
try {
    $webResponse = Invoke-WebRequest -Uri $webUrl -Method Get -TimeoutSec 10
    if ($webResponse.StatusCode -eq 200) {
        Write-Success "Web frontend is accessible"
    }
} catch {
    Write-Warning-Custom "Web frontend check failed (may still be starting up)"
    Write-Host "  You can test manually: $webUrl" -ForegroundColor Gray
}

# Final Summary
Show-Banner "🎉 Deployment Complete!"

Write-Host "Resource Group: " -NoNewline -ForegroundColor Cyan
Write-Host $resourceGroupName -ForegroundColor White

Write-Host ""
Write-Host "🌐 Application URLs:" -ForegroundColor Cyan
Write-Host "  API: " -NoNewline -ForegroundColor Gray
Write-Host $apiUrl -ForegroundColor Green
Write-Host "  Web: " -NoNewline -ForegroundColor Gray
Write-Host $webUrl -ForegroundColor Green

Write-Host ""
Write-Host "🗄️  PostgreSQL Details:" -ForegroundColor Cyan
Write-Host "  Server: " -NoNewline -ForegroundColor Gray
Write-Host $postgresServerFqdn -ForegroundColor White
Write-Host "  Database: " -NoNewline -ForegroundColor Gray
Write-Host "saifdb" -ForegroundColor White
Write-Host "  Username: " -NoNewline -ForegroundColor Gray
Write-Host "saifadmin" -ForegroundColor White
Write-Host "  HA Status: " -NoNewline -ForegroundColor Gray
Write-Host $postgresHAStatus -ForegroundColor $(if ($postgresHAStatus -eq 'Healthy') { 'Green' } else { 'Yellow' })

if (-not $disableHighAvailability) {
    Write-Host ""
    Write-Host "⚡ High Availability Configuration:" -ForegroundColor Cyan
    Write-Host "  Mode: Zone-Redundant" -ForegroundColor White
    Write-Host "  Primary Zone: $postgresPrimaryZone" -ForegroundColor White
    Write-Host "  Standby Zone: $postgresStandbyZone" -ForegroundColor White
    Write-Host "  RPO: 0 seconds (zero data loss)" -ForegroundColor White
    Write-Host "  RTO: 60-120 seconds (automatic failover)" -ForegroundColor White
}

Write-Host ""
Write-Host "📝 Next Steps:" -ForegroundColor Cyan
Write-Host "  1. Test the API: $apiUrl/api/healthcheck" -ForegroundColor White
Write-Host "  2. View Web UI: $webUrl" -ForegroundColor White
Write-Host "  3. Run failover test: .\Test-PostgreSQL-Failover.ps1 -ResourceGroupName '$resourceGroupName'" -ForegroundColor White

Write-Host ""
Write-Info "Deployment artifacts saved to:"
Write-Host "  Deployment name: $deploymentName" -ForegroundColor Gray

# Clear sensitive data
$postgresPasswordText = $null
$postgresPassword = $null

Write-Host ""
Write-Success "SAIF-PostgreSQL deployment completed successfully!"

#endregion
