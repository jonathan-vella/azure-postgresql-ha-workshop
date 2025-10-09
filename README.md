# SAIF-PostgreSQL: High Availability Payment Gateway Demo

[![Documentation Version](https://img.shields.io/badge/docs-v1.0.0-blue.svg)](docs/v1.0.0/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-blue.svg)](https://www.postgresql.org/)
[![Azure](https://img.shields.io/badge/Azure-Zone--Redundant%20HA-0089D6.svg)](https://azure.microsoft.com/en-us/products/postgresql/)
[![License](https://img.shields.io/badge/license-Educational%20Use-orange.svg)](LICENSE)

## Overview

SAIF-PostgreSQL is a deliberately vulnerable payment gateway application designed for security training and high availability demonstrations. This version uses **Azure Database for PostgreSQL Flexible Server** with **Zone-Redundant High Availability** to achieve:

- **RPO = 0** (Zero data loss)
- **RTO = 60-120 seconds** (Automatic failover)
- **SLA = 99.99%** (Zone-redundant deployment)

> 📚 **Documentation**: This README provides a quick overview. For comprehensive documentation, see the [docs/v1.0.0/](docs/v1.0.0/) directory.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                     Azure Region                         │
│              (Sweden Central / Germany West Central)     │
│                                                          │
│  ┌──────────────┐              ┌──────────────┐        │
│  │  Zone 1      │              │  Zone 2      │        │
│  │              │              │              │        │
│  │  ┌────────┐  │  Sync Rep   │  ┌────────┐  │        │
│  │  │Primary │◄─┼──────────────┼─►│Standby │  │        │
│  │  │PostgreSQL│ │              │  │PostgreSQL│ │        │
│  │  └────────┘  │              │  └────────┘  │        │
│  │              │              │              │        │
│  │  ┌────────┐  │              │              │        │
│  │  │App     │  │              │              │        │
│  │  │Services│  │              │              │        │
│  │  └────────┘  │              │              │        │
│  └──────────────┘              └──────────────┘        │
│                                                          │
│  ┌──────────────────────────────────────────┐          │
│  │  Container Registry (ACR)                 │          │
│  │  Key Vault (Secrets Management)           │          │
│  │  Application Insights (Monitoring)        │          │
│  └──────────────────────────────────────────┘          │
└─────────────────────────────────────────────────────────┘
```

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

## Quick Start

### Prerequisites
- Azure CLI installed and logged in
- PowerShell 7+ (pwsh)
- Docker Desktop (for local testing/database initialization)
- Azure subscription with Contributor access

> 📖 For detailed prerequisites and setup instructions, see the [Deployment Guide](docs/v1.0.0/deployment-guide.md).

### Deployment

#### Option 1: Deploy to Azure (Bicep)
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

## Cost Estimation

### Production Configuration (Zone-Redundant HA)
| Component | Specification | Monthly Cost |
|-----------|--------------|--------------|
| PostgreSQL Primary | Standard_D4ds_v5 (4 vCore, 16GB) | ~$325 |
| PostgreSQL Standby | Standard_D4ds_v5 (4 vCore, 16GB) | ~$325 |
| Storage | 128GB Premium SSD | ~$10 |
| App Services | 2x P1v3 | ~$200 |
| Supporting services | ACR, Key Vault, Insights | ~$50 |
| **Total** | | **~$910/month** |

## Performance Benchmarks

### Payment Transaction Throughput
- **Writes**: ~500 TPS (transactions per second)
- **Reads**: ~2,000 TPS
- **Failover Impact**: 16-18 seconds downtime (native Npgsql)
- **Data Loss**: 0 transactions (RPO=0)

### Failover Testing
The project includes **two failover testing options** for different performance requirements:

#### Option 1: PowerShell Script (Local Execution)
```powershell
# Run comprehensive failover test (12-13 TPS sustained load)
cd scripts
.\Test-PostgreSQL-Failover.ps1
```

**Capabilities**:
- 12-13 TPS sustained write load (PowerShell loop overhead)
- Automatic Npgsql dependency installation to `scripts/libs/`
- Real-time RTO/RPO measurement
- Connection loss detection with millisecond precision
- Best for: Local testing, quick validation

#### Option 2: C# Script (Azure Cloud Shell) ⭐ **RECOMMENDED FOR HIGH THROUGHPUT**
```bash
# Run high-performance failover test (200-500 TPS sustained load)
dotnet script Test-PostgreSQL-Failover.csx -- \
  "Host=your-server.postgres.database.azure.com;Database=saifdb;Username=user;Password=pass;SSL Mode=Require" \
  10 \
  5
```

**Capabilities**:
- **200-500 TPS** sustained write load (from Cloud Shell)
- Parallel async workers with persistent connections
- Sub-millisecond precision RTO/RPO measurement
- Real-time performance statistics (P50, P95, peak TPS)
- Best for: High-throughput testing, production-grade validation

> 📖 **Guides**: 
> - [Failover Testing Guide](docs/v1.0.0/failover-testing-guide.md) - Comprehensive testing procedures
> - [Cloud Shell Quick Start](scripts/CLOUD-SHELL-GUIDE.md) - Azure Cloud Shell setup (5 minutes)

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
SAIF-pgsql/
├── api/                          # Python FastAPI application
├── web/                          # PHP frontend
├── infra/                        # Infrastructure as Code (Bicep templates)
│   ├── main.bicep               # Main template
│   ├── main.parameters.json     # Parameters
│   └── modules/
│       ├── database/
│       │   └── postgresql.bicep # PostgreSQL HA module
│       └── keyvault/
│           └── keyvault.bicep   # Key Vault module
├── database/                     # Database scripts
│   ├── README.md                # Database documentation
│   ├── init-db.sql              # Schema initialization
│   ├── cleanup-db.sql           # Database cleanup procedures
│   └── enable-uuid.sql          # UUID extension enablement
├── scripts/                      # Deployment & testing automation
│   ├── README.md                # Scripts documentation
│   ├── Deploy-SAIF.ps1          # Main deployment script
│   ├── Quick-Deploy-SAIF.ps1    # Simplified deployment
│   ├── Initialize-Database.ps1  # Database initialization
│   ├── Test-PostgreSQL-Failover.ps1  # HA failover testing (12-13 TPS)
│   ├── Monitor-PostgreSQL-HA.ps1     # HA status monitoring
│   ├── libs/                    # Auto-installed Npgsql dependencies
│   ├── archive/                 # Historical failover test iterations
│   └── utils/                   # Diagnostic utilities
├── docs/                         # Documentation (organized)
│   ├── README.md                # Documentation index
│   ├── TROUBLESHOOTING.md       # Common issues & solutions
│   ├── guides/                  # Operational guides
│   │   └── container-initialization-guide.md
│   ├── architecture/            # Architecture documentation
│   └── v1.0.0/                  # Version 1.0.0 documentation
│       ├── deployment-guide.md  # Complete deployment guide
│       ├── failover-testing-guide.md # HA failover testing
│       └── ...                  # Additional versioned docs
└── docker-compose.yml           # Local development
```

## 📚 Documentation

**[📖 Complete Documentation Index](docs/README.md)** - Start here for all documentation

### Essential Guides

- **[🔥 TROUBLESHOOTING](docs/TROUBLESHOOTING.md)** - Common issues & solutions (9 issues covered)
- **[📘 Deployment Guide](docs/v1.0.0/deployment-guide.md)** - Complete step-by-step deployment
- **[⚡ Quick Reference](docs/v1.0.0/quick-reference.md)** - Commands cheat sheet
- **[🗄️ Database Initialization](docs/guides/container-initialization-guide.md)** - Setup procedures (3 methods)

### Deep Dive

- **[🏗️ Architecture](docs/v1.0.0/architecture.md)** - System design & components
- **[🧪 Failover Testing](docs/v1.0.0/failover-testing-guide.md)** - HA testing and RTO/RPO measurement
- **[💻 Implementation Summary](docs/v1.0.0/implementation-summary.md)** - Technical deep dive
- **[✅ Checklist](docs/v1.0.0/checklist.md)** - Project completion checklist
- **[📝 CHANGELOG](docs/v1.0.0/CHANGELOG.md)** - Version history

> 💡 **Tip**: Having issues? Check [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) first!

## References

- [Azure PostgreSQL Flexible Server HA](https://learn.microsoft.com/azure/reliability/reliability-postgresql-flexible-server)
- [Azure Well-Architected Framework](https://learn.microsoft.com/azure/architecture/framework/)
- [PostgreSQL Performance Tuning](https://www.postgresql.org/docs/current/performance-tips.html)

---

**⚠️ WARNING**: This application contains intentional security vulnerabilities for educational purposes. **DO NOT** deploy to production or expose to the internet without proper hardening.
