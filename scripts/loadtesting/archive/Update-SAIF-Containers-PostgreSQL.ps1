<#
.SYNOPSIS
    Updates SAIF-PostgreSQL containers in Azure.

.DESCRIPTION
    Rebuilds and redeploys API and Web containers to Azure Container Registry
    and restarts App Services.

.PARAMETER ResourceGroupName
    The resource group containing the deployed resources.

.PARAMETER RebuildApi
    Rebuild and push the API container.

.PARAMETER RebuildWeb
    Rebuild and push the Web container.

.PARAMETER SkipRestart
    Skip restarting App Services after build.

.EXAMPLE
    .\Update-SAIF-Containers-PostgreSQL.ps1 -ResourceGroupName "rg-saif-pgsql-swc-01"

.EXAMPLE
    .\Update-SAIF-Containers-PostgreSQL.ps1 -ResourceGroupName "rg-saif-pgsql-swc-01" -RebuildApi

.NOTES
    Author: SAIF Team
    Version: 2.0.0
    Date: 2025-01-08
    Requires: Azure CLI
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$false)]
    [switch]$RebuildApi = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$RebuildWeb = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipRestart = $false
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

function Write-Info {
    param([string]$message)
    Write-Host "ℹ️  $message" -ForegroundColor Cyan
}

#endregion

#region Main Script

Show-Banner "SAIF-PostgreSQL Container Update"

# Check Azure CLI login
Write-Step "Checking Azure CLI authentication..."
try {
    $currentAccount = az account show --query "{name:name, user:user.name}" -o json | ConvertFrom-Json
    Write-Success "Logged in as: $($currentAccount.user)"
} catch {
    Write-Error-Custom "Please run 'az login' first"
    exit 1
}

# If no rebuild flags specified, rebuild both
if (-not $RebuildApi -and -not $RebuildWeb) {
    Write-Info "No specific container specified, rebuilding both API and Web"
    $RebuildApi = $true
    $RebuildWeb = $true
}

# Get ACR name
Write-Step "Discovering Azure Container Registry..."
try {
    $acrList = az acr list --resource-group $ResourceGroupName --query "[].{name:name, loginServer:loginServer}" --output json | ConvertFrom-Json
    
    if ($acrList.Count -eq 0) {
        Write-Error-Custom "No Azure Container Registry found in resource group"
        exit 1
    }
    
    $acr = $acrList[0]
    $acrName = $acr.name
    $acrLoginServer = $acr.loginServer
    
    Write-Success "Found ACR: $acrName"
} catch {
    Write-Error-Custom "Failed to discover ACR"
    exit 1
}

# Get App Service names
Write-Step "Discovering App Services..."
try {
    $appServices = az webapp list --resource-group $ResourceGroupName --query "[?contains(name, 'saif')].{name:name, type:kind}" --output json | ConvertFrom-Json
    
    $apiAppName = ($appServices | Where-Object { $_.name -like '*api*' }).name
    $webAppName = ($appServices | Where-Object { $_.name -like '*web*' -and $_.name -notlike '*api*' }).name
    
    if ($apiAppName) {
        Write-Info "API App Service: $apiAppName"
    }
    if ($webAppName) {
        Write-Info "Web App Service: $webAppName"
    }
} catch {
    Write-Error-Custom "Failed to discover App Services"
    exit 1
}

# Rebuild API Container
if ($RebuildApi) {
    Show-Banner "Building API Container"
    
    Write-Step "Building and pushing API container image..."
    Write-Info "This may take 5-10 minutes..."
    
    $apiPath = Join-Path (Split-Path $PSScriptRoot -Parent) "api"
    
    if (-not (Test-Path $apiPath)) {
        Write-Error-Custom "API directory not found: $apiPath"
        exit 1
    }
    
    try {
        az acr build `
            --registry $acrName `
            --image saif/api:latest `
            --image "saif/api:$(Get-Date -Format 'yyyyMMdd-HHmmss')" `
            --file "$apiPath\Dockerfile" `
            $apiPath `
            --output table
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "API container built and pushed successfully"
        } else {
            Write-Error-Custom "API container build failed"
            exit 1
        }
    } catch {
        Write-Error-Custom "API container build failed: $_"
        exit 1
    }
}

# Rebuild Web Container
if ($RebuildWeb) {
    Show-Banner "Building Web Container"
    
    Write-Step "Building and pushing Web container image..."
    Write-Info "This may take 5-10 minutes..."
    
    $webPath = Join-Path (Split-Path $PSScriptRoot -Parent) "web"
    
    if (-not (Test-Path $webPath)) {
        Write-Error-Custom "Web directory not found: $webPath"
        exit 1
    }
    
    try {
        az acr build `
            --registry $acrName `
            --image saif/web:latest `
            --image "saif/web:$(Get-Date -Format 'yyyyMMdd-HHmmss')" `
            --file "$webPath\Dockerfile" `
            $webPath `
            --output table
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Web container built and pushed successfully"
        } else {
            Write-Error-Custom "Web container build failed"
            exit 1
        }
    } catch {
        Write-Error-Custom "Web container build failed: $_"
        exit 1
    }
}

# Restart App Services
if (-not $SkipRestart) {
    Show-Banner "Restarting App Services"
    
    if ($RebuildApi -and $apiAppName) {
        Write-Step "Restarting API App Service..."
        az webapp restart --name $apiAppName --resource-group $ResourceGroupName --output none
        Write-Success "API App Service restarted"
        
        Write-Info "Waiting for service to be ready (30 seconds)..."
        Start-Sleep -Seconds 30
        
        Write-Step "Testing API endpoint..."
        try {
            $apiUrl = "https://$apiAppName.azurewebsites.net"
            $healthCheck = Invoke-RestMethod -Uri "$apiUrl/api/healthcheck" -Method Get -TimeoutSec 10
            
            if ($healthCheck.status -eq "healthy") {
                Write-Success "API is healthy and responding"
            } else {
                Write-Warning "API responded but reports unhealthy status"
            }
        } catch {
            Write-Warning "API health check failed (may still be starting up)"
            Write-Info "Check manually: https://$apiAppName.azurewebsites.net/api/healthcheck"
        }
    }
    
    if ($RebuildWeb -and $webAppName) {
        Write-Step "Restarting Web App Service..."
        az webapp restart --name $webAppName --resource-group $ResourceGroupName --output none
        Write-Success "Web App Service restarted"
        
        Write-Info "Waiting for service to be ready (30 seconds)..."
        Start-Sleep -Seconds 30
        
        Write-Step "Testing Web endpoint..."
        try {
            $webUrl = "https://$webAppName.azurewebsites.net"
            $webResponse = Invoke-WebRequest -Uri $webUrl -Method Get -TimeoutSec 10
            
            if ($webResponse.StatusCode -eq 200) {
                Write-Success "Web frontend is accessible"
            }
        } catch {
            Write-Warning "Web frontend check failed (may still be starting up)"
            Write-Info "Check manually: https://$webAppName.azurewebsites.net"
        }
    }
} else {
    Write-Info "Skipping App Service restart (--SkipRestart flag set)"
    Write-Info "To apply changes, manually restart the App Services or re-run without --SkipRestart"
}

# Summary
Show-Banner "🎉 Container Update Complete!"

Write-Host "Updated Resources:" -ForegroundColor Cyan
if ($RebuildApi) {
    Write-Host "  ✅ API Container: $acrLoginServer/saif/api:latest" -ForegroundColor White
    if ($apiAppName -and -not $SkipRestart) {
        Write-Host "     App Service: https://$apiAppName.azurewebsites.net" -ForegroundColor Gray
    }
}
if ($RebuildWeb) {
    Write-Host "  ✅ Web Container: $acrLoginServer/saif/web:latest" -ForegroundColor White
    if ($webAppName -and -not $SkipRestart) {
        Write-Host "     App Service: https://$webAppName.azurewebsites.net" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Info "Next Steps:"
Write-Host "  1. Test the updated application" -ForegroundColor White
Write-Host "  2. Check logs: az webapp log tail --name <app-name> --resource-group $ResourceGroupName" -ForegroundColor White
Write-Host "  3. Monitor Application Insights for any errors" -ForegroundColor White

Write-Host ""
Write-Success "Container update completed successfully!"

#endregion
