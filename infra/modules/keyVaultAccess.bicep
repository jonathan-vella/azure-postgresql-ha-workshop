// Access Policy module for Key Vault
metadata name = 'Key Vault Access Policy'
metadata description = 'Updates Key Vault access policies for app services'
metadata owner = 'SAIF Team'
metadata version = '1.0.0'
metadata lastUpdated = '2025-06-22'

@description('The name of the Key Vault')
param keyVaultName string

@description('Array of principal IDs to grant Secret User access to')
param secretUserPrincipalIds array = []

// Add role assignment for app services to access Key Vault secrets
@description('Secret User built-in role definition ID')
var secretUserRoleId = '4633458b-17de-408a-b874-0445c86b69e6'

resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' existing = {
  name: keyVaultName
}

// Assign Secret User role to each provided principal ID
resource roleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for (principalId, index) in secretUserPrincipalIds: {
  name: guid(keyVault.id, principalId, secretUserRoleId)
  scope: keyVault
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', secretUserRoleId)
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}]
