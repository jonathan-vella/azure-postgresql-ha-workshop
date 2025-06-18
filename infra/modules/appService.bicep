metadata name = 'App Service'
metadata description = 'Creates an App Service instance for container deployments'
metadata owner = 'SAIF Team'
metadata version = '1.0.0'
metadata lastUpdated = '2025-06-18'
metadata documentation = 'https://github.com/your-org/saif/blob/main/docs/modules.md'

@description('The name of the app service')
param appServiceName string

@description('The Azure region where resources will be deployed')
param location string

@description('The app service plan ID to use')
param appServicePlanId string

@description('Container image to deploy')
param containerImage string

@description('Container registry URL')
param containerRegistryUrl string

@description('Container registry username')
param containerRegistryUsername string

@secure()
@description('Container registry password')
param containerRegistryPassword string

@description('Environment variables for the container')
param environmentVariables array = []

@description('Enable system-assigned managed identity')
param enableManagedIdentity bool = true

@description('Tags for the resources')
param tags object = {}

resource appService 'Microsoft.Web/sites@2022-03-01' = {
  name: appServiceName
  location: location
  tags: tags
  identity: enableManagedIdentity ? {
    type: 'SystemAssigned'
  } : null
  properties: {
    serverFarmId: appServicePlanId
    siteConfig: {
      appSettings: concat(environmentVariables, containerSettings)
      linuxFxVersion: 'DOCKER|${containerImage}'
      alwaysOn: true
      cors: {
        allowedOrigins: ['*'] // Deliberately insecure for challenge
      }
      ftpsState: 'Disabled'
    }
    httpsOnly: true
  }
}

// Add container registry credentials as app settings
var containerSettings = [
  {
    name: 'DOCKER_REGISTRY_SERVER_URL'
    value: containerRegistryUrl
  }
  {
    name: 'DOCKER_REGISTRY_SERVER_USERNAME'
    value: containerRegistryUsername
  }
  {
    name: 'DOCKER_REGISTRY_SERVER_PASSWORD'
    value: containerRegistryPassword
  }
]

// Update the site config with container configuration
resource appServiceConfig 'Microsoft.Web/sites/config@2022-03-01' = {
  parent: appService
  name: 'web'
  properties: {
    appCommandLine: ''
    // Container registry credentials are provided through app settings
  }
}

output appServiceName string = appService.name
output defaultHostname string = appService.properties.defaultHostName
output principalId string = enableManagedIdentity ? appService.identity.principalId : ''
