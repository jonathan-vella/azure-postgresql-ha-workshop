@description('The name of the Azure Container Registry')
param acrName string

@description('The location for the resources')
param location string = resourceGroup().location

@description('The SKU name for the container registry')
param skuName string = 'Basic'

@description('Tags for the resources')
param tags object = {}

resource acr 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' = {
  name: acrName
  location: location
  tags: tags
  sku: {
    name: skuName
  }
  properties: {
    adminUserEnabled: true
  }
}

@description('The URL of the container registry')
output loginServer string = acr.properties.loginServer
output acrName string = acr.name
output acrId string = acr.id
