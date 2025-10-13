# Documentation Archive v1.0.0

This directory contains archived documentation from versions 1.0.0 and 2.0.0 of the Azure PostgreSQL HA Workshop.

**Archive Date:** October 13, 2025  
**Documentation Cleanup:** v2.1.0 streamlining initiative

## 📁 Archive Structure

```
archive/docs-v1.0.0/
├── ARCHIVE-README.md (this file)
├── v1.0.0/                    # Version 1.0.0 documentation
│   ├── architecture.md        # → Moved to /docs/architecture.md
│   ├── deployment-guide.md    # → Moved to /docs/deployment-guide.md  
│   ├── failover-testing-guide.md  # → Merged into /docs/testing-guide.md
│   ├── CHANGELOG.md           # Historical version info
│   ├── checklist.md           # Project completion checklist
│   ├── index.md               # Documentation index (obsolete)
│   └── quick-reference.md     # Command reference (maintenance burden)
├── architecture/              # Implementation details (obsolete)
│   ├── HIGH-PERFORMANCE-8000TPS-ARCHITECTURE.md
│   ├── IMPLEMENTATION-COMPLETE.md
│   ├── QUICK-REFERENCE-8K-TPS.md
│   ├── AZURE-MONITOR-8K-TPS.md
│   ├── BICEP-UPDATES-8K-TPS.md
│   └── DEPLOYMENT-FIX-COMMAND-LINE-LENGTH.md
└── guides/                    # Operational procedures (specialized)
    ├── LOAD-TEST-QUICK-REF.md      # → Merged into /docs/testing-guide.md
    ├── BUILD-CONTAINERS-GUIDE.md   # Container build procedures
    ├── BUILD-CONTAINERS-QUICK-REF.md
    ├── container-initialization-guide.md
    └── README.md                    # Guides index
```

## 🎯 Current Active Documentation (v2.1.0)

The streamlined documentation structure in `/docs/` contains:

1. **[Main README](../../README.md)** - Project overview and quick start
2. **[Architecture Guide](../architecture.md)** - System design and components  
3. **[Deployment Guide](../deployment-guide.md)** - Setup and configuration
4. **[Testing Guide](../testing-guide.md)** - Load testing and failover procedures
5. **[Troubleshooting](../TROUBLESHOOTING.md)** - Common issues and solutions
6. **[Changelog](../CHANGELOG.md)** - Version history

## 📋 Content Migration Summary

### ✅ Content Preserved (Moved/Merged)
- **architecture.md** → `/docs/architecture.md` (streamlined)
- **deployment-guide.md** → `/docs/deployment-guide.md` (updated)
- **failover-testing-guide.md** → `/docs/testing-guide.md` (Part 2)
- **LOAD-TEST-QUICK-REF.md** → `/docs/testing-guide.md` (Part 1)

### 📚 Content Archived (Reference Only)
- **Implementation details** (architecture/) - Technical deep-dives
- **Operational procedures** (guides/) - Container builds, initialization
- **Project management** (checklist.md, index.md) - Process documentation
- **Quick references** (quick-reference.md) - Command lists

## 🔍 Migration Guide

### Updating Bookmarks
If you have bookmarks to old documentation:

| Old Path | New Path |
|----------|----------|
| `docs/v1.0.0/architecture.md` | `docs/architecture.md` |
| `docs/v1.0.0/deployment-guide.md` | `docs/deployment-guide.md` |
| `docs/v1.0.0/failover-testing-guide.md` | `docs/testing-guide.md#part-2` |
| `docs/guides/LOAD-TEST-QUICK-REF.md` | `docs/testing-guide.md#part-1` |
| `docs/README.md` | `../README.md` (root) |

---

**Archive Date:** October 13, 2025