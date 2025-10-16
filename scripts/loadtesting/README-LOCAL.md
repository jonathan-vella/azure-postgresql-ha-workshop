# Load Testing Directory

This directory contains tools and scripts for load testing the PostgreSQL HA infrastructure with controlled throughput.

## Quick Start

### Local Testing (Recommended for Development)

Run the load test in a local Docker container with controlled TPS:

```powershell
cd scripts/loadtesting
.\Start-LocalLoadTest.ps1 -Start -AdminPassword "your_postgres_password"

# In another terminal, start the test
curl -X POST http://localhost:8080/start

# Check status
curl http://localhost:8080/status | ConvertFrom-Json
```

**Why Local?**
- Target TPS: ~1,000 (configurable)
- CPU limit: 1 core (prevents excessive throughput)
- Memory limit: 512MB (controls resource usage)
- No Azure costs
- Immediate feedback for debugging

**See**: [LOCAL-TESTING-GUIDE.md](LOCAL-TESTING-GUIDE.md) for full documentation

### Azure App Service Testing (Production)

Deploy to Azure App Service for higher throughput and cloud testing:

```powershell
.\Deploy-LoadGenerator-AppService.ps1 -Action Deploy `
  -ResourceGroup "rg-pgv2-usc01" `
  -AppServiceName "app-loadgen" `
  -PostgreSQLServer "pg-cus.postgres.database.azure.com" `
  -DatabaseName "saifdb" `
  -AdminUsername "jonathan" `
  -AdminPassword $securePassword
```

**Why App Service?**
- Target TPS: 1,000-2,000+ (production-grade)
- Real-time Application Insights monitoring
- Scalable with multiple instances
- Production-ready reliability
- Cloud-based testing

**See**: [Load Testing Guide](../docs/load-testing-guide.md) for full documentation

## Files in This Directory

### Control Scripts

| File | Purpose | Usage |
|------|---------|-------|
| **Start-LocalLoadTest.ps1** | Local Docker container management | `.\Start-LocalLoadTest.ps1 -Start -AdminPassword "pwd"` |
| **Deploy-LoadGenerator-AppService.ps1** | Azure App Service deployment | `.\Deploy-LoadGenerator-AppService.ps1 -Action Deploy ...` |
| **Monitor-AppService-Logs.ps1** | Stream Azure logs to terminal | `.\Monitor-AppService-Logs.ps1 -ResourceGroup "rg" ...` |
| **Measure-Failover-RTO-RPO.ps1** | Measure recovery metrics during failover | `.\Measure-Failover-RTO-RPO.ps1 ...` |

### Application Code

| File | Purpose |
|------|---------|
| **Program.cs** | .NET 8.0 load generator web application |
| **LoadGeneratorWeb.csproj** | .NET project configuration |

### Docker Configuration

| File | Purpose | When to Use |
|------|---------|------------|
| **Dockerfile** | Production image (Azure App Service) | `Deploy-LoadGenerator-AppService.ps1` |
| **Dockerfile.local** | Local development image | `Start-LocalLoadTest.ps1` |
| **docker-compose.local.yml** | Local container orchestration | `docker-compose -f docker-compose.local.yml up` |

### Documentation

| File | Purpose |
|------|---------|
| **LOCAL-TESTING-GUIDE.md** | Complete local testing documentation |
| **LOCAL-TESTING-QUICKREF.md** | Quick reference commands |
| **README.md** | This file |

### Archive

| Directory | Purpose |
|-----------|---------|
| **archive/** | Deprecated testing approaches (ACI, PowerShell, C# Cloud Shell) |

## Architecture

### Local Testing Architecture

```
┌─────────────────────────────────────────────────┐
│          Your Local Machine                      │
│  ┌────────────────────────────────────────────┐ │
│  │  Docker Desktop                            │ │
│  │  ┌──────────────────────────────────────┐  │ │
│  │  │  loadgen-local Container             │  │ │
│  │  │  ┌────────────────────────────────┐  │  │ │
│  │  │  │  .NET 8.0 Load Generator       │  │  │ │
│  │  │  │  - HTTP API (/start, /status) │  │  │ │
│  │  │  │  - Database connections       │  │  │ │
│  │  │  │  - Transaction logging        │  │  │ │
│  │  │  └────────────────────────────────┘  │  │ │
│  │  │  Resource Limits:                     │  │ │
│  │  │  - 1 CPU core (throttles throughput)  │  │ │
│  │  │  - 512MB RAM                         │  │ │
│  │  └──────────────────────────────────────┘  │ │
│  └────────────────────────────────────────────┘ │
│                       │                          │
│                       ▼ (TCP 8080)              │
│  ┌────────────────────────────────────────────┐ │
│  │  Browser / curl / PowerShell              │ │
│  │  /health /status /start /logs             │ │
│  └────────────────────────────────────────────┘ │
└────────────┬────────────────────────────────────┘
             │
             ▼ (Network)
    ┌────────────────────┐
    │  PostgreSQL on     │
    │  Azure/Local       │
    │  (FQDN or IP)      │
    └────────────────────┘
```

### Azure Testing Architecture

```
┌──────────────────────────────────────────────┐
│            Azure Subscription                 │
│  ┌────────────────────────────────────────┐  │
│  │  App Service Plan (Linux)              │  │
│  │  ┌──────────────────────────────────┐  │  │
│  │  │  loadgen Container Instance      │  │  │
│  │  │  - Program.cs (load generator)   │  │  │
│  │  │  - .NET 8.0 Runtime              │  │  │
│  │  │  - HTTP API (/start, /status)    │  │  │
│  │  │  - TCP 8080 (internal)           │  │  │
│  │  └──────────────────────────────────┘  │  │
│  │  Scaling: 1-N instances (manual/auto)  │  │
│  └────────────────────────────────────────┘  │
│                       │                       │
│  ┌────────────────────────────────────────┐  │
│  │  Application Insights                  │  │
│  │  - Real-time telemetry               │  │
│  │  - Performance metrics                │  │
│  │  - Dependency tracking                │  │
│  └────────────────────────────────────────┘  │
│                                              │
│  ┌────────────────────────────────────────┐  │
│  │  PostgreSQL Flexible Server (HA)       │  │
│  │  - Zone redundancy                     │  │
│  │  - Automatic failover                  │  │
│  │  - Synchronous replication             │  │
│  └────────────────────────────────────────┘  │
└──────────────────────────────────────────────┘
```

## Configuration

### Local Testing Configuration

Edit `docker-compose.local.yml` to customize:

```yaml
environment:
  POSTGRESQL_SERVER: pg-cus.postgres.database.azure.com
  POSTGRESQL_DATABASE: saifdb
  POSTGRESQL_USERNAME: jonathan
  TARGET_TPS: 1000          # Adjust this for target throughput
  WORKER_COUNT: 5           # Reduce for lower TPS
  TEST_DURATION: 300        # 5 minutes
deploy:
  resources:
    limits:
      cpus: '1.0'           # Primary throughput throttle
      memory: 512M
```

### TPS Tuning Guide

| Target TPS | Worker Count | CPU Limit | Config |
|-----------|--------------|-----------|--------|
| 500 | 3 | 1.0 | Conservative testing |
| 1000 | 5 | 1.0 | **Default** ✓ |
| 2000 | 10 | 1.0 | Push limits (may spike) |
| 3000+ | 15+ | 2.0 | High performance (not recommended for local) |

**Formula**: `Local TPS ≈ 200 * WorkerCount * (CPU_cores / 2.0)`

## REST API

All endpoints return JSON (except `/health`).

### GET /health

Health check endpoint.

```powershell
curl http://localhost:8080/health
# Returns: healthy
```

### GET /status

Get current test status and metrics.

```powershell
curl http://localhost:8080/status | ConvertFrom-Json

# Returns:
{
  "running": false,
  "status": "completed",
  "startTime": "2025-10-16T10:30:00Z",
  "transactionsCompleted": 298765,
  "errors": 0,
  "uptime": "00:05:00",
  "logs": [...]
}
```

### POST /start

Start the load test.

```powershell
curl -X POST http://localhost:8080/start
# Returns: 202 Accepted
```

### GET /logs

Get all test logs as JSON array.

```powershell
curl http://localhost:8080/logs | ConvertFrom-Json

# Returns:
[
  "Starting load test: 1000 TPS, 5 workers, 300s duration",
  "✓ Connected to PostgreSQL",
  "✓ Load test completed",
  "  Transactions: 298765",
  "  Errors: 0",
  "  TPS: 995.88"
]
```

## Common Workflows

### Workflow 1: Basic Local Test

```powershell
# 1. Start container
cd scripts/loadtesting
.\Start-LocalLoadTest.ps1 -Start -AdminPassword "password"

# 2. Wait 10 seconds for startup
Start-Sleep -Seconds 10

# 3. Start test
Invoke-RestMethod http://localhost:8080/start -Method POST

# 4. Monitor status
Invoke-RestMethod http://localhost:8080/status | ConvertFrom-Json

# 5. Wait for completion (~5 minutes)
Start-Sleep -Seconds 300

# 6. Get final results
$results = Invoke-RestMethod http://localhost:8080/status
Write-Host "Completed: $($results.transactionsCompleted) transactions"
Write-Host "TPS: $($results.logs[-1])"

# 7. Stop container
.\Start-LocalLoadTest.ps1 -Stop
```

### Workflow 2: Azure Deployment

```powershell
# 1. Deploy to App Service
.\Deploy-LoadGenerator-AppService.ps1 -Action Deploy `
  -ResourceGroup "rg-pgv2-usc01" `
  -AppServiceName "app-loadgen" `
  -PostgreSQLServer "pg-cus.postgres.database.azure.com" `
  -DatabaseName "saifdb" `
  -AdminUsername "jonathan" `
  -AdminPassword $securePassword

# 2. Monitor logs
.\Monitor-AppService-Logs.ps1 -ResourceGroup "rg-pgv2-usc01" `
  -AppServiceName "app-loadgen"

# 3. Start test via browser or curl
# https://app-loadgen.azurewebsites.net/start

# 4. Check Application Insights in Azure Portal
```

### Workflow 3: Failover Testing with RTO/RPO

```powershell
# 1. Start local or Azure load test
# (See Workflow 1 or 2)

# 2. Measure RTO/RPO
.\Measure-Failover-RTO-RPO.ps1 `
  -AppServiceUrl "https://app-loadgen-XXXX.azurewebsites.net" `
  -ResourceGroup "rg-pgv2-usc01" `
  -ServerName "pg-cus" `
  -DatabaseName "saifdb" `
  -AdminUsername "jonathan" `
  -MaxMonitoringSeconds 90

# 3. Trigger failover manually in Azure Portal
# PostgreSQL Flexible Server > High Availability > Forced Failover

# 4. Script measures RTO (recovery time) and RPO (data loss)
```

## Performance Expectations

### Local Container Performance

```
Expected Output:
✓ Load test completed
  Transactions: 298,765
  Errors: 0
  TPS: 995.88 (consistent with 1000 target)
  Duration: ~5 minutes (300 seconds)
```

### Azure App Service Performance

```
Expected Output:
✓ Load test completed
  Transactions: 1,250,000+
  Errors: <10
  TPS: 1,200-2,000+ per instance
  Duration: ~10-15 minutes (higher throughput scales linearly)
```

## Troubleshooting

### Local Docker Issues

**Container won't start**
```powershell
# Check logs
docker logs loadgen-local

# Verify docker-compose.local.yml
Test-Path scripts/loadtesting/docker-compose.local.yml
```

**Port 8080 already in use**
```powershell
netstat -ano | findstr :8080
taskkill /PID <pid> /F
```

**Cannot connect to PostgreSQL**
```powershell
# Test connection locally
psql -h pg-cus.postgres.database.azure.com -U jonathan -d saifdb

# Check container network
docker exec loadgen-local ping pg-cus.postgres.database.azure.com
```

**Getting too much throughput (>2000 TPS)**
```powershell
# Reduce workers
.\Start-LocalLoadTest.ps1 -Start `
  -WorkerCount 2 `
  -AdminPassword "password"

# Or reduce target TPS
.\Start-LocalLoadTest.ps1 -Start `
  -TargetTPS 500 `
  -AdminPassword "password"
```

## Related Documentation

- **[Load Testing Guide](../docs/load-testing-guide.md)** - Comprehensive Azure App Service approach
- **[Failover Testing Guide](../docs/failover-testing-guide.md)** - RTO/RPO measurement procedures
- **[Local Testing Guide](LOCAL-TESTING-GUIDE.md)** - Complete local testing documentation
- **[Quick Reference](LOCAL-TESTING-QUICKREF.md)** - Quick command reference
- **[Main README](../../README.md)** - Project overview

## Files Created for Local Testing

```
scripts/loadtesting/
├── Start-LocalLoadTest.ps1          # Main control script (NEW)
├── docker-compose.local.yml         # Docker compose config (NEW)
├── Dockerfile.local                 # Local optimized Dockerfile (NEW)
├── LOCAL-TESTING-GUIDE.md           # Detailed documentation (NEW)
├── LOCAL-TESTING-QUICKREF.md        # Quick reference (NEW)
├── README.md                        # This file (UPDATED)
├── Program.cs                       # .NET load generator
├── LoadGeneratorWeb.csproj          # .NET project
├── Dockerfile                       # Production Dockerfile
├── Deploy-LoadGenerator-AppService.ps1
├── Monitor-AppService-Logs.ps1
├── Measure-Failover-RTO-RPO.ps1
└── archive/                         # Legacy approaches
    ├── Deploy-LoadGenerator-ACI.ps1
    └── Test-PostgreSQL-Failover.csx
```

## Next Steps

1. **Start Local Testing**: Follow [LOCAL-TESTING-GUIDE.md](LOCAL-TESTING-GUIDE.md)
2. **Verify TPS**: Confirm ~1000 TPS with default settings
3. **Adjust Parameters**: Customize worker count, TPS, or duration
4. **Deploy to Azure**: Use `Deploy-LoadGenerator-AppService.ps1` when ready
5. **Test Failover**: Use `Measure-Failover-RTO-RPO.ps1` to measure recovery

## Support

For issues or questions:
1. Check [LOCAL-TESTING-GUIDE.md](LOCAL-TESTING-GUIDE.md) Troubleshooting section
2. Review logs: `.\Start-LocalLoadTest.ps1 -Logs`
3. Test connectivity: `docker exec loadgen-local curl http://postgresql-server`
