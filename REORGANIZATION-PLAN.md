# 🗂️ Repository Reorganization Plan

**Goal:** Streamline the repository to support a highly repeatable workflow:
1. Deploy application + database
2. Validate deployment
3. Load test
4. Failover test
5. Measure RTO/RPO

**Date:** October 10, 2025  
**Status:** ⏳ PENDING APPROVAL

---

## 📋 Core Workflow Files (KEEP)

These files are essential for the primary use case and should remain in their current locations.

### **🚀 Infrastructure & Deployment**
| File/Folder | Location | Purpose | Keep? |
|------------|----------|---------|-------|
| `infra/main.bicep` | `/infra/` | Infrastructure as Code - PostgreSQL deployment | ✅ **KEEP** |
| `infra/main.json` | `/infra/` | ARM template (compiled from Bicep) | ✅ **KEEP** |
| `infra/main.parameters.json` | `/infra/` | Deployment parameters | ✅ **KEEP** |
| `infra/modules/database/` | `/infra/modules/` | PostgreSQL module | ✅ **KEEP** |
| `infra/modules/keyvault/` | `/infra/modules/` | Key Vault module | ✅ **KEEP** |
| `Deploy-SAIF-PostgreSQL.ps1` | `/scripts/` | **PRIMARY DEPLOYMENT SCRIPT** | ✅ **KEEP** |
| `Quick-Deploy-SAIF.ps1` | `/scripts/` | Simplified deployment wrapper | ✅ **KEEP** |

### **🌐 SAIF Web Application (REQUIRED FOR DEMOS)**
| File/Folder | Location | Purpose | Keep? |
|------------|----------|---------|-------|
| `web/` | `/` | PHP web frontend - **REQUIRED FOR DEMOS** | ✅ **KEEP** |
| `api/` | `/` | Python Flask API - **REQUIRED FOR DEMOS** | ✅ **KEEP** |
| `docker-compose.yml` | `/` | Local Docker setup for SAIF app testing | ✅ **KEEP** |
| `Rebuild-SAIF-Containers.ps1` | `/scripts/` | Container rebuild/redeploy for SAIF app | ✅ **KEEP** |
| `Test-SAIFLocal.ps1` | `/scripts/` | Local SAIF app testing utility | ✅ **KEEP** |
| `Build-SAIF-Containers.ps1` | `/scripts/utils/` | SAIF container build utility | ✅ **KEEP** |

### **💾 Database Setup**
| File/Folder | Location | Purpose | Keep? |
|------------|----------|---------|-------|
| `database/init-db.sql` | `/database/` | Database schema initialization | ✅ **KEEP** |
| `database/enable-uuid.sql` | `/database/` | UUID extension setup | ✅ **KEEP** |
| `database/cleanup-db.sql` | `/database/` | Database cleanup utility | ✅ **KEEP** |
| `database/README.md` | `/database/` | Database documentation | ✅ **KEEP** |
| `Initialize-Database.ps1` | `/scripts/` | **DATABASE INITIALIZATION SCRIPT** | ✅ **KEEP** |

### **🧪 Load Testing**
| File/Folder | Location | Purpose | Keep? |
|------------|----------|---------|-------|
| `LoadGenerator.csx` | `/scripts/` | **PRIMARY LOAD GENERATOR** (production-ready) | ✅ **KEEP** |
| `Deploy-LoadGenerator-ACI.ps1` | `/scripts/` | **LOAD TEST DEPLOYMENT SCRIPT** | ✅ **KEEP** |
| `Monitor-LoadGenerator-Resilient.ps1` | `/scripts/` | **LOAD TEST MONITORING** | ✅ **KEEP** |
| `Monitor-PostgreSQL-Realtime.ps1` | `/scripts/` | Real-time metrics monitor | ✅ **KEEP** |
| `docs/guides/LOAD-TEST-QUICK-REF.md` | `/docs/guides/` | **LOAD TEST QUICKSTART** | ✅ **KEEP** |

### **🔄 Failover Testing**
| File/Folder | Location | Purpose | Keep? |
|------------|----------|---------|-------|
| `Test-PostgreSQL-Failover.ps1` | `/scripts/` | **PRIMARY FAILOVER TEST SCRIPT** | ✅ **KEEP** |
| `Measure-Connection-RTO.ps1` | `/scripts/` | **RTO MEASUREMENT SCRIPT** | ✅ **KEEP** |
| `Monitor-Failover-Azure.ps1` | `/scripts/` | Failover monitoring (Azure Monitor API) | ✅ **KEEP** |
| `CONNECTION-RTO-GUIDE.md` | `/scripts/` | RTO measurement guide | ✅ **KEEP** |
| `MONITOR-FAILOVER-GUIDE.md` | `/scripts/` | Failover monitoring guide | ✅ **KEEP** |

### **📊 Monitoring & Validation**
| File/Folder | Location | Purpose | Keep? |
|------------|----------|---------|-------|
| `azure-workbooks/PostgreSQL-HA-Performance-Workbook.json` | `/azure-workbooks/` | **AZURE WORKBOOK (REQUESTED TO KEEP)** | ✅ **KEEP** |
| `azure-workbooks/IMPORT-GUIDE.md` | `/azure-workbooks/` | Workbook import instructions | ✅ **KEEP** |
| `Monitor-PostgreSQL-HA.ps1` | `/scripts/` | PostgreSQL HA monitoring script | ✅ **KEEP** |
| `Check-WAL-Settings.ps1` | `/scripts/` | WAL configuration validator | ✅ **KEEP** |

### **📖 Core Documentation**
| File/Folder | Location | Purpose | Keep? |
|------------|----------|---------|-------|
| `README.md` | `/` | **PRIMARY README** | ✅ **KEEP** |
| `docs/v1.0.0/deployment-guide.md` | `/docs/v1.0.0/` | Deployment guide | ✅ **KEEP** |
| `docs/v1.0.0/failover-testing-guide.md` | `/docs/v1.0.0/` | Failover testing guide | ✅ **KEEP** |
| `docs/v1.0.0/quick-reference.md` | `/docs/v1.0.0/` | Quick reference | ✅ **KEEP** |
| `docs/v1.0.0/architecture.md` | `/docs/v1.0.0/` | Architecture documentation | ✅ **KEEP** |
| `docs/v1.0.0/checklist.md` | `/docs/v1.0.0/` | Workshop checklist | ✅ **KEEP** |
| `docs/v1.0.0/index.md` | `/docs/v1.0.0/` | Documentation index | ✅ **KEEP** |
| `docs/guides/LOAD-TEST-QUICK-REF.md` | `/docs/guides/` | Load test quick reference | ✅ **KEEP** |
| `docs/guides/BUILD-CONTAINERS-GUIDE.md` | `/docs/guides/` | SAIF container build guide | ✅ **KEEP** |
| `docs/guides/BUILD-CONTAINERS-QUICK-REF.md` | `/docs/guides/` | SAIF container quick ref | ✅ **KEEP** |
| `docs/guides/container-initialization-guide.md` | `/docs/guides/` | SAIF container initialization | ✅ **KEEP** |
| `docs/guides/README.md` | `/docs/guides/` | Guides index | ✅ **KEEP** |
| `docs/README.md` | `/docs/` | Documentation index | ✅ **KEEP** |
| `docs/TROUBLESHOOTING.md` | `/docs/` | Troubleshooting guide | ✅ **KEEP** |
| `CHANGELOG.md` | `/` | Version history | ✅ **KEEP** |
| `LICENSE` | `/` | MIT License | ✅ **KEEP** |
| `SECURITY.md` | `/` | Security policy | ✅ **KEEP** |
| `CODE_OF_CONDUCT.md` | `/` | Community guidelines | ✅ **KEEP** |

---

## 📦 Files to Archive

These files are not essential for the core workflow and should be moved to an archive folder.

### **🌐 SAIF Web Application - STATUS: KEEP (REQUIRED FOR DEMOS)**
**No files to archive from this category** - All SAIF web/API components are required for demonstration purposes and will remain in their current locations.

### **🗄️ Duplicate/Outdated Scripts**
| File/Folder | Location | Reason | Archive To |
|------------|----------|---------|------------|
| `Test-PostgreSQL-Failover.csx` | `/scripts/` | C# version of failover test (PowerShell version is current) | `/archive/experimental/Test-PostgreSQL-Failover.csx` |
| `Test-LoadGenerator-Local.ps1` | `/scripts/` | Local testing utility (development artifact) | `/archive/development/Test-LoadGenerator-Local.ps1` |
| `Update-LoadTestFunction.ps1` | `/scripts/` | Old Azure Functions approach (replaced by ACI) | `/archive/deprecated-approaches/Update-LoadTestFunction.ps1` |
| `Monitor-LoadTest.ps1` | `/scripts/` | Old monitor script (replaced by Monitor-LoadGenerator-Resilient.ps1) | `/archive/deprecated-approaches/Monitor-LoadTest.ps1` |

### **📄 Duplicate Dashboard/Query Files (ROOT LEVEL)**
| File/Folder | Location | Reason | Archive To |
|------------|----------|---------|------------|
| `LoadGenerator.csx` | `/` (root) | Duplicate of `/scripts/LoadGenerator.csx` | `/archive/duplicates/LoadGenerator.csx` |
| `postgresql-dashboard-20251010-203953.json` | `/` | Generated file (older version) | `/archive/generated-outputs/postgresql-dashboard-20251010-203953.json` |
| `postgresql-dashboard-20251010-204421.json` | `/` | Generated file (newer version) | `/archive/generated-outputs/postgresql-dashboard-20251010-204421.json` |
| `postgresql-monitoring-queries-20251010-203953.kql` | `/` | Generated file (older version) | `/archive/generated-outputs/postgresql-monitoring-queries-20251010-203953.kql` |
| `postgresql-monitoring-queries-20251010-204421.kql` | `/` | Generated file (newer version) | `/archive/generated-outputs/postgresql-monitoring-queries-20251010-204421.kql` |
| `loadtest_logs_20251010_195042.txt` | `/` | Test log file | `/archive/test-runs/loadtest_logs_20251010_195042.txt` |
| `loadtest_logs_20251010_203045.txt` | `/` | Test log file | `/archive/test-runs/loadtest_logs_20251010_203045.txt` |
| `Create-PostgreSQL-Dashboard.ps1` | `/scripts/` | Dashboard automation (workbook is preferred) | `/archive/tools/Create-PostgreSQL-Dashboard.ps1` |

**Rationale:** Azure Workbook is the preferred monitoring solution. Generated dashboards and logs are test artifacts.

### **📚 Documentation Artifacts**
| File/Folder | Location | Reason | Archive To |
|------------|----------|---------|------------|
| `docs/architecture/ACR-BUILD-UNICODE-FIX.md` | `/docs/architecture/` | Development diary | `/archive/documentation/ACR-BUILD-UNICODE-FIX.md` |
| `docs/architecture/BUILD-AUTOMATION-SUMMARY.md` | `/docs/architecture/` | Development diary | `/archive/documentation/BUILD-AUTOMATION-SUMMARY.md` |
| `docs/guides/BUILD-CONTAINERS-GUIDE.md` | `/docs/guides/` | **KEEP** - SAIF container build guide (needed for demos) | ✅ **KEEP** |
| `docs/guides/BUILD-CONTAINERS-QUICK-REF.md` | `/docs/guides/` | **KEEP** - SAIF container quick ref (needed for demos) | ✅ **KEEP** |
| `docs/guides/CONSOLIDATION-SUMMARY.md` | `/docs/guides/` | Development diary | `/archive/documentation/CONSOLIDATION-SUMMARY.md` |
| `docs/guides/container-initialization-guide.md` | `/docs/guides/` | **KEEP** - SAIF container guide (needed for demos) | ✅ **KEEP** |
| `docs/v1.0.0/AUTO-REFRESH-FEATURE.md` | `/docs/v1.0.0/` | Development diary | `/archive/documentation/AUTO-REFRESH-FEATURE.md` |
| `docs/v1.0.0/DIAGNOSTIC-IMPLEMENTATION.md` | `/docs/v1.0.0/` | Development diary | `/archive/documentation/DIAGNOSTIC-IMPLEMENTATION.md` |
| `docs/v1.0.0/MISSING-IMAGES-FIX.md` | `/docs/v1.0.0/` | Development diary | `/archive/documentation/MISSING-IMAGES-FIX.md` |
| `docs/v1.0.0/MONITOR-SCRIPT-BUGFIX.md` | `/docs/v1.0.0/` | Development diary | `/archive/documentation/MONITOR-SCRIPT-BUGFIX.md` |
| `docs/v1.0.0/MONITOR-SCRIPT-UPDATE.md` | `/docs/v1.0.0/` | Development diary | `/archive/documentation/MONITOR-SCRIPT-UPDATE.md` |
| `docs/v1.0.0/implementation-summary.md` | `/docs/v1.0.0/` | Development diary | `/archive/documentation/implementation-summary.md` |
| `docs/DASHBOARD-QUICK-SETUP.md` | `/docs/` | Manual dashboard setup (workbook preferred) | `/archive/documentation/DASHBOARD-QUICK-SETUP.md` |
| `docs/MONITORING-SETUP-COMPLETE.md` | `/docs/` | Monitoring status doc (one-time) | `/archive/documentation/MONITORING-SETUP-COMPLETE.md` |
| `docs/DOCUMENTATION-UPDATES.md` | `/docs/` | Development diary | `/archive/documentation/DOCUMENTATION-UPDATES.md` |
| `scripts/BUGFIX-SUMMARY.md` | `/scripts/` | Development diary | `/archive/documentation/BUGFIX-SUMMARY.md` |
| `scripts/CLOUD-SHELL-GUIDE.md` | `/scripts/` | Cloud Shell setup guide (niche use case) | `/archive/documentation/CLOUD-SHELL-GUIDE.md` |
| `scripts/CLOUD-SHELL-TESTING.md` | `/scripts/` | Cloud Shell testing notes | `/archive/documentation/CLOUD-SHELL-TESTING.md` |
| `scripts/PERFORMANCE-VALIDATION.md` | `/scripts/` | Performance testing notes | `/archive/documentation/PERFORMANCE-VALIDATION.md` |
| `scripts/QUICKFIX.md` | `/scripts/` | Development notes | `/archive/documentation/QUICKFIX.md` |
| `scripts/CONNECTION-RTO-TROUBLESHOOTING.md` | `/scripts/` | Troubleshooting notes (merge into main troubleshooting?) | `/archive/documentation/CONNECTION-RTO-TROUBLESHOOTING.md` |

**Rationale:** Development diaries and build notes are historical artifacts. Users need operational guides, not development journals.

### **🧰 Utility Scripts (Limited Use)**
| File/Folder | Location | Reason | Archive To |
|------------|----------|---------|------------|
| `setup-cloudshell.ps1` | `/scripts/` | Cloud Shell setup (niche use case) | `/archive/utilities/setup-cloudshell.ps1` |
| `setup-cloudshell.sh` | `/scripts/` | Cloud Shell setup (niche use case) | `/archive/utilities/setup-cloudshell.sh` |
| `fix-indentation.ps1` | `/scripts/` | Development utility | `/archive/utilities/fix-indentation.ps1` |
| `fix-indentation.py` | `/scripts/` | Development utility | `/archive/utilities/fix-indentation.py` |
| `Diagnose-Failover-Performance.ps1` | `/scripts/utils/` | Diagnostic utility (specialized) | `/archive/utilities/Diagnose-Failover-Performance.ps1` |

### **🔬 Test Files (Development Artifacts)**
| File/Folder | Location | Reason | Archive To |
|------------|----------|---------|------------|
| `scripts/tests/failover_load_test.py` | `/scripts/tests/` | Python load test (replaced by C# LoadGenerator) | `/archive/test-scripts/failover_load_test.py` |
| `scripts/tests/failover_test_results_20251007_205649.csv` | `/scripts/tests/` | Test results | `/archive/test-runs/failover_test_results_20251007_205649.csv` |
| `scripts/tests/failover_test_results_20251007_205813.csv` | `/scripts/tests/` | Test results | `/archive/test-runs/failover_test_results_20251007_205813.csv` |
| `scripts/tests/run_failover_test.bat` | `/scripts/tests/` | Python test runner | `/archive/test-scripts/run_failover_test.bat` |
| `scripts/tests/run_failover_test.ps1` | `/scripts/tests/` | Python test runner | `/archive/test-scripts/run_failover_test.ps1` |

### **📦 DLL Files (Not Needed in Repo)**
| File/Folder | Location | Reason | Archive To |
|------------|----------|---------|------------|
| `scripts/libs/Microsoft.Extensions.Logging.Abstractions.dll` | `/scripts/libs/` | DLL files (NuGet downloads at runtime) | `/archive/libs/Microsoft.Extensions.Logging.Abstractions.dll` |
| `scripts/libs/Npgsql.dll` | `/scripts/libs/` | DLL files (NuGet downloads at runtime) | `/archive/libs/Npgsql.dll` |

**Rationale:** `LoadGenerator.csx` uses `#r "nuget:..."` directives, so DLLs are downloaded automatically. No need to commit them.

### **🗑️ Maintenance Files**
| File/Folder | Location | Reason | Archive To |
|------------|----------|---------|------------|
| `push-to-github.ps1` | `/` | Personal Git utility | `/archive/maintenance/push-to-github.ps1` |
| `GITHUB-RELEASE-CHECKLIST.md` | `/` | Release management | `/archive/maintenance/GITHUB-RELEASE-CHECKLIST.md` |

---

## 📁 Proposed New Structure

```
azure-postgresql-ha-workshop/
│
├── 📁 infra/                          # Infrastructure as Code
│   ├── main.bicep                     # ✅ PRIMARY IaC FILE
│   ├── main.json                      # ✅ ARM template
│   ├── main.parameters.json           # ✅ Deployment parameters
│   └── modules/                       # ✅ Bicep modules
│       ├── database/
│       └── keyvault/
│
├── 📁 database/                       # Database setup
│   ├── init-db.sql                    # ✅ Schema initialization
│   ├── enable-uuid.sql                # ✅ UUID extension
│   ├── cleanup-db.sql                 # ✅ Cleanup utility
│   └── README.md                      # ✅ Database docs
│
├── 📁 web/                            # SAIF Web Application (required for demos)
│   ├── index.php                      # ✅ PHP frontend
│   ├── Dockerfile                     # ✅ Web container build
│   ├── apache-config.conf             # ✅ Apache configuration
│   └── assets/                        # ✅ CSS, JS, images
│
├── 📁 api/                            # SAIF API Application (required for demos)
│   ├── app.py                         # ✅ Flask API
│   ├── Dockerfile                     # ✅ API container build
│   ├── requirements.txt               # ✅ Python dependencies
│   └── README.md                      # ✅ API documentation
│
├── 📄 docker-compose.yml              # ✅ Local SAIF testing (required for demos)
│
├── 📁 scripts/                        # Operational scripts
│   ├── 🚀 Deploy-SAIF-PostgreSQL.ps1  # ✅ PRIMARY DEPLOYMENT
│   ├── 🚀 Quick-Deploy-SAIF.ps1       # ✅ SIMPLIFIED DEPLOYMENT
│   ├── 🌐 Rebuild-SAIF-Containers.ps1 # ✅ SAIF APP REDEPLOY (required for demos)
│   ├── 🌐 Test-SAIFLocal.ps1          # ✅ SAIF LOCAL TESTING (required for demos)
│   ├── 💾 Initialize-Database.ps1     # ✅ DB INITIALIZATION
│   ├── 🧪 LoadGenerator.csx            # ✅ LOAD GENERATOR
│   ├── 🧪 Deploy-LoadGenerator-ACI.ps1 # ✅ LOAD TEST DEPLOY
│   ├── 📊 Monitor-LoadGenerator-Resilient.ps1  # ✅ LOAD TEST MONITOR
│   ├── 📊 Monitor-PostgreSQL-Realtime.ps1      # ✅ REAL-TIME METRICS
│   ├── 📊 Monitor-PostgreSQL-HA.ps1            # ✅ HA MONITOR
│   ├── 🔄 Test-PostgreSQL-Failover.ps1         # ✅ FAILOVER TEST
│   ├── 🔄 Measure-Connection-RTO.ps1           # ✅ RTO MEASUREMENT
│   ├── 🔄 Monitor-Failover-Azure.ps1           # ✅ FAILOVER MONITOR
│   ├── ✅ Check-WAL-Settings.ps1               # ✅ WAL VALIDATOR
│   ├── 📖 CONNECTION-RTO-GUIDE.md              # ✅ RTO GUIDE
│   ├── 📖 MONITOR-FAILOVER-GUIDE.md            # ✅ FAILOVER GUIDE
│   ├── 📖 README.md                            # ✅ SCRIPTS DOCS
│   ├── utils/                          # ✅ UTILITY SCRIPTS
│   │   └── Build-SAIF-Containers.ps1  # ✅ SAIF BUILD (required for demos)
│   └── archive/                       # ✅ ALREADY ARCHIVED SCRIPTS
│
├── 📁 azure-workbooks/                # Azure Portal monitoring
│   ├── PostgreSQL-HA-Performance-Workbook.json  # ✅ AZURE WORKBOOK
│   └── IMPORT-GUIDE.md                          # ✅ IMPORT INSTRUCTIONS
│
├── 📁 docs/                           # Documentation
│   ├── v1.0.0/                        # ✅ VERSION DOCS
│   │   ├── deployment-guide.md        # ✅ DEPLOYMENT GUIDE
│   │   ├── failover-testing-guide.md  # ✅ FAILOVER GUIDE
│   │   ├── quick-reference.md         # ✅ QUICK REFERENCE
│   │   ├── architecture.md            # ✅ ARCHITECTURE
│   │   ├── checklist.md               # ✅ CHECKLIST
│   │   ├── index.md                   # ✅ INDEX
│   │   └── CHANGELOG.md               # ✅ VERSION CHANGELOG
│   ├── guides/                        # ✅ OPERATIONAL GUIDES
│   │   ├── LOAD-TEST-QUICK-REF.md     # ✅ LOAD TEST QUICKSTART
│   │   └── README.md                  # ✅ GUIDES INDEX
│   ├── README.md                      # ✅ DOCS INDEX
│   └── TROUBLESHOOTING.md             # ✅ TROUBLESHOOTING
│
├── 📁 archive/                        # 🗄️ ARCHIVED FILES (NEW)
│   ├── deprecated-saif-app/           # Web/API app components
│   ├── deprecated-approaches/         # Old load test methods
│   ├── experimental/                  # Experimental scripts
│   ├── development/                   # Development utilities
│   ├── duplicates/                    # Duplicate files
│   ├── generated-outputs/             # Generated dashboards/queries
│   ├── test-runs/                     # Test logs and results
│   ├── test-scripts/                  # Old test scripts
│   ├── documentation/                 # Development diaries
│   ├── utilities/                     # Niche utility scripts
│   ├── libs/                          # DLL files
│   └── maintenance/                   # Maintenance scripts
│
├── 📄 README.md                       # ✅ PRIMARY README (UPDATE NEEDED)
├── 📄 CHANGELOG.md                    # ✅ VERSION HISTORY
├── 📄 LICENSE                         # ✅ MIT LICENSE
├── 📄 SECURITY.md                     # ✅ SECURITY POLICY
├── 📄 CODE_OF_CONDUCT.md              # ✅ COMMUNITY GUIDELINES
└── 📄 .gitignore                      # ✅ GIT IGNORE RULES
```

---

## 🎯 Supported Workflows After Reorganization

### **Workflow A: SAIF Demo (Security Vulnerabilities)**

**1. Deploy Infrastructure**
```powershell
.\scripts\Deploy-SAIF-PostgreSQL.ps1 -location "swedencentral"
```

**2. Build & Deploy SAIF Containers**
```powershell
.\scripts\Rebuild-SAIF-Containers.ps1 -resourceGroupName "rg-saif-pgsql-swc-01"
```

**3. Test Locally (Optional)**
```powershell
docker-compose up
.\scripts\Test-SAIFLocal.ps1
```

**4. Access SAIF Web App**
- Navigate to App Service URL
- Demonstrate SQL injection, XSS, and other vulnerabilities
- See: Security guides in documentation

---

### **Workflow B: High-Performance Load Testing**

**1. Deploy Infrastructure + Database**
```powershell
.\scripts\Quick-Deploy-SAIF.ps1 -environmentName "prod"
```

**2. Initialize Database**
```powershell
.\scripts\Initialize-Database.ps1 `
  -ResourceGroup "rg-saif-pgsql-swc-01" `
  -PostgreSQLServer "psql-saifpg-XXXXXXXX" `
  -DatabaseName "saifdb" `
  -AdminUsername "saifadmin"
```

**3. Load Test (8000+ TPS)**
```powershell
# See: docs/guides/LOAD-TEST-QUICK-REF.md
.\scripts\Deploy-LoadGenerator-ACI.ps1 -Action Deploy ...
.\scripts\Monitor-LoadGenerator-Resilient.ps1 ...
```

**4. Failover Test + Measure RTO**
```powershell
# See: scripts/CONNECTION-RTO-GUIDE.md
.\scripts\Measure-Connection-RTO.ps1 `
  -ResourceGroup "rg-saif-pgsql-swc-01" `
  -PostgreSQLServer "psql-saifpg-XXXXXXXX" `
  -DatabaseName "saifdb" `
  -AdminUser "saifadmin"
```

**5. Monitor Performance**
- **Azure Workbook:** Import `azure-workbooks/PostgreSQL-HA-Performance-Workbook.json` (see `IMPORT-GUIDE.md`)
- **Real-time Terminal:** `.\scripts\Monitor-PostgreSQL-Realtime.ps1`
- **HA Status:** `.\scripts\Monitor-PostgreSQL-HA.ps1`

---

## 📝 README.md Update Status

**NO MAJOR CHANGES REQUIRED** - The README correctly describes both use cases:

1. **SAIF Web/API Application** - Vulnerable payment gateway for security demos ✅ KEEP
2. **High-Performance Load Testing** - LoadGenerator.csx for 8K+ TPS testing ✅ KEEP
3. **PostgreSQL HA Testing** - Failover and RTO/RPO measurement ✅ KEEP
4. **Azure Workbook Monitoring** - Performance visualization ✅ KEEP

### Minor Updates Needed:
- ✏️ Add reference to new `docs/guides/LOAD-TEST-QUICK-REF.md`
- ✏️ Update architecture diagram to show both SAIF app AND LoadGenerator paths
- ✏️ Clarify two deployment modes: SAIF demo vs Load testing
- ✏️ Keep all existing content (web app, security vulnerabilities, cost estimation)

---

## 🚀 Benefits of Reorganization

### **Before (Current State):**
- ❌ 60+ files in root and scripts folders
- ❌ Duplicate files (`LoadGenerator.csx` in 2 places)
- ❌ Generated outputs mixed with source files
- ❌ Development diaries scattered across docs folders
- ❌ Unclear what's needed vs historical artifacts
- ❌ Test logs and generated dashboards cluttering root folder

### **After (Proposed State):**
- ✅ **~35 core operational files** clearly identified (including SAIF app)
- ✅ **No duplicates** - single source of truth for LoadGenerator.csx
- ✅ **Clean workspace** - only essential files visible in root
- ✅ **Two clear workflows supported:**
  - **SAIF Demo:** Deploy → Build Containers → Test Vulnerabilities
  - **Load Testing:** Deploy → Initialize DB → Load Test → Failover → Measure RTO/RPO
- ✅ **Historical artifacts preserved** in `/archive/` (not deleted)
- ✅ **Faster onboarding** - less confusion for new users
- ✅ **Better maintainability** - easier to update core scripts
- ✅ **SAIF app fully functional** - all demo capabilities preserved

---

## ⚠️ Migration Strategy

### **Phase 1: Archive (Manual Approval Required)**
1. Create `/archive/` folder structure
2. Move files per the plan above
3. Test core workflow still works
4. Update internal references (if any)

### **Phase 2: Documentation Update**
1. Update `README.md` (remove SAIF app focus)
2. Update `docs/v1.0.0/deployment-guide.md` (streamline)
3. Update `scripts/README.md` (remove archived scripts)
4. Add `archive/README.md` explaining archive contents

### **Phase 3: Validation**
1. Run full workflow: deploy → init → load → failover → measure
2. Verify all core scripts execute successfully
3. Verify Azure Workbook imports correctly
4. Verify documentation links still work

### **Phase 4: Commit & Tag**
1. Commit reorganization with detailed message
2. Tag as `v2.0.0-reorganized`
3. Update CHANGELOG.md

---

## 🔍 Files Requiring Path Updates

These files may reference archived scripts and need review:

| File | Potential References |
|------|---------------------|
| `README.md` | References to SAIF app, container builds |
| `docs/v1.0.0/deployment-guide.md` | References to Rebuild-SAIF-Containers.ps1 |
| `scripts/README.md` | References to archived scripts |
| `scripts/Deploy-SAIF-PostgreSQL.ps1` | May reference SAIF container builds |
| `scripts/Quick-Deploy-SAIF.ps1` | May reference SAIF container builds |

**Action:** Search for references to archived files and update or remove.

---

## 📊 Archive Statistics

| Category | Files to Archive | Total Size |
|----------|-----------------|------------|
| ~~SAIF Web App~~ | ~~6 folders/files~~ | **✅ KEEPING** (Required for demos) |
| Duplicate/Outdated Scripts | 4 files | ~50 KB |
| Generated Outputs (root) | 7 files | ~200 KB |
| Documentation Artifacts | 14 files (3 SAIF docs kept) | ~120 KB |
| Utility Scripts | 5 files | ~40 KB |
| Test Files | 5 files | ~100 KB |
| DLL Files | 2 files | ~2 MB |
| Maintenance Files | 2 files | ~10 KB |
| **TOTAL** | **~39 items** | **~2.5 MB** |

**Core operational files remaining:** ~35 files (~1.5 MB including SAIF app)

---

## ✅ Approval Checklist

Before proceeding with archiving:

- [ ] Review proposed archive list (above)
- [x] ✅ **CONFIRMED:** Azure Workbook should be kept (explicitly requested)
- [x] ✅ **CONFIRMED:** SAIF web/API app MUST BE KEPT (required for demos)
- [x] ✅ **CONFIRMED:** LoadGenerator.csx is the primary load test tool (production-ready at 12K+ TPS)
- [x] ✅ **CONFIRMED:** SAIF container build guides MUST BE KEPT (needed for redeployment)
- [ ] Confirm workflow is correct: Deploy → Validate → Load → Failover → Measure
- [ ] Verify no critical files are being archived
- [ ] Approve creation of `/archive/` folder structure

---

## 🎬 Next Steps

**Awaiting your approval to:**
1. ✋ Review this plan
2. ✋ Confirm files to archive
3. ✋ Approve archive structure
4. ✋ Proceed with Phase 1 (archiving)

**After approval, I will:**
1. ✅ Create `/archive/` folder structure
2. ✅ Move files systematically
3. ✅ Update documentation references
4. ✅ Test core workflow
5. ✅ Provide summary report

---

**Questions? Concerns? Modifications?**  
Please review each section and let me know if any files should be kept that I've marked for archiving, or if any "KEEP" files should actually be archived.
