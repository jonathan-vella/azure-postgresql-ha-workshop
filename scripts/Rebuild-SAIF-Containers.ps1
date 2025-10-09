<#
.SYNOPSIS
    Rebuild and deploy SAIF-PostgreSQL containers without infrastructure changes.

.DESCRIPTION
    This script rebuilds the API and Web containers, pushes them to ACR, and restarts
    the App Services. Use this when you've updated application code but don't need to
    change infrastructure.
    
    Benefits:
    - Fast updates (5-10 minutes vs 25-30 minutes full deployment)
    - No infrastructure changes or downtime
    - Preserves all data and settings
    - Automatic verification of images

.PARAMETER resourceGroupName
    The resource group containing the SAIF deployment.

.PARAMETER buildApi
    Build only the API container (default: build both).

.PARAMETER buildWeb
    Build only the Web container (default: build both).

.PARAMETER skipRestart
    Build containers but don't restart App Services.

.PARAMETER tag
    Custom image tag (default: latest).

.EXAMPLE
    .\Rebuild-SAIF-Containers.ps1 -resourceGroupName "rg-saif-pgsql-swc-01"

.EXAMPLE
    .\Rebuild-SAIF-Containers.ps1 -resourceGroupName "rg-saif-pgsql-swc-01" -buildApi

.EXAMPLE
    .\Rebuild-SAIF-Containers.ps1 -resourceGroupName "rg-saif-pgsql-swc-01" -tag "v1.2.0"

.NOTES
    Author: SAIF Team
    Version: 1.0.0
    Date: 2025-10-08
    Requires: Azure CLI, PowerShell 7+
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$resourceGroupName,
    
    [Parameter(Mandatory=$false)]
    [switch]$buildApi,
    
    [Parameter(Mandatory=$false)]
    [switch]$buildWeb,
    
    [Parameter(Mandatory=$false)]
    [switch]$skipRestart,
    
    [Parameter(Mandatory=$false)]
    [string]$tag = "latest"
)

$ErrorActionPreference = "Stop"

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

Show-Banner "SAIF Container Rebuild"

# Check Azure CLI authentication
Write-Step "Checking Azure CLI authentication..."
try {
    $currentAccount = az account show --query "{name:name, user:user.name}" -o json | ConvertFrom-Json
    Write-Success "Logged in as: $($currentAccount.user)"
} catch {
    Write-Error-Custom "Please run 'az login' first"
    exit 1
}

# Verify resource group exists
Write-Step "Verifying resource group..."
$rgExists = az group exists --name $resourceGroupName -o tsv
if ($rgExists -eq "false") {
    Write-Error-Custom "Resource group '$resourceGroupName' not found"
    exit 1
}
Write-Success "Resource group exists"

# Get ACR name
Write-Step "Finding Azure Container Registry..."
try {
    $acr = az acr list --resource-group $resourceGroupName --query "[0]" | ConvertFrom-Json
    if (-not $acr) {
        Write-Error-Custom "No ACR found in resource group"
        exit 1
    }
    $acrName = $acr.name
    $acrLoginServer = $acr.loginServer
    Write-Success "ACR found: $acrName"
} catch {
    Write-Error-Custom "Failed to retrieve ACR details"
    exit 1
}

# Get App Service names
Write-Step "Finding App Services..."
try {
    $apps = az webapp list --resource-group $resourceGroupName | ConvertFrom-Json
    $apiApp = $apps | Where-Object { $_.name -like '*api*' } | Select-Object -First 1
    $webApp = $apps | Where-Object { $_.name -like '*web*' } | Select-Object -First 1
    
    if ($apiApp) {
        Write-Info "API App: $($apiApp.name)"
    } else {
        Write-Warning-Custom "No API App Service found"
    }
    
    if ($webApp) {
        Write-Info "Web App: $($webApp.name)"
    } else {
        Write-Warning-Custom "No Web App Service found"
    }
} catch {
    Write-Warning-Custom "Failed to retrieve App Service details"
}

Write-Host ""

# Determine what to build
$buildBoth = (-not $buildApi -and -not $buildWeb)

if ($buildBoth -or $buildApi) {
    Show-Banner "Building API Container"
    
    Write-Step "Building and pushing API container..."
    Write-Info "Registry: $acrLoginServer"
    Write-Info "Image: saif/api:$tag"
    Write-Host ""
    
    # Get script directory and navigate to repo root
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $repoRoot = Split-Path -Parent $scriptDir
    
    Push-Location $repoRoot
    
    try {
        az acr build `
            --registry $acrName `
            --image "saif/api:$tag" `
            --file api\Dockerfile `
            api\ `
            --output table | Out-Host
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "API container built and pushed: $acrLoginServer/saif/api:$tag"
        } else {
            Write-Error-Custom "API container build failed"
            Pop-Location
            exit 1
        }
    } finally {
        Pop-Location
    }
    
    Write-Host ""
}

if ($buildBoth -or $buildWeb) {
    Show-Banner "Building Web Container"
    
    Write-Step "Building and pushing Web container..."
    Write-Info "Registry: $acrLoginServer"
    Write-Info "Image: saif/web:$tag"
    Write-Host ""
    
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $repoRoot = Split-Path -Parent $scriptDir
    
    Push-Location $repoRoot
    
    try {
        az acr build `
            --registry $acrName `
            --image "saif/web:$tag" `
            --file web\Dockerfile `
            web\ `
            --output table | Out-Host
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Web container built and pushed: $acrLoginServer/saif/web:$tag"
        } else {
            Write-Error-Custom "Web container build failed"
            Pop-Location
            exit 1
        }
    } finally {
        Pop-Location
    }
    
    Write-Host ""
}

# Verify images in registry
Show-Banner "Verification"

Write-Step "Verifying images in registry..."
try {
    $images = az acr repository list --name $acrName --output json | ConvertFrom-Json
    
    $apiImageExists = $images -contains "saif/api"
    $webImageExists = $images -contains "saif/web"
    
    if ($buildBoth -or $buildApi) {
        if ($apiImageExists) {
            # Get tags
            $apiTags = az acr repository show-tags --name $acrName --repository "saif/api" --output json | ConvertFrom-Json
            if ($apiTags -contains $tag) {
                Write-Success "API image verified: saif/api:$tag"
            } else {
                Write-Warning-Custom "API image exists but tag '$tag' not found"
            }
        } else {
            Write-Error-Custom "API image not found in registry"
        }
    }
    
    if ($buildBoth -or $buildWeb) {
        if ($webImageExists) {
            $webTags = az acr repository show-tags --name $acrName --repository "saif/web" --output json | ConvertFrom-Json
            if ($webTags -contains $tag) {
                Write-Success "Web image verified: saif/web:$tag"
            } else {
                Write-Warning-Custom "Web image exists but tag '$tag' not found"
            }
        } else {
            Write-Error-Custom "Web image not found in registry"
        }
    }
} catch {
    Write-Warning-Custom "Unable to verify images: $_"
}

Write-Host ""

# Restart App Services
if (-not $skipRestart) {
    Show-Banner "Restarting App Services"
    
    Write-Step "Restarting App Services to pull new images..."
    Write-Info "This may take 2-3 minutes for containers to start..."
    Write-Host ""
    
    $restartedApps = @()
    
    if ($apiApp -and ($buildBoth -or $buildApi)) {
        Write-Step "Restarting API App Service..."
        az webapp restart --name $apiApp.name --resource-group $resourceGroupName --output none
        if ($LASTEXITCODE -eq 0) {
            Write-Success "API App Service restarted: $($apiApp.name)"
            $restartedApps += @{
                Name = $apiApp.name
                Url = "https://$($apiApp.defaultHostName)/api/healthcheck"
                Type = "API"
            }
        } else {
            Write-Error-Custom "Failed to restart API App Service"
        }
    }
    
    if ($webApp -and ($buildBoth -or $buildWeb)) {
        Write-Step "Restarting Web App Service..."
        az webapp restart --name $webApp.name --resource-group $resourceGroupName --output none
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Web App Service restarted: $($webApp.name)"
            $restartedApps += @{
                Name = $webApp.name
                Url = "https://$($webApp.defaultHostName)"
                Type = "Web"
            }
        } else {
            Write-Error-Custom "Failed to restart Web App Service"
        }
    }
    
    if ($restartedApps.Count -gt 0) {
        Write-Host ""
        Write-Step "Waiting for services to be ready (30 seconds)..."
        Start-Sleep -Seconds 30
        
        Write-Host ""
        Write-Step "Testing endpoints..."
        
        foreach ($app in $restartedApps) {
            Write-Host ""
            Write-Info "Testing $($app.Type): $($app.Name)"
            
            try {
                if ($app.Type -eq "API") {
                    $response = Invoke-RestMethod -Uri $app.Url -Method Get -TimeoutSec 10
                    if ($response.status -eq "healthy") {
                        Write-Success "$($app.Type) is healthy and responding"
                        Write-Host "  Database: $($response.database)" -ForegroundColor Gray
                    } else {
                        Write-Warning-Custom "$($app.Type) responded but reports unhealthy status"
                    }
                } else {
                    $response = Invoke-WebRequest -Uri $app.Url -Method Get -TimeoutSec 10
                    if ($response.StatusCode -eq 200) {
                        Write-Success "$($app.Type) is accessible (Status: 200 OK)"
                    } else {
                        Write-Warning-Custom "$($app.Type) returned status: $($response.StatusCode)"
                    }
                }
            } catch {
                Write-Warning-Custom "$($app.Type) health check failed (may still be starting up)"
                Write-Host "  Test manually: $($app.Url)" -ForegroundColor Gray
            }
        }
    }
} else {
    Write-Info "Skipping App Service restart (--skipRestart flag set)"
    Write-Host ""
    Write-Warning-Custom "You must manually restart App Services to use new images:"
    if ($apiApp -and ($buildBoth -or $buildApi)) {
        Write-Host "  az webapp restart --name $($apiApp.name) --resource-group $resourceGroupName" -ForegroundColor Gray
    }
    if ($webApp -and ($buildBoth -or $buildWeb)) {
        Write-Host "  az webapp restart --name $($webApp.name) --resource-group $resourceGroupName" -ForegroundColor Gray
    }
}

# Summary
Show-Banner "🎉 Container Rebuild Complete!"

Write-Host "Resource Group: " -NoNewline -ForegroundColor Cyan
Write-Host $resourceGroupName -ForegroundColor White
Write-Host ""

Write-Host "🐳 Images Rebuilt:" -ForegroundColor Cyan
if ($buildBoth -or $buildApi) {
    Write-Host "  ✓ saif/api:$tag" -ForegroundColor Green
}
if ($buildBoth -or $buildWeb) {
    Write-Host "  ✓ saif/web:$tag" -ForegroundColor Green
}

Write-Host ""

if ($restartedApps.Count -gt 0) {
    Write-Host "🌐 Application URLs:" -ForegroundColor Cyan
    foreach ($app in $restartedApps) {
        Write-Host "  $($app.Type): $($app.Url)" -ForegroundColor Green
    }
}

Write-Host ""
Write-Success "Container rebuild completed successfully!"
