# Archive Folder

This folder contains obsolete scripts that have been superseded by newer versions but are preserved for reference.

## Archived Scripts

### Test-PostgreSQL-Failover.ps1 (Original)
- **Status**: Superseded by native version
- **Method**: Docker-based psql execution
- **Performance**: ~0.7-0.8 TPS
- **Superseded by**: `Test-PostgreSQL-Failover.ps1` (Npgsql native)
- **Date Archived**: 2025-10-09
- **Reason**: Native Npgsql version is 16x faster (12-13 TPS) and more reliable

### Test-PostgreSQL-Failover-Improved.ps1
- **Status**: Experimental iteration #1
- **Method**: Docker-based with improved RTO measurement
- **Performance**: ~1-2 TPS
- **Date Archived**: 2025-10-09
- **Reason**: Still Docker-bound, superseded by native version

### Test-PostgreSQL-Failover-Parallel.ps1
- **Status**: Experimental iteration #2
- **Method**: PowerShell background jobs with parallel Docker workers
- **Performance**: ~5-10 TPS
- **Issues**: Failover detection isolated in background jobs, not visible in console
- **Date Archived**: 2025-10-09
- **Reason**: Detection issues and still Docker-bound

### Test-PostgreSQL-Failover-Fast.ps1
- **Status**: Experimental iteration #3
- **Method**: Persistent worker processes with file-based communication
- **Performance**: ~10-20 TPS
- **Date Archived**: 2025-10-09
- **Reason**: Still limited by Docker per-transaction overhead, superseded by native version

### Initialize-Database-Container.ps1
- **Status**: Superseded
- **Method**: Container-based database initialization
- **Superseded by**: `Initialize-Database.ps1`
- **Date Archived**: 2025-10-09
- **Reason**: Main script now handles both container and direct initialization

### Initialize-Database-CloudShell.ps1
- **Status**: Edge case script
- **Method**: Cloud Shell specific initialization
- **Date Archived**: 2025-10-09
- **Reason**: Rarely used, edge case scenario

### Update-SAIF-Containers-PostgreSQL.ps1
- **Status**: Superseded
- **Superseded by**: `Rebuild-SAIF-Containers.ps1`
- **Date Archived**: 2025-10-09
- **Reason**: New rebuild script provides better functionality and naming

## Evolution Timeline

```
Test-PostgreSQL-Failover.ps1 (Original)
  ↓ Docker-based, 0.7 TPS
Test-PostgreSQL-Failover-Improved.ps1
  ↓ Better RTO measurement, 1-2 TPS
Test-PostgreSQL-Failover-Parallel.ps1
  ↓ Parallel workers, 5-10 TPS, detection issues
Test-PostgreSQL-Failover-Fast.ps1
  ↓ Persistent workers, 10-20 TPS, still Docker-bound
Test-PostgreSQL-Failover.ps1 (Native) ✅
  ✓ Npgsql native library, 12-13 TPS, reliable
  ✓ Auto-installs dependencies to libs/ folder
  ✓ Falls back to Docker if needed
  ✓ Production-ready
```

## Performance Comparison

| Version | Method | TPS | Bottleneck | Status |
|---------|--------|-----|------------|--------|
| Original | Docker | 0.7-0.8 | Container overhead | Archived |
| Improved | Docker | 1-2 | Container overhead | Archived |
| Parallel | Docker + Jobs | 5-10 | Container overhead + detection issues | Archived |
| Fast | Docker + Workers | 10-20 | Container overhead | Archived |
| **Native** | **Npgsql** | **12-13** | **PowerShell loop overhead** | **✅ CURRENT** |

## When to Use Archived Scripts

**Generally: Never.** These scripts are preserved for:
- Historical reference
- Understanding the evolution of the solution
- Academic purposes
- Fallback if the current version has unforeseen issues

**Always use**: `../Test-PostgreSQL-Failover.ps1` (native Npgsql version)

## Restoration

If you need to restore any archived script:

```powershell
# Copy back to main scripts folder
Copy-Item "archive\<script-name>.ps1" "..\<script-name>.ps1"
```

---

## October 2025 Cleanup - App Service Load Testing Migration

The following files were archived on **2025-10-16** as part of the migration to the new App Service-based load testing solution documented in `docs/load-testing-guide.md` and `docs/failover-testing-guide.md`.

### Superseded Scripts

| File | Reason | Replaced By |
|------|--------|-------------|
| `Deploy-LoadGenerator-ACI.ps1` | Old Azure Container Instances deployment | `Deploy-LoadGenerator-AppService.ps1` |
| `Run-LoadGenerator-Local.ps1` | Old local testing approach | App Service with HTTP API endpoints |
| `LoadGenerator.csx` | Old C# script version | `Program.cs` (compiled .NET 8.0 app) |
| `LoadGeneratorWeb.csx` | Old C# script web version | `Program.cs` (compiled .NET 8.0 app) |
| `entrypoint.sh` | Shell entrypoint for script execution | Dockerfile uses `dotnet LoadGeneratorWeb.dll` |
| `Check-WAL-Settings.ps1` | Utility script | Not needed in standard workflow |
| `Measure-Connection-RTO.ps1` | Simple RTO measurement | `Measure-Failover-RTO-RPO.ps1` (comprehensive RTO+RPO) |
| `Monitor-Failover-Azure.ps1` | Old monitoring script | `Monitor-AppService-Logs.ps1` |
| `Monitor-LoadGenerator-Resilient.ps1` | Old monitoring script | `Monitor-AppService-Logs.ps1` |
| `Monitor-PostgreSQL-HA.ps1` | Old monitoring script | `Monitor-AppService-Logs.ps1` |
| `Monitor-PostgreSQL-Realtime.ps1` | Old monitoring script | `Monitor-AppService-Logs.ps1` |
| `Monitor-Transactions-Docker.ps1` | Old monitoring script | `Monitor-AppService-Logs.ps1` |
| `Test-PostgreSQL-Failover.ps1` | Old failover test | `Measure-Failover-RTO-RPO.ps1` |
| `Validate-Transactions.ps1` | Utility script | Database queries in documentation |
| `APPSERVICE-LOADTESTING-GUIDE.md` | Draft guide | `docs/load-testing-guide.md` |

### Current Production Files (October 2025)

The following files remain in active use:

| File | Purpose |
|------|---------|
| `Build-LoadGenerator-Docker.ps1` | Build and push container to ACR |
| `Deploy-LoadGenerator-AppService.ps1` | Deploy/update/delete App Service |
| `Monitor-AppService-Logs.ps1` | Stream App Service container logs |
| `Measure-Failover-RTO-RPO.ps1` | Measure RTO and RPO during failover |
| `LoadGenerator-Config.ps1` | Centralized configuration |
| `Program.cs` | ASP.NET Core minimal API application |
| `LoadGeneratorWeb.csproj` | .NET 8.0 project file |
| `Dockerfile` | Multi-stage container build |

### Key Architecture Changes

**Before (ACI + Scripts)**:
- Azure Container Instances
- C# scripts executed with `dotnet-script`
- .NET 6.0
- Console application (exits after execution)
- 5-10 minute delay for Log Analytics

**After (App Service + Compiled App)**:
- Azure App Service on Linux
- Compiled .NET 8.0 web application
- ASP.NET Core minimal API
- Long-running web service with HTTP endpoints
- Immediate Application Insights telemetry

### Documentation References

- **Load Testing Guide**: `docs/load-testing-guide.md`
- **Failover Testing Guide**: `docs/failover-testing-guide.md`

---

*Last Updated: 2025-10-16*
