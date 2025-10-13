# 🚀 Build-SAIF-Containers.ps1 - Quick Reference

## One-Line Commands

```powershell
# ✅ Most Common: Build both containers
.\Build-SAIF-Containers.ps1

# ⚡ Fast: Build both in parallel
.\Build-SAIF-Containers.ps1 -parallel

# 🔄 Deploy: Build and restart services
.\Build-SAIF-Containers.ps1 -restartApps

# 🎯 Quick Iteration: API only
.\Build-SAIF-Containers.ps1 -buildWhat api

# 🧪 Local Test: Build without push
.\Build-SAIF-Containers.ps1 -skipPush

# 📦 Production: Versioned release
.\Build-SAIF-Containers.ps1 -tag "v1.0.0" -restartApps
```

---

## Common Workflows

### Development
```powershell
# Test → Push → Restart
.\Build-SAIF-Containers.ps1 -buildWhat api -skipPush    # Test locally
.\Build-SAIF-Containers.ps1 -buildWhat api              # Push to ACR
.\Build-SAIF-Containers.ps1 -buildWhat api -restartApps # Deploy
```

### Staging
```powershell
# Build with date tag
.\Build-SAIF-Containers.ps1 -tag "staging-$(Get-Date -Format 'yyyyMMdd')" -parallel -restartApps
```

### Production
```powershell
# Semantic versioning
.\Build-SAIF-Containers.ps1 -tag "v1.2.3" -restartApps
```

---

## Parameters at a Glance

| Parameter | Default | Values | Use Case |
|-----------|---------|--------|----------|
| `-registryName` | Auto-detect | `"myacr"` | Multi-registry deployments |
| `-resourceGroupName` | Auto-detect | `"my-rg"` | Multi-resource group |
| `-tag` | `"latest"` | `"v1.0.0"` | Version tracking |
| `-buildWhat` | `"all"` | `api`, `web`, `all` | Fast iteration |
| `-parallel` | Off | N/A | Speed up builds |
| `-skipPush` | Off | N/A | Local testing |
| `-restartApps` | Off | N/A | Auto-deployment |

---

## Timing Reference

| Mode | Time | Notes |
|------|------|-------|
| API only | 2-3 min | Sequential |
| Web only | 7-8 min | Sequential |
| Both (sequential) | 10-11 min | Default |
| Both (parallel) | 7-8 min | ~40% faster |

---

## Troubleshooting Quick Fixes

**Problem:** No ACR found  
**Fix:** `.\Build-SAIF-Containers.ps1 -registryName "myacr" -resourceGroupName "my-rg"`

**Problem:** Build fails  
**Fix:** `az acr login --name acrsaifpg10081025`

**Problem:** Unicode errors  
**Fix:** Already resolved in Dockerfile (update from repo)

**Problem:** Docker not found (with `-skipPush`)  
**Fix:** Remove `-skipPush` flag (uses ACR Tasks instead)

---

## Output Indicators

| Symbol | Meaning |
|--------|---------|
| 📍 | Current step |
| ✅ | Success |
| ❌ | Error |
| ⚠️  | Warning |
| ℹ️  | Information |
| ⏳ | In progress |

---

## CI/CD Integration

### Azure DevOps
```yaml
- script: .\scripts\Build-SAIF-Containers.ps1 -tag "$(Build.BuildNumber)" -parallel -restartApps
  displayName: 'Build Containers'
```

### GitHub Actions
```yaml
- run: .\scripts\Build-SAIF-Containers.ps1 -tag "${{ github.sha }}" -parallel -restartApps
  shell: pwsh
```

---

## Next Steps After Build

```powershell
# 1. Verify images
az acr repository list --name acrsaifpg10081025

# 2. Test API
Invoke-RestMethod https://app-saifpg-api-10081025.azurewebsites.net/api/healthcheck

# 3. View dashboard
Start-Process https://app-saifpg-web-10081025.azurewebsites.net

# 4. Monitor logs
az webapp log tail --name app-saifpg-api-10081025 --resource-group rg-saif-pgsql-swc-01
```

---

**Full Documentation:** See `BUILD-CONTAINERS-GUIDE.md`  
**Version:** 1.0.0 | **Date:** 2025-10-09
