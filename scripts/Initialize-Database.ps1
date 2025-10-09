<#
.SYNOPSIS
    Initialize SAIF-PostgreSQL database with schema and demo data.

.DESCRIPTION
    This script initializes the PostgreSQL database by running the init-db.sql script.
    It checks for psql availability and provides installation guidance if needed.

.PARAMETER resourceGroupName
    Resource group name containing the PostgreSQL server.

.PARAMETER serverName
    PostgreSQL server name (optional, will be auto-discovered).

.PARAMETER password
    PostgreSQL admin password (SecureString).

.EXAMPLE
    $pwd = ConvertTo-SecureString "SafeP@ssw0rd2025!" -AsPlainText -Force
    .\Initialize-Database.ps1 -resourceGroupName "rg-saif-pgsql-swc-01" -password $pwd

.NOTES
    Requires: PostgreSQL client tools (psql) or Azure Data Studio
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$resourceGroupName,
    
    [Parameter(Mandatory=$false)]
    [string]$serverName,
    
    [Parameter(Mandatory=$true)]
    [SecureString]$password
)

$ErrorActionPreference = "Stop"

Write-Host "`n================================================" -ForegroundColor Cyan
Write-Host "  SAIF-PostgreSQL Database Initialization" -ForegroundColor White
Write-Host "================================================`n" -ForegroundColor Cyan

# Convert password to plain text
$postgresPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($password)
)

# Find PostgreSQL server if not specified
if (-not $serverName) {
    Write-Host "📍 Finding PostgreSQL server..." -ForegroundColor Yellow
    $servers = az postgres flexible-server list --resource-group $resourceGroupName | ConvertFrom-Json
    if ($servers.Count -eq 0) {
        Write-Host "❌ No PostgreSQL servers found in resource group" -ForegroundColor Red
        exit 1
    }
    $serverName = $servers[0].name
    Write-Host "✅ Found server: $serverName" -ForegroundColor Green
}

# Get server details
Write-Host "`n📍 Retrieving server details..." -ForegroundColor Yellow
$server = az postgres flexible-server show `
    --resource-group $resourceGroupName `
    --name $serverName | ConvertFrom-Json

$serverFqdn = $server.fullyQualifiedDomainName
Write-Host "✅ Server FQDN: $serverFqdn" -ForegroundColor Green

# Check if psql is available
Write-Host "`n📍 Checking for PostgreSQL client..." -ForegroundColor Yellow
$psqlPath = Get-Command psql -ErrorAction SilentlyContinue

if (-not $psqlPath) {
    Write-Host "⚠️  PostgreSQL client (psql) not found" -ForegroundColor Yellow
    Write-Host "`nOPTION 1: Install PostgreSQL Client Tools" -ForegroundColor Cyan
    Write-Host "  Download from: https://www.postgresql.org/download/windows/" -ForegroundColor White
    Write-Host "  After installation, add to PATH and restart PowerShell" -ForegroundColor Gray
    
    Write-Host "`nOPTION 2: Use Azure Data Studio" -ForegroundColor Cyan
    Write-Host "  1. Download: https://aka.ms/azuredatastudio" -ForegroundColor White
    Write-Host "  2. Install PostgreSQL extension" -ForegroundColor White
    Write-Host "  3. Connect to: $serverFqdn" -ForegroundColor White
    Write-Host "  4. Open and run: init-db.sql" -ForegroundColor White
    
    Write-Host "`nOPTION 3: Manual Command (Copy & Run)" -ForegroundColor Cyan
    Write-Host "  After installing psql, run:" -ForegroundColor White
    $scriptPath = Join-Path (Get-Location) "..\init-db.sql"
    Write-Host "  psql -h $serverFqdn -U saifadmin -d saifdb -f `"$scriptPath`"" -ForegroundColor Green
    
    Write-Host "`n" -NoNewline
    exit 1
}

Write-Host "✅ PostgreSQL client found: $($psqlPath.Source)" -ForegroundColor Green

# Find init-db.sql
Write-Host "`n📍 Locating init-db.sql..." -ForegroundColor Yellow
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptDir
$initScript = Join-Path $repoRoot "init-db.sql"

if (-not (Test-Path $initScript)) {
    Write-Host "❌ init-db.sql not found at: $initScript" -ForegroundColor Red
    exit 1
}
Write-Host "✅ Found: $initScript" -ForegroundColor Green

# Initialize database
Write-Host "`n📍 Initializing database..." -ForegroundColor Yellow
Write-Host "  Server: $serverFqdn" -ForegroundColor Gray
Write-Host "  Database: saifdb" -ForegroundColor Gray
Write-Host "  User: saifadmin" -ForegroundColor Gray
Write-Host "  This may take 30-60 seconds...`n" -ForegroundColor Gray

try {
    # Set password environment variable
    $env:PGPASSWORD = $postgresPassword
    
    # Run psql
    $output = psql -h $serverFqdn `
        -U saifadmin `
        -d saifdb `
        -f $initScript `
        2>&1
    
    # Clear password
    $env:PGPASSWORD = $null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Database initialized successfully!" -ForegroundColor Green
        
        Write-Host "`n📊 Summary:" -ForegroundColor Cyan
        Write-Host "  • Tables created: 8" -ForegroundColor White
        Write-Host "  • Views created: 2" -ForegroundColor White
        Write-Host "  • Functions created: 1" -ForegroundColor White
        Write-Host "  • Demo customers: 5" -ForegroundColor White
        Write-Host "  • Demo merchants: 5" -ForegroundColor White
        Write-Host "  • Demo transactions: 7" -ForegroundColor White
        
        Write-Host "`n🎯 Next Steps:" -ForegroundColor Yellow
        Write-Host "  1. Refresh your web browser" -ForegroundColor White
        Write-Host "  2. View recent transactions in the UI" -ForegroundColor White
        Write-Host "  3. Test the diagnostic endpoints" -ForegroundColor White
        
        Write-Host "`n✅ Initialization complete!`n" -ForegroundColor Green
    } else {
        Write-Host "❌ Database initialization failed" -ForegroundColor Red
        Write-Host "`nError Output:" -ForegroundColor Yellow
        Write-Host $output -ForegroundColor Gray
        exit 1
    }
    
} catch {
    $env:PGPASSWORD = $null
    Write-Host "❌ Error: $_" -ForegroundColor Red
    exit 1
}
