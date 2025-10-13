# SAIF-PostgreSQL Quick Reference Card

**Version 2.0.0** | **Date: 2025-10-09**

---

## 🚀 Quick Commands

### Full Deployment (New Environment)

```powershell
# Interactive (prompts for password)
cd c:\Repos\SAIF\SAIF-pgsql\scripts
.\Deploy-SAIF-PostgreSQL.ps1 -location "swedencentral"

# Automated with password
$pwd = ConvertTo-SecureString "YourPassword123!" -AsPlainText -Force
.\Deploy-SAIF-PostgreSQL.ps1 -location "swedencentral" -postgresqlPassword $pwd -autoApprove

# Quick deploy with auto-generated password
.\Quick-Deploy-SAIF.ps1 -environmentName "dev"
```

⏱️ **Time:** 25-30 minutes  
📦 **Includes:** Infrastructure + Containers + Database + Validation

---

### Container Updates Only

```powershell
# Rebuild both containers
.\Rebuild-SAIF-Containers.ps1 -resourceGroupName "rg-saif-pgsql-swc-01"

# Rebuild API only
.\Rebuild-SAIF-Containers.ps1 -resourceGroupName "rg-saif-pgsql-swc-01" -buildApi

# Rebuild Web only
.\Rebuild-SAIF-Containers.ps1 -resourceGroupName "rg-saif-pgsql-swc-01" -buildWeb
```

⏱️ **Time:** 5-10 minutes (80% faster!)  
📦 **Updates:** Application code only, no infrastructure changes

---

## 📋 Script Overview

| Script | Purpose | Use When |
|--------|---------|----------|
| **Deploy-SAIF-PostgreSQL.ps1** | Complete deployment | First deployment, infrastructure changes |
| **Quick-Deploy-SAIF.ps1** | Simplified deployment | Demos, testing, CI/CD pipelines |
| **Rebuild-SAIF-Containers.ps1** | Container updates | Application code changes only |

---

## 🎯 Common Scenarios

### Scenario 1: First Time Setup
```powershell
.\Quick-Deploy-SAIF.ps1 -location "swedencentral" -environmentName "dev"
```

### Scenario 2: Update Application Code
```powershell
# Make your code changes, then:
.\Rebuild-SAIF-Containers.ps1 -resourceGroupName "rg-saif-pgsql-swc-01"
```

### Scenario 3: Production Deployment
```powershell
$pwd = ConvertTo-SecureString "SecureP@ssw0rd!" -AsPlainText -Force
.\Deploy-SAIF-PostgreSQL.ps1 `
    -location "swedencentral" `
    -postgresqlPassword $pwd `
    -postgresqlSku "Standard_D4ds_v5" `
    -autoApprove
```

### Scenario 4: Dev Environment (Cost Optimized)
```powershell
.\Quick-Deploy-SAIF.ps1 `
    -environmentName "dev" `
    -disableHighAvailability
```

### Scenario 5: Infrastructure Only
```powershell
$pwd = ConvertTo-SecureString "YourPassword!" -AsPlainText -Force
.\Deploy-SAIF-PostgreSQL.ps1 `
    -location "swedencentral" `
    -postgresqlPassword $pwd `
    -skipContainers `
    -autoApprove

# Build containers later
.\Rebuild-SAIF-Containers.ps1 -resourceGroupName "rg-saif-pgsql-swc-01"
```

---

## 🔧 Parameters Quick Reference

### Deploy-SAIF-PostgreSQL.ps1

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `-location` | string | swedencentral | Azure region |
| `-resourceGroupName` | string | auto | Resource group name |
| `-postgresqlPassword` | SecureString | prompt | Admin password |
| `-postgresqlSku` | string | Standard_D4ds_v5 | PostgreSQL SKU |
| `-disableHighAvailability` | switch | false | Disable HA |
| `-skipContainers` | switch | false | Skip container builds |
| `-autoApprove` | switch | false | Skip prompts |

### Quick-Deploy-SAIF.ps1

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `-location` | string | swedencentral | Azure region |
| `-environmentName` | string | dev | Environment (dev/test/staging/prod) |
| `-postgresqlPassword` | SecureString | auto-generate | Admin password |
| `-skipContainers` | switch | false | Skip container builds |
| `-disableHighAvailability` | switch | false | Disable HA |

### Rebuild-SAIF-Containers.ps1

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `-resourceGroupName` | string | required | Resource group name |
| `-buildApi` | switch | false | Build API only |
| `-buildWeb` | switch | false | Build Web only |
| `-skipRestart` | switch | false | Don't restart services |
| `-tag` | string | latest | Image tag |

---

## 🩺 Health Checks

### API Health Check
```powershell
Invoke-RestMethod "https://<app-name>.azurewebsites.net/api/healthcheck"
# Expected: { "status": "healthy", "database": "connected" }
```

### Web Health Check
```powershell
Invoke-WebRequest "https://<app-name>.azurewebsites.net"
# Expected: Status 200 OK
```

### PostgreSQL HA Status
```powershell
az postgres flexible-server show `
    --name <server-name> `
    --resource-group <rg-name> `
    --query "{state:state, haState:highAvailability.state}"
# Expected: state=Ready, haState=Healthy
```

---

## ⚠️ Troubleshooting Quick Fixes

### Issue: App Services Won't Start
```powershell
# Check if containers exist
az acr repository list --name <acrName>

# If missing, rebuild
.\Rebuild-SAIF-Containers.ps1 -resourceGroupName <rgName>
```

### Issue: Deployment Hangs
```powershell
# Check deployment status
az deployment group list --resource-group <rgName> --output table

# The updated script handles this automatically with retries
```

### Issue: Can't Connect to Database
```powershell
# Check firewall rules
az postgres flexible-server firewall-rule list `
    --resource-group <rgName> `
    --name <serverName>

# Add your IP
az postgres flexible-server firewall-rule create `
    --resource-group <rgName> `
    --name <serverName> `
    --rule-name "MyIP" `
    --start-ip-address <yourIP> `
    --end-ip-address <yourIP>
```

---

## 📊 Cost Estimates

| Environment | Configuration | Monthly Cost |
|-------------|--------------|--------------|
| **Dev** | D2ds_v5, No HA | ~$250 |
| **Test** | D2ds_v5, HA | ~$500 |
| **Staging** | D4ds_v5, HA | ~$910 |
| **Production** | D4ds_v5, HA | ~$910 |

💡 **Tip:** Use `-disableHighAvailability` for dev/test to save ~50%

---

## 🔗 Documentation Links

- **Full Deployment Guide:** `docs/v1.0.0/deployment-guide.md`
- **Failover Testing:** `docs/v1.0.0/failover-testing-guide.md`
- **Enhancement Summary:** `docs/v1.0.0/deployment-enhancements-summary.md`
- **This Quick Ref:** `docs/v1.0.0/quick-reference.md`

---

## 📞 Getting Help

```powershell
# View script help
Get-Help .\Deploy-SAIF-PostgreSQL.ps1 -Full
Get-Help .\Quick-Deploy-SAIF.ps1 -Full
Get-Help .\Rebuild-SAIF-Containers.ps1 -Full

# Check Azure CLI
az account show
az postgres flexible-server --help
```

---

## ✅ Pre-Flight Checklist

Before deploying, verify:
- [ ] Azure CLI installed and logged in (`az login`)
- [ ] PowerShell 7+ installed (`$PSVersionTable.PSVersion`)
- [ ] Sufficient Azure quota (PostgreSQL, App Services, ACR)
- [ ] Target region supports availability zones (for HA)
- [ ] Password meets requirements (12+ chars, mixed case, numbers)

---

**Last Updated:** 2025-10-09  
**Version:** 2.0.0  
**Repository:** https://github.com/jonathan-vella/SAIF
