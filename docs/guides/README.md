# Operational Guides

This folder contains operational and procedural guides for working with SAIF-PostgreSQL.

---

## 📘 Available Guides

### Container Management

#### [BUILD-CONTAINERS-GUIDE.md](BUILD-CONTAINERS-GUIDE.md)
**Comprehensive container build guide**

**Topics covered:**
- ACR Tasks (cloud-native builds)
- Local Docker builds
- Parallel builds for faster deployment
- Troubleshooting build issues
- Best practices and security

**When to use:**
- Complete understanding of container build process
- Troubleshooting build failures
- Learning about ACR Tasks vs local builds
- Implementing custom build workflows

**Time required:** 15-20 minutes read

---

#### [BUILD-CONTAINERS-QUICK-REF.md](BUILD-CONTAINERS-QUICK-REF.md)
**Quick reference for common container operations**

**Topics covered:**
- Quick rebuild commands
- One-liner examples
- Common scenarios
- Fast troubleshooting

**When to use:**
- Need commands fast
- Quick container updates
- During active development

**Time required:** 2-3 minutes

---

### Database Operations

#### [container-initialization-guide.md](container-initialization-guide.md)
**Database initialization procedures**

**Topics covered:**
- Database schema setup (3 methods)
- Container-based initialization
- Direct psql connection
- Cloud Shell initialization
- Troubleshooting database issues

**When to use:**
- First deployment
- Database schema updates
- Troubleshooting database connectivity
- Understanding initialization options

**Time required:** 10-15 minutes

---

### Historical Documentation

#### [CONSOLIDATION-SUMMARY.md](CONSOLIDATION-SUMMARY.md)
**Project consolidation and reorganization summary**

**Topics covered:**
- Documentation structure evolution
- File consolidation decisions
- Historical context
- Migration notes

**When to use:**
- Understanding project history
- Reference for past decisions
- Academic/research purposes

**Time required:** 5-10 minutes

---

## 🎯 Quick Navigation

### I Want To...

#### Build and Deploy Containers
1. **Quick rebuild**: See [BUILD-CONTAINERS-QUICK-REF.md](BUILD-CONTAINERS-QUICK-REF.md)
2. **Detailed guide**: See [BUILD-CONTAINERS-GUIDE.md](BUILD-CONTAINERS-GUIDE.md)
3. **Main scripts**: `../scripts/Rebuild-SAIF-Containers.ps1`

#### Initialize Database
1. **Setup guide**: See [container-initialization-guide.md](container-initialization-guide.md)
2. **Main script**: `../scripts/Initialize-Database.ps1`

#### Understand Project Evolution
1. **Consolidation summary**: See [CONSOLIDATION-SUMMARY.md](CONSOLIDATION-SUMMARY.md)
2. **Version docs**: See `../v1.0.0/CHANGELOG.md`

---

## 📂 Related Documentation

- **Main Documentation**: [../README.md](../README.md)
- **Versioned Docs**: [../v1.0.0/index.md](../v1.0.0/index.md)
- **Architecture**: [../architecture/](../architecture/)
- **Troubleshooting**: [../TROUBLESHOOTING.md](../TROUBLESHOOTING.md)

---

## 🔄 Version Information

These guides apply to **SAIF-PostgreSQL v1.0.0** and later.

For version-specific documentation, see the versioned folders:
- Current: [../v1.0.0/](../v1.0.0/)

---

*Last Updated: 2025-10-09*
