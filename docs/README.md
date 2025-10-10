# SAIF-PostgreSQL Documentation

Complete documentation for the SAIF Payment Gateway with Azure PostgreSQL Zone-Redundant High Availability deployment.

This directory contains versioned documentation for the SAIF-PostgreSQL project following semantic versioning principles.

---

## 📚 Quick Navigation

### Current Version: v1.0.0 (Latest)

**[→ View v1.0.0 Documentation](v1.0.0/index.md)**

**Release Date**: 2025-10-09  
**Status**: ✅ Current & Supported  
**PostgreSQL Version**: 16  
**Azure HA Mode**: Zone-Redundant

---

## 🚀 Getting Started

| Document | Purpose | Time Required |
|----------|---------|---------------|
| [**Main README**](../README.md) | Project overview, features, quick start | 5 min |
| [**Deployment Guide**](v1.0.0/deployment-guide.md) | Complete step-by-step deployment | 25-30 min |
| [**Quick Reference**](v1.0.0/quick-reference.md) | Commands cheat sheet | 2 min |

### What's Included in v1.0.0

- Complete deployment guide with automated scripts
- Zone-redundant PostgreSQL Flexible Server implementation
- FastAPI backend with comprehensive endpoints
- PHP frontend with security vulnerabilities (educational)
- Docker Compose for local development
- Bicep infrastructure as code
- PowerShell automation scripts
- Failover testing and monitoring tools

---

## 🔧 Essential Guides

| Document | Purpose | When to Use |
|----------|---------|-------------|
| [**TROUBLESHOOTING**](TROUBLESHOOTING.md) | Common issues & solutions (9 issues covered) | When things don't work |
| [**Failover Testing**](v1.0.0/failover-testing-guide.md) | HA testing with native Npgsql (12-13 TPS) | Testing resilience |
| [**Container Builds**](guides/BUILD-CONTAINERS-GUIDE.md) | Container build procedures | Building/updating containers |
| [**Database Setup**](guides/container-initialization-guide.md) | Database initialization (3 methods) | First deployment |

---

## 📖 Reference Documentation

### v1.0.0 Quick Links

| Document | Purpose | Use For |
|----------|---------|---------|
| [**Index**](v1.0.0/index.md) | Documentation navigation | Starting point |
| [**Architecture**](v1.0.0/architecture.md) | System design & components | Understanding the system |
| [**Implementation Summary**](v1.0.0/implementation-summary.md) | Technical implementation details | Deep dive into code |
| [**CHANGELOG**](v1.0.0/CHANGELOG.md) | Version history | Tracking changes |
| [**Checklist**](v1.0.0/checklist.md) | Project completion status | Progress tracking |

---

## 📘 Operational Guides

Procedural guides for day-to-day operations:

| Guide | Purpose | Location |
|-------|---------|----------|
| **Container Management** | Build and deploy containers | [guides/BUILD-CONTAINERS-GUIDE.md](guides/BUILD-CONTAINERS-GUIDE.md) |
| **Quick Container Reference** | Fast rebuild commands | [guides/BUILD-CONTAINERS-QUICK-REF.md](guides/BUILD-CONTAINERS-QUICK-REF.md) |
| **Database Initialization** | Setup database schema | [guides/container-initialization-guide.md](guides/container-initialization-guide.md) |

[**→ View All Operational Guides**](guides/README.md)

---

## 🎯 Common Tasks

### I Want To...

#### Deploy SAIF to Azure
1. Read [Main README - Quick Start](../README.md#quick-start)
2. Follow [Deployment Guide](v1.0.0/deployment-guide.md)
3. Reference [Database Initialization Guide](guides/container-initialization-guide.md)

#### Fix Application Issues
1. Check [TROUBLESHOOTING Guide](TROUBLESHOOTING.md)
2. Review [Quick Diagnosis Flowchart](TROUBLESHOOTING.md#quick-diagnosis)
3. Apply solutions from [Common Issues section](TROUBLESHOOTING.md#common-issues)

#### Test High Availability
1. Review [Architecture - HA Section](v1.0.0/architecture.md)
2. Follow [Failover Testing Guide](v1.0.0/failover-testing-guide.md)
3. Use `Test-PostgreSQL-Failover.ps1` (native Npgsql, 12-13 TPS)

#### Update Containers
1. Quick method: [Container Quick Reference](guides/BUILD-CONTAINERS-QUICK-REF.md)
2. Detailed guide: [Container Build Guide](guides/BUILD-CONTAINERS-GUIDE.md)
3. Run: `scripts/Rebuild-SAIF-Containers.ps1`

#### Understand the System
1. Read [Architecture Documentation](v1.0.0/architecture.md)
2. Review [Implementation Summary](v1.0.0/implementation-summary.md)
3. Check [Project Structure in Main README](../README.md#project-structure)

---

## 🔄 Version History

| Version | Release Date | Status | Notes |
|---------|-------------|--------|-------|
| [v1.0.0](v1.0.0/index.md) | 2025-10-09 | ✅ Current | Initial release with PostgreSQL 16 and zone-redundant HA |

---

## 📁 Documentation Structure

```
docs/
├── README.md (this file)                         # Documentation index
├── TROUBLESHOOTING.md                            # Complete troubleshooting guide
├── architecture/                                 # Technical architecture docs
│   ├── ACR-BUILD-UNICODE-FIX.md
│   └── BUILD-AUTOMATION-SUMMARY.md
├── guides/                                       # Operational guides
│   ├── README.md
│   ├── BUILD-CONTAINERS-GUIDE.md
│   ├── BUILD-CONTAINERS-QUICK-REF.md
│   ├── container-initialization-guide.md
│   └── CONSOLIDATION-SUMMARY.md
└── v1.0.0/                                       # Version-specific docs
    ├── index.md                                  # Documentation navigation
    ├── quick-reference.md                        # Quick reference card
    ├── deployment-guide.md                       # Complete deployment guide
    ├── architecture.md                           # System architecture
    ├── failover-testing-guide.md                 # HA testing procedures
    ├── implementation-summary.md                 # Technical implementation
    ├── CHANGELOG.md                              # Version history
    └── checklist.md                              # Project completion checklist
```

---

## 🎯 Finding the Right Documentation

### I want to...

- **Get started quickly** → [Quick Reference](v1.0.0/quick-reference.md)
- **Deploy to Azure** → [Deployment Guide](v1.0.0/deployment-guide.md)
- **Understand the architecture** → [Architecture](v1.0.0/architecture.md)
- **See all available docs** → [Index](v1.0.0/index.md)
- **Check project completion** → [Checklist](v1.0.0/checklist.md)
- **Get implementation details** → [Implementation Summary](v1.0.0/implementation-summary.md)

---

## 📝 Semantic Versioning

This documentation follows [Semantic Versioning 2.0.0](https://semver.org/):

- **Major version (X.0.0)** - Breaking changes (incompatible API/infrastructure changes)
- **Minor version (0.X.0)** - New features (backward-compatible additions)
- **Patch version (0.0.X)** - Bug fixes and clarifications (no functional changes)

### When to use which version?

- **Latest version (v1.0.0)** - Recommended for new deployments
- **Previous versions** - Use if you have existing deployments on that version

---

## 🚀 Contributing to Documentation

When updating documentation:

1. **Bug fixes/clarifications** - Update current version (patch increment)
2. **New features** - Create new minor version (e.g., v1.1.0)
3. **Breaking changes** - Create new major version (e.g., v2.0.0)

### Documentation Standards

- Use Markdown format
- Include code examples with syntax highlighting
- Provide command-line examples for PowerShell
- Link between related documents
- Keep language clear and concise
- Include diagrams where helpful

---

## 📊 Documentation Statistics

| Metric | Count | Notes |
|--------|-------|-------|
| **Total Documents** | 11 | Consolidated from 34+ files |
| **Issues Covered** | 9 | All with solutions |
| **Deployment Methods** | 3 | Bicep, Manual, Container-only |
| **Database Init Methods** | 3 | Container, Local psql, Azure Cloud Shell |
| **Testing Scenarios** | 4+ | Failover, Load, Vulnerability, Integration |

---

## 🛠️ Quick Command Reference

### Get Help
```powershell
# View documentation locally
Get-Content docs\TROUBLESHOOTING.md | Select-String -Pattern "Issue"

# Open in browser (if markdown viewer installed)
code docs\README.md
```

### Find Specific Topics
```powershell
# Search all documentation
Get-ChildItem docs\*.md -Recurse | Select-String -Pattern "failover"

# Search troubleshooting guide
Get-Content docs\TROUBLESHOOTING.md | Select-String -Pattern "uuid-ossp"
```

---

## 🔍 Key Features Documented

### Deployment
- ✅ Automated Azure infrastructure deployment (Bicep)
- ✅ Zone-Redundant PostgreSQL HA configuration
- ✅ Container builds and App Service deployment
- ✅ Database initialization with Docker (no local psql needed)

### Troubleshooting
- ✅ 9 root causes documented with solutions
- ✅ Azure PostgreSQL uuid-ossp extension requirements
- ✅ API/Frontend contract mismatches
- ✅ Browser caching issues
- ✅ Database connection problems
- ✅ Container deployment issues

### High Availability
- ✅ Zone-redundant HA setup (Zone 1 + Zone 2)
- ✅ Automated failover testing (RTO: 60-120s, RPO: 0s)
- ✅ Real-time monitoring dashboard
- ✅ SLA compliance validation (99.99% uptime)

### Security (Educational)
- ⚠️ **Intentional vulnerabilities** for learning:
  - SQL injection demonstrations
  - SSRF testing endpoints
  - Information disclosure examples
- 🚫 **DO NOT USE IN PRODUCTION**

---

## 📞 Need Help?

### Having Issues?
1. **Check TROUBLESHOOTING.md first** - Covers 9 common issues
2. **Review relevant guide** - See Quick Navigation above
3. **Check Azure Service Health** - [status.azure.com](https://status.azure.com)
4. **Enable debug logging** - See Troubleshooting guide
5. **Submit GitHub issue** - Include logs and error messages

### Want to Contribute?
- Improve documentation
- Report issues or gaps
- Share your deployment experiences
- Add troubleshooting scenarios

---

## 🔄 Recent Updates (October 9, 2025)

- ✅ **New**: Comprehensive TROUBLESHOOTING.md (consolidates 9 root causes)
- ✅ **Updated**: Main README.md Quick Start section
- ✅ **Updated**: Deployment Guide with current working procedures
- ✅ **Removed**: Obsolete/redundant documentation (migration-guide, deployment-enhancements-summary, quickstart-v1)
- ✅ **Consolidated**: 34 markdown files → 11 essential documents

---

**Last Updated**: 2025-10-09  
**Documentation Version**: 1.1.0  
**Application Version**: 1.0.0-pgsql

For the main project README, see [../README.md](../README.md)
