@description('The name of the SQL server')
param sqlServerName string

@description('The name of the SQL database')
param sqlDatabaseName string

@description('The administrator login username for the SQL server')
param sqlAdministratorLogin string

@secure()
@description('The administrator login password for the SQL server')
param sqlAdministratorPassword string

@description('The location for the resources')
param location string = resourceGroup().location

@description('Tags for the resources')
param tags object = {}

// SQL Server - deliberately not secure for challenge purposes
resource sqlServer 'Microsoft.Sql/servers@2022-05-01-preview' = {
  name: sqlServerName
  location: location
  tags: tags
  properties: {
    administratorLogin: sqlAdministratorLogin
    administratorLoginPassword: sqlAdministratorPassword
    publicNetworkAccess: 'Enabled'  // Deliberately insecure
    minimalTlsVersion: '1.0'        // Deliberately insecure
  }
}

// Allow Azure services to access the SQL Server - deliberately insecure
resource sqlServerFirewallRule 'Microsoft.Sql/servers/firewallRules@2022-05-01-preview' = {
  parent: sqlServer
  name: 'AllowAllAzureIPs'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// SQL Database
resource sqlDatabase 'Microsoft.Sql/servers/databases@2022-05-01-preview' = {
  parent: sqlServer
  name: sqlDatabaseName
  location: location
  tags: tags
  sku: {
    name: 'Basic'
    tier: 'Basic'
  }
}

output sqlServerName string = sqlServer.name
output sqlServerFqdn string = '${sqlServer.name}${environment().suffixes.sqlServerHostname}'
output sqlDatabaseName string = sqlDatabaseName
