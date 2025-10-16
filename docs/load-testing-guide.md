# Load Testing Guide - Azure App Service with Application Insights

**Version**: 1.1.0  
**Last Updated**: October 16, 2025  
**Status**: Current

Complete guide for deploying and running the PostgreSQL load testing solution using Azure App Service with immediate Application Insights logging.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Deployment](#deployment)
- [Running Load Tests](#running-load-tests)
- [Monitoring](#monitoring)
- [Database Verification](#database-verification)
- [Failover Testing](#failover-testing)
- [Troubleshooting](#troubleshooting)
- [Configuration Reference](#configuration-reference)

---

## Overview

The load testing solution uses:
- **Azure App Service** - Hosts the load generator as a containerized web service
- **Azure Container Registry (ACR)** - Stores the container images
- **Application Insights** - Provides immediate telemetry and logging (no LAW delays)
- **Managed Identity** - Secure authentication to ACR (no admin credentials)
- **.NET 8.0 Web API** - HTTP endpoints for controlling and monitoring tests

### Key Features

✅ **Immediate Logging** - Application Insights provides instant visibility (vs 5-10 min LAW delay)  
✅ **HTTP API** - Control tests via REST endpoints (`/start`, `/status`, `/health`, `/logs`)  
✅ **Real Transactions** - Inserts actual data into `transactions` table  
✅ **Auto-Provisioning** - Automatically creates ACR if it doesn't exist  
✅ **Managed Identity** - Secure, credential-free ACR authentication  
✅ **Centralized Config** - Single configuration file for all settings  

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     Resource Group (rg-pgv2-usc01)              │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────────┐      ┌─────────────────────────────┐    │
│  │ Azure Container  │      │   App Service Plan (P0V3)   │    │
│  │   Registry (ACR) │      │   ┌─────────────────────┐   │    │
│  │                  │◄─────┤   │  Load Generator     │   │    │
│  │ loadgenerator:   │      │   │  Web Service        │   │    │
│  │    latest        │      │   │  (.NET 8.0)         │   │    │
│  └──────────────────┘      │   └─────────────────────┘   │    │
│         ▲                  └─────────────────────────────┘    │
│         │                            │                         │
│         │ Managed Identity           │ Logs/Metrics            │
│         │ (AcrPull)                  ▼                         │
│         │                  ┌─────────────────────────────┐    │
│  ┌──────┴───────────┐      │  Application Insights       │    │
│  │  System-Assigned │      │  (Linked to LAW)            │    │
│  │  Managed Identity│      └─────────────────────────────┘    │
│  └──────────────────┘                │                         │
│                                      │ Query/Visualize         │
│                                      ▼                         │
│                        ┌──────────────────────────────┐        │
│                        │  Log Analytics Workspace     │        │
│                        │  (law-uscentral)             │        │
│                        └──────────────────────────────┘        │
│                                                                 │
│  Load Generator inserts data into:                             │
│  ┌──────────────────────────────────────────────────────┐     │
│  │  Azure PostgreSQL Flexible Server (pg-cus)           │     │
│  │  Database: saifdb                                    │     │
│  │  Table: transactions (customer_id, merchant_id, etc) │     │
│  └──────────────────────────────────────────────────────┘     │
└─────────────────────────────────────────────────────────────────┘
```

---

## Prerequisites

### Required Software

- **PowerShell 7+** - For running deployment scripts
- **Azure CLI** - For Azure resource management
- **Docker** (optional) - Only needed for local testing
- **PostgreSQL Client** (optional) - For database verification

### Azure Resources

Must exist in the same resource group (`rg-pgv2-usc01`):
- ✅ PostgreSQL Flexible Server (`pg-cus`)
- ✅ Database (`saifdb`) with `transactions` table
- ✅ Log Analytics Workspace (`law-uscentral`)

### Permissions

Your Azure account needs:
- Contributor access to resource group
- Permission to create App Service, ACR, Application Insights
- Permission to assign Managed Identity roles

### Database Schema

Ensure the `transactions` table exists:

```sql
CREATE TABLE IF NOT EXISTS transactions (
    transaction_id SERIAL PRIMARY KEY,
    customer_id INTEGER NOT NULL,
    merchant_id INTEGER NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    status VARCHAR(50) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

---

## Quick Start

### 1. Configure Settings

Edit `scripts/loadtesting/LoadGenerator-Config.ps1`:

```powershell
# Core Configuration
$Region = "centralus"                    # Azure region for all resources
$ResourceGroup = "rg-pgv2-usc01"         # Resource group name

# PostgreSQL Configuration
$PostgreSQLServer = "pg-cus.postgres.database.azure.com"
$DatabaseName = "saifdb"
$AdminUsername = "jonathan"
# Password will be prompted or set via environment variable

# Load Test Parameters
$TargetTPS = 1000          # Target transactions per second
$WorkerCount = 200         # Number of parallel workers
$TestDuration = 300        # Test duration in seconds (5 minutes)

# App Service Configuration
$AppServiceConfig = @{
    Name = "app-loadgen-$RandomSuffix"
    SKU = "P0V3"           # 1 CPU, 4GB RAM
}

# Container Registry
$ContainerRegistry = @{
    Name = "acrsaifpg100815203"  # Auto-created if doesn't exist
    ImageName = "loadgenerator"
    ImageTag = "latest"
}
```

### 2. Build Container Image

```powershell
# Build and push Docker image to ACR
.\scripts\loadtesting\Build-LoadGenerator-Docker.ps1

# Expected output:
# ✓ ACR found or created
# ✓ Image built: acrsaifpg100815203.azurecr.io/loadgenerator:latest
# ✓ Image pushed to registry
```

### 3. Deploy App Service

```powershell
# Deploy App Service with managed identity and Application Insights
.\scripts\loadtesting\Deploy-LoadGenerator-AppService.ps1 -Action Deploy

# Expected output:
# ✓ App Service Plan created (P0V3)
# ✓ Application Insights created (linked to LAW)
# ✓ App Service created with container
# ✓ Managed Identity configured
# ✓ AcrPull role assigned
# ✓ Environment variables set
# App URL: https://app-loadgen-xxxxx.azurewebsites.net
```

### 4. Start Load Test

```powershell
# Verify service is healthy
curl https://app-loadgen-xxxxx.azurewebsites.net/health

# Start a load test
curl -X POST https://app-loadgen-xxxxx.azurewebsites.net/start

# Check status
curl https://app-loadgen-xxxxx.azurewebsites.net/status
```

---

## Deployment

### Script 1: Build-LoadGenerator-Docker.ps1

Builds the Docker container image and pushes to ACR.

**Purpose:**
- Auto-detects or auto-creates Azure Container Registry
- Builds .NET 8.0 web application into Docker image
- Pushes image to ACR with authentication

**Usage:**

```powershell
# Basic build (uses config file)
.\scripts\loadtesting\Build-LoadGenerator-Docker.ps1

# Specify custom ACR name
.\scripts\loadtesting\Build-LoadGenerator-Docker.ps1 -ContainerRegistryName "myacr123"
```

**What it does:**

1. ✅ Checks if specified ACR exists in resource group
2. ✅ If not found, searches for any ACR in the resource group
3. ✅ If no ACR exists, creates new one with Basic SKU
4. ✅ Authenticates to ACR using Azure CLI
5. ✅ Builds Docker image with multi-stage build
6. ✅ Tags image as `latest`
7. ✅ Pushes to ACR registry
8. ✅ Verifies image is available

**Output:**

```
🏗️  Load Generator Docker Build & Push
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ Step 1: ACR Management
  ✓ Found specified ACR: acrsaifpg100815203
✓ Step 2: Validation
✓ Step 3: ACR Authentication
✓ Step 4: Building Docker Image
✓ Step 5: Verifying Image

✅ Build Complete!
Image URI: acrsaifpg100815203.azurecr.io/loadgenerator:latest
```

---

### Script 2: Deploy-LoadGenerator-AppService.ps1

Deploys or manages the App Service load generator.

**Purpose:**
- Creates App Service Plan, Application Insights, and App Service
- Configures managed identity for ACR access
- Sets environment variables for load test configuration

**Usage:**

```powershell
# Deploy new App Service
.\scripts\loadtesting\Deploy-LoadGenerator-AppService.ps1 -Action Deploy

# Update existing App Service with new settings
.\scripts\loadtesting\Deploy-LoadGenerator-AppService.ps1 -Action Update

# Delete App Service (keeps ACR and images)
.\scripts\loadtesting\Deploy-LoadGenerator-AppService.ps1 -Action Delete
```

**Parameters:**

- `-Action` - Required: `Deploy`, `Update`, or `Delete`
- Uses configuration from `LoadGenerator-Config.ps1`

**What Deploy does:**

1. ✅ **Step 1**: Validates ACR exists
2. ✅ **Step 2**: Creates App Service Plan (P0V3)
3. ✅ **Step 3**: Creates Application Insights (linked to existing LAW)
4. ✅ **Step 4**: Creates App Service with nginx placeholder
5. ✅ **Step 5**: Configures System-Assigned Managed Identity
   - Assigns managed identity to App Service
   - Grants `AcrPull` role on ACR
   - Waits for identity propagation
6. ✅ **Step 6**: Updates container configuration
   - Sets container image from ACR
   - Uses managed identity (no credentials)
7. ✅ **Step 7**: Sets application environment variables
   - PostgreSQL connection details
   - Load test parameters (TPS, workers, duration)
   - Application Insights key
   - **Clears Docker registry credentials** (forces managed identity)
8. ✅ **Step 8**: Configures scaling (single instance by default)
9. ✅ **Step 9**: Enables diagnostics logging
10. ✅ **Step 10**: Displays summary with App URL

**Output:**

```
🚀 Load Generator App Service Deployment
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✓ Step 1: Validate ACR
✓ Step 2: App Service Plan
✓ Step 3: Application Insights
✓ Step 4: Create App Service
✓ Step 5: Managed Identity Setup
✓ Step 6: Container Configuration
✓ Step 7: Application Settings
✓ Step 8: Scaling Configuration
✓ Step 9: Diagnostics Logging
✓ Step 10: Summary

✅ Deployment Complete!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
App Service: app-loadgen-xxxxx
URL: https://app-loadgen-xxxxx.azurewebsites.net
Application Insights: appins-loadgen-xxxxx

Next Steps:
  1. Test health: curl https://app-loadgen-xxxxx.azurewebsites.net/health
  2. Start test:   curl -X POST https://app-loadgen-xxxxx.azurewebsites.net/start
  3. Check status: curl https://app-loadgen-xxxxx.azurewebsites.net/status
```

---

### Script 3: Monitor-AppService-Logs.ps1

Streams real-time logs from App Service.

**Purpose:**
- View container startup logs
- Monitor application output
- Debug deployment issues

**Usage:**

```powershell
# Stream logs for default App Service (auto-discovered)
.\scripts\loadtesting\Monitor-AppService-Logs.ps1

# Stream logs for specific App Service
.\scripts\loadtesting\Monitor-AppService-Logs.ps1 -AppServiceName "app-loadgen-abcde"

# Stream logs for specific resource group
.\scripts\loadtesting\Monitor-AppService-Logs.ps1 -ResourceGroup "my-rg"
```

**Output:**

```
📊 Monitoring App Service Logs
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
App Service: app-loadgen-xxxxx
Resource Group: rg-pgv2-usc01

Streaming logs (Ctrl+C to exit)...
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

2025-10-16T11:00:00.000Z INFO - Pulling image: acrsaifpg100815203.azurecr.io/loadgenerator:latest
2025-10-16T11:00:05.000Z INFO - Pull Image successful
2025-10-16T11:00:06.000Z INFO - Starting container for site
2025-10-16T11:00:07.000Z INFO - Container is running
Starting server on port 80
```

---

## Running Load Tests

### HTTP Endpoints

The load generator exposes the following REST endpoints:

#### GET /health

Health check endpoint for monitoring service availability.

**Request:**
```powershell
curl https://app-loadgen-xxxxx.azurewebsites.net/health
```

**Response:**
```json
"healthy"
```

**Use Cases:**
- Verify service is running
- App Service health probes
- Monitoring systems

---

#### GET /status

Returns current test execution status and metrics.

**Request:**
```powershell
curl https://app-loadgen-xxxxx.azurewebsites.net/status
```

**Response (Test Running):**
```json
{
  "running": true,
  "status": "running",
  "startTime": "2025-10-16T11:14:22Z",
  "transactionsCompleted": 899759,
  "errors": 0,
  "uptime": "00:02:20.211",
  "logs": [
    "Starting load test: 1000 TPS, 200 workers, 300s duration",
    "✓ Connected to PostgreSQL"
  ]
}
```

**Response (Test Completed):**
```json
{
  "running": false,
  "status": "completed",
  "startTime": "2025-10-16T11:14:22Z",
  "transactionsCompleted": 2105328,
  "errors": 0,
  "uptime": "00:06:39.740",
  "logs": [
    "Starting load test: 1000 TPS, 200 workers, 300s duration",
    "✓ Connected to PostgreSQL",
    "✓ Load test completed",
    "  Transactions: 2105328",
    "  Errors: 0",
    "  TPS: 5270.50"
  ]
}
```

**PowerShell Examples:**

```powershell
# Simple status check
curl https://app-loadgen-xxxxx.azurewebsites.net/status

# Formatted output
curl https://app-loadgen-xxxxx.azurewebsites.net/status | ConvertFrom-Json | Format-List

# Key metrics only
curl https://app-loadgen-xxxxx.azurewebsites.net/status | ConvertFrom-Json | Select-Object running,status,transactionsCompleted,errors

# Calculate TPS
$status = curl https://app-loadgen-xxxxx.azurewebsites.net/status | ConvertFrom-Json
$tps = [math]::Round($status.transactionsCompleted / $status.uptime.TotalSeconds, 0)
Write-Host "Current TPS: $tps"

# Watch in real-time (updates every 5 seconds)
while ($true) {
    $status = curl https://app-loadgen-xxxxx.azurewebsites.net/status | ConvertFrom-Json
    Clear-Host
    Write-Host "Load Test Status - $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor Cyan
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
    Write-Host "Running:      $($status.running)"
    Write-Host "Status:       $($status.status)"
    Write-Host "Transactions: $($status.transactionsCompleted)"
    Write-Host "Errors:       $($status.errors)"
    Write-Host "Uptime:       $($status.uptime)"
    $tps = [math]::Round($status.transactionsCompleted / $status.uptime.TotalSeconds, 0)
    Write-Host "TPS:          $tps"
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
    Start-Sleep -Seconds 5
}
```

---

#### POST /start

Starts a new load test with configured parameters.

**Request:**
```powershell
curl -X POST https://app-loadgen-xxxxx.azurewebsites.net/start
```

**Response (Success):**
```
HTTP 202 Accepted
```

**Response (Test Already Running):**
```json
{
  "error": "Test already running"
}
```
```
HTTP 400 Bad Request
```

**Configuration:**

Load test parameters are read from App Service environment variables:
- `POSTGRESQL_SERVER` - PostgreSQL server hostname
- `POSTGRESQL_PORT` - PostgreSQL port (default: 5432)
- `POSTGRESQL_DATABASE` - Database name
- `POSTGRESQL_USERNAME` - Admin username
- `POSTGRESQL_PASSWORD` - Admin password
- `TARGET_TPS` - Target transactions per second
- `WORKER_COUNT` - Number of parallel workers
- `TEST_DURATION` - Test duration in seconds

These are set during deployment via `Deploy-LoadGenerator-AppService.ps1`.

---

#### GET /logs

Returns detailed execution logs from the current or last test.

**Request:**
```powershell
curl https://app-loadgen-xxxxx.azurewebsites.net/logs
```

**Response:**
```json
[
  "Starting load test: 1000 TPS, 200 workers, 300s duration",
  "✓ Connected to PostgreSQL",
  "✓ Load test completed",
  "  Transactions: 2105328",
  "  Errors: 0",
  "  TPS: 5270.50"
]
```

**PowerShell Examples:**

```powershell
# View logs
curl https://app-loadgen-xxxxx.azurewebsites.net/logs

# Formatted logs
curl https://app-loadgen-xxxxx.azurewebsites.net/logs | ConvertFrom-Json | ForEach-Object { Write-Host $_ }

# Save logs to file
curl https://app-loadgen-xxxxx.azurewebsites.net/logs | ConvertFrom-Json | Out-File -FilePath "loadtest-logs.txt"
```

---

### Complete Test Workflow

```powershell
# 1. Verify service is healthy
$appUrl = "https://app-loadgen-xxxxx.azurewebsites.net"
curl "$appUrl/health"
# Expected: "healthy"

# 2. Check if a test is already running
$status = curl "$appUrl/status" | ConvertFrom-Json
if ($status.running) {
    Write-Host "⚠️  Test already running. Wait for completion or restart App Service."
} else {
    Write-Host "✅ Ready to start new test"
}

# 3. Start the load test
curl -X POST "$appUrl/start"
Write-Host "✅ Load test started"

# 4. Monitor progress (every 10 seconds for 5 minutes)
$startTime = Get-Date
$duration = 300  # 5 minutes
while (((Get-Date) - $startTime).TotalSeconds -lt $duration) {
    $status = curl "$appUrl/status" | ConvertFrom-Json
    $tps = [math]::Round($status.transactionsCompleted / $status.uptime.TotalSeconds, 0)
    
    Write-Host "$(Get-Date -Format 'HH:mm:ss') | Running: $($status.running) | Transactions: $($status.transactionsCompleted) | Errors: $($status.errors) | TPS: $tps"
    
    if (-not $status.running) {
        Write-Host "✅ Test completed"
        break
    }
    
    Start-Sleep -Seconds 10
}

# 5. Get final results
$finalStatus = curl "$appUrl/status" | ConvertFrom-Json
Write-Host "`n📊 Final Results:"
Write-Host "  Status: $($finalStatus.status)"
Write-Host "  Total Transactions: $($finalStatus.transactionsCompleted)"
Write-Host "  Errors: $($finalStatus.errors)"
Write-Host "  Duration: $($finalStatus.uptime)"
$avgTps = [math]::Round($finalStatus.transactionsCompleted / $finalStatus.uptime.TotalSeconds, 0)
Write-Host "  Average TPS: $avgTps"

# 6. View detailed logs
Write-Host "`n📋 Detailed Logs:"
curl "$appUrl/logs" | ConvertFrom-Json | ForEach-Object { Write-Host "  $_" }
```

---

## Monitoring

### Application Insights (Recommended)

Application Insights provides **immediate visibility** into your load tests (no 5-10 minute delay).

#### Access Application Insights

1. Go to Azure Portal
2. Navigate to your resource group: `rg-pgv2-usc01`
3. Find Application Insights: `appins-loadgen-xxxxx`

#### Live Metrics Stream

Real-time telemetry as the test runs:

1. Open Application Insights
2. Click **Live Metrics** in left menu
3. View live:
   - Request rate (HTTP calls to `/status`, `/start`, etc.)
   - Server response time
   - Failed requests
   - Memory and CPU usage
   - Custom metrics

#### Transaction Search

View individual HTTP requests and their details:

1. Open Application Insights
2. Click **Transaction search**
3. Filter by:
   - Operation name: `GET /status`, `POST /start`, etc.
   - Time range: Last hour, Last 24 hours, Custom
   - Result code: 200, 400, 500, etc.

#### Application Map

Visualize dependencies between components:

1. Open Application Insights
2. Click **Application map**
3. See connections:
   - App Service → PostgreSQL
   - HTTP endpoints
   - Response times
   - Failure rates

#### Kusto Queries (KQL)

Run custom queries against telemetry data:

```kusto
// HTTP request rate by endpoint
requests
| where timestamp > ago(1h)
| summarize count() by name, bin(timestamp, 1m)
| render timechart

// Error rate
requests
| where timestamp > ago(1h)
| summarize Total = count(), Errors = countif(success == false) by bin(timestamp, 1m)
| extend ErrorRate = Errors * 100.0 / Total
| render timechart

// Average response time
requests
| where timestamp > ago(1h)
| summarize avg(duration) by name, bin(timestamp, 1m)
| render timechart

// Custom events (if implemented)
customEvents
| where timestamp > ago(1h)
| where name == "LoadTestCompleted"
| project timestamp, customDimensions
```

---

### Azure Portal Monitoring

#### App Service Metrics

1. Navigate to App Service: `app-loadgen-xxxxx`
2. Click **Metrics** in left menu
3. Add charts for:
   - **CPU Percentage** - Monitor CPU usage during tests
   - **Memory Percentage** - Track memory consumption
   - **HTTP 2xx/4xx/5xx** - Request success/failure rates
   - **Response Time** - Endpoint latency
   - **Data In/Out** - Network bandwidth usage

#### Container Logs

View real-time container logs:

```powershell
# Stream logs using Azure CLI
az webapp log tail --name app-loadgen-xxxxx --resource-group rg-pgv2-usc01

# Download logs
az webapp log download --name app-loadgen-xxxxx --resource-group rg-pgv2-usc01 --log-file app-logs.zip

# Or use the PowerShell script
.\scripts\loadtesting\Monitor-AppService-Logs.ps1
```

---

### Log Analytics Workspace

Application Insights data is also sent to the Log Analytics Workspace (`law-uscentral`).

#### Query Application Insights via LAW

```kusto
// View all App Service requests
AppRequests
| where AppRoleName == "app-loadgen-xxxxx"
| order by TimeGenerated desc
| take 100

// View traces/logs
AppTraces
| where AppRoleName == "app-loadgen-xxxxx"
| order by TimeGenerated desc
| take 100

// View exceptions
AppExceptions
| where AppRoleName == "app-loadgen-xxxxx"
| order by TimeGenerated desc
| take 100

// Performance metrics
AppPerformanceCounters
| where AppRoleName == "app-loadgen-xxxxx"
| summarize avg(Value) by CounterName, bin(TimeGenerated, 1m)
| render timechart
```

---

### Monitoring Dashboard Script

Create a real-time monitoring dashboard in PowerShell:

```powershell
$appUrl = "https://app-loadgen-xxxxx.azurewebsites.net"

while ($true) {
    Clear-Host
    
    # Header
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  LOAD GENERATOR MONITORING DASHBOARD" -ForegroundColor Cyan
    Write-Host "  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    
    # Get status
    try {
        $status = curl "$appUrl/status" -TimeoutSec 5 | ConvertFrom-Json
        
        # Status
        $statusColor = if ($status.running) { "Green" } else { "Yellow" }
        Write-Host "Status:       " -NoNewline
        Write-Host $status.status.ToUpper() -ForegroundColor $statusColor
        
        Write-Host "Running:      " -NoNewline
        Write-Host $status.running -ForegroundColor $statusColor
        
        Write-Host "Start Time:   $($status.startTime)"
        Write-Host "Uptime:       $($status.uptime)"
        Write-Host ""
        
        # Metrics
        Write-Host "─────────────────────────────────────────────────────────────" -ForegroundColor Gray
        Write-Host "METRICS" -ForegroundColor Yellow
        Write-Host "─────────────────────────────────────────────────────────────" -ForegroundColor Gray
        
        $transactions = $status.transactionsCompleted
        $errors = $status.errors
        $successRate = if ($transactions -gt 0) { ((($transactions - $errors) / $transactions) * 100) } else { 0 }
        $tps = if ($status.uptime.TotalSeconds -gt 0) { [math]::Round($transactions / $status.uptime.TotalSeconds, 0) } else { 0 }
        
        Write-Host "Transactions: " -NoNewline
        Write-Host $transactions.ToString("N0") -ForegroundColor Green
        
        Write-Host "Errors:       " -NoNewline
        $errorColor = if ($errors -eq 0) { "Green" } else { "Red" }
        Write-Host $errors.ToString("N0") -ForegroundColor $errorColor
        
        Write-Host "Success Rate: " -NoNewline
        Write-Host "$($successRate.ToString("F2"))%" -ForegroundColor $(if ($successRate -ge 99) { "Green" } else { "Yellow" })
        
        Write-Host "Avg TPS:      " -NoNewline
        Write-Host $tps.ToString("N0") -ForegroundColor Cyan
        
        Write-Host ""
        
        # Recent Logs
        Write-Host "─────────────────────────────────────────────────────────────" -ForegroundColor Gray
        Write-Host "RECENT LOGS" -ForegroundColor Yellow
        Write-Host "─────────────────────────────────────────────────────────────" -ForegroundColor Gray
        
        $logs = $status.logs | Select-Object -Last 5
        foreach ($log in $logs) {
            if ($log -like "*✓*") {
                Write-Host "  $log" -ForegroundColor Green
            } elseif ($log -like "*✗*" -or $log -like "*Error*") {
                Write-Host "  $log" -ForegroundColor Red
            } else {
                Write-Host "  $log"
            }
        }
        
    } catch {
        Write-Host "❌ Failed to connect to load generator" -ForegroundColor Red
        Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "Press Ctrl+C to exit | Refreshing every 5 seconds..." -ForegroundColor Gray
    
    Start-Sleep -Seconds 5
}
```

Save this as `Monitor-LoadTest-Dashboard.ps1` and run:

```powershell
.\Monitor-LoadTest-Dashboard.ps1
```

---

## Database Verification

### Query Transaction Count

```sql
-- Total transactions
SELECT COUNT(*) AS total_transactions FROM transactions;

-- Transactions by status
SELECT status, COUNT(*) AS count 
FROM transactions 
GROUP BY status 
ORDER BY count DESC;

-- Recent transactions
SELECT * FROM transactions 
ORDER BY transaction_id DESC 
LIMIT 10;
```

### Monitor in Real-Time

```sql
-- Watch transaction count (run periodically)
SELECT 
    COUNT(*) AS total,
    COUNT(*) FILTER (WHERE created_at > NOW() - INTERVAL '1 minute') AS last_minute,
    COUNT(*) FILTER (WHERE created_at > NOW() - INTERVAL '1 hour') AS last_hour
FROM transactions;

-- Transaction rate per second (last 5 minutes)
SELECT 
    DATE_TRUNC('second', created_at) AS second,
    COUNT(*) AS transactions_per_second
FROM transactions
WHERE created_at > NOW() - INTERVAL '5 minutes'
GROUP BY second
ORDER BY second DESC
LIMIT 10;
```

### Verify Load Test Results

After a test completes:

```sql
-- Get final transaction count
SELECT COUNT(*) AS total_transactions FROM transactions;

-- Compare with /status endpoint
-- Example: If /status shows 2,105,328 transactions, this query should match

-- Transaction distribution by customer
SELECT 
    customer_id,
    COUNT(*) AS transaction_count,
    SUM(amount) AS total_amount,
    AVG(amount) AS avg_amount
FROM transactions
GROUP BY customer_id
ORDER BY transaction_count DESC;

-- Transaction distribution by merchant
SELECT 
    merchant_id,
    COUNT(*) AS transaction_count,
    SUM(amount) AS total_amount,
    AVG(amount) AS avg_amount
FROM transactions
GROUP BY merchant_id
ORDER BY transaction_count DESC;
```

### Clean Up Test Data

```sql
-- Delete all test transactions
TRUNCATE TABLE transactions RESTART IDENTITY;

-- Or delete transactions from specific time range
DELETE FROM transactions 
WHERE created_at >= '2025-10-16 11:00:00' 
  AND created_at <= '2025-10-16 12:00:00';

-- Verify deletion
SELECT COUNT(*) FROM transactions;
```

### PostgreSQL Connection

```powershell
# Connect using psql
$env:PGPASSWORD = "your-password"
psql -h pg-cus.postgres.database.azure.com -U jonathan -d saifdb -p 5432

# Or using Azure CLI
az postgres flexible-server connect `
  --name pg-cus `
  --admin-user jonathan `
  --admin-password "your-password" `
  --database-name saifdb
```

---

## Failover Testing

Combine the load generator with failover testing to measure RTO (Recovery Time Objective).

### Failover Test Workflow

```powershell
# 1. Start load test
$appUrl = "https://app-loadgen-xxxxx.azurewebsites.net"
curl -X POST "$appUrl/start"
Write-Host "✅ Load test started"

# 2. Wait for steady state (30 seconds)
Start-Sleep -Seconds 30

# 3. Get baseline metrics
$baseline = curl "$appUrl/status" | ConvertFrom-Json
$baselineTps = [math]::Round($baseline.transactionsCompleted / $baseline.uptime.TotalSeconds, 0)
Write-Host "📊 Baseline TPS: $baselineTps"

# 4. Trigger failover
Write-Host "⚠️  Triggering failover..."
.\scripts\Test-PostgreSQL-Failover.ps1 `
    -ResourceGroup "rg-pgv2-usc01" `
    -ServerName "pg-cus"

# 5. Monitor recovery
$failoverStart = Get-Date
$recovered = $false

while (-not $recovered) {
    Start-Sleep -Seconds 5
    
    try {
        $status = curl "$appUrl/status" -TimeoutSec 5 | ConvertFrom-Json
        $currentTps = [math]::Round($status.transactionsCompleted / $status.uptime.TotalSeconds, 0)
        
        Write-Host "$(Get-Date -Format 'HH:mm:ss') | Transactions: $($status.transactionsCompleted) | Errors: $($status.errors) | TPS: $currentTps"
        
        # Consider recovered when TPS reaches 80% of baseline
        if ($currentTps -ge ($baselineTps * 0.8)) {
            $recovered = $true
            $rto = ((Get-Date) - $failoverStart).TotalSeconds
            Write-Host "`n✅ RECOVERED!"
            Write-Host "📊 RTO (Recovery Time Objective): $($rto.ToString("F2")) seconds"
        }
    } catch {
        Write-Host "$(Get-Date -Format 'HH:mm:ss') | ❌ Connection failed (failover in progress)"
    }
}

# 6. Get final results
$final = curl "$appUrl/status" | ConvertFrom-Json
Write-Host "`n📊 Final Results:"
Write-Host "  Total Transactions: $($final.transactionsCompleted)"
Write-Host "  Errors: $($final.errors)"
Write-Host "  Error Rate: $(($final.errors / $final.transactionsCompleted * 100).ToString("F2"))%"
```

### Automated Failover Test Script

Save this as `Test-Failover-With-Load.ps1`:

```powershell
param(
    [Parameter(Mandatory=$true)]
    [string]$AppServiceUrl,
    
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroup,
    
    [Parameter(Mandatory=$true)]
    [string]$ServerName,
    
    [int]$BaselineSeconds = 30,
    
    [double]$RecoveryThreshold = 0.8
)

Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  PostgreSQL Failover Test with Load Generator" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan

# Start load test
Write-Host "`n1️⃣  Starting load test..."
curl -X POST "$AppServiceUrl/start" | Out-Null
Start-Sleep -Seconds 5

$initialStatus = curl "$AppServiceUrl/status" | ConvertFrom-Json
if (-not $initialStatus.running) {
    Write-Host "❌ Failed to start load test" -ForegroundColor Red
    exit 1
}
Write-Host "✅ Load test started" -ForegroundColor Green

# Establish baseline
Write-Host "`n2️⃣  Establishing baseline ($BaselineSeconds seconds)..."
Start-Sleep -Seconds $BaselineSeconds

$baseline = curl "$AppServiceUrl/status" | ConvertFrom-Json
$baselineTps = [math]::Round($baseline.transactionsCompleted / $baseline.uptime.TotalSeconds, 0)
Write-Host "✅ Baseline TPS: $baselineTps" -ForegroundColor Green

# Trigger failover
Write-Host "`n3️⃣  Triggering failover..."
$failoverStart = Get-Date

.\scripts\Test-PostgreSQL-Failover.ps1 -ResourceGroup $ResourceGroup -ServerName $ServerName

# Monitor recovery
Write-Host "`n4️⃣  Monitoring recovery..."
Write-Host "Target TPS: $([math]::Round($baselineTps * $RecoveryThreshold, 0))"
Write-Host ""

$recovered = $false
$maxErrors = 0
$errorWindow = @()

while (-not $recovered) {
    Start-Sleep -Seconds 2
    
    try {
        $status = curl "$AppServiceUrl/status" -TimeoutSec 5 | ConvertFrom-Json
        $elapsed = ((Get-Date) - $failoverStart).TotalSeconds
        $currentTps = if ($status.uptime.TotalSeconds -gt 0) { 
            [math]::Round($status.transactionsCompleted / $status.uptime.TotalSeconds, 0) 
        } else { 0 }
        
        $errorWindow += $status.errors
        if ($errorWindow.Count -gt 1) {
            $recentErrors = $errorWindow[-1] - $errorWindow[-2]
            if ($recentErrors -gt $maxErrors) { $maxErrors = $recentErrors }
        }
        
        $indicator = if ($currentTps -ge ($baselineTps * $RecoveryThreshold)) { "🟢" } else { "🔴" }
        Write-Host "$indicator $(Get-Date -Format 'HH:mm:ss') | Elapsed: $($elapsed.ToString("F1"))s | TPS: $currentTps | Errors: $($status.errors)"
        
        if ($currentTps -ge ($baselineTps * $RecoveryThreshold) -and $elapsed -gt 10) {
            $recovered = $true
        }
        
        if ($elapsed -gt 300) {
            Write-Host "`n⚠️  Recovery timeout (5 minutes)" -ForegroundColor Yellow
            break
        }
    } catch {
        $elapsed = ((Get-Date) - $failoverStart).TotalSeconds
        Write-Host "🔴 $(Get-Date -Format 'HH:mm:ss') | Elapsed: $($elapsed.ToString("F1"))s | CONNECTION FAILED" -ForegroundColor Red
    }
}

# Final results
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  FAILOVER TEST RESULTS" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan

$rto = ((Get-Date) - $failoverStart).TotalSeconds
$final = curl "$AppServiceUrl/status" | ConvertFrom-Json

Write-Host ""
Write-Host "⏱️  RTO (Recovery Time Objective): $($rto.ToString("F2")) seconds" -ForegroundColor $(if ($rto -lt 60) { "Green" } else { "Yellow" })
Write-Host "📊 Baseline TPS: $baselineTps"
Write-Host "📊 Recovery TPS: $([math]::Round($final.transactionsCompleted / $final.uptime.TotalSeconds, 0))"
Write-Host "❌ Total Errors: $($final.errors)"
Write-Host "📈 Max Errors/Second: $maxErrors"
Write-Host ""

if ($rto -lt 60) {
    Write-Host "✅ RTO PASSED: < 60 seconds" -ForegroundColor Green
} else {
    Write-Host "⚠️  RTO WARNING: >= 60 seconds" -ForegroundColor Yellow
}
```

Usage:

```powershell
.\Test-Failover-With-Load.ps1 `
    -AppServiceUrl "https://app-loadgen-xxxxx.azurewebsites.net" `
    -ResourceGroup "rg-pgv2-usc01" `
    -ServerName "pg-cus" `
    -BaselineSeconds 30 `
    -RecoveryThreshold 0.8
```

---

## Troubleshooting

### Container Won't Start

**Symptoms:**
- App Service shows "Container exited" error
- Health check fails on port 80
- Container logs show errors

**Solutions:**

```powershell
# Check container logs
.\scripts\loadtesting\Monitor-AppService-Logs.ps1

# Verify image was pushed to ACR
az acr repository show-tags --name acrsaifpg100815203 --repository loadgenerator

# Force pull latest image
az webapp config container set `
    --name app-loadgen-xxxxx `
    --resource-group rg-pgv2-usc01 `
    --docker-custom-image-name acrsaifpg100815203.azurecr.io/loadgenerator:latest

az webapp restart --name app-loadgen-xxxxx --resource-group rg-pgv2-usc01
```

---

### Managed Identity ACR Pull Fails

**Symptoms:**
- Container logs show "unauthorized: authentication required"
- Portal shows "Admin Credentials" instead of Managed Identity

**Solutions:**

```powershell
# Verify managed identity exists
az webapp identity show --name app-loadgen-xxxxx --resource-group rg-pgv2-usc01

# Verify role assignment
$principalId = (az webapp identity show --name app-loadgen-xxxxx --resource-group rg-pgv2-usc01 --query principalId -o tsv)
az role assignment list --assignee $principalId --scope /subscriptions/YOUR-SUB-ID/resourceGroups/rg-pgv2-usc01/providers/Microsoft.ContainerRegistry/registries/acrsaifpg100815203

# Re-assign role if missing
.\scripts\loadtesting\Deploy-LoadGenerator-AppService.ps1 -Action Update

# Verify credentials are cleared (force managed identity)
az webapp config appsettings list --name app-loadgen-xxxxx --resource-group rg-pgv2-usc01 | ConvertFrom-Json | Where-Object { $_.name -like "DOCKER_REGISTRY*" }
```

---

### No Transactions in Database

**Symptoms:**
- `/status` shows millions of transactions
- Database `SELECT COUNT(*)` returns 0

**Causes:**
- Container running old image with `SELECT 1` instead of `INSERT`
- Wrong database configuration
- Connection errors not being logged

**Solutions:**

```powershell
# Check environment variables
az webapp config appsettings list --name app-loadgen-xxxxx --resource-group rg-pgv2-usc01 | ConvertFrom-Json | Where-Object { $_.name -like "POSTGRESQL*" }

# Rebuild and redeploy with latest code
.\scripts\loadtesting\Build-LoadGenerator-Docker.ps1
az webapp restart --name app-loadgen-xxxxx --resource-group rg-pgv2-usc01

# Check logs for connection errors
curl https://app-loadgen-xxxxx.azurewebsites.net/logs

# Verify database connection manually
$env:PGPASSWORD = "your-password"
psql -h pg-cus.postgres.database.azure.com -U jonathan -d saifdb -c "SELECT COUNT(*) FROM transactions;"
```

---

### High Error Rate

**Symptoms:**
- `/status` shows many errors
- TPS much lower than expected

**Solutions:**

```powershell
# Check error logs
curl https://app-loadgen-xxxxx.azurewebsites.net/logs

# Common causes:
# 1. Connection pool exhausted - reduce worker count or increase pool size
# 2. Database overloaded - reduce TPS target
# 3. Network issues - check NSG rules, firewall

# Reduce load to diagnose
az webapp config appsettings set `
    --name app-loadgen-xxxxx `
    --resource-group rg-pgv2-usc01 `
    --settings WORKER_COUNT=50 TARGET_TPS=500

az webapp restart --name app-loadgen-xxxxx --resource-group rg-pgv2-usc01

# Test with lower load
curl -X POST https://app-loadgen-xxxxx.azurewebsites.net/start
```

---

### App Service Performance Issues

**Symptoms:**
- Slow response times
- Timeouts on HTTP requests
- Container CPU/memory maxed out

**Solutions:**

```powershell
# Check metrics in portal
# Navigate to: App Service > Metrics > Add Chart

# Scale up to larger SKU
az appservice plan update `
    --name plan-loadgen-xxxxx `
    --resource-group rg-pgv2-usc01 `
    --sku P1V3  # 2 CPU, 8GB RAM

# Or scale out to multiple instances
az webapp update `
    --name app-loadgen-xxxxx `
    --resource-group rg-pgv2-usc01 `
    --set numberOfWorkers=2

# Restart after scaling
az webapp restart --name app-loadgen-xxxxx --resource-group rg-pgv2-usc01
```

---

### Can't Find App Service

**Symptoms:**
- Commands fail with "resource not found"
- Random suffix in name changes

**Solution:**

The App Service name includes a random 5-character suffix. Use this to find it:

```powershell
# List all App Services with 'loadgen' in the name
az webapp list --resource-group rg-pgv2-usc01 --query "[?contains(name, 'loadgen')].{Name:name, State:state, URL:defaultHostName}" -o table

# Get full details
az webapp list --resource-group rg-pgv2-usc01 --query "[?contains(name, 'loadgen')]" -o json
```

---

## Configuration Reference

### LoadGenerator-Config.ps1

Complete configuration file with all options:

```powershell
# ============================================================================
# Load Generator Configuration
# Single source of truth for all deployment settings
# ============================================================================

# Generate random suffix for resource uniqueness
$RandomSuffix = -join ((48..57) + (97..122) | Get-Random -Count 5 | ForEach-Object {[char]$_})

# ============================================================================
# CORE CONFIGURATION
# ============================================================================

# Azure region for all resources
$Region = "centralus"

# Resource group name (all resources in same RG)
$ResourceGroup = "rg-pgv2-usc01"

# ============================================================================
# POSTGRESQL CONFIGURATION
# ============================================================================

# PostgreSQL server (without .postgres.database.azure.com suffix)
$PostgreSQLServer = "pg-cus.postgres.database.azure.com"

# PostgreSQL port
$PostgreSQLPort = 5432

# Database name
$DatabaseName = "saifdb"

# Admin username
$AdminUsername = "jonathan"

# Admin password (will be prompted if not set)
# $AdminPassword = "your-password"  # Or set via: $env:POSTGRES_PASSWORD

# ============================================================================
# LOAD TEST PARAMETERS
# ============================================================================

# Target transactions per second
$TargetTPS = 1000

# Number of parallel workers
$WorkerCount = 200

# Test duration in seconds (300 = 5 minutes)
$TestDuration = 300

# ============================================================================
# APP SERVICE CONFIGURATION
# ============================================================================

$AppServiceConfig = @{
    # App Service name (random suffix added automatically)
    Name = "app-loadgen-$RandomSuffix"
    
    # App Service Plan name
    PlanName = "plan-loadgen-$RandomSuffix"
    
    # SKU: P0V3 (1 CPU, 4GB), P1V3 (2 CPU, 8GB), P2V3 (4 CPU, 16GB)
    SKU = "P0V3"
    
    # Number of instances (scale out)
    Instances = 1
}

# ============================================================================
# APPLICATION INSIGHTS CONFIGURATION
# ============================================================================

$AppInsightsConfig = @{
    # Application Insights name
    Name = "appins-loadgen-$RandomSuffix"
    
    # Existing Log Analytics Workspace name
    LogAnalyticsWorkspace = "law-uscentral"
    
    # Application type
    ApplicationType = "web"
}

# ============================================================================
# CONTAINER REGISTRY CONFIGURATION
# ============================================================================

$ContainerRegistry = @{
    # ACR name (will be auto-created if doesn't exist)
    Name = "acrsaifpg100815203"
    
    # SKU: Basic, Standard, Premium
    SKU = "Basic"
    
    # Container image name
    ImageName = "loadgenerator"
    
    # Image tag
    ImageTag = "latest"
}

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

# Function to get full image URI
function Get-ContainerImageUri {
    return "$($ContainerRegistry.Name).azurecr.io/$($ContainerRegistry.ImageName):$($ContainerRegistry.ImageTag)"
}

# Function to get App Service URL
function Get-AppServiceUrl {
    return "https://$($AppServiceConfig.Name).azurewebsites.net"
}

# Function to validate configuration
function Test-Configuration {
    $errors = @()
    
    if ([string]::IsNullOrEmpty($Region)) {
        $errors += "Region is required"
    }
    
    if ([string]::IsNullOrEmpty($ResourceGroup)) {
        $errors += "ResourceGroup is required"
    }
    
    if ([string]::IsNullOrEmpty($PostgreSQLServer)) {
        $errors += "PostgreSQLServer is required"
    }
    
    if ([string]::IsNullOrEmpty($DatabaseName)) {
        $errors += "DatabaseName is required"
    }
    
    if ([string]::IsNullOrEmpty($AdminUsername)) {
        $errors += "AdminUsername is required"
    }
    
    if ($errors.Count -gt 0) {
        Write-Host "❌ Configuration validation failed:" -ForegroundColor Red
        $errors | ForEach-Object { Write-Host "   - $_" -ForegroundColor Red }
        return $false
    }
    
    return $true
}

# ============================================================================
# EXPORT (comment out if causing issues when sourcing)
# ============================================================================

# Don't export if this causes errors - variables are already in scope
# Export-ModuleMember -Variable * -Function *
```

### Environment Variables

Set during deployment in App Service:

| Variable | Description | Example |
|----------|-------------|---------|
| `POSTGRESQL_SERVER` | PostgreSQL hostname | `pg-cus.postgres.database.azure.com` |
| `POSTGRESQL_PORT` | PostgreSQL port | `5432` |
| `POSTGRESQL_DATABASE` | Database name | `saifdb` |
| `POSTGRESQL_USERNAME` | Admin username | `jonathan` |
| `POSTGRESQL_PASSWORD` | Admin password | `********` (secure) |
| `TARGET_TPS` | Target transactions/sec | `1000` |
| `WORKER_COUNT` | Parallel workers | `200` |
| `TEST_DURATION` | Test duration (seconds) | `300` |
| `APPLICATIONINSIGHTS_CONNECTION_STRING` | AppInsights connection | (auto-set) |
| `ASPNETCORE_URLS` | Listening URLs | `http://+:80` |

---

## Best Practices

### Security

✅ **Use Managed Identity** - Never use admin credentials for ACR  
✅ **Secure Passwords** - Store PostgreSQL password in Key Vault or prompt at runtime  
✅ **Network Security** - Use NSG rules and private endpoints for production  
✅ **HTTPS Only** - App Service uses HTTPS by default  

### Performance

✅ **Right-size SKU** - P0V3 is good for moderate load, scale up for higher TPS  
✅ **Monitor Metrics** - Watch CPU, memory, network during tests  
✅ **Connection Pooling** - Npgsql handles this automatically  
✅ **Rate Limiting** - Built-in delay between transactions to control TPS  

### Reliability

✅ **Health Checks** - App Service uses `/health` endpoint  
✅ **Error Handling** - All exceptions caught and counted  
✅ **Graceful Shutdown** - CancellationToken ensures clean completion  
✅ **Logging** - Application Insights captures all telemetry  

### Cost Optimization

✅ **Scale Down When Idle** - Stop App Service when not testing  
✅ **Use Basic ACR** - Sufficient for low-frequency deployments  
✅ **Monitor Costs** - Check Azure Cost Management regularly  

---

## Quick Reference Commands

```powershell
# Deploy Everything
.\scripts\loadtesting\Build-LoadGenerator-Docker.ps1
.\scripts\loadtesting\Deploy-LoadGenerator-AppService.ps1 -Action Deploy

# Start Test
curl -X POST https://app-loadgen-xxxxx.azurewebsites.net/start

# Monitor Test
curl https://app-loadgen-xxxxx.azurewebsites.net/status | ConvertFrom-Json | Format-List

# View Logs
curl https://app-loadgen-xxxxx.azurewebsites.net/logs

# Check Database
psql -h pg-cus.postgres.database.azure.com -U jonathan -d saifdb -c "SELECT COUNT(*) FROM transactions;"

# Update Configuration
# Edit: scripts/loadtesting/LoadGenerator-Config.ps1
.\scripts\loadtesting\Deploy-LoadGenerator-AppService.ps1 -Action Update

# Clean Up
.\scripts\loadtesting\Deploy-LoadGenerator-AppService.ps1 -Action Delete
```

---

## Support & Feedback

For issues or questions:
1. Check [Troubleshooting](#troubleshooting) section
2. Review Application Insights logs
3. Check container logs with `Monitor-AppService-Logs.ps1`
4. Review deployment outputs for errors

---

## Appendix

### File Structure

```
azure-postgresql-ha-workshop/
├── scripts/
│   └── loadtesting/
│       ├── Dockerfile                      # Container image definition
│       ├── LoadGenerator-Config.ps1        # Configuration file
│       ├── Build-LoadGenerator-Docker.ps1  # Build script
│       ├── Deploy-LoadGenerator-AppService.ps1  # Deploy script
│       ├── Monitor-AppService-Logs.ps1     # Monitoring script
│       ├── Measure-Failover-RTO-RPO.ps1    # RTO/RPO measurement script
│       ├── Program.cs                      # Web API application
│       ├── LoadGeneratorWeb.csproj         # .NET project file
│       └── archive/                        # Archived/superseded files
└── docs/
    └── v1.0.0/
        ├── load-testing-guide.md           # This file
        └── failover-testing-quick-reference.md
```

### Version History

- **v1.0.0** (2025-10-16)
  - Initial release with App Service + Application Insights
  - Managed Identity for ACR authentication
  - HTTP API for test control
  - Real transaction inserts
  - Centralized configuration

---

**Last Updated**: 2025-10-16  
**Version**: 1.0.0  
**Author**: Azure PostgreSQL HA Workshop Team
