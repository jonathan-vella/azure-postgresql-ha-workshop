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

@description('Tags for the resources')
param tags object = {}

resource appService 'Microsoft.Web/sites@2022-03-01' = {
  name: appServiceName
  location: location
  tags: tags
  properties: {
    serverFarmId: appServicePlanId
    siteConfig: {
      appSettings: environmentVariables
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

// Set the Docker container configuration
resource appServiceConfig 'Microsoft.Web/sites/config@2022-03-01' = {
  name: '${appService.name}/web'
  properties: {
    appCommandLine: ''
    dockerRegistryUrl: containerRegistryUrl
    dockerRegistryUsername: containerRegistryUsername
    dockerRegistryPassword: containerRegistryPassword
  }
}

output appServiceName string = appService.name
output defaultHostname string = appService.properties.defaultHostName
