# Utils Folder

This folder contains diagnostic and low-level utility scripts that are used for troubleshooting and advanced scenarios.

## Utility Scripts

### Diagnose-Failover-Performance.ps1
- **Purpose**: Troubleshooting tool for when failover tests don't meet SLA targets
- **Use Case**: Analyze network latency, DNS resolution, database performance
- **When to Use**: After running `Test-PostgreSQL-Failover.ps1` if RTO > 120 seconds
- **Output**: Detailed diagnostics report

**Example:**
```powershell
.\utils\Diagnose-Failover-Performance.ps1 -ResourceGroupName "rg-saif-pgsql-swc-01"
```

### Build-SAIF-Containers.ps1
- **Purpose**: Low-level manual container build script
- **Use Case**: Advanced container customization, troubleshooting build issues
- **When to Use**: When `Rebuild-SAIF-Containers.ps1` doesn't meet your needs
- **Note**: Most users should use `Rebuild-SAIF-Containers.ps1` instead

**Example:**
```powershell
.\utils\Build-SAIF-Containers.ps1 -ResourceGroupName "rg-saif-pgsql-swc-01"
```

## When to Use Utils

These utilities are for:
- 🔍 **Troubleshooting**: Diagnose issues with deployments or failovers
- 🛠️ **Advanced scenarios**: Low-level control over build/deployment processes
- 🧪 **Experimentation**: Testing alternative approaches

**For normal operations**, use the main scripts in the parent `scripts/` folder.

## Maintenance Note

These utilities are maintained separately and may not receive the same level of updates as main scripts. They are provided as-is for advanced users.

---

*Last Updated: 2025-10-08*
