# Local Load Testing Guide

## Overview

Running the load test in a local Docker container allows you to:
- **Control TPS precisely** with CPU/memory resource limits
- **Iterate quickly** without Azure deployment delays
- **Test locally** before pushing to production Azure environment
- **Debug issues** with immediate container logs
- **Reduce costs** by testing on your local machine

## Problem Statement

When running on Azure App Service, the load generator achieves 6,000+ TPS because:
- App Service has multiple CPU cores and ample memory
- Network latency is minimal (internal Azure network)
- The application scales horizontally with container resources

**Solution**: Run locally with:
- Single CPU core limit (1.0 CPU)
- Memory constraint (512MB)
- Reduced worker count (5 workers instead of 50+)
- Results in ~1,000 TPS on typical laptop/desktop

## Prerequisites

### Required
- **Docker Desktop** (Windows/Mac) or Docker Engine (Linux)
  - Download: https://www.docker.com/products/docker-desktop
  - Ensure Docker is running before starting tests
- **.NET 8.0 SDK** (for local builds, optional for Docker builds)
- **PostgreSQL credentials** with database access

### System Requirements
- **Minimum 2 CPU cores** (1 reserved for Docker container, 1 for system)
- **2GB RAM minimum** (512MB for container + 1.5GB for system/Docker)
- **Stable network connection** to PostgreSQL (local or cloud)

## Quick Start

### 1. Start the Container

```powershell
cd scripts/loadtesting

# Basic start with defaults (Target TPS: 1000, Workers: 5)
.\Start-LocalLoadTest.ps1 -Start -AdminPassword "your_postgres_password"

# Or with custom TPS
.\Start-LocalLoadTest.ps1 -Start `
  -TargetTPS 500 `
  -WorkerCount 3 `
  -AdminPassword "your_postgres_password"
```

### 2. Check Container Status

```powershell
# In another terminal
.\Start-LocalLoadTest.ps1 -Status

# Or check directly via HTTP
curl http://localhost:8080/health
```

### 3. Start the Load Test

**Option A: PowerShell**
```powershell
$body = $null
Invoke-RestMethod -Uri "http://localhost:8080/start" `
  -Method POST `
  -Body $body

# Check status
Invoke-RestMethod -Uri "http://localhost:8080/status" | ConvertFrom-Json
```

**Option B: curl**
```powershell
# Start test
curl -X POST http://localhost:8080/start

# Check status
curl http://localhost:8080/status | ConvertFrom-Json

# Stream logs
curl http://localhost:8080/logs | ConvertFrom-Json
```

### 4. Monitor the Test

```powershell
# Stream container logs in real-time
.\Start-LocalLoadTest.ps1 -Logs

# Or with Docker directly
docker logs -f loadgen-local
```

### 5. Stop the Container

```powershell
# Stop but keep the container
.\Start-LocalLoadTest.ps1 -Stop

# Or remove completely
.\Start-LocalLoadTest.ps1 -Clean
```

## Configuration Parameters

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `POSTGRESQL_SERVER` | `pg-cus.postgres.database.azure.com` | PostgreSQL FQDN |
| `POSTGRESQL_PORT` | `5432` | PostgreSQL port |
| `POSTGRESQL_DATABASE` | `saifdb` | Database name |
| `POSTGRESQL_USERNAME` | `jonathan` | Database user |
| `POSTGRESQL_PASSWORD` | (required) | Database password |
| `TARGET_TPS` | `1000` | Transactions per second target |
| `WORKER_COUNT` | `5` | Concurrent worker threads |
| `TEST_DURATION` | `300` | Test duration in seconds |

### Resource Limits

The local Docker configuration limits resources to control TPS:

| Resource | Limit | Impact |
|----------|-------|--------|
| **CPU** | 1.0 core (100%) | Primary throttle for local execution |
| **Memory** | 512MB hard limit | Prevents runaway memory usage |
| **Workers** | 5 (adjustable) | Concurrent database connections |

**Formula for estimated TPS:**
```
Local TPS ≈ TARGET_TPS * (WorkerCount / 50) * (CPU_limit / 4)

Examples:
- 1 CPU, 5 workers → ~1,000 TPS
- 1 CPU, 3 workers → ~600 TPS
- 2 CPU, 5 workers → ~2,000 TPS (if CPU not limited)
```

## Usage Examples

### Example 1: Test at 500 TPS (Conservative)

```powershell
cd scripts/loadtesting
.\Start-LocalLoadTest.ps1 -Start `
  -TargetTPS 500 `
  -WorkerCount 3 `
  -TestDuration 600 `
  -AdminPassword "password"

# Monitor
.\Start-LocalLoadTest.ps1 -Logs
```

### Example 2: Test at 1000 TPS (Default)

```powershell
# Start with defaults
.\Start-LocalLoadTest.ps1 -Start -AdminPassword "password"

# Wait 5 seconds for container startup
Start-Sleep -Seconds 5

# Check health
Invoke-RestMethod http://localhost:8080/health

# Start test via API
Invoke-RestMethod http://localhost:8080/start -Method POST
```

### Example 3: Test Database Connection from Local

```powershell
# If PostgreSQL is local, use:
.\Start-LocalLoadTest.ps1 -Start `
  -PostgreSQLServer "localhost" `
  -DatabaseName "saifdb" `
  -AdminUsername "postgres" `
  -AdminPassword "postgres"
```

### Example 4: Continuous Integration

```powershell
# Start container
.\Start-LocalLoadTest.ps1 -Start `
  -TargetTPS 1000 `
  -TestDuration 120 `
  -AdminPassword $env:PG_PASSWORD

# Wait for startup
Start-Sleep -Seconds 5

# Run test
Invoke-RestMethod http://localhost:8080/start -Method POST

# Wait for completion
Start-Sleep -Seconds 130

# Get results
$results = Invoke-RestMethod http://localhost:8080/status
Write-Host "Transactions: $($results.transactionsCompleted)"
Write-Host "Errors: $($results.errors)"

# Cleanup
.\Start-LocalLoadTest.ps1 -Stop
```

## Troubleshooting

### Issue: Container fails to start

```powershell
# Check container logs
docker logs loadgen-local

# Verify docker-compose.local.yml exists
Test-Path scripts/loadtesting/docker-compose.local.yml

# Try manual docker start
docker build -f scripts/loadtesting/Dockerfile.local -t loadgen-local .
```

### Issue: Cannot connect to PostgreSQL

```powershell
# Verify credentials
$params = @{
    "Host" = "pg-cus.postgres.database.azure.com"
    "Port" = 5432
    "Database" = "saifdb"
    "Username" = "jonathan"
    "Password" = "your_password"
    "SSL Mode" = "Require"
}

# Test connection from host
psql -h pg-cus.postgres.database.azure.com -U jonathan -d saifdb

# Check container can reach network
docker exec loadgen-local curl -I https://pg-cus.postgres.database.azure.com
```

### Issue: Getting too much throughput (>1000 TPS)

**Reduce worker count:**
```powershell
.\Start-LocalLoadTest.ps1 -Start `
  -TargetTPS 1000 `
  -WorkerCount 2 `  # Reduce from 5
  -AdminPassword "password"
```

**Or reduce target TPS:**
```powershell
.\Start-LocalLoadTest.ps1 -Start `
  -TargetTPS 500 `   # Reduce from 1000
  -WorkerCount 5 `
  -AdminPassword "password"
```

**Or add CPU limit:** Edit `docker-compose.local.yml` and reduce:
```yaml
cpus: '0.5'  # Changed from '1.0'
```

### Issue: "Port 8080 already in use"

```powershell
# Find what's using port 8080
netstat -ano | findstr :8080

# Kill the process
taskkill /PID <pid> /F

# Or stop existing container
.\Start-LocalLoadTest.ps1 -Stop
```

### Issue: High memory usage on host machine

```powershell
# Docker Desktop is consuming too much
# Stop Docker Desktop and restart
# Or reduce container memory limit in docker-compose.local.yml:
memory: 256M  # Changed from 512M
```

## REST API Endpoints

### GET /health

**Purpose**: Health check endpoint

```powershell
curl http://localhost:8080/health

# Response
healthy
```

### GET /status

**Purpose**: Get current test status and metrics

```powershell
curl http://localhost:8080/status | ConvertFrom-Json

# Response
{
  "running": false,
  "status": "completed",
  "startTime": "2025-10-16T10:30:00Z",
  "transactionsCompleted": 298765,
  "errors": 0,
  "uptime": "00:05:00",
  "logs": [
    "Starting load test: 1000 TPS, 5 workers, 300s duration",
    "✓ Connected to PostgreSQL",
    "✓ Load test completed",
    "  Transactions: 298765",
    "  Errors: 0",
    "  TPS: 995.88"
  ]
}
```

### POST /start

**Purpose**: Start the load test

```powershell
curl -X POST http://localhost:8080/start

# Response
202 Accepted
```

### GET /logs

**Purpose**: Get all test logs as JSON array

```powershell
curl http://localhost:8080/logs | ConvertFrom-Json

# Response
[
  "Starting load test: 1000 TPS, 5 workers, 300s duration",
  "✓ Connected to PostgreSQL",
  ...
]
```

## Performance Expectations

### Local Container Performance

| Configuration | Typical TPS | CPU Usage | Memory | Use Case |
|---------------|------------|-----------|--------|----------|
| 1 CPU, 5 workers | 800-1,200 | 95-100% | 200MB | **Default** - Target 1K TPS |
| 1 CPU, 3 workers | 500-700 | 60-80% | 150MB | Conservative testing |
| 1 CPU, 10 workers | 1,500-2,000 | 100% | 300MB | Push limits |
| 2 CPU, 5 workers | 1,500-2,500+ | 50% per core | 250MB | Higher throughput |

### Comparison to Azure App Service

| Metric | Local Container | Azure App Service (P0v3) |
|--------|-----------------|--------------------------|
| **Target TPS** | 1,000 (configurable) | 1,000-2,000+ |
| **CPU** | 1 core | 1-2 cores |
| **Memory** | 512MB | 1-2GB |
| **Latency** | Variable (local network) | Lower (Azure network) |
| **Startup** | ~10 seconds | ~30 seconds |
| **Cost** | Free (local) | $10-50/month |

## Next Steps

1. **Local Testing**: Verify TPS stabilizes at ~1,000 with default settings
2. **Adjust Parameters**: Modify worker count or duration for your test scenarios
3. **Test to Azure**: Once stable locally, deploy to Azure App Service using `Deploy-LoadGenerator-AppService.ps1`
4. **Compare Results**: Compare local throughput vs Azure throughput to validate scaling behavior

## Related Documentation

- [Load Testing Guide](load-testing-guide.md) - Azure App Service approach
- [Load Testing Cheat Sheet](load-testing-cheat-sheet.md) - Quick reference
- [Failover Testing Guide](../docs/failover-testing-guide.md) - RTO/RPO measurement
