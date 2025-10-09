# SAIF-PostgreSQL Troubleshooting Guide

**Last Updated**: 2025-10-09  
**Version**: 1.1.0

This comprehensive guide covers all known issues, their root causes, and solutions for the SAIF-PostgreSQL payment gateway application.

## Table of Contents

- [Quick Diagnosis](#quick-diagnosis)
- [Common Issues](#common-issues)
  - [Application Not Working](#1-application-not-working-no-transactions-found)
  - [Payment Processing Failures](#2-payment-processing-failures)
  - [Database Connection Issues](#3-database-connection-issues)
  - [Container Deployment Issues](#4-container-deployment-issues)
  - [Browser Caching Problems](#5-browser-caching-problems)
  - [Diagnostic Endpoints Not Working](#6-diagnostic-endpoints-not-working)
- [Root Cause Analysis](#root-cause-analysis)
- [Prevention Strategies](#prevention-strategies)
- [Support Resources](#support-resources)

---

## Quick Diagnosis

Use this flowchart to quickly identify your issue:

```
Application Not Working?
│
├─► No transactions showing?
│   └─► See Issue #1: Application Not Working
│
├─► Payment processing fails?
│   ├─► "Invalid API Key" → See Issue #2: Payment Processing
│   ├─► "Not Found" (404) → See Issue #2: Payment Processing
│   └─► "Network error" → See Issue #5: Browser Caching
│
├─► Database errors?
│   ├─► "extension uuid-ossp not found" → See Issue #3: Database
│   └─► "Connection refused" → See Issue #3: Database
│
└─► Diagnostic tools not working?
    └─► 404 errors → See Issue #6: Diagnostic Endpoints
```

---

## Common Issues

### 1. Application Not Working (No Transactions Found)

**Symptoms:**
- Web UI displays "No transactions found"
- Dashboard shows 0 transactions
- Database appears empty even after initialization

**Root Causes:**

#### Cause 1A: Azure PostgreSQL Extension Not Enabled

Azure PostgreSQL Flexible Server blocks extensions by default for security. The `uuid-ossp` extension is required for `uuid_generate_v4()` function used in transaction IDs.

**Evidence:**
```bash
$ docker run postgres:16-alpine psql -h <server> -U saifadmin -d saifdb -f init-db.sql
psql:init-db.sql:16: ERROR:  extension "uuid-ossp" is not allow-listed for "azure_pg_admin"
HINT:  Use SET azure.extensions TO list allowed extensions
```

**Solution:**
```powershell
# Enable uuid-ossp extension in Azure
az postgres flexible-server parameter set \
  --resource-group rg-saif-pgsql-swc-01 \
  --server-name psql-saifpg-XXXXXXXX \
  --name azure.extensions \
  --value "UUID-OSSP"

# Create the extension in the database
docker run --rm -e PGPASSWORD="YourPassword" postgres:16-alpine \
  psql -h psql-saifpg-XXXXXXXX.postgres.database.azure.com \
  -U saifadmin -d saifdb \
  -c 'CREATE EXTENSION IF NOT EXISTS "uuid-ossp";'

# Re-run initialization script
docker run --rm -v ${PWD}:/scripts -e PGPASSWORD="YourPassword" postgres:16-alpine \
  psql -h psql-saifpg-XXXXXXXX.postgres.database.azure.com \
  -U saifadmin -d saifdb \
  -f /scripts/init-db.sql
```

**Verification:**
```powershell
# Check that all 8 tables were created
docker run --rm -e PGPASSWORD="YourPassword" postgres:16-alpine \
  psql -h psql-saifpg-XXXXXXXX.postgres.database.azure.com \
  -U saifadmin -d saifdb \
  -c '\dt'

# Should show: customers, merchants, payment_methods, transactions, orders, order_items, transaction_logs, audit_log

# Check transaction count
docker run --rm -e PGPASSWORD="YourPassword" postgres:16-alpine \
  psql -h psql-saifpg-XXXXXXXX.postgres.database.azure.com \
  -U saifadmin -d saifdb \
  -c 'SELECT COUNT(*) FROM transactions;'

# Should show: 7 (demo transactions from init-db.sql)
```

#### Cause 1B: Missing API Endpoints

The frontend JavaScript calls `/api/transactions/recent` and `/api/db-status` endpoints that weren't initially implemented in the API.

**Evidence:**
```javascript
// Browser console error:
GET https://app-saifpg-api-XXXXXXXX.azurewebsites.net/api/transactions/recent 404 (Not Found)
GET https://app-saifpg-api-XXXXXXXX.azurewebsites.net/api/db-status 404 (Not Found)
```

**Solution:**
These endpoints have been added to `api/app.py`. Rebuild the API container:

```powershell
az acr build --registry <your-acr> --image saif/api:latest --file api/Dockerfile ./api
az webapp restart --name app-saifpg-api-XXXXXXXX --resource-group rg-saif-pgsql-swc-01
```

**Verification:**
```powershell
# Test the endpoints
Invoke-RestMethod "https://app-saifpg-api-XXXXXXXX.azurewebsites.net/api/transactions/recent?limit=5"
Invoke-RestMethod "https://app-saifpg-api-XXXXXXXX.azurewebsites.net/api/db-status"
```

#### Cause 1C: SQL Column Name Bug

The SQL query in `/api/transactions/recent` referenced `m.name` instead of the correct column name `m.merchant_name`.

**Evidence:**
```json
{
  "detail": "Failed to retrieve transactions: column m.name does not exist\nLINE 12: m.name as merchant_name\n"
}
```

**Solution:**
Fixed in `api/app.py` line ~565. The query now uses `m.merchant_name` correctly.

---

### 2. Payment Processing Failures

**Symptoms:**
- Clicking "Process Payment" shows "Payment Failed - Not Found"
- Or "Payment Failed - Invalid API Key"
- Or "Payment Failed - Network error or API unavailable"

**Root Causes:**

#### Cause 2A: Incorrect Frontend Endpoint Path

Frontend was calling `/api/process-payment` but the actual API endpoint is `/api/payments/process`.

**Evidence:**
```javascript
// Browser console:
POST https://app-saifpg-api-XXXXXXXX.azurewebsites.net/api/process-payment 404 (Not Found)
```

**Solution:**
Fixed in `web/assets/js/custom.js` line 87. Now correctly calls `/api/payments/process`.

#### Cause 2B: Missing API Key Header

The API requires an `X-API-Key` header, but the frontend wasn't sending it.

**Evidence:**
```json
{
  "detail": "Invalid API Key"
}
```

**Solution:**
Added `X-API-Key` header to payment request in `web/assets/js/custom.js`:

```javascript
const response = await fetch(`${API_BASE_URL}/api/payments/process`, {
    method: 'POST',
    headers: {
        'Content-Type': 'application/json',
        'X-API-Key': 'demo_api_key_12345'
    },
    body: JSON.stringify({ /* payment data */ })
});
```

#### Cause 2C: Decimal Type Conversion Error

The API was multiplying `float` (payment amount) with `Decimal` (merchant fee percentage from PostgreSQL), causing a type error.

**Evidence:**
```json
{
  "detail": "Payment processing failed: unsupported operand type(s) for *: 'float' and 'decimal.Decimal'"
}
```

**Solution:**
Fixed in `api/app.py` line 177 by explicitly converting Decimal to float:

```python
merchant_fee = (payment.amount * float(merchant['fee_percentage']) / 100) + float(merchant['fee_fixed'])
```

#### Cause 2D: Field Name Mismatch

Frontend expected `data.created_at` but API returns `data.transaction_date`.

**Evidence:**
```javascript
// Browser console:
RangeError: Invalid time value
    at formatDate (custom.js:38)
```

**Solution:**
Changed `web/assets/js/custom.js` line 111 to use `data.transaction_date`:

```javascript
<p><strong>Timestamp:</strong> ${formatDate(data.transaction_date)}</p>
```

**Complete Test:**
```powershell
# Test payment processing
$body = @{
    customer_id = 1
    merchant_id = 1
    amount = 99.99
    currency = 'USD'
    description = 'Test payment'
} | ConvertTo-Json

$headers = @{'X-API-Key' = 'demo_api_key_12345'}

Invoke-RestMethod "https://app-saifpg-api-XXXXXXXX.azurewebsites.net/api/payments/process" `
    -Method Post `
    -Body $body `
    -ContentType "application/json" `
    -Headers $headers

# Expected response:
# transaction_id   : <uuid>
# status           : completed
# amount           : 99.99
# currency         : USD
# merchant_fee     : 3.19971
# net_amount       : 96.79029
# transaction_date : <timestamp>
```

---

### 3. Database Connection Issues

**Symptoms:**
- Application shows "Database: Disconnected"
- API health check fails
- Connection timeout errors

**Common Causes:**

#### Cause 3A: Firewall Rules

Azure PostgreSQL Flexible Server has firewall enabled by default.

**Solution:**
```powershell
# Allow Azure services
az postgres flexible-server firewall-rule create \
  --resource-group rg-saif-pgsql-swc-01 \
  --name psql-saifpg-XXXXXXXX \
  --rule-name "AllowAzureServices" \
  --start-ip-address 0.0.0.0 \
  --end-ip-address 0.0.0.0

# Allow your IP for testing
az postgres flexible-server firewall-rule create \
  --resource-group rg-saif-pgsql-swc-01 \
  --name psql-saifpg-XXXXXXXX \
  --rule-name "AllowMyIP" \
  --start-ip-address <your-ip> \
  --end-ip-address <your-ip>
```

#### Cause 3B: Incorrect Connection String

Verify connection string format:

```
Server=<server>.postgres.database.azure.com;
Database=saifdb;
Port=5432;
User Id=saifadmin;
Password=<password>;
Ssl Mode=Require;
```

#### Cause 3C: SSL/TLS Configuration

Azure PostgreSQL requires SSL connections.

**Solution:**
Ensure connection string includes `Ssl Mode=Require` or `sslmode=require`.

**Verification:**
```powershell
# Test connection
docker run --rm -e PGPASSWORD="YourPassword" postgres:16-alpine \
  psql "host=psql-saifpg-XXXXXXXX.postgres.database.azure.com port=5432 dbname=saifdb user=saifadmin sslmode=require" \
  -c "SELECT version();"
```

---

### 4. Container Deployment Issues

**Symptoms:**
- Container build fails
- App service shows old container image
- Changes not reflecting after deployment

**Common Causes:**

#### Cause 4A: ACR Authentication

**Solution:**
```powershell
# Login to ACR
az acr login --name <your-acr>

# Verify authentication
az acr repository list --name <your-acr>
```

#### Cause 4B: App Service Not Pulling Latest Image

Azure App Service caches container images.

**Solution:**
```powershell
# After building new image, restart the web app to force pull
az webapp restart --name app-saifpg-web-XXXXXXXX --resource-group rg-saif-pgsql-swc-01

# Or stop/start to force complete refresh
az webapp stop --name app-saifpg-web-XXXXXXXX --resource-group rg-saif-pgsql-swc-01
az webapp start --name app-saifpg-web-XXXXXXXX --resource-group rg-saif-pgsql-swc-01
```

#### Cause 4C: Build Context Issues

Ensure you're in the correct directory when building:

```powershell
# Build API (from root directory)
az acr build --registry <your-acr> --image saif/api:latest --file api/Dockerfile ./api

# Build Web (from root directory)
az acr build --registry <your-acr> --image saif/web:latest --file web/Dockerfile ./web
```

---

### 5. Browser Caching Problems

**Symptoms:**
- Changes not reflecting in browser
- Old JavaScript code still executing
- "Network error or API unavailable" after fixes deployed

**Root Cause:**
Browser aggressively caches JavaScript files, even after server updates.

**Solution Implemented:**
Added cache-busting timestamp to `web/index.php`:

```html
<script src="/assets/js/custom.js?v=<?php echo time(); ?>"></script>
```

This forces browser to fetch new JavaScript on every page load.

**Manual Workaround:**
If cache-busting isn't working:

1. **Chrome/Edge**: Press F12 → Right-click Refresh button → "Empty Cache and Hard Reload"
2. **Firefox**: Ctrl+Shift+Delete → Clear cache → Reload page
3. **All browsers**: Ctrl+Shift+R (hard refresh)

**Verification:**
```powershell
# Download and verify current JavaScript
$js = Invoke-WebRequest "https://app-saifpg-web-XXXXXXXX.azurewebsites.net/assets/js/custom.js" -UseBasicParsing
$js.Content | Select-String -Pattern "X-API-Key"

# Should show: 'X-API-Key': 'demo_api_key_12345'
```

---

### 6. Diagnostic Endpoints Not Working

**Symptoms:**
- SQL Injection test shows 404
- SSRF test shows 404
- Info Disclosure shows 404

**Root Cause:**
Frontend was calling `/api/vulnerable/*` endpoints, but API has them at different paths.

**Solution:**
Fixed endpoint paths in `web/assets/js/custom.js`:

| Frontend Was Calling | Actual API Endpoint | Fix Applied |
|---------------------|---------------------|-------------|
| `GET /api/vulnerable/sql-version` | `GET /api/sqlversion` | ✅ Fixed |
| `POST /api/vulnerable/curl-url` | `GET /api/curl?url=xxx` | ✅ Fixed |
| `GET /api/vulnerable/print-env` | `GET /api/printenv` | ✅ Fixed |

**Test Diagnostic Tools:**
```powershell
# SQL Version test
Invoke-RestMethod "https://app-saifpg-api-XXXXXXXX.azurewebsites.net/api/sqlversion" `
    -Headers @{'X-API-Key'='demo_api_key_12345'}

# SSRF test (careful with metadata endpoint!)
Invoke-RestMethod "https://app-saifpg-api-XXXXXXXX.azurewebsites.net/api/curl?url=https://example.com"

# Environment variables
Invoke-RestMethod "https://app-saifpg-api-XXXXXXXX.azurewebsites.net/api/printenv" `
    -Headers @{'X-API-Key'='demo_api_key_12345'}
```

---

## Root Cause Analysis

### Timeline of Issues Discovered (October 9, 2025)

| Time | Issue Discovered | Root Cause | Resolution |
|------|------------------|------------|------------|
| T+0 | No transactions showing | Azure PostgreSQL uuid-ossp not enabled | Enabled extension via Azure parameter |
| T+1 | API 404 errors | Missing /api/transactions/recent endpoint | Added endpoint to API |
| T+2 | SQL error in API | Wrong column name (m.name vs m.merchant_name) | Fixed SQL query |
| T+3 | Payment processing 404 | Wrong endpoint path in frontend | Changed to /api/payments/process |
| T+4 | Invalid API Key error | Missing X-API-Key header | Added header to requests |
| T+5 | Type conversion error | float * Decimal incompatibility | Cast Decimal to float |
| T+6 | Invalid time value error | Field name mismatch (created_at vs transaction_date) | Changed field name |
| T+7 | Browser cache | Old JS file cached | Added cache-busting timestamp |
| T+8 | Diagnostic 404 errors | Wrong endpoint paths | Corrected all 3 paths |

### Lessons Learned

1. **Azure PostgreSQL Security**: Extensions must be explicitly allow-listed before they can be created
2. **Type Safety**: Python's dynamic typing requires careful handling of PostgreSQL numeric types
3. **API Contracts**: Frontend and backend must agree on endpoint paths and response schemas
4. **Browser Caching**: Static files need cache-busting strategies for rapid development
5. **End-to-End Testing**: Test complete user flows, not just individual components

---

## Prevention Strategies

### 1. Infrastructure as Code Validation

Add extension enabling to Bicep template:

```bicep
resource postgresConfig 'Microsoft.DBforPostgreSQL/flexibleServers/configurations@2023-03-01-preview' = {
  parent: postgresServer
  name: 'azure.extensions'
  properties: {
    value: 'UUID-OSSP,PG_STAT_STATEMENTS'
    source: 'user-override'
  }
}
```

### 2. Database Initialization Script

Add pre-flight checks to `init-db.sql`:

```sql
-- Verify extension is available
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_available_extensions WHERE name = 'uuid-ossp'
  ) THEN
    RAISE EXCEPTION 'uuid-ossp extension not available. Enable it in Azure first.';
  END IF;
END $$;

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
```

### 3. API Contract Testing

Add integration tests:

```python
def test_payment_endpoint():
    response = client.post("/api/payments/process", 
        json={"customer_id": 1, "merchant_id": 1, "amount": 99.99},
        headers={"X-API-Key": "demo_api_key_12345"})
    assert response.status_code == 200
    assert "transaction_id" in response.json()
    assert "transaction_date" in response.json()  # Not created_at!
```

### 4. Frontend-Backend Integration

Maintain a shared OpenAPI spec and generate TypeScript types:

```yaml
# openapi.yaml
paths:
  /api/payments/process:
    post:
      responses:
        '200':
          content:
            application/json:
              schema:
                properties:
                  transaction_id: {type: string}
                  transaction_date: {type: string, format: date-time}
```

### 5. Deployment Verification

Add health check script:

```powershell
# scripts/Verify-Deployment.ps1
$apiUrl = "https://app-saifpg-api-XXXXXXXX.azurewebsites.net"

# Test health
$health = Invoke-RestMethod "$apiUrl/api/healthcheck"
if ($health.database -ne "connected") { throw "Database not connected" }

# Test transaction listing
$txs = Invoke-RestMethod "$apiUrl/api/transactions/recent?limit=1"
if ($txs.transactions.Count -eq 0) { throw "No transactions found" }

Write-Host "✅ Deployment verified" -ForegroundColor Green
```

---

## Support Resources

### Quick Reference Commands

```powershell
# Check database status
az postgres flexible-server show \
  --resource-group rg-saif-pgsql-swc-01 \
  --name psql-saifpg-XXXXXXXX \
  --query "{state:state, version:version, haState:highAvailability.state}"

# View API logs
az webapp log tail \
  --name app-saifpg-api-XXXXXXXX \
  --resource-group rg-saif-pgsql-swc-01

# View Web logs
az webapp log tail \
  --name app-saifpg-web-XXXXXXXX \
  --resource-group rg-saif-pgsql-swc-01

# Check ACR builds
az acr task list-runs \
  --registry <your-acr> \
  --top 5 \
  --output table
```

### Log Locations

- **API Logs**: Azure Portal → App Service → Log Stream
- **Database Logs**: Azure Portal → PostgreSQL → Server logs
- **Build Logs**: ACR → Tasks → Runs
- **Browser Console**: F12 → Console tab

### Useful Azure CLI Queries

```powershell
# List all resources in resource group
az resource list \
  --resource-group rg-saif-pgsql-swc-01 \
  --output table

# Check App Service configuration
az webapp config show \
  --name app-saifpg-api-XXXXXXXX \
  --resource-group rg-saif-pgsql-swc-01

# View PostgreSQL parameters
az postgres flexible-server parameter list \
  --resource-group rg-saif-pgsql-swc-01 \
  --server-name psql-saifpg-XXXXXXXX \
  --query "[?name=='azure.extensions']"
```

---

## Still Having Issues?

If you've followed this guide and still experiencing problems:

1. **Check Azure Service Health**: [https://status.azure.com](https://status.azure.com)
2. **Review Application Insights**: Look for exceptions and failed requests
3. **Enable Debug Logging**: Set `LOG_LEVEL=DEBUG` in App Service environment variables
4. **Test Locally**: Use `docker-compose up` to reproduce issues locally
5. **Check Firewall Rules**: Ensure App Service can reach PostgreSQL

### Contact Information

- **Project Repository**: [GitHub Issues](https://github.com/jonathan-vella/SAIF)
- **Azure Support**: [Azure Portal Support](https://portal.azure.com/#blade/Microsoft_Azure_Support/HelpAndSupportBlade)

---

**Last Updated**: 2025-10-09  
**Document Version**: 1.1.0  
**Application Version**: 1.0.0-pgsql
