// Main Bicep template for SAIF deployment
metadata name = 'SAIF Infrastructure'
metadata description = 'Deploys the infrastructure for SAIF (Secure AI Foundations)'
metadata owner = 'SAIF Team'
metadata version = '1.0.0'
metadata lastUpdated = '2025-06-18'
metadata documentation = 'https://github.com/your-org/saif/blob/main/docs/deployment.md'

// Parameters
@description('The Azure region where resources will be deployed')
@allowed([
  'swedencentral'
  'germanywestcentral'
])
param location string = 'swedencentral'

@description('The name of the environment')
@minLength(4)
@maxLength(16)
param environmentName string = 'saif'

@description('The administrator login username for the SQL Server')
@minLength(1)
param sqlAdminLogin string = 'saifadmin'

@description('The administrator login password for the SQL Server')
@secure()
@minLength(12)
param sqlAdminPassword string = 'ComplexP@ss123' // This should be changed in a production environment

@description('Tags for the resources')
param tags object = {}

// Variables
var randomSuffix = substring(uniqueString(resourceGroup().id), 0, 6)
var acrName = 'saifacr${randomSuffix}'
var appServicePlanName = '${environmentName}-plan-${randomSuffix}'
var apiAppServiceName = '${environmentName}-api-${randomSuffix}'
var webAppServiceName = '${environmentName}-web-${randomSuffix}'
var sqlServerName = '${environmentName}-sql-${randomSuffix}'
var sqlDatabaseName = 'saif'
var logAnalyticsName = '${environmentName}-logs-${randomSuffix}'
var appInsightsName = '${environmentName}-insights-${randomSuffix}'

// Default tags that are applied to all resources
var defaultTags = union(tags, {
  Environment: environmentName
  Owner: 'SAIF Team'
  DeploymentTime: utcNow('yyyy-MM-dd')
  Application: 'SAIF'
})

// Create container registry
module containerRegistry 'modules/containerRegistry.bicep' = {
  name: 'containerRegistry'
  params: {
    acrName: acrName
    location: location
    tags: tags
  }
}

// Create monitoring resources
module monitoring 'modules/monitoring.bicep' = {
  name: 'monitoring'
  params: {
    logAnalyticsName: logAnalyticsName
    location: location
    tags: tags
  }
}

// Create SQL database
module sqlDatabase 'modules/sqlDatabase.bicep' = {
  name: 'sqlDatabase'
  params: {
    sqlServerName: sqlServerName
    sqlDatabaseName: sqlDatabaseName
    sqlAdministratorLogin: sqlAdminLogin
    sqlAdministratorPassword: sqlAdminPassword
    location: location
    tags: tags
  }
}

// Create App Service Plan
module appServicePlan 'modules/appServicePlan.bicep' = {
  name: 'appServicePlan'
  params: {
    appServicePlanName: appServicePlanName
    location: location
    skuName: 'B1'
    skuTier: 'Basic'
    tags: tags
  }
}

// Create API App Service
module apiAppService 'modules/appService.bicep' = {
  name: 'apiAppService'
  params: {
    appServiceName: apiAppServiceName
    location: location
    appServicePlanId: appServicePlan.outputs.appServicePlanId
    containerImage: '${containerRegistry.outputs.loginServer}/saif/api:latest'
    containerRegistryUrl: 'https://${containerRegistry.outputs.loginServer}'
    containerRegistryUsername: listCredentials('Microsoft.ContainerRegistry/registries/${acrName}', '2023-01-01-preview').username
    containerRegistryPassword: listCredentials('Microsoft.ContainerRegistry/registries/${acrName}', '2023-01-01-preview').passwords[0].value
    environmentVariables: [
      {
        name: 'SQL_SERVER'
        value: '${sqlDatabase.outputs.sqlServerFqdn}'
      }
      {
        name: 'SQL_DATABASE'
        value: sqlDatabase.outputs.sqlDatabaseName
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
        name: 'API_KEY'
        value: 'insecure_api_key_12345'  // Deliberately insecure
      }
      {
        name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
        value: monitoring.outputs.appInsightsConnectionString
      }
    ]
    tags: tags
  }
}

// Create Web App Service
module webAppService 'modules/appService.bicep' = {
  name: 'webAppService'
  params: {
    appServiceName: webAppServiceName
    location: location
    appServicePlanId: appServicePlan.outputs.appServicePlanId
    containerImage: '${containerRegistry.outputs.loginServer}/saif/web:latest'
    containerRegistryUrl: 'https://${containerRegistry.outputs.loginServer}'
    containerRegistryUsername: listCredentials('Microsoft.ContainerRegistry/registries/${acrName}', '2023-01-01-preview').username
    containerRegistryPassword: listCredentials('Microsoft.ContainerRegistry/registries/${acrName}', '2023-01-01-preview').passwords[0].value
    environmentVariables: [
      {
        name: 'API_URL'
        value: 'https://${apiAppService.outputs.defaultHostname}'
      }
      {
        name: 'API_KEY'
        value: 'insecure_api_key_12345'  // Deliberately insecure
      }
      {
        name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
        value: monitoring.outputs.appInsightsConnectionString
      }
    ]
    tags: tags
  }
}

// Outputs
output apiUrl string = 'https://${apiAppService.outputs.defaultHostname}'
output webUrl string = 'https://${webAppService.outputs.defaultHostname}'
output sqlServerName string = sqlDatabase.outputs.sqlServerName
output sqlDatabaseName string = sqlDatabase.outputs.sqlDatabaseName
output sqlServerFqdn string = sqlDatabase.outputs.sqlServerFqdn
output acrName string = containerRegistry.outputs.acrName
