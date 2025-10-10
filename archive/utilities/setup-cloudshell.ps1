# Cloud Shell Setup Script for PowerShell
# Save as setup-cloudshell.ps1

Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  Azure Cloud Shell Setup for SAIF-PostgreSQL Testing        ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Step 1: Check if dotnet-script is already installed
Write-Host "🔍 Checking for dotnet-script..." -ForegroundColor Yellow
$dotnetScriptPath = "$HOME/.dotnet/tools/dotnet-script"

if (Test-Path $dotnetScriptPath) {
    Write-Host "✅ dotnet-script is already installed" -ForegroundColor Green
    & $dotnetScriptPath --version
} else {
    Write-Host "📦 Installing dotnet-script..." -ForegroundColor Yellow
    dotnet tool install -g dotnet-script
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ dotnet-script installed successfully" -ForegroundColor Green
    } else {
        Write-Host "❌ Failed to install dotnet-script" -ForegroundColor Red
        exit 1
    }
}

# Step 2: Add to PATH for current session
Write-Host ""
Write-Host "🔧 Configuring PATH..." -ForegroundColor Yellow
$env:PATH += ":$HOME/.dotnet/tools"

# Step 3: Verify installation
Write-Host ""
Write-Host "✅ Verification:" -ForegroundColor Green
dotnet-script --version

# Step 4: Set up for PowerShell profile (persistent)
Write-Host ""
Write-Host "📝 Adding to PowerShell profile for future sessions..." -ForegroundColor Yellow
$profilePath = $PROFILE.CurrentUserAllHosts

if (-not (Test-Path $profilePath)) {
    New-Item -Path $profilePath -ItemType File -Force | Out-Null
}

$pathEntry = '$env:PATH += ":$HOME/.dotnet/tools"'
if (-not (Select-String -Path $profilePath -Pattern ".dotnet/tools" -Quiet)) {
    Add-Content -Path $profilePath -Value $pathEntry
    Write-Host "✅ Added to PowerShell profile" -ForegroundColor Green
} else {
    Write-Host "✅ Already in PowerShell profile" -ForegroundColor Green
}

# Step 5: Clone repository
Write-Host ""
Write-Host "📥 Checking for SAIF repository..." -ForegroundColor Yellow

if (Test-Path "SAIF") {
    Write-Host "✅ SAIF repository already exists" -ForegroundColor Green
    Push-Location SAIF
    git pull origin main
    Write-Host "✅ Updated to latest version" -ForegroundColor Green
    Pop-Location
} else {
    Write-Host "📥 Cloning SAIF repository..." -ForegroundColor Yellow
    git clone https://github.com/jonathan-vella/SAIF.git
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Repository cloned successfully" -ForegroundColor Green
    } else {
        Write-Host "❌ Failed to clone repository" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                    SETUP COMPLETE                            ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "📍 Next steps:" -ForegroundColor White
Write-Host "   1. cd SAIF/SAIF-pgsql/scripts" -ForegroundColor Gray
Write-Host "   2. Get your connection string (see below)" -ForegroundColor Gray
Write-Host "   3. Run: dotnet script Test-PostgreSQL-Failover.csx -- `"`$CONN_STRING`" 10 5" -ForegroundColor Gray
Write-Host ""
Write-Host "🔐 Get connection string from Key Vault:" -ForegroundColor Yellow
Write-Host '   $PG_PASSWORD = az keyvault secret show --vault-name <vault> --name postgresql-admin-password --query value -o tsv' -ForegroundColor Gray
Write-Host '   $CONN_STRING = "Host=<server>.postgres.database.azure.com;Database=saifdb;Username=saifadmin;Password=$PG_PASSWORD;SSL Mode=Require"' -ForegroundColor Gray
Write-Host ""
