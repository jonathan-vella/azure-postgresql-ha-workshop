<#
.SYNOPSIS
    Tests SAIF-PostgreSQL application locally using Docker Compose.

.DESCRIPTION
    Validates local development environment, starts containers, and runs health checks.

.PARAMETER SkipBuild
    Skip building containers (use existing images).

.PARAMETER CleanStart
    Remove existing containers and volumes before starting.

.EXAMPLE
    .\Test-SAIFLocal.ps1

.EXAMPLE
    .\Test-SAIFLocal.ps1 -CleanStart

.NOTES
    Author: SAIF Team
    Version: 2.0.0
    Date: 2025-01-08
    Requires: Docker Desktop
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [switch]$SkipBuild,
    
    [Parameter(Mandatory=$false)]
    [switch]$CleanStart
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

Show-Banner "SAIF-PostgreSQL Local Test"

# Check Docker
Write-Step "Checking Docker Desktop..."
try {
    $dockerVersion = docker --version
    Write-Success "Docker installed: $dockerVersion"
    
    $dockerInfo = docker info 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Error-Custom "Docker is not running. Please start Docker Desktop."
        exit 1
    }
    Write-Success "Docker is running"
} catch {
    Write-Error-Custom "Docker not found. Please install Docker Desktop."
    exit 1
}

# Check docker-compose
Write-Step "Checking Docker Compose..."
try {
    $composeVersion = docker-compose --version
    Write-Success "Docker Compose installed: $composeVersion"
} catch {
    Write-Error-Custom "Docker Compose not found."
    exit 1
}

# Navigate to project root
$projectRoot = Split-Path $PSScriptRoot -Parent
Set-Location $projectRoot

Write-Info "Project directory: $projectRoot"

# Clean start if requested
if ($CleanStart) {
    Show-Banner "Clean Start"
    
    Write-Step "Stopping and removing existing containers..."
    docker-compose down -v 2>&1 | Out-Null
    Write-Success "Cleaned up existing containers and volumes"
}

# Start services
Show-Banner "Starting Services"

if ($SkipBuild) {
    Write-Step "Starting containers (using existing images)..."
    docker-compose up -d
} else {
    Write-Step "Building and starting containers..."
    Write-Info "This may take 5-10 minutes on first run..."
    docker-compose up -d --build
}

if ($LASTEXITCODE -ne 0) {
    Write-Error-Custom "Failed to start containers"
    Write-Host "Check logs with: docker-compose logs" -ForegroundColor Yellow
    exit 1
}

Write-Success "Containers started"

# Wait for services to be ready
Write-Step "Waiting for services to be ready (60 seconds)..."
Start-Sleep -Seconds 60

# Check container status
Show-Banner "Container Status"

$containers = docker-compose ps --format json | ConvertFrom-Json

Write-Host "Container Status:" -ForegroundColor Cyan
foreach ($container in $containers) {
    $status = if ($container.State -eq "running") { "✅" } else { "❌" }
    Write-Host "  $status $($container.Service): $($container.State)" -ForegroundColor White
}

# Health Checks
Show-Banner "Health Checks"

# PostgreSQL
Write-Step "Testing PostgreSQL connection..."
try {
    $pgTest = docker-compose exec -T postgres psql -U saifadmin -d saifdb -c "SELECT 1;" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Success "PostgreSQL is healthy"
    } else {
        Write-Error-Custom "PostgreSQL connection failed"
        Write-Host "Error: $pgTest" -ForegroundColor Red
    }
} catch {
    Write-Error-Custom "PostgreSQL test failed: $_"
}

# API
Write-Step "Testing API endpoint..."
try {
    $apiResponse = Invoke-RestMethod -Uri "http://localhost:8000/api/healthcheck" -Method Get -TimeoutSec 10
    
    if ($apiResponse.status -eq "healthy") {
        Write-Success "API is healthy"
        Write-Host "  Database: $($apiResponse.database)" -ForegroundColor Gray
        Write-Host "  Version: $($apiResponse.version)" -ForegroundColor Gray
    } else {
        Write-Error-Custom "API reports unhealthy status"
    }
} catch {
    Write-Error-Custom "API health check failed: $_"
    Write-Host "  URL: http://localhost:8000/api/healthcheck" -ForegroundColor Gray
}

# Web
Write-Step "Testing Web frontend..."
try {
    $webResponse = Invoke-WebRequest -Uri "http://localhost:8080" -Method Get -TimeoutSec 10
    
    if ($webResponse.StatusCode -eq 200) {
        Write-Success "Web frontend is accessible"
    } else {
        Write-Error-Custom "Web frontend returned status: $($webResponse.StatusCode)"
    }
} catch {
    Write-Error-Custom "Web frontend check failed: $_"
    Write-Host "  URL: http://localhost:8080" -ForegroundColor Gray
}

# Functional Tests
Show-Banner "Functional Tests"

# Test 1: Database Status
Write-Step "Test 1: Database Status"
try {
    $dbStatus = Invoke-RestMethod -Uri "http://localhost:8000/api/db-status" -Method Get -TimeoutSec 10
    Write-Success "Database status retrieved"
    Write-Host "  Version: $($dbStatus.version)" -ForegroundColor Gray
    Write-Host "  Connection count: $($dbStatus.connection_count)" -ForegroundColor Gray
    Write-Host "  Transaction count: $($dbStatus.transaction_count)" -ForegroundColor Gray
} catch {
    Write-Error-Custom "Database status test failed"
}

# Test 2: Create Test Transaction
Write-Step "Test 2: Create Test Transaction"
try {
    $txResponse = Invoke-RestMethod -Uri "http://localhost:8000/api/test/create-transaction" -Method Post -TimeoutSec 10
    Write-Success "Test transaction created"
    Write-Host "  Transaction ID: $($txResponse.transaction_id)" -ForegroundColor Gray
    Write-Host "  Amount: $($txResponse.amount)" -ForegroundColor Gray
} catch {
    Write-Error-Custom "Transaction creation test failed"
}

# Test 3: Process Payment
Write-Step "Test 3: Process Payment"
try {
    $paymentData = @{
        customer_id = 1
        merchant_id = 1
        amount = 99.99
        currency = "USD"
        description = "Test payment"
    } | ConvertTo-Json
    
    $paymentResponse = Invoke-RestMethod `
        -Uri "http://localhost:8000/api/process-payment" `
        -Method Post `
        -ContentType "application/json" `
        -Body $paymentData `
        -TimeoutSec 10
    
    Write-Success "Payment processed successfully"
    Write-Host "  Transaction ID: $($paymentResponse.transaction_id)" -ForegroundColor Gray
    Write-Host "  Status: $($paymentResponse.status)" -ForegroundColor Gray
    Write-Host "  Amount: $($paymentResponse.amount)" -ForegroundColor Gray
} catch {
    Write-Error-Custom "Payment processing test failed"
}

# Test 4: Get Recent Transactions
Write-Step "Test 4: Get Recent Transactions"
try {
    $txListResponse = Invoke-RestMethod `
        -Uri "http://localhost:8000/api/transactions/recent?limit=5" `
        -Method Get `
        -TimeoutSec 10
    
    Write-Success "Retrieved recent transactions"
    Write-Host "  Count: $($txListResponse.transactions.Count)" -ForegroundColor Gray
} catch {
    Write-Error-Custom "Transaction list test failed"
}

# Load Test
Show-Banner "Load Test"

Write-Step "Generating 20 test transactions..."
try {
    $startTime = Get-Date
    $successCount = 0
    $failCount = 0
    
    for ($i = 1; $i -le 20; $i++) {
        try {
            Invoke-RestMethod `
                -Uri "http://localhost:8000/api/test/create-transaction" `
                -Method Post `
                -TimeoutSec 5 | Out-Null
            $successCount++
        } catch {
            $failCount++
        }
        
        if ($i % 5 -eq 0) {
            Write-Host "  Progress: $i/20 transactions" -ForegroundColor Gray
        }
    }
    
    $duration = ((Get-Date) - $startTime).TotalSeconds
    $tps = [Math]::Round($successCount / $duration, 2)
    
    Write-Success "Load test completed"
    Write-Host "  Successful: $successCount" -ForegroundColor Green
    Write-Host "  Failed: $failCount" -ForegroundColor $(if ($failCount -gt 0) { 'Red' } else { 'Gray' })
    Write-Host "  Duration: $([Math]::Round($duration, 2))s" -ForegroundColor Gray
    Write-Host "  TPS: $tps" -ForegroundColor Gray
} catch {
    Write-Error-Custom "Load test failed: $_"
}

# Final Summary
Show-Banner "🎉 Test Complete!"

Write-Host "Access Points:" -ForegroundColor Cyan
Write-Host "  🌐 Web UI:  http://localhost:8080" -ForegroundColor White
Write-Host "  🔌 API:     http://localhost:8000" -ForegroundColor White
Write-Host "  📊 Docs:    http://localhost:8000/docs" -ForegroundColor White
Write-Host "  🗄️  PostgreSQL: localhost:5432" -ForegroundColor White

Write-Host ""
Write-Host "Test Credentials:" -ForegroundColor Cyan
Write-Host "  Database: saifdb" -ForegroundColor Gray
Write-Host "  Username: saifadmin" -ForegroundColor Gray
Write-Host "  Password: P@ssw0rd123!" -ForegroundColor Gray

Write-Host ""
Write-Host "Useful Commands:" -ForegroundColor Cyan
Write-Host "  View logs:     docker-compose logs -f" -ForegroundColor White
Write-Host "  Stop services: docker-compose down" -ForegroundColor White
Write-Host "  Restart:       docker-compose restart" -ForegroundColor White
Write-Host "  Clean all:     docker-compose down -v" -ForegroundColor White

Write-Host ""
Write-Success "Local environment is ready for testing!"

#endregion
