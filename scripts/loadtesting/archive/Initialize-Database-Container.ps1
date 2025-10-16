<#
.SYNOPSIS
    Initialize SAIF PostgreSQL database using a PostgreSQL Docker container.

.DESCRIPTION
    This script runs a PostgreSQL client container to execute init-db.sql against
    your Azure PostgreSQL Flexible Server. This eliminates the need to install
    PostgreSQL tools locally - only Docker Desktop is required.

.PARAMETER resourceGroupName
    The name of the Azure resource group containing the PostgreSQL server.

.PARAMETER password
    The admin password for the PostgreSQL server (as SecureString).

.PARAMETER serverName
    (Optional) The name of the PostgreSQL server. If not provided, auto-discovers.

.EXAMPLE
    $pwd = ConvertTo-SecureString "SafeP@ssw0rd2025!" -AsPlainText -Force
    .\Initialize-Database-Container.ps1 -resourceGroupName "rg-saif-pgsql-swc-01" -password $pwd

.NOTES
    Prerequisites:
    - Docker Desktop installed and running
    - Azure CLI authenticated
    
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

Write-Section "🐳 Container-Based Database Initialization"

# Check Docker
Write-Info "Checking Docker availability..."
$dockerAvailable = Get-Command docker -ErrorAction SilentlyContinue

if (-not $dockerAvailable) {
    Write-Error-Custom "Docker is not installed or not in PATH."
    Write-Host "`nPlease install Docker Desktop from:" -ForegroundColor Yellow
    Write-Host "https://www.docker.com/products/docker-desktop" -ForegroundColor Green
    exit 1
}

# Test Docker daemon
Write-Info "Verifying Docker daemon is running..."
try {
    $dockerTest = docker ps 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Error-Custom "Docker daemon is not running."
        Write-Host "Please start Docker Desktop and try again." -ForegroundColor Yellow
        exit 1
    }
    Write-Success "Docker is available and running"
} catch {
    Write-Error-Custom "Failed to communicate with Docker daemon: $_"
    exit 1
}

# Check Azure CLI
Write-Info "Checking Azure CLI authentication..."
$azAccount = az account show 2>$null | ConvertFrom-Json
if (-not $azAccount) {
    Write-Error-Custom "Not logged in to Azure CLI. Run: az login"
    exit 1
}
Write-Success "Authenticated as: $($azAccount.user.name)"

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

# Convert SecureString password to plain text (only for container env var)
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($password)
$plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)

# Enable uuid-ossp extension in Azure (required for init script)
Write-Section "🔧 Configuring Azure PostgreSQL"
Write-Info "Enabling uuid-ossp extension..."

try {
    $extensionResult = az postgres flexible-server parameter set `
        --resource-group $resourceGroupName `
        --server-name $serverName `
        --name azure.extensions `
        --value "UUID-OSSP" `
        --output none 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Extension enabled in Azure PostgreSQL"
    }
    
    # Create extension in database
    Write-Info "Creating uuid-ossp extension in database..."
    $createExtResult = docker run --rm `
        -e PGPASSWORD=$plainPassword `
        postgres:16-alpine `
        psql -h $serverFqdn `
             -U saifadmin `
             -d saifdb `
             -c 'CREATE EXTENSION IF NOT EXISTS "uuid-ossp";' `
        2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Extension created successfully"
    }
} catch {
    Write-Warning-Custom "Extension setup encountered warnings (may already exist)"
}

# Execute init-db.sql using PostgreSQL container
Write-Section "🚀 Running Database Initialization"
Write-Info "Using official PostgreSQL 16 Docker image..."
Write-Info "Executing init-db.sql against $serverFqdn..."

try {
    # Run psql in container with mounted SQL file
    # Using --rm to auto-remove container after execution
    # Using official postgres:16-alpine image (smaller, faster)
    $containerResult = docker run --rm `
        -e PGPASSWORD=$plainPassword `
        -v "${initScript}:/scripts/init-db.sql:ro" `
        postgres:16-alpine `
        psql -h $serverFqdn `
             -U saifadmin `
             -d saifdb `
             -f /scripts/init-db.sql `
        2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Database initialized successfully!"
        
        # Show summary
        Write-Section "📊 Initialization Summary"
        Write-Host "  Database: saifdb" -ForegroundColor White
        Write-Host "  Server: $serverFqdn" -ForegroundColor White
        Write-Host "  Script: init-db.sql" -ForegroundColor White
        Write-Host "`n  Expected data created:" -ForegroundColor Cyan
        Write-Host "    • 5 customers" -ForegroundColor White
        Write-Host "    • 5 merchants" -ForegroundColor White
        Write-Host "    • 7 transactions" -ForegroundColor White
        Write-Host "    • 3 orders with items" -ForegroundColor White
        
        Write-Host "`n✨ Next steps:" -ForegroundColor Green
        Write-Host "   1. Open your web app: https://app-saifpg-web-10081025.azurewebsites.net" -ForegroundColor White
        Write-Host "   2. Refresh the browser (Ctrl+F5)" -ForegroundColor White
        Write-Host "   3. Verify transactions are now visible" -ForegroundColor White
        
    } else {
        Write-Error-Custom "Database initialization failed"
        Write-Host "`nDocker output:" -ForegroundColor Yellow
        Write-Host $containerResult -ForegroundColor Gray
        exit 1
    }
    
} catch {
    Write-Error-Custom "Failed to run container: $_"
    exit 1
} finally {
    # Clear password from memory
    $plainPassword = $null
    [System.GC]::Collect()
}

Write-Host "`n"
