# Local Load Test - Quick Reference

## One-Liner Start

```powershell
cd scripts/loadtesting
.\Start-LocalLoadTest.ps1 -Start -AdminPassword "your_password"
```

## Essential Commands

```powershell
# Start container (default 1000 TPS)
.\Start-LocalLoadTest.ps1 -Start -AdminPassword "password"

# Start container (custom TPS)
.\Start-LocalLoadTest.ps1 -Start -TargetTPS 500 -AdminPassword "password"

# Check status
.\Start-LocalLoadTest.ps1 -Status

# View logs
.\Start-LocalLoadTest.ps1 -Logs

# Stop container
.\Start-LocalLoadTest.ps1 -Stop

# Clean up
.\Start-LocalLoadTest.ps1 -Clean
```

## REST API Quick Reference

```powershell
# Health check
curl http://localhost:8080/health

# Start test (HTTP POST)
curl -X POST http://localhost:8080/start

# Get status (returns JSON)
curl http://localhost:8080/status | ConvertFrom-Json

# Get logs (returns JSON array)
curl http://localhost:8080/logs | ConvertFrom-Json
```

## Configuration Snippets

### Conservative Test (500 TPS, 2 min)

```powershell
.\Start-LocalLoadTest.ps1 -Start `
  -TargetTPS 500 `
  -WorkerCount 3 `
  -TestDuration 120 `
  -AdminPassword "password"
```

### Standard Test (1000 TPS, 5 min)

```powershell
.\Start-LocalLoadTest.ps1 -Start `
  -TargetTPS 1000 `
  -WorkerCount 5 `
  -TestDuration 300 `
  -AdminPassword "password"
```

### Stress Test (Push limits)

```powershell
.\Start-LocalLoadTest.ps1 -Start `
  -TargetTPS 2000 `
  -WorkerCount 10 `
  -TestDuration 60 `
  -AdminPassword "password"
```

### Local PostgreSQL

```powershell
.\Start-LocalLoadTest.ps1 -Start `
  -PostgreSQLServer "localhost" `
  -DatabaseName "saifdb" `
  -AdminUsername "postgres" `
  -AdminPassword "password"
```

## Docker Commands (Direct)

```powershell
# Build image
docker build -f scripts/loadtesting/Dockerfile.local -t loadgen-local .

# Run container
docker run -d `
  -p 8080:80 `
  --name loadgen-local `
  -e POSTGRESQL_SERVER=pg-cus.postgres.database.azure.com `
  -e POSTGRESQL_PASSWORD=password `
  -e TARGET_TPS=1000 `
  -e WORKER_COUNT=5 `
  loadgen-local

# Check logs
docker logs -f loadgen-local

# Stop container
docker stop loadgen-local

# Remove container
docker rm loadgen-local
```

## Expected Output

### After Starting Container

```
═══════════════════════════════════════════
Starting Local Load Test Container
═══════════════════════════════════════════

[Info] Configuration:
  PostgreSQL Server: pg-cus.postgres.database.azure.com
  Database: saifdb
  Username: jonathan
  Target TPS: 1000
  Workers: 5
  Duration: 300 seconds
  Container: loadgen-local
  Web Interface: http://localhost:8080

[Success] ✓ Container started successfully
📊 Access the load test console at: http://localhost:8080
```

### After Starting Test

```
{
  "running": true,
  "status": "running",
  "startTime": "2025-10-16T10:30:00Z",
  "transactionsCompleted": 12345,
  "errors": 0,
  "uptime": "00:00:12",
  "logs": [
    "Starting load test: 1000 TPS, 5 workers, 300s duration",
    "✓ Connected to PostgreSQL",
    ...
  ]
}
```

### After Test Completion

```
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

## Typical Workflow

```powershell
# Terminal 1: Start the container
cd scripts/loadtesting
.\Start-LocalLoadTest.ps1 -Start -AdminPassword "password"

# Wait ~10 seconds for startup

# Terminal 2: Check status
.\Start-LocalLoadTest.ps1 -Status

# Terminal 2: Start the load test
Invoke-RestMethod http://localhost:8080/start -Method POST

# Terminal 1: Monitor logs (if you want to see them)
.\Start-LocalLoadTest.ps1 -Logs

# Terminal 2: Poll status every 30 seconds
1..10 | ForEach-Object { 
    Invoke-RestMethod http://localhost:8080/status | ConvertFrom-Json
    Start-Sleep -Seconds 30
}

# After test completes (5 min for default)
.\Start-LocalLoadTest.ps1 -Stop
```

## Parameters Reference

| Parameter | Default | Range | Impact |
|-----------|---------|-------|--------|
| TargetTPS | 1000 | 100-5000 | Transactions per second |
| WorkerCount | 5 | 1-20 | Concurrent connections |
| TestDuration | 300 | 10-3600 | Test length (seconds) |
| PostgreSQLServer | pg-cus.postgres.database.azure.com | - | Server FQDN/IP |
| PostgreSQLPort | 5432 | - | PostgreSQL port |
| DatabaseName | saifdb | - | Database to test |
| AdminUsername | jonathan | - | PostgreSQL user |
| AdminPassword | (required) | - | PostgreSQL password |

## Troubleshooting Quick Fixes

| Issue | Solution |
|-------|----------|
| Container won't start | Run `docker logs loadgen-local` |
| Port 8080 in use | `.\Start-LocalLoadTest.ps1 -Stop` then restart |
| Can't connect to DB | Verify credentials with `psql -h ... -U ... -d ...` |
| Too much throughput | Reduce WORKER_COUNT from 5 to 2-3 |
| Host machine slow | Stop container: `.\Start-LocalLoadTest.ps1 -Stop` |
| Out of memory | Reduce WORKER_COUNT or TPS value |

## File Locations

| File | Purpose |
|------|---------|
| `Start-LocalLoadTest.ps1` | Main control script |
| `docker-compose.local.yml` | Container configuration |
| `Dockerfile.local` | Container image definition |
| `LOCAL-TESTING-GUIDE.md` | Full documentation |
| `Program.cs` | Load test application code |

## Environment Variables in Docker

Set in `docker-compose.local.yml` or via `-e` flag:

```yaml
POSTGRESQL_SERVER: pg-cus.postgres.database.azure.com
POSTGRESQL_PORT: "5432"
POSTGRESQL_DATABASE: saifdb
POSTGRESQL_USERNAME: jonathan
POSTGRESQL_PASSWORD: (your_password)
TARGET_TPS: "1000"
WORKER_COUNT: "5"
TEST_DURATION: "300"
```

## Web Endpoints

| Endpoint | Method | Returns | Purpose |
|----------|--------|---------|---------|
| /health | GET | "healthy" | Health check |
| /status | GET | JSON | Get test status & metrics |
| /start | POST | 202 | Start load test |
| /logs | GET | JSON array | Get all logs |
