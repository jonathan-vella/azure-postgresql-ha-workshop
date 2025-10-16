<#
.SYNOPSIS
Build and push LoadGenerator Docker image to Azure Container Registry (ACR)

.DESCRIPTION
This script builds a Dockerfile for the LoadGenerator application and pushes it to ACR.
The LoadGenerator is a C# application that performs distributed load testing against PostgreSQL.

.PARAMETER ContainerRegistry
ACR name (without .azurecr.io) - e.g., 'acrsaifpg10081025'

.PARAMETER ImageName
Container image name - default: 'loadgenerator'

.PARAMETER ImageTag
Container image tag/version - default: 'latest'

.PARAMETER ResourceGroup
Azure Resource Group containing the ACR

.PARAMETER DockerfilePath
Path to Dockerfile - default: './Dockerfile'

.EXAMPLE
.\Build-LoadGenerator-Docker.ps1 -ContainerRegistry "acrsaifpg10081025" `
    -ResourceGroup "rg-saif-pgsql-swc-01" `
    -ImageTag "1.0"
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$ContainerRegistryName,

    [Parameter(Mandatory = $false)]
    [string]$ResourceGroup,

    [Parameter(Mandatory = $false)]
    [string]$ImageName = "loadgenerator",

    [Parameter(Mandatory = $false)]
    [string]$ImageTag = "latest",

    [Parameter(Mandatory = $false)]
    [string]$DockerfilePath = "./scripts/loadtesting/Dockerfile",

    [Parameter(Mandatory = $false)]
    [string]$ConfigFile = "./scripts/loadtesting/LoadGenerator-Config.ps1"
)

# ============================================================================
# RESOLVE CONFIG FILE PATH
# ============================================================================

# If config file is relative path, resolve it relative to script directory
if (-not [System.IO.Path]::IsPathRooted($ConfigFile)) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $ConfigFile = Join-Path $scriptDir $ConfigFile
}

# ============================================================================
# LOAD CONFIGURATION IF PROVIDED
# ============================================================================

if (Test-Path $ConfigFile) {
    . $ConfigFile
    
    # Extract values from config if parameters not provided
    if (-not $ContainerRegistryName) {
        $ContainerRegistryName = $ContainerRegistry.Name
    }
    if (-not $ResourceGroup) {
        $ResourceGroup = $ResourceGroup
    }
    if (-not $ImageName -or $ImageName -eq "loadgenerator") {
        $ImageName = $ContainerRegistry.ImageName
    }
    if (-not $ImageTag -or $ImageTag -eq "latest") {
        $ImageTag = $ContainerRegistry.ImageTag
    }
}

# Validate required parameters
if (-not $ContainerRegistryName) {
    throw "ContainerRegistry is required (use -ContainerRegistryName or provide LoadGenerator-Config.ps1)"
}
if (-not $ResourceGroup) {
    throw "ResourceGroup is required (use -ResourceGroup or provide LoadGenerator-Config.ps1)"
}

# Set error action preference
$ErrorActionPreference = "Stop"

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

function Get-ExistingACR {
    param(
        [string]$ACRName,
        [string]$ResourceGroup
    )
    
    try {
        $acr = az acr show --name $ACRName --resource-group $ResourceGroup 2>$null | ConvertFrom-Json
        return $acr
    }
    catch {
        return $null
    }
}

function Get-FirstACRInResourceGroup {
    param(
        [string]$ResourceGroup
    )
    
    try {
        $acrs = az acr list --resource-group $ResourceGroup 2>$null | ConvertFrom-Json
        if ($acrs -and $acrs.Count -gt 0) {
            return $acrs[0]
        }
        return $null
    }
    catch {
        return $null
    }
}

function New-ACR {
    param(
        [string]$ACRName,
        [string]$ResourceGroup
    )
    
    Write-Host "  Creating new ACR: $ACRName..." -ForegroundColor Yellow
    try {
        $acr = az acr create --resource-group $ResourceGroup `
            --name $ACRName `
            --sku Basic `
            --admin-enabled true | ConvertFrom-Json
        
        Write-Host "  ✓ ACR created successfully" -ForegroundColor Green
        return $acr
    }
    catch {
        Write-Host "  ✗ Failed to create ACR" -ForegroundColor Red
        throw
    }
}

Write-Host "🏗️  Load Generator Docker Build & Push" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

# ============================================================================
# STEP 1: Find or Create ACR
# ============================================================================

Write-Host "`n✓ Step 1: ACR Management" -ForegroundColor Cyan

# First, check if specified ACR exists
$acr = Get-ExistingACR -ACRName $ContainerRegistryName -ResourceGroup $ResourceGroup

if ($acr) {
    Write-Host "  ✓ Found specified ACR: $ContainerRegistryName" -ForegroundColor Green
    $loginServer = $acr.loginServer
    Write-Host "    Login Server: $loginServer" -ForegroundColor Cyan
}
else {
    Write-Host "  ℹ ACR '$ContainerRegistryName' not found in resource group" -ForegroundColor Yellow
    
    # Check if there's an existing ACR in the resource group
    $existingACR = Get-FirstACRInResourceGroup -ResourceGroup $ResourceGroup
    
    if ($existingACR) {
        Write-Host "  ✓ Found existing ACR in resource group: $($existingACR.name)" -ForegroundColor Green
        $ContainerRegistryName = $existingACR.name
        $acr = $existingACR
        $loginServer = $acr.loginServer
        Write-Host "    Login Server: $loginServer" -ForegroundColor Cyan
    }
    else {
        # No existing ACR, create a new one
        Write-Host "  ℹ No existing ACR found in resource group, creating new one..." -ForegroundColor Yellow
        
        # Generate unique ACR name
        $uniqueSuffix = Get-Random -Minimum 1000 -Maximum 9999
        $newACRName = "$($ContainerRegistryName.Substring(0, [Math]::Min(14, $ContainerRegistryName.Length)))$uniqueSuffix"
        
        $acr = New-ACR -ACRName $newACRName -ResourceGroup $ResourceGroup
        $ContainerRegistryName = $newACRName
        $loginServer = $acr.loginServer
        Write-Host "    New ACR Name: $ContainerRegistryName" -ForegroundColor Cyan
        Write-Host "    Login Server: $loginServer" -ForegroundColor Cyan
    }
}

# Validate Dockerfile exists
Write-Host "`n✓ Step 2: Validation" -ForegroundColor Cyan
if (-not (Test-Path $DockerfilePath)) {
    Write-Host "  ✗ Dockerfile not found at: $DockerfilePath" -ForegroundColor Red
    throw "Dockerfile not found"
}
Write-Host "  ✓ Dockerfile found at: $DockerfilePath" -ForegroundColor Green

# ============================================================================
# STEP 3: Login to ACR
# ============================================================================

Write-Host "`n✓ Step 3: ACR Authentication" -ForegroundColor Cyan
try {
    az acr login --name $ContainerRegistryName 2>$null | Out-Null
    Write-Host "  ✓ Logged in successfully" -ForegroundColor Green
}
catch {
    Write-Host "  ✗ Failed to login to ACR" -ForegroundColor Red
    throw
}

# ============================================================================
# STEP 4: Build Image
# ============================================================================

Write-Host "`n✓ Step 4: Building Docker Image" -ForegroundColor Cyan
$fullImageName = "$loginServer/$ImageName`:$ImageTag"
Write-Host "  Image: $fullImageName" -ForegroundColor Cyan

try {
    az acr build --registry $ContainerRegistryName `
        --image "$ImageName`:$ImageTag" `
        --file $DockerfilePath `
        . 2>$null | Out-Null
    
    Write-Host "  ✓ Image built successfully" -ForegroundColor Green
}
catch {
    Write-Host "  ✗ Failed to build image" -ForegroundColor Red
    throw
}

# ============================================================================
# STEP 5: Verify Image
# ============================================================================

Write-Host "`n✓ Step 5: Verifying Image" -ForegroundColor Cyan
try {
    $images = az acr repository show-tags --name $ContainerRegistryName `
        --repository $ImageName 2>$null | ConvertFrom-Json
    
    if ($ImageTag -in $images) {
        Write-Host "  ✓ Image tag verified: $ImageTag" -ForegroundColor Green
    }
    else {
        Write-Host "  ⚠ Tag not immediately visible (may need refresh)" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "  ⚠ Could not verify image (continuing anyway)" -ForegroundColor Yellow
}

# Output summary
Write-Host "`n✅ Build Complete!" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
Write-Host "Image URI: $fullImageName" -ForegroundColor Cyan
Write-Host "`nNext Step:" -ForegroundColor Yellow
Write-Host "  Deploy to App Service using Deploy-LoadGenerator-AppService.ps1" -ForegroundColor Cyan
