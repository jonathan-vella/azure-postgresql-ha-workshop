// ============================================================================
// SAIF-PostgreSQL Main Infrastructure Template
// ============================================================================
// This template deploys complete SAIF-PostgreSQL infrastructure including:
// - Azure Container Registry
// - Key Vault for secrets
// - PostgreSQL Flexible Server with Zone-Redundant HA
// - App Service Plan (Linux)
// - API App Service (Python/FastAPI)
// - Web App Service (PHP)
// - Application Insights & Log Analytics
// ============================================================================

targetScope = 'resourceGroup'

// ============================================================================
// PARAMETERS
// ============================================================================

@description('Azure region for all resources')
@allowed([
  'swedencentral'
  'germanywestcentral'
  'eastus'
  'eastus2'
  'westus2'
  'westeurope'
  'northeurope'
])
param location string = 'swedencentral'

@description('Administrator username for PostgreSQL')
@minLength(1)
@maxLength(63)
param postgresAdminLogin string = 'saifadmin'

@description('Administrator password for PostgreSQL')
@minLength(12)
@secure()
param postgresAdminPassword string

@description('PostgreSQL version')
@allowed([
  '16'
  '15'
  '14'
])
param postgresqlVersion string = '16'

@description('PostgreSQL compute SKU')
@allowed([
  'Standard_B2s'    // Burstable: 2 vCore, 4 GB RAM (dev/test)
  'Standard_D2ds_v5' // General Purpose: 2 vCore, 8 GB RAM
  'Standard_D4ds_v5' // General Purpose: 4 vCore, 16 GB RAM (recommended)
  'Standard_D8ds_v5' // General Purpose: 8 vCore, 32 GB RAM
])
param postgresqlSku string = 'Standard_D4ds_v5'

@description('PostgreSQL storage size in GB')
@minValue(32)
@maxValue(16384)
param postgresqlStorageSizeGB int = 128

@description('Enable High Availability')
param enableHighAvailability bool = true

@description('Backup retention period in days')
@minValue(7)
@maxValue(35)
param backupRetentionDays int = 7

@description('API key for demo authentication (insecure by design)')
param apiKey string = 'demo_api_key_12345'

@description('Tags to apply to all resources')
param tags object = {
  Environment: 'Demo'
  Application: 'SAIF-PostgreSQL'
  Purpose: 'Security Training & HA Testing'
}

@description('Unique suffix for resource names (provided by deployment script to ensure uniqueness and avoid conflicts)')
param uniqueSuffix string = substring(uniqueString(resourceGroup().id, resourceGroup().location), 0, 8)

// ============================================================================
// VARIABLES
// ============================================================================

// Use shorter suffix for Key Vault (max 24 chars total)
// Format: kvsaifpg + 8 chars = 16 chars (safe)
var shortSuffix = toLower(uniqueSuffix)

var naming = {
  acr: 'acrsaifpg${shortSuffix}'
  keyVault: 'kvsaifpg${shortSuffix}'  // Shortened prefix for 24-char limit
  postgres: 'psql-saifpg-${shortSuffix}'
  appServicePlan: 'plan-saifpg-${shortSuffix}'
  apiApp: 'app-saifpg-api-${shortSuffix}'
  webApp: 'app-saifpg-web-${shortSuffix}'
  logAnalytics: 'log-saifpg-${shortSuffix}'
  appInsights: 'ai-saifpg-${shortSuffix}'
}

var postgresDatabase = 'saifdb'
var highAvailabilityMode = enableHighAvailability ? 'ZoneRedundant' : 'Disabled'
var skuTier = startsWith(postgresqlSku, 'Standard_B') ? 'Burstable' : 'GeneralPurpose'

// ============================================================================
// LOG ANALYTICS WORKSPACE
// ============================================================================

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: naming.logAnalytics
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
  }
}

// ============================================================================
// APPLICATION INSIGHTS
// ============================================================================

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: naming.appInsights
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
    Flow_Type: 'Bluefield'
    Request_Source: 'rest'
  }
}

// ============================================================================
// KEY VAULT
// ============================================================================

module keyVault 'modules/keyvault/keyvault.bicep' = {
  name: 'keyVault-deployment'
  params: {
    keyVaultName: naming.keyVault
    location: location
    tags: tags
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    enablePurgeProtection: true  // Changed to true to allow recovery of soft-deleted vault
    enableRbacAuthorization: true
    publicNetworkAccess: true
  }
}

// Store PostgreSQL password in Key Vault
resource secretPostgresPassword 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  name: '${naming.keyVault}/POSTGRES-ADMIN-PASSWORD'
  dependsOn: [
    keyVault
  ]
  properties: {
    value: postgresAdminPassword
    contentType: 'text/plain'
    attributes: {
      enabled: true
    }
  }
}

// Store API key in Key Vault
resource secretApiKey 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  name: '${naming.keyVault}/API-KEY'
  dependsOn: [
    keyVault
  ]
  properties: {
    value: apiKey
    contentType: 'text/plain'
    attributes: {
      enabled: true
    }
  }
}

// ============================================================================
// CONTAINER REGISTRY
// ============================================================================

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: naming.acr
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    adminUserEnabled: false
    publicNetworkAccess: 'Enabled'
    networkRuleBypassOptions: 'AzureServices'
  }
}

// ============================================================================
// POSTGRESQL FLEXIBLE SERVER
// ============================================================================

module postgresql 'modules/database/postgresql.bicep' = {
  name: 'postgresql-deployment'
  params: {
    serverName: naming.postgres
    location: location
    administratorLogin: postgresAdminLogin
    administratorPassword: postgresAdminPassword
    postgresqlVersion: postgresqlVersion
    skuTier: skuTier
    skuName: postgresqlSku
    storageSizeGB: postgresqlStorageSizeGB
    highAvailabilityMode: highAvailabilityMode
    availabilityZone: '1'
    standbyAvailabilityZone: '2'
    backupRetentionDays: backupRetentionDays
    geoRedundantBackup: false
    storageAutoGrow: true
    tags: tags
    databaseName: postgresDatabase
  }
}

// ============================================================================
// APP SERVICE PLAN
// ============================================================================

resource appServicePlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: naming.appServicePlan
  location: location
  tags: tags
  kind: 'linux'
  sku: {
    name: 'P1v3'
    tier: 'PremiumV3'
    capacity: 1
  }
  properties: {
    reserved: true // Required for Linux
    zoneRedundant: false
  }
}

// ============================================================================
// API APP SERVICE
// ============================================================================

resource apiAppService 'Microsoft.Web/sites@2023-12-01' = {
  name: naming.apiApp
  location: location
  tags: tags
  kind: 'app,linux,container'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'DOCKER|${acr.properties.loginServer}/saif/api:latest'
      alwaysOn: true
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      http20Enabled: true
      acrUseManagedIdentityCreds: true
      appSettings: [
        {
          name: 'POSTGRES_HOST'
          value: postgresql.outputs.serverFqdn
        }
        {
          name: 'POSTGRES_PORT'
          value: '6432'  // Use PgBouncer connection pooling (6432) instead of direct (5432)
        }
        {
          name: 'POSTGRES_DATABASE'
          value: postgresql.outputs.databaseName
        }
        {
          name: 'POSTGRES_USER'
          value: postgresAdminLogin
        }
        {
          name: 'POSTGRES_PASSWORD'
          value: postgresAdminPassword  // Intentionally exposed for demo - should use Key Vault reference
        }
        {
          name: 'API_KEY'
          value: apiKey  // Intentionally hardcoded for demo
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights.properties.ConnectionString
        }
        {
          name: 'WEBSITES_PORT'
          value: '8000'
        }
      ]
    }
    clientAffinityEnabled: false
  }
}

// ============================================================================
// WEB APP SERVICE
// ============================================================================

resource webAppService 'Microsoft.Web/sites@2023-12-01' = {
  name: naming.webApp
  location: location
  tags: tags
  kind: 'app,linux,container'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'DOCKER|${acr.properties.loginServer}/saif/web:latest'
      alwaysOn: true
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      http20Enabled: true
      acrUseManagedIdentityCreds: true
      appSettings: [
        {
          name: 'API_URL'
          value: 'https://${apiAppService.properties.defaultHostName}'
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights.properties.ConnectionString
        }
      ]
    }
    clientAffinityEnabled: false
  }
}

// ============================================================================
// RBAC ROLE ASSIGNMENTS
// ============================================================================

// ACR Pull role for API App Service
resource apiAcrPullRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acr.id, apiAppService.id, 'AcrPull')
  scope: acr
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
    principalId: apiAppService.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// ACR Pull role for Web App Service
resource webAcrPullRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acr.id, webAppService.id, 'AcrPull')
  scope: acr
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
    principalId: webAppService.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Key Vault Secrets User role for API App Service
resource apiKeyVaultSecretsUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(naming.keyVault, apiAppService.id, 'KeyVaultSecretsUser')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')
    principalId: apiAppService.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// ============================================================================
// OUTPUTS
// ============================================================================

@description('Resource group name')
output resourceGroupName string = resourceGroup().name

@description('Location')
output location string = location

@description('Container Registry name')
output acrName string = acr.name

@description('Container Registry login server')
output acrLoginServer string = acr.properties.loginServer

@description('Key Vault name')
output keyVaultName string = keyVault.outputs.keyVaultName

@description('Key Vault URI')
output keyVaultUri string = keyVault.outputs.keyVaultUri

@description('PostgreSQL server name')
output postgresServerName string = postgresql.outputs.serverName

@description('PostgreSQL server FQDN')
output postgresServerFqdn string = postgresql.outputs.serverFqdn

@description('PostgreSQL database name')
output postgresDatabaseName string = postgresql.outputs.databaseName

@description('PostgreSQL administrator login')
output postgresAdminLogin string = postgresql.outputs.administratorLogin

@description('PostgreSQL HA status')
output postgresHAStatus string = postgresql.outputs.highAvailabilityStatus

@description('PostgreSQL primary zone')
output postgresPrimaryZone string = postgresql.outputs.primaryAvailabilityZone

@description('PostgreSQL standby zone')
output postgresStandbyZone string = postgresql.outputs.standbyAvailabilityZone

@description('API App Service name')
output apiAppName string = apiAppService.name

@description('API App Service URL')
output apiUrl string = 'https://${apiAppService.properties.defaultHostName}'

@description('Web App Service name')
output webAppName string = webAppService.name

@description('Web App Service URL')
output webUrl string = 'https://${webAppService.properties.defaultHostName}'

@description('Application Insights connection string')
output appInsightsConnectionString string = appInsights.properties.ConnectionString

@description('Log Analytics workspace ID')
output logAnalyticsWorkspaceId string = logAnalytics.id
