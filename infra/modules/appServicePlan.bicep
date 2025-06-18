@description('The name of the app service plan')
param appServicePlanName string

@description('The location for the resources')
param location string = resourceGroup().location

@description('The SKU name for the app service plan')
param skuName string = 'B1'

@description('The SKU tier for the app service plan')
param skuTier string = 'Basic'

@description('Tags for the resources')
param tags object = {}

resource appServicePlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: appServicePlanName
  location: location
  tags: tags
  sku: {
    name: skuName
    tier: skuTier
  }
  kind: 'linux'
  properties: {
    reserved: true
  }
}

output appServicePlanId string = appServicePlan.id
