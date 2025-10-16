<#
.SYNOPSIS
    Run load generator locally using Docker

.DESCRIPTION
    Runs the C# load generator in a local Docker container for testing and debugging.
    Much faster than deploying to ACI for quick iterations.

.PARAMETER PostgreSQLServer
    PostgreSQL server FQDN (e.g., pg-cus.postgres.database.azure.com)

.PARAMETER DatabaseName
    Database name (default: saifdb)

.PARAMETER AdminUsername
    Database username (default: jonathan)

.PARAMETER PostgreSQLPassword
    PostgreSQL admin password (SecureString or plain string)

.PARAMETER TargetTPS
    Target transactions per second (default: 1000)

.PARAMETER WorkerCount
    Number of parallel workers (default: 100)

.PARAMETER TestDuration
    Test duration in seconds (default: 60)

.PARAMETER UsePgBouncer
    Use PgBouncer port 6432 (default: true)

.PARAMETER EnableVerbose
    Enable verbose logging (default: false)

.EXAMPLE
    .\Run-LoadGenerator-Local.ps1 -PostgreSQLServer "pg-cus.postgres.database.azure.com" -AdminUsername "jonathan"

.EXAMPLE
    .\Run-LoadGenerator-Local.ps1 `
        -PostgreSQLServer "pg-cus.postgres.database.azure.com" `
        -DatabaseName "saifdb" `
        -AdminUsername "jonathan" `
        -TargetTPS 2000 `
        -WorkerCount 200 `
        -TestDuration 180

.NOTES
    Author: Azure Principal Architect Agent
    Version: 1.0.0
    Requires: Docker Desktop
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$PostgreSQLServer,

    [Parameter(Mandatory=$false)]
    [string]$DatabaseName = "saifdb",

    [Parameter(Mandatory=$false)]
    [string]$AdminUsername = "jonathan",

    [Parameter(Mandatory=$false)]
    $PostgreSQLPassword,

    [Parameter(Mandatory=$false)]
    [int]$TargetTPS = 1000,

    [Parameter(Mandatory=$false)]
    [int]$WorkerCount = 100,

    [Parameter(Mandatory=$false)]
    [int]$TestDuration = 60,

    [Parameter(Mandatory=$false)]
    [bool]$UsePgBouncer = $true,

    [Parameter(Mandatory=$false)]
    [bool]$EnableVerbose = $false
)

$ErrorActionPreference = "Stop"

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

function Write-Banner {
    param([string]$Message)
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host $Message -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Step {
    param([string]$Message)
    Write-Host "▶ $Message" -ForegroundColor Yellow
}

function Write-Success {
    param([string]$Message)
    Write-Host "✅ $Message" -ForegroundColor Green
}

function Write-Error {
    param([string]$Message)
    Write-Host "❌ $Message" -ForegroundColor Red
}

function Write-Info {
    param([string]$Message)
    Write-Host "ℹ️  $Message" -ForegroundColor Cyan
}

# ============================================================================
# MAIN
# ============================================================================

Write-Banner "🐳 RUNNING LOAD GENERATOR LOCALLY IN DOCKER"

# Check Docker
Write-Step "Checking Docker..."
$dockerVersion = docker --version 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Error "Docker not found. Please install Docker Desktop from https://www.docker.com/products/docker-desktop"
    exit 1
}
Write-Success "Docker installed: $dockerVersion"

# Get password if not provided
if (-not $PostgreSQLPassword) {
    Write-Step "Enter database credentials"
    Write-Host "Username: $AdminUsername" -ForegroundColor White
    $PostgreSQLPassword = Read-Host "Password" -AsSecureString
}

# Convert SecureString to plain text
if ($PostgreSQLPassword -is [SecureString]) {
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($PostgreSQLPassword)
    $plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
} else {
    $plainPassword = $PostgreSQLPassword
}

# Ensure server FQDN
if (-not $PostgreSQLServer.Contains(".")) {
    $PostgreSQLServer = "$PostgreSQLServer.postgres.database.azure.com"
}

# Build connection string
$port = if ($UsePgBouncer) { 6432 } else { 5432 }
$minPoolSize = [int]($WorkerCount * 0.25)
$maxPoolSize = $WorkerCount + 100

$connectionString = "Host=$PostgreSQLServer;Port=$port;Database=$DatabaseName;Username=$AdminUsername;Password=$plainPassword;SSL Mode=Require;Pooling=true;Minimum Pool Size=$minPoolSize;Maximum Pool Size=$maxPoolSize;Connection Idle Lifetime=300"

Write-Step "Configuration:"
Write-Host "   PostgreSQL Server: $PostgreSQLServer" -ForegroundColor White
Write-Host "   Database: $DatabaseName" -ForegroundColor White
Write-Host "   Username: $AdminUsername" -ForegroundColor White
Write-Host "   Port: $port $(if ($UsePgBouncer) { '(PgBouncer)' } else { '(Direct)' })" -ForegroundColor White
Write-Host "   Target TPS: $TargetTPS" -ForegroundColor White
Write-Host "   Workers: $WorkerCount" -ForegroundColor White
Write-Host "   Duration: $TestDuration seconds" -ForegroundColor White
Write-Host "   Verbose: $EnableVerbose" -ForegroundColor White
Write-Host ""

# Get script directory
$scriptDir = $PSScriptRoot
if ([string]::IsNullOrEmpty($scriptDir)) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
}

# Check if LoadGenerator.csx exists
$loadGenScript = Join-Path $scriptDir "LoadGenerator.csx"
if (-not (Test-Path $loadGenScript)) {
    Write-Error "LoadGenerator.csx not found at: $loadGenScript"
    exit 1
}

Write-Success "Found LoadGenerator.csx"

# Create output directory for results
$outputDir = Join-Path $scriptDir "loadtest-results"
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$csvOutput = Join-Path $outputDir "loadtest_results_$timestamp.csv"
$detailedLog = Join-Path $outputDir "loadtest_detailed_$timestamp.log"
$errorLog = Join-Path $outputDir "loadtest_errors_$timestamp.log"

Write-Info "Results will be saved to:"
Write-Host "   CSV: $csvOutput" -ForegroundColor White
Write-Host "   Detailed Log: $detailedLog" -ForegroundColor White
Write-Host "   Error Log: $errorLog" -ForegroundColor White
Write-Host ""

# Generate unique container name
$containerName = "loadgen-local-$timestamp"

Write-Step "Starting Docker container..."
Write-Info "Container name: $containerName"
Write-Host ""

# Run Docker container
# Mount the scripts directory to access LoadGenerator.csx
# Mount output directory to save results
# Note: Using array format to avoid PowerShell variable interpolation issues with bash variables
$dockerArgs = @(
    "run"
    "--rm"
    "--name"
    $containerName
    "-v"
    "$($scriptDir):/app"
    "-v"
    "$($outputDir):/output"
    "-e"
    "POSTGRES_CONNECTION_STRING=$connectionString"
    "-e"
    "TARGET_TPS=$TargetTPS"
    "-e"
    "WORKER_COUNT=$WorkerCount"
    "-e"
    "TEST_DURATION=$TestDuration"
    "-e"
    "OUTPUT_CSV=/output/loadtest_results_$timestamp.csv"
    "-e"
    "ENABLE_VERBOSE=$($EnableVerbose.ToString().ToLower())"
    "mcr.microsoft.com/dotnet/sdk:8.0"
    "/bin/bash"
    "-c"
    "echo 'Installing dotnet-script...' && dotnet tool install -g dotnet-script && export PATH=`$PATH:/root/.dotnet/tools && echo 'Starting load generator...' && cd /app && dotnet script LoadGenerator.csx"
)

Write-Info "Running Docker command..."
Write-Host ""

# Execute Docker command
try {
    # Show the command (without password)
    $safeArgs = $dockerArgs.Clone()
    for ($i = 0; $i -lt $safeArgs.Count; $i++) {
        if ($safeArgs[$i] -like "*Password=*") {
            $safeArgs[$i] = $safeArgs[$i] -replace "Password=[^;]+", "Password=***"
        }
    }
    Write-Host "Command (password hidden):" -ForegroundColor DarkGray
    Write-Host "docker $($safeArgs -join ' ')" -ForegroundColor DarkGray
    Write-Host ""
    
    # Execute using argument array (avoids PowerShell variable interpolation)
    & docker $dockerArgs
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Success "Load test completed successfully!"
        Write-Host ""
        Write-Info "Results saved to:"
        Write-Host "   $outputDir" -ForegroundColor White
        Write-Host ""
        
        # Check if CSV was created
        if (Test-Path $csvOutput) {
            Write-Success "CSV file created: $(Split-Path -Leaf $csvOutput)"
            $lineCount = (Get-Content $csvOutput | Measure-Object -Line).Lines
            Write-Info "Data points: $($lineCount - 1)" # Subtract header
        } else {
            Write-Host "⚠️  CSV file not found at expected location" -ForegroundColor Yellow
        }
        
        # List all files in output directory
        Write-Host ""
        Write-Info "All output files:"
        Get-ChildItem $outputDir -Filter "*$timestamp*" | ForEach-Object {
            $size = [math]::Round($_.Length / 1KB, 2)
            Write-Host "   - $($_.Name) ($size KB)" -ForegroundColor White
        }
    } else {
        Write-Error "Load test failed with exit code: $LASTEXITCODE"
    }
} catch {
    Write-Error "Failed to run Docker container: $_"
    
    # Try to clean up container if it exists
    Write-Host ""
    Write-Step "Attempting to clean up container..."
    docker rm -f $containerName 2>$null | Out-Null
} finally {
    # Clear password from memory
    if ($plainPassword) {
        $plainPassword = $null
    }
    if ($connectionString) {
        $connectionString = $null
    }
    $env:POSTGRES_CONNECTION_STRING = $null
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
