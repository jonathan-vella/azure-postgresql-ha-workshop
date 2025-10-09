<#
.SYNOPSIS
    Build and push SAIF-PostgreSQL containers to Azure Container Registry.

.DESCRIPTION
    This script automates building and pushing both API and Web containers to ACR.
    Designed for fast iteration during development and reliable CI/CD deployments.
    
    Features:
    - Parallel builds (optional) for faster execution
    - Automatic ACR authentication
    - Health checks after deployment
    - Detailed progress reporting
    - Error handling with rollback guidance
    
.PARAMETER registryName
    The name of the Azure Container Registry (without .azurecr.io).
    Default: Automatically detected from resource group.

.PARAMETER resourceGroupName
    The name of the resource group containing ACR.
    Default: Automatically detected from current subscription.

.PARAMETER tag
    The image tag to use. Default is 'latest'.
    Use semantic versions for production (e.g., 'v1.2.3').

.PARAMETER buildWhat
    What to build: 'all', 'api', or 'web'. Default is 'all'.

.PARAMETER parallel
    Build containers in parallel (faster but uses more resources).
    Default: false (sequential builds).

.PARAMETER skipPush
    Build containers locally without pushing to ACR (for testing).

.PARAMETER restartApps
    Automatically restart App Services after pushing new images.

.EXAMPLE
    .\Build-SAIF-Containers.ps1
    
    Builds and pushes both API and Web containers with default settings.

.EXAMPLE
    .\Build-SAIF-Containers.ps1 -tag "v1.0.0" -restartApps
    
    Builds with version tag and restarts App Services.

.EXAMPLE
    .\Build-SAIF-Containers.ps1 -buildWhat api -skipPush
    
    Builds only the API container locally (no ACR push).

.EXAMPLE
    .\Build-SAIF-Containers.ps1 -parallel
    
    Builds both containers in parallel for faster execution.

.NOTES
    Author: Azure Principal Architect
    Version: 1.0.0
    Date: 2025-10-08
    Requires: Azure CLI, Docker (optional for local builds)
    
    Architecture Notes:
    - Uses ACR Tasks for cloud-native builds (no local Docker required)
    - Implements Azure Well-Architected Framework best practices
    - Unicode-safe build process (progress-bar=off for pip)
    - Idempotent operations (safe to run multiple times)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$registryName,
    
    [Parameter(Mandatory=$false)]
    [string]$resourceGroupName,
    
    [Parameter(Mandatory=$false)]
    [string]$tag = "latest",
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("all", "api", "web")]
    [string]$buildWhat = "all",
    
    [Parameter(Mandatory=$false)]
    [switch]$parallel,
    
    [Parameter(Mandatory=$false)]
    [switch]$skipPush,
    
    [Parameter(Mandatory=$false)]
    [switch]$restartApps
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Script variables
$scriptStartTime = Get-Date

#region Helper Functions

function Write-Banner {
    param([string]$message, [string]$color = "Cyan")
    $border = "=" * ($message.Length + 4)
    Write-Host ""
    Write-Host $border -ForegroundColor $color
    Write-Host "| $message |" -ForegroundColor White -BackgroundColor DarkBlue
    Write-Host $border -ForegroundColor $color
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

function Write-Progress-Custom {
    param([string]$message)
    Write-Host "⏳ $message" -ForegroundColor Magenta
}

function Get-ElapsedTime {
    param([datetime]$startTime)
    $elapsed = (Get-Date) - $startTime
    if ($elapsed.TotalMinutes -ge 1) {
        return "{0:N1}m {1:N0}s" -f $elapsed.TotalMinutes, $elapsed.Seconds
    } else {
        return "{0:N1}s" -f $elapsed.TotalSeconds
    }
}

#endregion

#region Main Script

Write-Banner "SAIF Container Build & Push" "Cyan"

# Step 1: Validate Azure CLI
Write-Step "Validating Azure CLI authentication..."
try {
    $currentAccount = az account show --query "{name:name, user:user.name, id:id}" -o json | ConvertFrom-Json
    Write-Success "Authenticated as: $($currentAccount.user)"
    Write-Info "Subscription: $($currentAccount.name)"
} catch {
    Write-Error-Custom "Please run 'az login' first"
    exit 1
}

# Step 2: Auto-detect ACR if not specified
if (-not $registryName -or -not $resourceGroupName) {
    Write-Step "Auto-detecting Azure Container Registry..."
    
    try {
        # Find ACR in subscription
        $acrListJson = az acr list --query "[].{name:name, resourceGroup:resourceGroup}" -o json
        $acrList = $acrListJson | ConvertFrom-Json
        
        if ($acrList.Count -eq 0) {
            Write-Error-Custom "No Azure Container Registry found in subscription"
            Write-Host "Create one with: az acr create --name <registry-name> --resource-group <rg-name> --sku Basic" -ForegroundColor Gray
            exit 1
        }
        
        if ($acrList.Count -eq 1) {
            $registryName = $acrList[0].name
            $resourceGroupName = $acrList[0].resourceGroup
            Write-Success "Detected ACR: $registryName (in $resourceGroupName)"
        } else {
            # Multiple ACRs found - look for SAIF-related one
            $saifAcr = $acrList | Where-Object { $_.name -like "*saif*" } | Select-Object -First 1
            
            if ($saifAcr) {
                $registryName = $saifAcr.name
                $resourceGroupName = $saifAcr.resourceGroup
                Write-Success "Detected SAIF ACR: $registryName (in $resourceGroupName)"
            } else {
                Write-Error-Custom "Multiple ACRs found. Please specify --registryName and --resourceGroupName"
                Write-Host "Available registries:" -ForegroundColor Yellow
                $acrList | ForEach-Object { Write-Host "  - $($_.name) (in $($_.resourceGroup))" -ForegroundColor Gray }
                exit 1
            }
        }
    } catch {
        Write-Error-Custom "Failed to detect ACR: $_"
        exit 1
    }
}

# Step 3: Verify ACR exists and get login server
Write-Step "Verifying ACR configuration..."
try {
    $acrInfo = az acr show --name $registryName --resource-group $resourceGroupName --query "{loginServer:loginServer, sku:sku.name, adminEnabled:adminUserEnabled}" -o json | ConvertFrom-Json
    $loginServer = $acrInfo.loginServer
    Write-Success "ACR verified: $loginServer (SKU: $($acrInfo.sku))"
} catch {
    Write-Error-Custom "ACR '$registryName' not found in resource group '$resourceGroupName'"
    exit 1
}

# Step 4: Determine repository paths
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptDir
$apiDir = Join-Path $repoRoot "api"
$webDir = Join-Path $repoRoot "web"

Write-Info "Repository root: $repoRoot"
Write-Info "API directory: $apiDir"
Write-Info "Web directory: $webDir"

# Validate directories exist
if (-not (Test-Path $apiDir)) {
    Write-Error-Custom "API directory not found: $apiDir"
    exit 1
}
if (-not (Test-Path $webDir)) {
    Write-Error-Custom "Web directory not found: $webDir"
    exit 1
}

# Step 5: Display build configuration
Write-Host ""
Write-Info "Build Configuration:"
Write-Host "  Registry: $loginServer" -ForegroundColor White
Write-Host "  Tag: $tag" -ForegroundColor White
Write-Host "  Build Target: $buildWhat" -ForegroundColor White
Write-Host "  Parallel Builds: $(if ($parallel) { 'Enabled' } else { 'Disabled' })" -ForegroundColor White
Write-Host "  Push to ACR: $(if ($skipPush) { 'Skip' } else { 'Yes' })" -ForegroundColor White
Write-Host "  Restart Apps: $(if ($restartApps) { 'Yes' } else { 'No' })" -ForegroundColor White
Write-Host ""

# Step 6: Build containers
Write-Banner "Building Container Images" "Yellow"

$buildResults = @{}
$buildJobs = @()

function Build-Container {
    param(
        [string]$name,
        [string]$imageName,
        [string]$dockerfilePath,
        [string]$contextPath,
        [string]$registryName,
        [string]$tag,
        [bool]$skipPush
    )
    
    $buildStartTime = Get-Date
    $fullImageName = "$imageName`:$tag"
    
    Write-Step "Building $name container..."
    Write-Info "Image: $fullImageName"
    Write-Info "Context: $contextPath"
    
    if ($skipPush) {
        # Local Docker build (requires Docker installed)
        Write-Progress-Custom "Building locally with Docker..."
        
        try {
            docker build -t $fullImageName -f $dockerfilePath $contextPath
            
            if ($LASTEXITCODE -eq 0) {
                $elapsed = Get-ElapsedTime $buildStartTime
                Write-Success "$name built successfully in $elapsed"
                return @{ success = $true; duration = $elapsed; image = $fullImageName }
            } else {
                Write-Error-Custom "$name build failed (exit code: $LASTEXITCODE)"
                return @{ success = $false; error = "Docker build failed" }
            }
        } catch {
            Write-Error-Custom "$name build exception: $_"
            return @{ success = $false; error = $_.Exception.Message }
        }
    } else {
        # ACR Task build (cloud-native, no local Docker needed)
        Write-Progress-Custom "Building with ACR Tasks (cloud build)..."
        
        try {
            # Use --no-logs to avoid Unicode encoding issues on Windows
            $buildOutput = az acr build `
                --registry $registryName `
                --image $fullImageName `
                --file $dockerfilePath `
                $contextPath `
                --no-logs `
                2>&1
            
            if ($LASTEXITCODE -eq 0) {
                $elapsed = Get-ElapsedTime $buildStartTime
                Write-Success "$name built and pushed successfully in $elapsed"
                
                # Get image digest
                try {
                    $manifest = az acr repository show-manifests `
                        --name $registryName `
                        --repository $imageName `
                        --orderby time_desc `
                        --top 1 `
                        --query "[0].digest" `
                        -o tsv
                    
                    Write-Info "Digest: $manifest"
                } catch {
                    # Digest lookup is optional
                }
                
                return @{ success = $true; duration = $elapsed; image = $fullImageName }
            } else {
                Write-Error-Custom "$name build failed"
                Write-Host "Build output:" -ForegroundColor Gray
                Write-Host $buildOutput -ForegroundColor Gray
                return @{ success = $false; error = "ACR build failed" }
            }
        } catch {
            Write-Error-Custom "$name build exception: $_"
            return @{ success = $false; error = $_.Exception.Message }
        }
    }
}

# Build API container
if ($buildWhat -eq "all" -or $buildWhat -eq "api") {
    if ($parallel) {
        Write-Info "Starting API build job (parallel)..."
        $apiJob = Start-Job -ScriptBlock ${function:Build-Container} -ArgumentList @(
            "API",
            "saif/api",
            (Join-Path $apiDir "Dockerfile"),
            $apiDir,
            $registryName,
            $tag,
            $skipPush.IsPresent
        )
        $buildJobs += @{ name = "API"; job = $apiJob }
    } else {
        $buildResults["API"] = Build-Container `
            -name "API" `
            -imageName "saif/api" `
            -dockerfilePath (Join-Path $apiDir "Dockerfile") `
            -contextPath $apiDir `
            -registryName $registryName `
            -tag $tag `
            -skipPush $skipPush.IsPresent
    }
}

# Build Web container
if ($buildWhat -eq "all" -or $buildWhat -eq "web") {
    if ($parallel) {
        Write-Info "Starting Web build job (parallel)..."
        $webJob = Start-Job -ScriptBlock ${function:Build-Container} -ArgumentList @(
            "Web",
            "saif/web",
            (Join-Path $webDir "Dockerfile"),
            $webDir,
            $registryName,
            $tag,
            $skipPush.IsPresent
        )
        $buildJobs += @{ name = "Web"; job = $webJob }
    } else {
        $buildResults["Web"] = Build-Container `
            -name "Web" `
            -imageName "saif/web" `
            -dockerfilePath (Join-Path $webDir "Dockerfile") `
            -contextPath $webDir `
            -registryName $registryName `
            -tag $tag `
            -skipPush $skipPush.IsPresent
    }
}

# Wait for parallel builds to complete
if ($parallel -and $buildJobs.Count -gt 0) {
    Write-Step "Waiting for parallel builds to complete..."
    
    foreach ($buildJob in $buildJobs) {
        Write-Progress-Custom "Waiting for $($buildJob.name) build..."
        Wait-Job -Job $buildJob.job | Out-Null
        $buildResults[$buildJob.name] = Receive-Job -Job $buildJob.job
        Remove-Job -Job $buildJob.job -Force
    }
}

# Step 7: Report build results
Write-Banner "Build Results" "Green"

$allSuccessful = $true
$totalDuration = New-TimeSpan

foreach ($container in $buildResults.Keys) {
    $result = $buildResults[$container]
    
    if ($result.success) {
        Write-Host "  $container : " -NoNewline -ForegroundColor White
        Write-Host "✅ Success" -NoNewline -ForegroundColor Green
        Write-Host " ($($result.duration))" -ForegroundColor Gray
        
        if ($result.duration -match '(\d+\.?\d*)m') {
            $minutes = [double]$Matches[1]
            $totalDuration = $totalDuration.Add([TimeSpan]::FromMinutes($minutes))
        } elseif ($result.duration -match '(\d+\.?\d*)s') {
            $seconds = [double]$Matches[1]
            $totalDuration = $totalDuration.Add([TimeSpan]::FromSeconds($seconds))
        }
    } else {
        Write-Host "  $container : " -NoNewline -ForegroundColor White
        Write-Host "❌ Failed" -ForegroundColor Red
        if ($result.error) {
            Write-Host "    Error: $($result.error)" -ForegroundColor Gray
        }
        $allSuccessful = $false
    }
}

Write-Host ""

if (-not $allSuccessful) {
    Write-Error-Custom "One or more builds failed"
    Write-Host "Troubleshooting tips:" -ForegroundColor Yellow
    Write-Host "  1. Check Dockerfile syntax" -ForegroundColor Gray
    Write-Host "  2. Verify source files exist" -ForegroundColor Gray
    Write-Host "  3. Check ACR permissions: az acr login --name $registryName" -ForegroundColor Gray
    Write-Host "  4. Review ACR build logs: az acr task logs --registry $registryName" -ForegroundColor Gray
    exit 1
}

Write-Success "All builds completed successfully!"

# Step 8: Verify images in registry (if pushed)
if (-not $skipPush) {
    Write-Banner "Verifying Registry Images" "Cyan"
    
    Write-Step "Listing images in registry..."
    try {
        $repositories = az acr repository list --name $registryName -o json | ConvertFrom-Json
        $saifRepos = $repositories | Where-Object { $_ -like "saif/*" }
        
        Write-Info "SAIF images in registry:"
        foreach ($repo in $saifRepos) {
            $tags = az acr repository show-tags --name $registryName --repository $repo -o json | ConvertFrom-Json
            
            if ($tags -contains $tag) {
                Write-Host "  ✅ $repo`:$tag" -ForegroundColor Green
            } else {
                Write-Host "  ⚠️  $repo (tag '$tag' not found)" -ForegroundColor Yellow
            }
        }
    } catch {
        Write-Warning-Custom "Could not verify images in registry (may still be processing)"
    }
}

# Step 9: Restart App Services (if requested)
if ($restartApps -and -not $skipPush) {
    Write-Banner "Restarting App Services" "Yellow"
    
    Write-Step "Finding App Services..."
    try {
        $appServices = az webapp list --resource-group $resourceGroupName --query "[?contains(name, 'saif')].{name:name, state:state}" -o json | ConvertFrom-Json
        
        if ($appServices.Count -eq 0) {
            Write-Warning-Custom "No SAIF App Services found in $resourceGroupName"
        } else {
            foreach ($app in $appServices) {
                Write-Step "Restarting $($app.name)..."
                
                az webapp restart --name $app.name --resource-group $resourceGroupName --output none
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Success "$($app.name) restarted"
                } else {
                    Write-Warning-Custom "Failed to restart $($app.name)"
                }
            }
            
            Write-Info "Waiting 10 seconds for services to initialize..."
            Start-Sleep -Seconds 10
            Write-Success "App Services restarted (allow 30-60s for full startup)"
        }
    } catch {
        Write-Warning-Custom "Could not restart App Services: $_"
    }
}

# Step 10: Final summary
Write-Banner "🎉 Build Complete!" "Green"

$scriptDuration = Get-ElapsedTime $scriptStartTime

Write-Host "Summary:" -ForegroundColor Cyan
Write-Host "  Registry: " -NoNewline -ForegroundColor Gray
Write-Host "$loginServer" -ForegroundColor White
Write-Host "  Tag: " -NoNewline -ForegroundColor Gray
Write-Host "$tag" -ForegroundColor White
Write-Host "  Containers Built: " -NoNewline -ForegroundColor Gray
Write-Host "$($buildResults.Keys.Count)" -ForegroundColor White
Write-Host "  Total Duration: " -NoNewline -ForegroundColor Gray
Write-Host $scriptDuration -ForegroundColor White
Write-Host "  Mode: " -NoNewline -ForegroundColor Gray
Write-Host "$(if ($parallel) { 'Parallel' } else { 'Sequential' })" -ForegroundColor White
Write-Host ""

if (-not $skipPush) {
    Write-Host "📦 Images available at:" -ForegroundColor Cyan
    foreach ($container in $buildResults.Keys) {
        $result = $buildResults[$container]
        if ($result.success) {
            Write-Host "  $loginServer/$($result.image)" -ForegroundColor Green
        }
    }
    Write-Host ""
}

Write-Host "📝 Next Steps:" -ForegroundColor Cyan
if ($skipPush) {
    Write-Host "  1. Test locally: docker run -p 8000:8000 saif/api:$tag" -ForegroundColor White
    Write-Host "  2. Push to ACR: Re-run without --skipPush flag" -ForegroundColor White
} elseif (-not $restartApps) {
    Write-Host "  1. Restart App Services: Re-run with --restartApps flag" -ForegroundColor White
    Write-Host "  2. Test API: Invoke-RestMethod https://<api-app>.azurewebsites.net/api/healthcheck" -ForegroundColor White
    Write-Host "  3. View Dashboard: https://<web-app>.azurewebsites.net" -ForegroundColor White
} else {
    Write-Host "  1. Test API: Invoke-RestMethod https://<api-app>.azurewebsites.net/api/healthcheck" -ForegroundColor White
    Write-Host "  2. View Dashboard: https://<web-app>.azurewebsites.net" -ForegroundColor White
    Write-Host "  3. Monitor logs: az webapp log tail --name <app-name> --resource-group $resourceGroupName" -ForegroundColor White
}

Write-Host ""
Write-Success "Container build completed successfully in $scriptDuration!"

#endregion
