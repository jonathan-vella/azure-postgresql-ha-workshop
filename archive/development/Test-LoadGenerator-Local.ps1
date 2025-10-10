<#
.SYNOPSIS
    Test the LoadGenerator.csx script locally using Docker

.DESCRIPTION
    Runs the load generator in a local Docker container for debugging and validation.
    This provides immediate log visibility without Azure API issues.

.PARAMETER PostgreSQLServer
    PostgreSQL server name (without .postgres.database.azure.com)

.PARAMETER PostgreSQLPassword
    PostgreSQL admin password (SecureString)

.PARAMETER TargetTPS
    Target transactions per second (default: 100)

.PARAMETER WorkerCount
    Number of parallel workers (default: 10)

.PARAMETER TestDuration
    Test duration in seconds (default: 60)

.EXAMPLE
    $pwd = ConvertTo-SecureString "MyPassword" -AsPlainText -Force
    .\Test-LoadGenerator-Local.ps1 -PostgreSQLServer "psql-saifpg-10081025" -PostgreSQLPassword $pwd

.NOTES
    Requires Docker Desktop to be running
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$PostgreSQLServer,

    [Parameter(Mandatory=$true)]
    [SecureString]$PostgreSQLPassword,

    [Parameter(Mandatory=$false)]
    [int]$TargetTPS = 100,

    [Parameter(Mandatory=$false)]
    [int]$WorkerCount = 10,

    [Parameter(Mandatory=$false)]
    [int]$TestDuration = 60,

    [Parameter(Mandatory=$false)]
    [string]$DatabaseName = "saifdb",

    [Parameter(Mandatory=$false)]
    [string]$AdminUsername = "saifadmin",

    [Parameter(Mandatory=$false)]
    [bool]$UsePgBouncer = $true
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "🧪 LOCAL LOAD GENERATOR TEST (DOCKER)" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Check Docker
Write-Host "▶ Checking Docker..." -ForegroundColor Yellow
try {
    docker version | Out-Null
    Write-Host "✅ Docker is running" -ForegroundColor Green
}
catch {
    Write-Host "❌ Docker is not running. Please start Docker Desktop." -ForegroundColor Red
    exit 1
}

# Get script paths
$scriptRoot = Split-Path -Parent $PSCommandPath
$loadGenScript = Join-Path $scriptRoot "LoadGenerator.csx"

if (!(Test-Path $loadGenScript)) {
    Write-Host "❌ LoadGenerator.csx not found at: $loadGenScript" -ForegroundColor Red
    exit 1
}

Write-Host "✅ LoadGenerator.csx found" -ForegroundColor Green

# Convert SecureString to plain text
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($PostgreSQLPassword)
$plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

# Build connection string
$port = if ($UsePgBouncer) { 6432 } else { 5432 }
$connectionString = "Host=$PostgreSQLServer.postgres.database.azure.com;Port=$port;Database=$DatabaseName;Username=$AdminUsername;Password=$plainPassword;SSL Mode=Require"

Write-Host ""
Write-Host "▶ Configuration:" -ForegroundColor Yellow
Write-Host "   PostgreSQL Server: $PostgreSQLServer" -ForegroundColor Gray
Write-Host "   Database: $DatabaseName" -ForegroundColor Gray
Write-Host "   Port: $port $(if ($UsePgBouncer) { '(PgBouncer)' } else { '' })" -ForegroundColor Gray
Write-Host "   Target TPS: $TargetTPS" -ForegroundColor Gray
Write-Host "   Workers: $WorkerCount" -ForegroundColor Gray
Write-Host "   Duration: $TestDuration seconds" -ForegroundColor Gray
Write-Host ""

# Create temp directory for output
$tempDir = Join-Path $env:TEMP "loadtest-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
Write-Host "✅ Created temp directory: $tempDir" -ForegroundColor Green

# Copy script to temp
$tempScript = Join-Path $tempDir "LoadGenerator.csx"
Copy-Item $loadGenScript $tempScript
Write-Host "✅ Copied LoadGenerator.csx" -ForegroundColor Green

# Create logs directory
$logsDir = Join-Path $tempDir "logs"
New-Item -ItemType Directory -Path $logsDir -Force | Out-Null

Write-Host ""
Write-Host "▶ Starting Docker container..." -ForegroundColor Yellow

# Run Docker container
$containerName = "loadtest-local-$(Get-Date -Format 'HHmmss')"

try {
    docker run --rm `
        --name $containerName `
        -v "${tempDir}:/app" `
        -v "${logsDir}:/mnt/logs" `
        -e "POSTGRES_CONNECTION_STRING=$connectionString" `
        -e "TARGET_TPS=$TargetTPS" `
        -e "WORKER_COUNT=$WorkerCount" `
        -e "TEST_DURATION=$TestDuration" `
        -e "OUTPUT_CSV=/mnt/logs/loadtest_results.csv" `
        -e "ENABLE_VERBOSE=false" `
        mcr.microsoft.com/dotnet/sdk:8.0 `
        bash -c "cd /app && dotnet tool install -g dotnet-script --version 1.6.0 && /root/.dotnet/tools/dotnet-script LoadGenerator.csx"
    
    Write-Host ""
    Write-Host "✅ Container completed successfully!" -ForegroundColor Green
}
catch {
    Write-Host ""
    Write-Host "❌ Container failed: $_" -ForegroundColor Red
    exit 1
}
finally {
    # Clean up password from memory
    $plainPassword = $null
    $connectionString = $null
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
}

# Show output files
Write-Host ""
Write-Host "▶ Output files:" -ForegroundColor Yellow
Get-ChildItem $logsDir -Recurse | ForEach-Object {
    Write-Host "   📄 $($_.Name) ($([math]::Round($_.Length/1KB, 2)) KB)" -ForegroundColor Gray
}

# Offer to open logs
Write-Host ""
$response = Read-Host "Open logs directory? (Y/n)"
if ($response -ne 'n') {
    Start-Process $logsDir
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "✅ TEST COMPLETED" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "Logs saved to: $logsDir" -ForegroundColor Green
Write-Host ""
