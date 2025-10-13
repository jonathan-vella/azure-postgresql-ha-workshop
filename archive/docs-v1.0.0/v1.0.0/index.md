# SAIF-PostgreSQL Documentation Index

## 📚 Complete Documentation Guide

### Getting Started
1. **[README.md](../../README.md)** - Start here!
   - Project overview and features
   - Quick start guide
   - Architecture overview
   - Cost estimates
   - Feature comparison with Azure SQL version

2. **[Quick Reference](quick-reference.md)** - Quick reference card
   - Essential commands
   - Common workflows
   - Troubleshooting tips
   - One-page cheat sheet

### Deployment & Operations
3. **[Deployment Guide](deployment-guide.md)** - Comprehensive deployment guide
   - Prerequisites and requirements
   - Local development setup
   - Azure deployment (automated and manual)
   - Failover testing procedures
   - Monitoring strategies
   - Troubleshooting common issues
   - **Most detailed operational guide**

4. **[Failover Testing Guide](failover-testing-guide.md)** - HA failover testing
   - Zone-redundant HA testing procedures
   - RTO/RPO measurement
   - Automated testing scripts
   - Performance metrics and SLA validation
   - Cost optimization strategies
   - **Complete failover testing reference**

5. **[Architecture](architecture.md)** - System architecture
   - Architecture diagrams
   - Component descriptions
   - HA configuration details

### Technical Documentation
6. **[Implementation Summary](implementation-summary.md)** - Implementation summary
   - Project structure breakdown
   - Database schema details
   - API endpoint catalog
   - Infrastructure components
   - PowerShell script reference
   - Cost breakdowns
   - Success metrics

7. **[API Documentation](../../api/README.md)** - API documentation
   - Endpoint specifications
   - Request/response formats
   - Authentication details
   - Example API calls
   - Vulnerability endpoints (educational)

### Code & Infrastructure
8. **[Database Schema](../../database/init-db.sql)** - Database schema
   - Complete table definitions
   - Foreign key relationships
   - Indexes and constraints
   - Views and functions
   - Demo data generation

9. **[Infrastructure Template](../../infra/main.bicep)** - Infrastructure template
   - Azure resource definitions
   - Zone-redundant HA configuration
   - Security settings
   - Monitoring setup

### Automation Scripts
10. **[Deploy-SAIF-PostgreSQL.ps1](../../scripts/Deploy-SAIF-PostgreSQL.ps1)**
    - Complete deployment automation
    - Parameter reference
    - Usage examples

11. **[Test-PostgreSQL-Failover.ps1](../../scripts/Test-PostgreSQL-Failover.ps1)**
    - Failover testing automation
    - RTO/RPO measurement
    - SLA validation

12. **[Monitor-PostgreSQL-HA.ps1](../../scripts/Monitor-PostgreSQL-HA.ps1)**
    - Real-time monitoring dashboard
    - HA status tracking
    - Performance metrics

13. **[Update-SAIF-Containers-PostgreSQL.ps1](../../scripts/archive/Update-SAIF-Containers-PostgreSQL.ps1)**
    - Container update automation
    - Selective rebuild options

14. **[Test-SAIFLocal.ps1](../../scripts/Test-SAIFLocal.ps1)**
    - Local development testing
    - Docker Compose validation
    - Health checks

---

## 📖 Reading Paths

### For First-Time Users
```
1. README.md (overview)
2. quickstart.md (commands)
3. deployment-guide.md → "Local Development" section
4. Test locally with docker-compose
```

### For Azure Deployment
```
1. deployment-guide.md → "Prerequisites" section
2. deployment-guide.md → "Azure Deployment" section
3. Run Deploy-SAIF-PostgreSQL.ps1
4. deployment-guide.md → "Monitoring" section
```

### For Failover Testing
```
1. failover-testing-guide.md → "Prerequisites" section
2. failover-testing-guide.md → "Infrastructure Requirements" section
3. Run Test-PostgreSQL-Failover.ps1
4. failover-testing-guide.md → "Understanding Results" section
```

### For Understanding Architecture
```
1. architecture.md (diagrams)
2. implementation-summary.md → "Database Architecture" section
3. init-db.sql (actual schema)
4. infra/main.bicep (infrastructure code)
```

### For Developers
```
1. api/README.md (API specification)
2. api/app.py (implementation)
3. web/index.php (frontend)
4. web/assets/js/custom.js (JavaScript)
```

### For Operations/DevOps
```
1. deployment-guide.md → "Monitoring" section
2. Monitor-PostgreSQL-HA.ps1 script
3. deployment-guide.md → "Troubleshooting" section
4. Update-SAIF-Containers-PostgreSQL.ps1 script
```

### For Security Learning
```
1. README.md → "Educational Purpose" section
2. api/README.md → "Vulnerable Endpoints" section
3. api/app.py → Vulnerable endpoint implementations
4. Test the vulnerabilities (educational only!)
```

---

## 🎯 Quick Links by Task

| Task | Documentation |
|------|--------------|
| **Deploy locally** | deployment-guide.md → Local Development |
| **Deploy to Azure** | deployment-guide.md → Azure Deployment + Deploy-SAIF-PostgreSQL.ps1 |
| **Test failover** | failover-testing-guide.md + Test-PostgreSQL-Failover.ps1 |
| **Measure RTO/RPO** | failover-testing-guide.md → Understanding Results |
| **Monitor HA status** | Monitor-PostgreSQL-HA.ps1 |
| **Update containers** | Update-SAIF-Containers-PostgreSQL.ps1 |
| **Understand costs** | README.md → Cost Analysis + failover-testing-guide.md → Cost Optimization |
| **Troubleshoot issues** | deployment-guide.md → Troubleshooting + failover-testing-guide.md → Troubleshooting |
| **API reference** | api/README.md |
| **Database schema** | init-db.sql + implementation-summary.md → Database Architecture |
| **Security info** | README.md → Security Considerations + api/README.md |

---

## 📁 File Organization

```
SAIF-pgsql/
├── README.md                    ⭐ Start here
├── QUICKSTART.md                📋 Quick reference
├── DEPLOY.md                    📖 Complete deployment guide
├── SUMMARY.md                   📊 Implementation details
├── ARCHITECTURE.md              🏗️  Architecture diagrams
├── INDEX.md                     📚 This file
│
├── api/
│   ├── README.md                🔌 API documentation
│   ├── app.py                   💻 API implementation
│   └── Dockerfile               🐳 Container definition
│
├── web/
│   ├── index.php                🌐 Web dashboard
│   └── assets/
│       ├── css/custom.css       🎨 Styling
│       └── js/custom.js         ⚡ Frontend logic
│
├── infra/
│   ├── main.bicep               ☁️  Infrastructure template
│   └── modules/                 📦 Reusable modules
│
├── scripts/
│   ├── Deploy-SAIF-PostgreSQL.ps1          🚀 Deploy
│   ├── Test-PostgreSQL-Failover.ps1        🧪 Test failover
│   ├── Monitor-PostgreSQL-HA.ps1           📊 Monitor
│   ├── Update-SAIF-Containers-PostgreSQL.ps1 🔄 Update
│   └── Test-SAIFLocal.ps1                  🏠 Local test
│
├── init-db.sql                  🗄️  Database schema
└── docker-compose.yml           🐳 Local development
```

---

## 🎓 Learning Resources

### Internal Documentation
- **Comprehensive**: deployment-guide.md (most detailed)
- **Quick reference**: quickstart.md
- **Architecture**: architecture.md + implementation-summary.md
- **API specs**: api/README.md

### External Resources
- [Azure PostgreSQL HA Documentation](https://learn.microsoft.com/azure/postgresql/flexible-server/concepts-high-availability)
- [Bicep Language Reference](https://learn.microsoft.com/azure/azure-resource-manager/bicep/)
- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [PostgreSQL 16 Documentation](https://www.postgresql.org/docs/16/)

---

## 📞 Need Help?

1. **Check documentation**:
   - deployment-guide.md → Troubleshooting section
   - quickstart.md → Common issues
   
2. **Review logs**:
   - Local: `docker-compose logs -f`
   - Azure: `az webapp log tail`
   
3. **Test health**:
   - API: `/api/healthcheck`
   - Database: Monitor-PostgreSQL-HA.ps1

4. **Azure resources**:
   - Azure Portal → Resource health
   - Application Insights → Failures
   - Log Analytics → Custom queries

---

**Documentation Version**: 1.0.0  
**Last Updated**: 2025-10-09  
**Status**: Complete ✅
