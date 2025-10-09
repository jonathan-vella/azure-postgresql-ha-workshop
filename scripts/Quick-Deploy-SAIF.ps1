<#
.SYNOPSIS
    Quick deployment script for SAIF-PostgreSQL environments.

.DESCRIPTION
    Simplified deployment script that automates the complete SAIF-PostgreSQL deployment
    with sensible defaults and automatic password generation. Perfect for:
    - Demo environments
    - Development environments
    - Quick testing
    - CI/CD pipelines

.PARAMETER location
    Azure region for deployment. Default: swedencentral

.PARAMETER environmentName
    Environment name (dev, test, staging, prod). Used for resource naming.
    Default: dev

.PARAMETER postgresqlPassword
    Optional PostgreSQL password. If not provided, a secure password will be auto-generated.

.PARAMETER skipContainers
    Skip container builds (infrastructure only).

.PARAMETER disableHighAvailability
    Disable HA for cost savings (not recommended for production).

.EXAMPLE
    .\Quick-Deploy-SAIF.ps1

.EXAMPLE
    .\Quick-Deploy-SAIF.ps1 -location "germanywestcentral" -environmentName "prod"

.EXAMPLE
    .\Quick-Deploy-SAIF.ps1 -environmentName "test" -disableHighAvailability

.NOTES
    Author: SAIF Team
    Version: 1.0.0
    Date: 2025-10-08
    Requires: Azure CLI, PowerShell 7+
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("swedencentral", "germanywestcentral", "eastus", "eastus2", "westus2", "westeurope", "northeurope")]
    [string]$location = "swedencentral",
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("dev", "test", "staging", "prod")]
    [string]$environmentName = "dev",
    
    [Parameter(Mandatory=$false)]
    [SecureString]$postgresqlPassword,
    
    [Parameter(Mandatory=$false)]
    [switch]$skipContainers,
    
    [Parameter(Mandatory=$false)]
    [switch]$disableHighAvailability
)

$ErrorActionPreference = "Stop"

#region Helper Functions

function Write-Banner {
    param([string]$text)
    $border = "=" * 70
    Write-Host ""
    Write-Host $border -ForegroundColor Cyan
    Write-Host "  $text" -ForegroundColor White -BackgroundColor DarkBlue
    Write-Host $border -ForegroundColor Cyan
    Write-Host ""
}

function Write-Success {
    param([string]$message)
    Write-Host "✅ $message" -ForegroundColor Green
}

function Write-Info {
    param([string]$message)
    Write-Host "ℹ️  $message" -ForegroundColor Cyan
}

function Write-Warning-Custom {
    param([string]$message)
    Write-Host "⚠️  $message" -ForegroundColor Yellow
}

function New-SecurePassword {
    # Generate a secure password with all required characters
    $length = 16
    $uppercase = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    $lowercase = "abcdefghijklmnopqrstuvwxyz"
    $numbers = "0123456789"
    $special = "!@#$%^&*"
    
    $allChars = $uppercase + $lowercase + $numbers + $special
    
    # Ensure at least one of each required type
    $password = @(
        $uppercase[(Get-Random -Maximum $uppercase.Length)]
        $lowercase[(Get-Random -Maximum $lowercase.Length)]
        $numbers[(Get-Random -Maximum $numbers.Length)]
        $special[(Get-Random -Maximum $special.Length)]
    )
    
    # Fill the rest with random characters
    for ($i = $password.Count; $i -lt $length; $i++) {
        $password += $allChars[(Get-Random -Maximum $allChars.Length)]
    }
    
    # Shuffle the password
    return ($password | Get-Random -Count $password.Count) -join ''
}

#endregion

Write-Banner "SAIF-PostgreSQL Quick Deploy"

# Display environment info
Write-Info "Environment Configuration:"
Write-Host "  Environment: $environmentName" -ForegroundColor White
Write-Host "  Location: $location" -ForegroundColor White
Write-Host "  High Availability: $(if ($disableHighAvailability) { 'Disabled' } else { 'Enabled' })" -ForegroundColor White
Write-Host "  Containers: $(if ($skipContainers) { 'Skip' } else { 'Build & Deploy' })" -ForegroundColor White
Write-Host ""

# Generate or use provided password
if (-not $postgresqlPassword) {
    Write-Info "Generating secure PostgreSQL password..."
    $generatedPassword = New-SecurePassword
    $postgresqlPassword = ConvertTo-SecureString $generatedPassword -AsPlainText -Force
    
    Write-Success "Password generated"
    Write-Host ""
    Write-Warning-Custom "IMPORTANT: Save this password securely!"
    Write-Host "  PostgreSQL Password: " -NoNewline -ForegroundColor Yellow
    Write-Host $generatedPassword -ForegroundColor White
    Write-Host ""
    
    # Save to temp file for this session
    $credentialFile = Join-Path $env:TEMP "saif-credentials-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
    @"
SAIF-PostgreSQL Deployment Credentials
Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Environment: $environmentName
Location: $location

PostgreSQL Admin Password: $generatedPassword

IMPORTANT: Delete this file after saving the password to your secure password manager.
"@ | Set-Content -Path $credentialFile
    
    Write-Info "Credentials saved to: $credentialFile"
    Write-Host ""
    
    $continue = Read-Host "Press Enter to continue or Ctrl+C to cancel"
} else {
    Write-Success "Using provided password"
}

# Determine SKU based on environment
$postgresqlSku = switch ($environmentName) {
    "prod" { "Standard_D4ds_v5" }
    "staging" { "Standard_D4ds_v5" }
    "test" { "Standard_D2ds_v5" }
    "dev" { "Standard_D2ds_v5" }
    default { "Standard_D2ds_v5" }
}

Write-Info "Using PostgreSQL SKU: $postgresqlSku (optimized for $environmentName)"
Write-Host ""

# Build resource group name
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
$resourceGroupName = "rg-saif-$environmentName-$locationShort-01"

Write-Info "Target Resource Group: $resourceGroupName"
Write-Host ""

# Get script directory and path to main deployment script
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$deployScript = Join-Path $scriptDir "Deploy-SAIF-PostgreSQL.ps1"

if (-not (Test-Path $deployScript)) {
    Write-Host "❌ Deployment script not found: $deployScript" -ForegroundColor Red
    exit 1
}

# Start deployment
Write-Banner "Starting Deployment"

$deployParams = @{
    location = $location
    resourceGroupName = $resourceGroupName
    postgresqlPassword = $postgresqlPassword
    postgresqlSku = $postgresqlSku
    autoApprove = $true
}

if ($skipContainers) {
    $deployParams.skipContainers = $true
}

if ($disableHighAvailability) {
    $deployParams.disableHighAvailability = $true
}

try {
    Write-Info "Calling main deployment script..."
    Write-Host "  This will take approximately 25-30 minutes" -ForegroundColor Gray
    Write-Host ""
    
    & $deployScript @deployParams
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Deployment failed with exit code: $LASTEXITCODE" -ForegroundColor Red
        exit $LASTEXITCODE
    }
    
    Write-Banner "🎉 Quick Deploy Complete!"
    
    # Retrieve deployment info
    Write-Info "Retrieving deployment details..."
    
    $apiApp = az webapp list --resource-group $resourceGroupName --query "[?contains(name, 'api')]" | ConvertFrom-Json | Select-Object -First 1
    $webApp = az webapp list --resource-group $resourceGroupName --query "[?contains(name, 'web')]" | ConvertFrom-Json | Select-Object -First 1
    $postgresServer = az postgres flexible-server list --resource-group $resourceGroupName | ConvertFrom-Json | Select-Object -First 1
    
    Write-Host ""
    Write-Host "📋 Deployment Summary" -ForegroundColor Cyan
    Write-Host "=" * 70 -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Environment:      " -NoNewline -ForegroundColor Gray
    Write-Host $environmentName -ForegroundColor White
    Write-Host "Resource Group:   " -NoNewline -ForegroundColor Gray
    Write-Host $resourceGroupName -ForegroundColor White
    Write-Host "Location:         " -NoNewline -ForegroundColor Gray
    Write-Host $location -ForegroundColor White
    Write-Host ""
    
    if ($apiApp) {
        Write-Host "🌐 Application URLs:" -ForegroundColor Cyan
        Write-Host "  API:  https://$($apiApp.defaultHostName)" -ForegroundColor Green
        if ($webApp) {
            Write-Host "  Web:  https://$($webApp.defaultHostName)" -ForegroundColor Green
        }
        Write-Host ""
    }
    
    if ($postgresServer) {
        Write-Host "🗄️  Database:" -ForegroundColor Cyan
        Write-Host "  Server:   $($postgresServer.fullyQualifiedDomainName)" -ForegroundColor White
        Write-Host "  Database: saifdb" -ForegroundColor White
        Write-Host "  Username: saifadmin" -ForegroundColor White
        Write-Host ""
    }
    
    Write-Host "📝 Next Steps:" -ForegroundColor Yellow
    Write-Host "  1. Test the API health endpoint" -ForegroundColor White
    Write-Host "  2. Access the Web UI" -ForegroundColor White
    if (-not $disableHighAvailability) {
        Write-Host "  3. Run failover test: .\Test-PostgreSQL-Failover.ps1 -ResourceGroupName '$resourceGroupName'" -ForegroundColor White
    }
    Write-Host ""
    
    if ($credentialFile -and (Test-Path $credentialFile)) {
        Write-Warning-Custom "Don't forget to save your password and delete: $credentialFile"
    }
    
    Write-Host ""
    Write-Success "Deployment completed successfully!"
    
} catch {
    Write-Host "❌ Deployment failed: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Gray
    exit 1
}
