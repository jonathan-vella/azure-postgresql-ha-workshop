
# Azure PostgreSQL High Availability Workshop

**Last Updated:** 2025-10-16

> **⚠️ SECURITY NOTICE**: This repository contains intentional security vulnerabilities for training purposes. DO NOT use in production!

[![Documentation Version](https://img.shields.io/badge/docs-v1.1.0-blue.svg)](docs/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-blue.svg)](https://www.postgresql.org/)
[![Azure](https://img.shields.io/badge/Azure-Zone--Redundant%20HA-0089D6.svg)](https://azure.microsoft.com/en-us/products/postgresql/)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

## 🎯 Purpose

Hands-on workshop for learning **Azure PostgreSQL Flexible Server Zone-Redundant High Availability**, failover testing, and database security concepts. Supports two workflows:

1. **SAIF Security Demo** - Vulnerable payment gateway application for security training
2. **High-Performance Load Testing** - 8000+ TPS PostgreSQL HA testing and validation

## 📚 What You'll Learn

- Deploy Zone-Redundant HA PostgreSQL Flexible Server
- Measure RTO (Recovery Time Objective) and RPO (Recovery Point Objective)
- **High-performance load testing** (8000+ TPS validated, 12,000+ TPS capable)
- Test failover scenarios under sustained load
- Identify and fix common security vulnerabilities
- Implement secure database patterns
- Performance monitoring with Azure Workbooks

## 💰 Estimated Costs

**Default Configuration** (as deployed):

| Resource | Configuration | Estimated Cost/Hour | Monthly (730 hrs) |
|----------|--------------|---------------------|-------------------|
| PostgreSQL Flexible Server | Standard_D4ds_v5 (4 vCores, 16 GB RAM) | ~$0.28/hr | ~$205 |
| PostgreSQL Zone-Redundant HA | Standby replica (same SKU) | ~$0.28/hr | ~$205 |
| PostgreSQL Storage | 128 GB Premium SSD | ~$0.05/hr | ~$40 |
| App Service Plan | P1v3 (2 vCPU, 8 GB RAM, Linux) | ~$0.26/hr | ~$190 |
| Container Registry | Standard tier | ~$0.83/day | ~$25 |
| Key Vault | Secrets storage + operations | ~$0.03/day | ~$1 |
| Application Insights | Basic ingestion (Pay-as-you-go) | Variable | ~$10 |
| **Total** | **Zone-Redundant HA Setup** | **~$0.90/hr** | **~$675/month** |

💡 **Workshop duration: 2-4 hours** = **~$3.60 total cost**

**High-Performance Configuration** (for 8K+ TPS testing):

| Resource | Configuration | Estimated Cost/Hour | Monthly (730 hrs) |
|----------|--------------|---------------------|-------------------|
| PostgreSQL Flexible Server | Standard_D16ds_v5 (16 vCores, 64 GB RAM) | ~$1.15/hr | ~$840 |
| PostgreSQL Zone-Redundant HA | Standby replica (same SKU) | ~$1.15/hr | ~$840 |
| PostgreSQL Storage | 8 TB (P60 - 16K IOPS, 500 MB/s) | ~$1.10/hr | ~$800 |
| App Service Plan | P1v3 (2 vCPU, 8 GB RAM, Linux) | ~$0.26/hr | ~$190 |
| Load Testing (ACI) | 16 vCPU, 32 GB RAM (transient) | ~$0.80/hr | **$0** (test only) |
| Supporting services | ACR, Key Vault, Insights | ~$0.04/hr | ~$35 |
| **Total** | **High-Performance Setup** | **~$3.70/hr** | **~$2,705/month** |

💡 **8K TPS Load Test duration: 5-10 minutes** = **~$0.62 test cost**

> 💸 **Cost Optimization Tips**:
> - **Development/Testing**: Use `-disableHighAvailability` flag to reduce costs by ~50% (single-zone deployment)
> - **Stop/Start**: Stop PostgreSQL server when not in use (stops compute costs, only pay for storage)
> - **Reserved Capacity**: Save up to 60% with 3-year reserved pricing for production workloads
> - **Burstable Tier**: Use Standard_B2s (~$0.05/hr) for non-production workloads
> - **Load Testing**: ACI is pay-per-second, delete after test completion to avoid charges

## 🏗️ Architecture

This workshop uses **Azure Database for PostgreSQL Flexible Server** with **Zone-Redundant High Availability** to achieve:

- **RPO = 0** (Zero data loss)
- **RTO = 60-120 seconds** (Automatic failover)
- **SLA = 99.99%** (Zone-redundant deployment)

> 📚 **Documentation**: This README provides a quick overview. For comprehensive documentation, see the [docs/](docs/) directory.

## Architecture

```mermaid
graph TB
  subgraph Azure["☁️ Azure Cloud - Sweden Central"]
    subgraph Zone1["🔵 Availability Zone 1"]
      Web["🌐 Web App Service<br/>(PHP/Apache)<br/>Port 80<br/>(Zonal)"]
      API["⚡ API App Service<br/>(FastAPI)<br/>Port 8000<br/>(Zonal)"]
      PrimaryDB["🗄️ PostgreSQL Primary<br/>Standard_D4ds_v5<br/>Port 5432<br/>128GB Premium SSD"]
      Monitor["📊 Application Insights<br/>& Log Analytics"]
    end
        
    subgraph Zone2["🔷 Availability Zone 2"]
      StandbyDB["🗄️ PostgreSQL Standby<br/>Hot Standby (Read Replica)<br/>Synchronous Replication"]
    end
        
    subgraph Support["🛠️ Supporting Services"]
      KeyVault["🔐 Azure Key Vault<br/>(Secrets & Creds)"]
      ACR["📦 Azure Container Registry<br/>(Docker Images)"]
      Backup["💾 Azure Backup<br/>(7-day retention)"]
    end
        
    LoadGen["🔄 Load Generator<br/>(Optional - ACI)<br/>12,600+ TPS Capacity"]
  end
    
  Users["👥 End Users<br/>(Web Browsers)"]
    
  Users -->|"HTTPS (443)"| Web
  Web -->|"HTTP (8000)"| API
  API -->|"PostgreSQL (5432)"| PrimaryDB
  LoadGen -.->|"Load Testing"| API
    
  PrimaryDB ==>|"Synchronous Replication<br/>RPO = 0 (Zero Data Loss)"| StandbyDB
  PrimaryDB -->|"Telemetry"| Monitor
  API -->|"Telemetry"| Monitor
  Web -->|"Telemetry"| Monitor
    
  StandbyDB -.->|"Automatic Failover<br/>RTO: 60-120s"| PrimaryDB
    
  PrimaryDB -.->|"Get Secrets"| KeyVault
  API -.->|"Get Secrets"| KeyVault
  Web -.->|"Pull Images"| ACR
  API -.->|"Pull Images"| ACR
  PrimaryDB -.->|"Automated Backups"| Backup
    
  classDef primary fill:#4A90E2,stroke:#2E5C8A,stroke-width:3px,color:#fff
  classDef standby fill:#87CEEB,stroke:#4A90E2,stroke-width:2px,color:#000
  classDef app fill:#52C41A,stroke:#389E0D,stroke-width:2px,color:#fff
  classDef support fill:#FFA940,stroke:#D46B08,stroke-width:2px,color:#fff
  classDef monitor fill:#722ED1,stroke:#531DAB,stroke-width:2px,color:#fff
  classDef users fill:#F5222D,stroke:#A8071A,stroke-width:2px,color:#fff
  classDef loadgen fill:#FA8C16,stroke:#D46B08,stroke-width:2px,color:#fff
    
  class PrimaryDB primary
  class StandbyDB standby
  class Web,API app
  class KeyVault,ACR,Backup support
  class Monitor monitor
  class Users users
  class LoadGen loadgen
```

**Architecture Highlights:**
- **App Service is Zonal**: Web/API App Service is deployed in a single zone (Zone 1) for lowest latency
- **Zone-Redundant HA for PostgreSQL**: Primary (Zone 1) and Standby (Zone 2) with synchronous replication
- **RPO = 0**: Zero data loss with synchronous commit
- **RTO = 60-120s**: Automatic failover between zones
- **SLA = 99.99%**: Zone-redundant deployment guarantee
- **Shared Services**: ACR, Key Vault, and monitoring are zone-redundant
- **Load Testing**: Optional ACI deployment for 8K-12K TPS validation

## Key Features

### Payment Gateway Components
- **Customers**: Customer account management
- **Merchants**: Merchant/vendor profiles
- **Payment Methods**: Credit cards, bank accounts, digital wallets
- **Transactions**: Payment processing records with full audit trail
- **Orders**: Order tracking and fulfillment

### High Availability Features
- **Zone-Redundant HA**: Primary and standby across availability zones
- **Synchronous Replication**: Zero data loss guarantee
- **Automatic Failover**: 60-120 second RTO
- **Continuous Write Testing**: Validates failover with zero data loss
- **Monitoring Dashboard**: Real-time HA status and metrics

### Educational Vulnerabilities (Intentional)
- ⚠️ SQL Injection in `/api/sqlversion` endpoint
- ⚠️ Command Injection in `/api/curl` endpoint
- ⚠️ Information Disclosure via `/api/printenv`
- ⚠️ Hardcoded API keys
- ⚠️ Permissive CORS policies
- ⚠️ Exposed database connection strings

## 🚀 Quick Start

### Prerequisites
- Azure subscription ([free trial available](https://azure.microsoft.com/free/))
- Azure CLI installed and logged in
- PowerShell 7+ or Azure Cloud Shell
- Docker Desktop (optional, for local testing)

> 📖 For detailed prerequisites and setup instructions, see the [Deployment Guide](docs/deployment-guide.md).

### Deploy (5 minutes)

```powershell
# Clone repository
git clone https://github.com/jonathan-vella/azure-postgresql-ha-workshop.git
cd azure-postgresql-ha-workshop

# Deploy infrastructure
./scripts/Deploy-SAIF-PostgreSQL.ps1 -location swedencentral -autoApprove
```

[Full documentation →](docs/deployment-guide.md)

### Deployment Options

#### Option 1: Quick Deploy (Recommended for Workshop)
```powershell
# Deploy infrastructure
cd infra
az deployment group create \
  --resource-group rg-saif-pgsql-swc-01 \
  --template-file main.bicep \
  --parameters main.parameters.json

# Initialize database
cd ../scripts
.\Initialize-Database.ps1 `
  -serverName "psql-saifpg-XXXXXXXX" `
  -adminPassword "YourSecurePassword"

# Build and deploy containers
az acr build --registry <your-acr> --image saif/api:latest --file api/Dockerfile ./api
az acr build --registry <your-acr> --image saif/web:latest --file web/Dockerfile ./web

# Restart web apps to pull new images
az webapp restart --name app-saifpg-api-XXXXXXXX --resource-group rg-saif-pgsql-swc-01
az webapp restart --name app-saifpg-web-XXXXXXXX --resource-group rg-saif-pgsql-swc-01
```

#### Option 2: Local Development
```powershell
# Start local services
docker-compose up -d

# Initialize database
docker exec -it saif-postgres psql -U saifadmin -d saifdb -f /docker-entrypoint-initdb.d/init-db.sql

# Access application
# Web: http://localhost:8080
# API: http://localhost:8000
```

> 📖 For comprehensive deployment options and troubleshooting, see [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md).

### Database Initialization

The database requires the **uuid-ossp** extension for transaction IDs. On Azure PostgreSQL Flexible Server, this must be explicitly enabled:

```powershell
# Enable uuid-ossp extension
az postgres flexible-server parameter set \
  --resource-group rg-saif-pgsql-swc-01 \
  --server-name psql-saifpg-XXXXXXXX \
  --name azure.extensions \
  --value "UUID-OSSP"

# Run initialization script
cd scripts
.\Initialize-Database.ps1 `
  -serverName "psql-saifpg-XXXXXXXX.postgres.database.azure.com" `
  -adminPassword "YourPassword"
```

> 📖 For detailed database initialization procedures, see [Container Initialization Guide](docs/guides/container-initialization-guide.md).

## Database Schema

### Payment Gateway Schema
```sql
-- Customers
CREATE TABLE customers (
    customer_id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    phone VARCHAR(20),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Merchants
CREATE TABLE merchants (
    merchant_id SERIAL PRIMARY KEY,
    merchant_name VARCHAR(255) NOT NULL,
    merchant_code VARCHAR(50) UNIQUE NOT NULL,
    api_key VARCHAR(255),
    status VARCHAR(20) DEFAULT 'active'
);

-- Transactions
CREATE TABLE transactions (
    transaction_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id INTEGER REFERENCES customers(customer_id),
    merchant_id INTEGER REFERENCES merchants(merchant_id),
    amount DECIMAL(10,2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'USD',
    status VARCHAR(20),
    transaction_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

## API Endpoints

### Payment Gateway APIs
- `POST /api/payments/process` - Process payment transaction
- `GET /api/payments/{transaction_id}` - Get transaction status
- `GET /api/payments/customer/{customer_id}` - Get customer transactions
- `POST /api/customers/create` - Create customer account

### Diagnostic APIs (Vulnerable by Design)
- `GET /api/healthcheck` - Service health status
- `GET /api/ip` - Server IP information
- `GET /api/sqlversion` - Database version ⚠️ SQL Injection vulnerability
- `GET /api/curl?url=<url>` - Fetch URL ⚠️ SSRF/Command injection
- `GET /api/printenv` - Environment variables ⚠️ Information disclosure

## 📊 Performance Benchmarks

### App Service Load Testing (Current)
- **Validated TPS**: **1,000-2,000+ TPS per instance** (immediate App Insights logging)
- **Scaling**: Supports multiple App Service instances for higher throughput
- **Response Time**: Immediate telemetry (no Log Analytics delays)
- **Infrastructure**: P0v3 App Service Plan (standard) to P1v3 (upgrade for higher TPS)
- **Monitoring**: Real-time HTTP status endpoints + Application Insights dashboard

### Failover Testing Performance (RTO/RPO)
- **Measured RTO**: **16-25 seconds** (Zone-Redundant HA automatic failover)
- **Measured RPO**: **0 transactions** (zero data loss with synchronous replication)
- **Test Method**: App Service load test + manual failover trigger + Measure-Failover-RTO-RPO.ps1
- **Success Rate**: 100% data consistency (all transactions persisted before failover)
- **Monitoring**: Real-time probes (1-second intervals), detailed CSV reports

> 📖 **Quick Start**: See [Load Testing Guide](docs/load-testing-guide.md) for complete deployment and monitoring

### Legacy Benchmarks (ACI - Archived)
- **8000-12,600+ TPS** (Azure Container Instances, archived approach)
- **Succeeded**: October 10, 2025 test with D16ds_v5 + P60 storage
- **Reference**: [Archive benchmarks](archive/) for historical context

### Load Testing & Failover Testing

The workshop includes **two testing approaches**:

#### Option 1: App Service Load Testing ⭐ **RECOMMENDED - IMMEDIATE MONITORING**
```powershell
# Deploy load generator to App Service
cd scripts/loadtesting
.\Deploy-LoadGenerator-AppService.ps1 `
  -Action "Deploy" `
  -ResourceGroup "rg-pgv2-usc01" `
  -AppServiceName "app-loadgen" `
  -PostgreSQLServer "pg-cus.postgres.database.azure.com" `
  -DatabaseName "saifdb" `
  -AdminUsername "jonathan"

# Start load test via HTTP API
$url = "https://app-loadgen.azurewebsites.net/start"
curl -X POST $url | ConvertFrom-Json

# Monitor in real-time
.\Monitor-AppService-Logs.ps1 -ResourceGroup "rg-pgv2-usc01" -AppServiceName "app-loadgen"

# Check status
curl https://app-loadgen.azurewebsites.net/status | ConvertFrom-Json | Format-List
```

**Use Case**: Production-grade load testing with immediate Application Insights monitoring  
**Throughput**: **1,000-2,000+ TPS** per App Service instance (scalable)  
**Features**:
- HTTP API endpoints (`/start`, `/status`, `/health`, `/logs`)
- Real-time Application Insights telemetry (no delays)
- Container-based .NET 8.0 application
- Automatic database transaction logging
- Easy scaling via App Service plan upgrade

> 📖 **Complete Guide**: [Load Testing Guide](docs/load-testing-guide.md) - Comprehensive deployment & monitoring

#### Option 2: RTO/RPO Failover Testing ⭐ **MEASURE RECOVERY METRICS**
```powershell
# Start failover measurement with running load test
cd scripts/loadtesting
.\Measure-Failover-RTO-RPO.ps1 `
  -AppServiceUrl "https://app-loadgen-6wuso.azurewebsites.net" `
  -ResourceGroup "rg-pgv2-usc01" `
  -ServerName "pg-cus" `
  -DatabaseName "saifdb" `
  -AdminUsername "jonathan" `
  -MaxMonitoringSeconds 90

# Then trigger manual failover in Azure Portal:
# 1. PostgreSQL Flexible Server > High Availability blade
# 2. Click "Forced failover"
# 3. Confirm action
# Script will measure RTO and RPO
```

**Use Case**: Measure recovery time and data loss during failover  
**RTO**: 16-25 seconds (measured in October 2025)  
**RPO**: 0 transactions (zero data loss with synchronous replication)  
**Features**:
- Real-time monitoring during failover
- Connection loss detection (1-second probes)
- Database transaction count verification
- TPS recovery tracking
- CSV report generation with detailed metrics

> 📖 **Complete Guide**: [Failover Testing Guide](docs/failover-testing-guide.md) - RTO/RPO measurement procedures
> 📖 **Cheat Sheet**: [Load Testing Cheat Sheet](docs/load-testing-cheat-sheet.md) - Quick commands reference

## Security Considerations

### Production Hardening (Not Included)
This is an **educational environment** with intentional vulnerabilities. For production:

1. **Remove SQL Injection**: Use parameterized queries everywhere
2. **Implement Input Validation**: Sanitize all user inputs
3. **Secure Environment Variables**: Use Key Vault exclusively
4. **Network Isolation**: Use VNet integration + Private Endpoints
5. **Authentication**: Implement Entra ID authentication
6. **Audit Logging**: Enable PostgreSQL audit extension

## Project Structure

```
azure-postgresql-ha-workshop/
├── 📁 infra/                          # Infrastructure as Code (Bicep templates)
│   ├── main.bicep                     # Main deployment template
│   ├── main.parameters.json           # Deployment parameters
│   └── modules/
│       ├── database/
│       │   └── postgresql.bicep       # PostgreSQL HA module
│       └── keyvault/
│           └── keyvault.bicep         # Key Vault secrets management
│
├── 📁 database/                       # Database initialization scripts
│   ├── init-db.sql                    # Schema creation (customers, merchants, transactions)
│   ├── enable-uuid.sql                # UUID extension setup
│   ├── cleanup-db.sql                 # Database cleanup utilities
│   └── README.md                      # Database documentation
│
├── 📁 web/                            # SAIF PHP Web Application (security demos)
├── 📁 api/                            # SAIF Python FastAPI (security demos)
├── 📄 docker-compose.yml              # Local SAIF development environment
│
├── 📁 scripts/                        # Operational scripts
│   ├── 🚀 Deploy-SAIF-PostgreSQL.ps1  # Full infrastructure deployment
│   ├── 🚀 Quick-Deploy-SAIF.ps1       # Simplified deployment wrapper
│   ├── 🌐 Rebuild-SAIF-Containers.ps1 # SAIF app container rebuild
│   ├── 🌐 Test-SAIFLocal.ps1          # Local SAIF testing
│   ├── 💾 Initialize-Database.ps1     # Database initialization
│   ├── 📖 README.md                    # Scripts documentation
│   │
│   ├── 📁 loadtesting/                # Load testing & failover testing scripts (current)
│   │   ├── 🧪 Program.cs              # .NET 8.0 load generator web app
│   │   ├── 🧪 Dockerfile              # Multi-stage container build
│   │   ├── � Deploy-LoadGenerator-AppService.ps1 # Deploy to App Service
│   │   ├── � Monitor-AppService-Logs.ps1         # Stream container logs
│   │   ├── 🔄 Measure-Failover-RTO-RPO.ps1       # RTO/RPO measurement
│   │   ├── � LoadGenerator-Config.ps1  # Centralized configuration
│   │   ├── 📖 README.md                 # Load testing documentation (v1.0.0)
│   │   └── archive/                     # Archived testing approaches
│   │
│   ├── utils/
│   │   └── Build-SAIF-Containers.ps1   # SAIF container build utility
│   └── archive/                        # Archived scripts (historical)
│
├── 📁 azure-workbooks/                # Azure Portal monitoring
│   ├── PostgreSQL-HA-Performance-Workbook.json # Pre-configured workbook (6 charts)
│   └── IMPORT-GUIDE.md                         # 30-second import guide
│
├── 📁 docs/                           # Documentation (v1.1.0+)
│   ├── architecture.md                # System architecture & design (v2.0.0)
│   ├── CHANGELOG.md                   # Documentation version history (v2.2.0)
│   ├── deployment-guide.md            # Complete deployment guide (v2.1.0)
│   ├── failover-testing-guide.md      # RTO/RPO measurement procedures (v1.0.0)
│   ├── load-testing-guide.md          # App Service load testing guide (v1.1.0)
│   ├── load-testing-cheat-sheet.md    # Quick reference commands (v1.0.0)
│   ├── README.md                      # Documentation index
│   ├── VERSIONING-UPDATE-PLAN.md      # Semantic versioning migration plan
│   ├── VERSIONING-UPDATE-SUMMARY.md   # Implementation summary
│   │
│   └── archive/ (v1.0.0 docs - deprecated)
│       ├── index.md, quick-reference.md, checklist.md
│       ├── guides/ (container, initialization procedures)
│       └── architecture/ (detailed implementations)
│
└── 📁 archive/                        # Archived files (historical reference)
    ├── deprecated-approaches/         # Old testing methods
    ├── documentation/                 # Development diaries
    ├── duplicates/                    # Removed duplicates
    ├── generated-outputs/             # Test artifacts
    └── README.md                      # Archive documentation
```

## 📚 Documentation

**[📖 Complete Documentation Index](docs/README.md)** - Start here for all documentation

### 🚀 Quick Start Guides

- **[📘 Deployment Guide](docs/deployment-guide.md)** - Complete step-by-step deployment
- **[🧪 Testing Guide](docs/testing-guide.md)** - Load testing (8K TPS) + Failover testing
- **[🏗️ Architecture](docs/architecture.md)** - System design and components
- **[🔥 Troubleshooting](docs/TROUBLESHOOTING.md)** - Common issues & solutions

### 🧪 Testing & Monitoring

- **[🧪 Testing Guide](docs/testing-guide.md)** - Complete load testing (8K TPS) + failover testing
- **[📊 Azure Workbook Import](azure-workbooks/IMPORT-GUIDE.md)** - 30-second performance dashboard setup
- **[📖 RTO Measurement](scripts/CONNECTION-RTO-GUIDE.md)** - Connection RTO testing guide
- **[📖 Failover Monitoring](scripts/MONITOR-FAILOVER-GUIDE.md)** - Monitor failover events

### 🗄️ Database & SAIF Application

- **[🗄️ Database Initialization](archive/docs-v1.0.0/guides/container-initialization-guide.md)** - Setup procedures (archived)
- **[🐳 Container Build Guide](archive/docs-v1.0.0/guides/BUILD-CONTAINERS-GUIDE.md)** - SAIF app container builds (archived)

### 📐 Architecture & Deep Dive

- **[🏗️ Architecture](docs/architecture.md)** - System design & components
- **[💻 Implementation Details](archive/docs-v1.0.0/architecture/IMPLEMENTATION-COMPLETE.md)** - Technical deep dive (archived)
- **[📝 Changelog](docs/CHANGELOG.md)** - Version history

> 💡 **Tip**: Having issues? Check [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) first!

## 🤝 Contributing

Contributions welcome! Please read our [Code of Conduct](CODE_OF_CONDUCT.md) before contributing.

### How to Contribute:
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

MIT License - See [LICENSE](LICENSE) for details.

Copyright (c) 2025 Jonathan Vella

## ⚠️ Security Disclaimer

This project contains **intentional security vulnerabilities** for educational purposes. See [SECURITY.md](SECURITY.md) for details.

**DO NOT**:
- ❌ Deploy this in production environments
- ❌ Use these patterns in real applications
- ❌ Expose these applications to the public internet

## 🙏 Acknowledgments

Built for Microsoft Azure training workshops and hackathons.

## 📚 References

- [Azure PostgreSQL Flexible Server HA](https://learn.microsoft.com/azure/reliability/reliability-postgresql-flexible-server)
- [Azure Well-Architected Framework](https://learn.microsoft.com/azure/architecture/framework/)
- [PostgreSQL Performance Tuning](https://www.postgresql.org/docs/current/performance-tips.html)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/) - Security vulnerability reference

---

## 📦 Repository Organization

This repository was reorganized on **October 10, 2025** (v2.0.0) to streamline workflows and improve maintainability:

- **Core operational files**: Infrastructure, deployment, load testing, monitoring (35 files)
- **Archived files**: Historical artifacts preserved in `/archive/` (44 files)
- **Two workflows supported**: SAIF security demos + High-performance load testing

See [REORGANIZATION-SUMMARY.md](REORGANIZATION-SUMMARY.md) for complete reorganization details.
