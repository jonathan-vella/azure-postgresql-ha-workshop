metadata name = 'Key Vault'
metadata description = 'Creates an Azure Key Vault for secure storage of secrets'
metadata owner = 'SAIF Team'
metadata version = '1.0.0'
metadata lastUpdated = '2025-06-22'
metadata documentation = 'https://github.com/your-org/saif/blob/main/docs/modules.md'

@description('The name of the Key Vault')
param keyVaultName string

@description('The Azure region where resources will be deployed')
param location string = resourceGroup().location

@description('Tags for the resources')
param tags object = {}

@description('The tenant ID for the Azure AD tenant')
param tenantId string = subscription().tenantId

@secure()
@description('SQL Administrator password to store in Key Vault')
param sqlAdminPassword string = ''

// Principal IDs will be managed by keyVaultAccess.bicep module

resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: tenantId
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
  }
}

// Create SQL password secret if provided
resource sqlPasswordSecret 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = if (!empty(sqlAdminPassword)) {
  parent: keyVault
  name: 'sql-password'
  properties: {
    value: sqlAdminPassword
  }
}

// Role assignments will be managed by keyVaultAccess.bicep module

output keyVaultName string = keyVault.name
output keyVaultUri string = keyVault.properties.vaultUri
