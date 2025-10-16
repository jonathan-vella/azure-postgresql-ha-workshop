<#
.SYNOPSIS
    Initialize SAIF PostgreSQL database using Azure Cloud Shell.

.DESCRIPTION
    This script uploads init-db.sql to Azure Cloud Shell and executes it against
    your PostgreSQL server. Cloud Shell has psql pre-installed, so no local tools needed.
    
    This is the EASIEST option - requires only a web browser!

.PARAMETER resourceGroupName
    The name of the Azure resource group containing the PostgreSQL server.

.PARAMETER password
    The admin password for the PostgreSQL server (as SecureString).

.PARAMETER serverName
    (Optional) The name of the PostgreSQL server. If not provided, auto-discovers.

.EXAMPLE
    $pwd = ConvertTo-SecureString "SafeP@ssw0rd2025!" -AsPlainText -Force
    .\Initialize-Database-CloudShell.ps1 -resourceGroupName "rg-saif-pgsql-swc-01" -password $pwd

.NOTES
    Prerequisites:
    - Azure CLI authenticated
    - Azure Cloud Shell configured (first-time setup if needed)
    
    Author: SAIF Deployment Team
    Version: 1.0.0
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$resourceGroupName,

    [Parameter(Mandatory = $true)]
    [SecureString]$password,

    [Parameter(Mandatory = $false)]
    [string]$serverName
)

# ========================================
# Helper Functions
# ========================================

function Write-Section {
    param([string]$Message)
    Write-Host "`n╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  $Message" -ForegroundColor White
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "✅ $Message" -ForegroundColor Green
}

function Write-Info {
    param([string]$Message)
    Write-Host "ℹ️  $Message" -ForegroundColor Cyan
}

function Write-Warning-Custom {
    param([string]$Message)
    Write-Host "⚠️  $Message" -ForegroundColor Yellow
}

function Write-Error-Custom {
    param([string]$Message)
    Write-Host "❌ $Message" -ForegroundColor Red
}

# ========================================
# Main Script
# ========================================

Write-Section "☁️  Azure Cloud Shell Database Initialization"

# Check Azure CLI
Write-Info "Checking Azure CLI authentication..."
$azAccount = az account show 2>$null | ConvertFrom-Json
if (-not $azAccount) {
    Write-Error-Custom "Not logged in to Azure CLI. Run: az login"
    exit 1
}
Write-Success "Authenticated as: $($azAccount.user.name)"
Write-Success "Subscription: $($azAccount.name)"

# Discover PostgreSQL server
if (-not $serverName) {
    Write-Info "Discovering PostgreSQL server in resource group '$resourceGroupName'..."
    $servers = az postgres flexible-server list --resource-group $resourceGroupName --query "[].{name:name, state:state}" | ConvertFrom-Json
    
    if (-not $servers -or $servers.Count -eq 0) {
        Write-Error-Custom "No PostgreSQL servers found in resource group '$resourceGroupName'"
        exit 1
    }
    
    if ($servers.Count -gt 1) {
        Write-Warning-Custom "Multiple PostgreSQL servers found. Using first one."
    }
    
    $serverName = $servers[0].name
    Write-Success "Found server: $serverName (State: $($servers[0].state))"
} else {
    Write-Info "Using specified server: $serverName"
}

# Get server FQDN
Write-Info "Retrieving server connection details..."
$serverFqdn = az postgres flexible-server show --name $serverName --resource-group $resourceGroupName --query "fullyQualifiedDomainName" -o tsv
if (-not $serverFqdn) {
    Write-Error-Custom "Failed to retrieve server FQDN"
    exit 1
}
Write-Success "Server FQDN: $serverFqdn"

# Locate init-db.sql
$scriptDir = Split-Path -Parent $PSCommandPath
$repoRoot = Split-Path -Parent $scriptDir
$initScript = Join-Path $repoRoot "init-db.sql"

if (-not (Test-Path $initScript)) {
    Write-Error-Custom "init-db.sql not found at: $initScript"
    exit 1
}
Write-Success "Found init-db.sql: $initScript"

# Convert SecureString password
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($password)
$plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)

Write-Section "📋 Generating Cloud Shell Script"

# Create a bash script for Cloud Shell
$cloudShellScript = @"
#!/bin/bash
# SAIF PostgreSQL Database Initialization Script
# Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

echo "╔══════════════════════════════════════════════════════════════╗"
echo "  🗄️  SAIF Database Initialization via Cloud Shell"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Set PostgreSQL connection details
export PGHOST='$serverFqdn'
export PGUSER='saifadmin'
export PGDATABASE='saifdb'
export PGPASSWORD='$plainPassword'

echo "ℹ️  Connecting to: $serverFqdn"
echo "ℹ️  Database: saifdb"
echo ""

# Execute the SQL script
echo "🚀 Executing init-db.sql..."
psql -f init-db.sql

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Database initialized successfully!"
    echo ""
    echo "📊 Expected data created:"
    echo "   • 5 customers (john.doe@example.com, jane.smith@example.com, etc.)"
    echo "   • 5 merchants (TechStore Inc, Fashion Boutique, etc.)"
    echo "   • 7 transactions (completed, processing, failed, refunded)"
    echo "   • 3 orders with items"
    echo ""
    echo "✨ Next steps:"
    echo "   1. Close this Cloud Shell window"
    echo "   2. Open your web app and refresh the browser"
    echo "   3. Verify transactions are now visible"
    echo ""
else
    echo ""
    echo "❌ Database initialization failed!"
    echo "Please check the error messages above."
    exit 1
fi

# Clean up password from environment
unset PGPASSWORD
"@

# Save scripts to temp directory
$tempDir = Join-Path $env:TEMP "saif-cloudshell"
if (-not (Test-Path $tempDir)) {
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
}

$cloudShellScriptPath = Join-Path $tempDir "init-database.sh"
$cloudShellScript | Out-File -FilePath $cloudShellScriptPath -Encoding utf8 -Force

Write-Success "Cloud Shell script generated: $cloudShellScriptPath"

Write-Section "☁️  Opening Azure Cloud Shell"

Write-Host @"

📋 INSTRUCTIONS:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Azure Cloud Shell will open in your browser. Follow these steps:

1️⃣  Wait for Cloud Shell to fully load (you'll see a bash prompt)

2️⃣  Upload the files:
   • Click the 📁 "Upload/Download files" button in Cloud Shell toolbar
   • Upload these TWO files:
     ✓ $initScript
     ✓ $cloudShellScriptPath

3️⃣  Run the initialization:
   bash init-database.sh

4️⃣  Wait for completion (should take 5-10 seconds)

5️⃣  Close Cloud Shell and refresh your web app

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Press any key to open Azure Cloud Shell...
"@ -ForegroundColor Cyan

$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Open Cloud Shell
Write-Info "Opening Cloud Shell in your default browser..."
Start-Process "https://shell.azure.com"

Write-Host "`n"
Write-Section "📂 Files Ready for Upload"
Write-Host "  SQL Script: " -NoNewline -ForegroundColor White
Write-Host $initScript -ForegroundColor Green
Write-Host "  Bash Script: " -NoNewline -ForegroundColor White
Write-Host $cloudShellScriptPath -ForegroundColor Green

Write-Host "`n💡 TIP: " -NoNewline -ForegroundColor Yellow
Write-Host "Both files are in the upload list. Select them both and upload together!" -ForegroundColor White
Write-Host "`n"

# Clear password
$plainPassword = $null
[System.GC]::Collect()
