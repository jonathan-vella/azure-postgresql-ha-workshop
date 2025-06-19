// Main Bicep template for SAIF deployment
metadata name = 'SAIF Infrastructure'
metadata description = 'Deploys the infrastructure for SAIF (Secure AI Foundations) hackathon'
metadata owner = 'SAIF Team'
metadata version = '1.0.0'
metadata lastUpdated = '2025-06-19'
metadata documentation = 'https://github.com/your-org/saif/blob/main/docs/deployment.md'

// Parameters
@description('The Azure region where resources will be deployed')
@allowed([
  'swedencentral'
  'germanywestcentral'
])
param location string = 'swedencentral'

@description('The administrator login username for the SQL Server')
param sqlAdminLogin string = 'saifadmin'

@description('The administrator login password for the SQL Server')
@secure()
@minLength(12)
param sqlAdminPassword string

@description('Tags for the resources')
param tags object = {}

// Variables
var uniqueSuffix = substring(uniqueString(resourceGroup().id), 0, 6)
var acrName = 'acrsaif${uniqueSuffix}'
var appServicePlanName = 'plan-saif-${uniqueSuffix}'
var apiAppServiceName = 'app-saif-api-${uniqueSuffix}'
var webAppServiceName = 'app-saif-web-${uniqueSuffix}'
var sqlServerName = 'sql-saif-${uniqueSuffix}'
var sqlDatabaseName = 'saifdb'
var logAnalyticsName = 'log-saif-${uniqueSuffix}'
var appInsightsName = 'ai-saif-${uniqueSuffix}'

// Default tags applied to all resources
var defaultTags = union(tags, {
  Environment: 'hackathon'
  Application: 'SAIF'
  Purpose: 'Security Training'
})

// Create Log Analytics workspace
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsName
  location: location
  tags: defaultTags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

// Create Application Insights
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  tags: defaultTags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
  }
}

// Create Container Registry
resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: acrName
  location: location
  tags: defaultTags
  sku: {
    name: 'Standard'
  }
  properties: {
    adminUserEnabled: false
  }
}

// Create SQL Server
resource sqlServer 'Microsoft.Sql/servers@2023-05-01-preview' = {
  name: sqlServerName
  location: location
  tags: defaultTags
  properties: {
    administratorLogin: sqlAdminLogin
    administratorLoginPassword: sqlAdminPassword
    version: '12.0'
    publicNetworkAccess: 'Enabled'
  }
}

// Create SQL Database
resource sqlDatabase 'Microsoft.Sql/servers/databases@2023-05-01-preview' = {
  parent: sqlServer
  name: sqlDatabaseName
  location: location
  tags: defaultTags
  sku: {
    name: 'S1'
    tier: 'Standard'
  }
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
  }
}

// Create firewall rule to allow Azure services
resource sqlFirewallRule 'Microsoft.Sql/servers/firewallRules@2023-05-01-preview' = {
  parent: sqlServer
  name: 'AllowAzureServices'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// Create App Service Plan
resource appServicePlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: appServicePlanName
  location: location
  tags: defaultTags
  sku: {
    name: 'P1v3'
    tier: 'PremiumV3'
  }
  kind: 'linux'
  properties: {
    reserved: true
  }
}

// Create API App Service
resource apiAppService 'Microsoft.Web/sites@2023-01-01' = {
  name: apiAppServiceName
  location: location
  tags: defaultTags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      linuxFxVersion: 'DOCKER|${acr.properties.loginServer}/saif/api:latest'
      alwaysOn: true
      acrUseManagedIdentityCreds: true
      appSettings: [
        {
          name: 'SQL_SERVER'
          value: sqlServer.properties.fullyQualifiedDomainName
        }
        {
          name: 'SQL_DATABASE'
          value: sqlDatabaseName
        }
        {
          name: 'SQL_USERNAME'
          value: sqlAdminLogin
        }
        {
          name: 'SQL_PASSWORD'
          value: sqlAdminPassword
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights.properties.ConnectionString
        }
      ]
    }
    httpsOnly: true
  }
}

// Create Web App Service
resource webAppService 'Microsoft.Web/sites@2023-01-01' = {
  name: webAppServiceName
  location: location
  tags: defaultTags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      linuxFxVersion: 'DOCKER|${acr.properties.loginServer}/saif/web:latest'
      alwaysOn: true
      acrUseManagedIdentityCreds: true
      appSettings: [
        {
          name: 'API_URL'
          value: 'https://${apiAppService.properties.defaultHostName}'
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights.properties.ConnectionString        }
      ]
    }
    httpsOnly: true
  }
}

// Grant AcrPull permissions to App Services
resource apiAcrRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acr.id, apiAppService.id, 'AcrPull')
  scope: acr
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
    principalId: apiAppService.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource webAcrRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acr.id, webAppService.id, 'AcrPull')
  scope: acr
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
    principalId: webAppService.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Outputs
output resourceGroupName string = resourceGroup().name
output acrName string = acr.name
output acrLoginServer string = acr.properties.loginServer
output apiAppServiceName string = apiAppService.name
output webAppServiceName string = webAppService.name
output apiUrl string = 'https://${apiAppService.properties.defaultHostName}'
output webUrl string = 'https://${webAppService.properties.defaultHostName}'
output sqlServerName string = sqlServer.name
output sqlServerFqdn string = sqlServer.properties.fullyQualifiedDomainName
output sqlDatabaseName string = sqlDatabaseName
output logAnalyticsWorkspaceId string = logAnalytics.id
output appInsightsConnectionString string = appInsights.properties.ConnectionString
