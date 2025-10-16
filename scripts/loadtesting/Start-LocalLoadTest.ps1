<#
.SYNOPSIS
Deploy and run LoadGenerator locally in Docker container

.DESCRIPTION
Manages local Docker container for load testing with controlled throughput.
Provides resource limiting to achieve target TPS on local machines.

.PARAMETER Action
Operation to perform:
  - Start: Build and start the container
  - Stop: Stop the running container
  - Status: Check container status
  - Logs: Stream container logs
  - Clean: Remove container and volumes

.PARAMETER PostgreSQLServer
PostgreSQL server FQDN - default: 'pg-cus.postgres.database.azure.com'

.PARAMETER DatabaseName
PostgreSQL database name - default: 'saifdb'

.PARAMETER AdminUsername
PostgreSQL admin username - default: 'jonathan'

.PARAMETER AdminPassword
PostgreSQL admin password - will prompt if not provided

.PARAMETER TargetTPS
Target transactions per second - default: 1000
(Lower on local machine due to CPU/memory constraints)

.PARAMETER WorkerCount
Number of concurrent workers - default: 5
(Lower for local execution to control throughput)

.PARAMETER TestDuration
Test duration in seconds - default: 300

.EXAMPLE
# Start local load test with default settings
.\Start-LocalLoadTest.ps1 -Start -AdminPassword "MyPassword"

# Start with custom TPS
.\Start-LocalLoadTest.ps1 -Start -TargetTPS 500 -AdminPassword "MyPassword"

# Check status
.\Start-LocalLoadTest.ps1 -Status

# View logs
.\Start-LocalLoadTest.ps1 -Logs

# Stop container
.\Start-LocalLoadTest.ps1 -Stop

# Clean up
.\Start-LocalLoadTest.ps1 -Clean
#>

param(
    [ValidateSet('Start', 'Stop', 'Status', 'Logs', 'Clean')]
    [string]$Action = 'Start',
    
    [string]$PostgreSQLServer = 'pg-cus.postgres.database.azure.com',
    [string]$DatabaseName = 'saifdb',
    [string]$AdminUsername = 'jonathan',
    [string]$AdminPassword,
    [int]$TargetTPS = 1000,
    [int]$WorkerCount = 5,
    [int]$TestDuration = 300
)

$ContainerName = 'loadgen-local'
$ComposeFile = Join-Path $PSScriptRoot 'docker-compose.local.yml'

function Write-Header {
    param([string]$Message)
    Write-Host "`n═══════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host $Message -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════`n" -ForegroundColor Cyan
}

function Write-Status {
    param([string]$Message, [string]$Status = 'Info')
    $Color = @{
        'Success' = 'Green'
        'Error'   = 'Red'
        'Warning' = 'Yellow'
        'Info'    = 'Cyan'
    }
    Write-Host "[$Status] $Message" -ForegroundColor $Color[$Status]
}

# Validate prerequisites
function Test-Prerequisites {
    Write-Header "Validating Prerequisites"
    
    # Check Docker
    try {
        docker --version | Out-Null
        Write-Status "✓ Docker is available" 'Success'
    }
    catch {
        Write-Status "✗ Docker is not installed or not in PATH" 'Error'
        exit 1
    }
    
    # Check Docker Compose
    try {
        docker-compose --version | Out-Null
        Write-Status "✓ Docker Compose is available" 'Success'
    }
    catch {
        Write-Status "✗ Docker Compose is not installed" 'Error'
        exit 1
    }
    
    # Check compose file exists
    if (-not (Test-Path $ComposeFile)) {
        Write-Status "✗ docker-compose.local.yml not found at $ComposeFile" 'Error'
        exit 1
    }
    Write-Status "✓ docker-compose.local.yml found" 'Success'
}

# Start container
function Invoke-Start {
    Write-Header "Starting Local Load Test Container"
    
    # Prompt for password if not provided
    if ([string]::IsNullOrEmpty($AdminPassword)) {
        $AdminPassword = Read-Host "Enter PostgreSQL password" -AsSecureString
        $AdminPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($AdminPassword)
        )
    }
    
    # Check if container already running
    $runningContainer = docker ps --filter "name=$ContainerName" --quiet
    if ($runningContainer) {
        Write-Status "Container '$ContainerName' is already running (ID: $runningContainer)" 'Warning'
        Write-Host "Use '-Stop' to stop it first, or '-Clean' to remove it`n"
        return
    }
    
    # Set environment variables for compose
    $env:POSTGRESQL_SERVER = $PostgreSQLServer
    $env:POSTGRESQL_DATABASE = $DatabaseName
    $env:POSTGRESQL_USERNAME = $AdminUsername
    $env:POSTGRESQL_PASSWORD = $AdminPassword
    $env:TARGET_TPS = $TargetTPS
    $env:WORKER_COUNT = $WorkerCount
    $env:TEST_DURATION = $TestDuration
    
    Write-Status "Configuration:" 'Info'
    Write-Host "  PostgreSQL Server: $PostgreSQLServer"
    Write-Host "  Database: $DatabaseName"
    Write-Host "  Username: $AdminUsername"
    Write-Host "  Target TPS: $TargetTPS"
    Write-Host "  Workers: $WorkerCount"
    Write-Host "  Duration: $TestDuration seconds"
    Write-Host "  Container: $ContainerName"
    Write-Host "  Web Interface: http://localhost:8080`n"
    
    Write-Status "Building and starting container..." 'Info'
    try {
        docker-compose -f $ComposeFile up -d
        Start-Sleep -Seconds 5
        
        # Check if started successfully
        $containerStatus = docker ps --filter "name=$ContainerName" --quiet
        if ($containerStatus) {
            Write-Status "✓ Container started successfully (ID: $containerStatus)" 'Success'
            Write-Host "`n📊 Access the load test console at: http://localhost:8080`n"
            Write-Host "Available endpoints:"
            Write-Host "  • /start   - Start the load test via POST"
            Write-Host "  • /status  - Check test status (returns JSON)"
            Write-Host "  • /health  - Health check endpoint"
            Write-Host "  • /logs    - Stream test logs (returns JSON)`n"
        }
        else {
            Write-Status "✗ Container failed to start" 'Error'
            docker-compose -f $ComposeFile logs --tail 20
            exit 1
        }
    }
    catch {
        Write-Status "✗ Error starting container: $_" 'Error'
        exit 1
    }
}

# Stop container
function Invoke-Stop {
    Write-Header "Stopping Local Load Test Container"
    
    $containerStatus = docker ps --filter "name=$ContainerName" --quiet
    if (-not $containerStatus) {
        Write-Status "Container '$ContainerName' is not running" 'Warning'
        return
    }
    
    try {
        docker-compose -f $ComposeFile down
        Write-Status "✓ Container stopped" 'Success'
    }
    catch {
        Write-Status "✗ Error stopping container: $_" 'Error'
        exit 1
    }
}

# Show status
function Invoke-Status {
    Write-Header "Container Status"
    
    $container = docker ps -a --filter "name=$ContainerName" --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}"
    if ($container) {
        $container | Format-Table -AutoSize
        
        # If running, show more details
        $runningContainer = docker ps --filter "name=$ContainerName" --quiet
        if ($runningContainer) {
            Write-Host "`n📊 Load Test Status:" -ForegroundColor Cyan
            try {
                $response = Invoke-RestMethod -Uri "http://localhost:8080/status" -ErrorAction SilentlyContinue
                if ($response) {
                    $response | Format-List
                }
            }
            catch {
                Write-Status "Could not connect to container - it may still be starting" 'Warning'
            }
        }
    }
    else {
        Write-Status "No container found with name '$ContainerName'" 'Warning'
    }
}

# Show logs
function Invoke-Logs {
    Write-Header "Container Logs"
    
    $containerStatus = docker ps -a --filter "name=$ContainerName" --quiet
    if (-not $containerStatus) {
        Write-Status "Container '$ContainerName' not found" 'Error'
        return
    }
    
    try {
        docker-compose -f $ComposeFile logs -f
    }
    catch {
        Write-Status "✗ Error retrieving logs: $_" 'Error'
    }
}

# Clean up
function Invoke-Clean {
    Write-Header "Cleaning Up"
    
    Write-Status "⚠ This will remove the container and associated volumes" 'Warning'
    $response = Read-Host "Continue? (yes/no)"
    
    if ($response -ne 'yes') {
        Write-Status "Cleanup cancelled" 'Info'
        return
    }
    
    try {
        docker-compose -f $ComposeFile down -v
        Write-Status "✓ Container and volumes removed" 'Success'
    }
    catch {
        Write-Status "✗ Error during cleanup: $_" 'Error'
        exit 1
    }
}

# Main execution
try {
    Test-Prerequisites
    
    switch ($Action) {
        'Start' { Invoke-Start }
        'Stop'  { Invoke-Stop }
        'Status' { Invoke-Status }
        'Logs'  { Invoke-Logs }
        'Clean' { Invoke-Clean }
    }
}
catch {
    Write-Status "✗ Unexpected error: $_" 'Error'
    exit 1
}
