// ============================================================================
// Azure Key Vault Module for Secure Secrets Management
// ============================================================================
// This module deploys Azure Key Vault for storing:
// - PostgreSQL administrator password
// - Application secrets
// - API keys
// ============================================================================

@description('Name of the Key Vault')
param keyVaultName string

@description('Location for the Key Vault')
param location string

@description('SKU name for Key Vault')
@allowed([
  'standard'
  'premium'
])
param skuName string = 'standard'

@description('Enable soft delete')
param enableSoftDelete bool = true

@description('Soft delete retention period in days')
@minValue(7)
@maxValue(90)
param softDeleteRetentionInDays int = 7

@description('Enable purge protection')
param enablePurgeProtection bool = false

@description('Enable RBAC authorization')
param enableRbacAuthorization bool = true

@description('Enable public network access')
param publicNetworkAccess bool = true

@description('Tags to apply to resources')
param tags object = {}

@description('Tenant ID for access policies')
param tenantId string = tenant().tenantId

// ============================================================================
// KEY VAULT
// ============================================================================

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    tenantId: tenantId
    sku: {
      family: 'A'
      name: skuName
    }
    
    // Network ACLs
    publicNetworkAccess: publicNetworkAccess ? 'Enabled' : 'Disabled'
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
    
    // Soft delete and purge protection
    enableSoftDelete: enableSoftDelete
    softDeleteRetentionInDays: softDeleteRetentionInDays
    enablePurgeProtection: enablePurgeProtection
    
    // Authorization
    enableRbacAuthorization: enableRbacAuthorization
    
    // Access policies (empty - using RBAC for demo)
    accessPolicies: []
  }
}

// ============================================================================
// OUTPUTS
// ============================================================================

@description('The resource ID of the Key Vault')
output keyVaultId string = keyVault.id

@description('The name of the Key Vault')
output keyVaultName string = keyVault.name

@description('The URI of the Key Vault')
output keyVaultUri string = keyVault.properties.vaultUri
