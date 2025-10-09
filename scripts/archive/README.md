# Archive Folder

This folder contains obsolete scripts that have been superseded by newer versions but are preserved for reference.

## Archived Scripts

### Test-PostgreSQL-Failover.ps1 (Original)
- **Status**: Superseded by native version
- **Method**: Docker-based psql execution
- **Performance**: ~0.7-0.8 TPS
- **Superseded by**: `Test-PostgreSQL-Failover.ps1` (Npgsql native)
- **Date Archived**: 2025-10-08
- **Reason**: Native Npgsql version is 16x faster (12-13 TPS) and more reliable

### Test-PostgreSQL-Failover-Improved.ps1
- **Status**: Experimental iteration #1
- **Method**: Docker-based with improved RTO measurement
- **Performance**: ~1-2 TPS
- **Date Archived**: 2025-10-08
- **Reason**: Still Docker-bound, superseded by native version

### Test-PostgreSQL-Failover-Parallel.ps1
- **Status**: Experimental iteration #2
- **Method**: PowerShell background jobs with parallel Docker workers
- **Performance**: ~5-10 TPS
- **Issues**: Failover detection isolated in background jobs, not visible in console
- **Date Archived**: 2025-10-08
- **Reason**: Detection issues and still Docker-bound

### Test-PostgreSQL-Failover-Fast.ps1
- **Status**: Experimental iteration #3
- **Method**: Persistent worker processes with file-based communication
- **Performance**: ~10-20 TPS
- **Date Archived**: 2025-10-08
- **Reason**: Still limited by Docker per-transaction overhead, superseded by native version

### Initialize-Database-Container.ps1
- **Status**: Superseded
- **Method**: Container-based database initialization
- **Superseded by**: `Initialize-Database.ps1`
- **Date Archived**: 2025-10-08
- **Reason**: Main script now handles both container and direct initialization

### Initialize-Database-CloudShell.ps1
- **Status**: Edge case script
- **Method**: Cloud Shell specific initialization
- **Date Archived**: 2025-10-08
- **Reason**: Rarely used, edge case scenario

### Update-SAIF-Containers-PostgreSQL.ps1
- **Status**: Superseded
- **Superseded by**: `Rebuild-SAIF-Containers.ps1`
- **Date Archived**: 2025-10-08
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

*Last Updated: 2025-10-08*
