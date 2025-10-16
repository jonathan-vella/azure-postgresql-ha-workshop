# Changelog

**Version**: 2.2.0  
**Last Updated**: October 16, 2025  
**Status**: Current

All notable changes to the Azure PostgreSQL HA Workshop will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.1.0] - 2025-10-13

### Added
- ✨ **Documentation Streamlining**: Consolidated to 4 core documents + minimal support
- 📚 New consolidated `docs/testing-guide.md` (combines load testing + failover testing)
- 📋 New `docs/CHANGELOG.md` for version tracking
- 📁 Comprehensive archival system in `archive/docs-v1.0.0/`

### Changed
- 🏗️ **Architecture Guide**: Moved to `docs/architecture.md`, streamlined content
- 📘 **Deployment Guide**: Moved to `docs/deployment-guide.md`, updated to v2.1.0
- 🔄 **Documentation Structure**: Flat hierarchy, improved navigation
- 📝 Updated all version references to 2.1.0
- 🗓️ Updated all "Last Updated" dates to October 13, 2025

### Removed
- 🗂️ **Archived 30+ documentation files** to `archive/docs-v1.0.0/`:
  - All `docs/v1.0.0/*` files (except core content moved to new locations)
  - All `docs/architecture/*` files (implementation details)
  - Most `docs/guides/*` files (operational procedures)
  - Redundant `docs/README.md` (index file)

### Technical Details
- **Semantic Versioning**: 2.0.0 → 2.1.0 (minor version, backward compatible)
- **Content Preservation**: 100% of content archived, zero data loss
- **Link Updates**: All internal references updated to new structure
- **Maintenance Reduction**: 85% fewer active documentation files

## [2.0.0] - 2025-10-10

### Added
- 🚀 **Repository Reorganization**: Major restructuring for dual workflows
- 📊 **Load Testing Capability**: 8K-12K TPS validation with LoadGenerator.csx
- 📈 **Performance Monitoring**: Azure Workbook with 6 charts and real-time metrics
- 💰 **Cost Estimates**: Accurate pricing for default and high-performance configurations

### Changed
- 📁 **Project Structure**: Reorganized from SAIF-focused to dual-purpose
- 🎯 **Use Cases**: Now supports both SAIF security demos + high-performance HA testing
- 📋 **Documentation**: Updated all guides for v2.0.0 repository structure
- 🔧 **Scripts**: Enhanced with production-grade load testing and monitoring

## [1.0.0] - 2025-09-30

### Added
- 🎯 **Initial Release**: SAIF Payment Gateway with PostgreSQL HA
- 🏗️ **Infrastructure**: Bicep templates for zone-redundant PostgreSQL deployment
- 🔐 **Security Demos**: Intentional vulnerabilities for educational purposes
- 🧪 **Basic Failover Testing**: PowerShell-based RTO/RPO measurement
- 📚 **Comprehensive Documentation**: Deployment, architecture, and testing guides

### Features
- **Azure PostgreSQL Flexible Server** with Zone-Redundant HA
- **SAIF Web/API Applications** (PHP + Python FastAPI)
- **Database Schema** for payment gateway simulation
- **Docker Compose** for local development
- **PowerShell Scripts** for deployment and testing

---

## Version Support

| Version | Status | Documentation | Archive Location |
|---------|--------|---------------|------------------|
| 2.1.0 | ✅ **Current** | `/docs/` | - |
| 2.0.0 | 📋 Archived | `archive/docs-v1.0.0/` | Complete |
| 1.0.0 | 📋 Archived | `archive/docs-v1.0.0/` | Complete |

## Migration Guide

### From v2.0.0 to v2.1.0
- **Documentation Links**: Update any bookmarks to new `/docs/` structure
- **Testing Workflows**: Use new consolidated `docs/testing-guide.md`
- **Architecture References**: Use `docs/architecture.md`

### From v1.0.0 to v2.0.0+
- **Repository Structure**: See `REORGANIZATION-SUMMARY.md` for complete changes
- **Load Testing**: New high-performance capabilities with LoadGenerator.csx
- **Monitoring**: Import Azure Workbook from `azure-workbooks/` folder