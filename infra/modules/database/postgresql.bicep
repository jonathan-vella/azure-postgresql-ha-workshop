// ============================================================================
// PostgreSQL Flexible Server Module with Zone-Redundant High Availability
// ============================================================================
// This module deploys Azure Database for PostgreSQL Flexible Server with:
// - Zone-Redundant HA (Primary in Zone 1, Standby in Zone 2)
// - Standard_D4ds_v5 compute tier (4 vCores, 16 GB RAM)
// - 128 GB Premium SSD storage with auto-grow
// - 7-day backup retention
// - Public access with firewall rules
// - Integration with Key Vault for secure credential storage
// ============================================================================

@description('Name of the PostgreSQL Flexible Server')
param serverName string

@description('Location for the PostgreSQL server')
param location string

@description('Administrator username for PostgreSQL')
param administratorLogin string

@description('Administrator password for PostgreSQL')
@secure()
param administratorPassword string

@description('PostgreSQL version')
@allowed([
  '16'
  '15'
  '14'
])
param postgresqlVersion string = '16'

@description('Compute tier for the server')
@allowed([
  'Burstable'
  'GeneralPurpose'
  'MemoryOptimized'
])
param skuTier string = 'GeneralPurpose'

@description('Compute SKU name')
param skuName string = 'Standard_D4ds_v5'

@description('Storage size in GB')
param storageSizeGB int = 128

@description('High availability mode')
@allowed([
  'Disabled'
  'ZoneRedundant'
  'SameZone'
])
param highAvailabilityMode string = 'ZoneRedundant'

@description('Availability zone for primary server')
param availabilityZone string = '1'

@description('Availability zone for standby server')
param standbyAvailabilityZone string = '2'

@description('Backup retention period in days')
@minValue(7)
@maxValue(35)
param backupRetentionDays int = 7

@description('Enable geo-redundant backup')
param geoRedundantBackup bool = false

@description('Enable storage auto-grow')
param storageAutoGrow bool = true

@description('Tags to apply to resources')
param tags object = {}

@description('Database name to create')
param databaseName string = 'saifdb'

// ============================================================================
// POSTGRESQL FLEXIBLE SERVER
// ============================================================================

resource postgresqlServer 'Microsoft.DBforPostgreSQL/flexibleServers@2024-08-01' = {
  name: serverName
  location: location
  tags: tags
  sku: {
    name: skuName
    tier: skuTier
  }
  properties: {
    version: postgresqlVersion
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorPassword
    
    // Storage configuration
    storage: {
      storageSizeGB: storageSizeGB
      autoGrow: storageAutoGrow ? 'Enabled' : 'Disabled'
    }
    
    // Backup configuration
    backup: {
      backupRetentionDays: backupRetentionDays
      geoRedundantBackup: geoRedundantBackup ? 'Enabled' : 'Disabled'
    }
    
    // High Availability configuration
    highAvailability: {
      mode: highAvailabilityMode
      standbyAvailabilityZone: highAvailabilityMode == 'ZoneRedundant' ? standbyAvailabilityZone : null
    }
    
    // Availability zone for primary
    availabilityZone: availabilityZone
    
    // Network configuration - Public access for demo
    network: {
      publicNetworkAccess: 'Enabled'
    }
    
    // Authentication configuration
    authConfig: {
      activeDirectoryAuth: 'Disabled'
      passwordAuth: 'Enabled'
    }
  }
}

// ============================================================================
// DATABASE
// ============================================================================

resource database 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2024-08-01' = {
  parent: postgresqlServer
  name: databaseName
  properties: {
    charset: 'UTF8'
    collation: 'en_US.utf8'
  }
}

// ============================================================================
// FIREWALL RULES
// ============================================================================

// Allow Azure services to access the server
resource firewallRuleAzureServices 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2024-08-01' = {
  parent: postgresqlServer
  name: 'AllowAllAzureServicesAndResourcesWithinAzureIps'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// Allow all IPs for demo (INSECURE - for educational purposes only)
resource firewallRuleAllIPs 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2024-08-01' = {
  parent: postgresqlServer
  name: 'AllowAllIPs'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '255.255.255.255'
  }
}

// ============================================================================
// SERVER CONFIGURATIONS
// ============================================================================

// Enable query performance insights
resource configQueryPerformance 'Microsoft.DBforPostgreSQL/flexibleServers/configurations@2024-08-01' = {
  parent: postgresqlServer
  name: 'pg_stat_statements.track'
  properties: {
    value: 'all'
    source: 'user-override'
  }
}

// Set connection limit (default for D4ds_v5 is ~859)
resource configMaxConnections 'Microsoft.DBforPostgreSQL/flexibleServers/configurations@2024-08-01' = {
  parent: postgresqlServer
  name: 'max_connections'
  properties: {
    value: '200'
    source: 'user-override'
  }
}

// Enable auto-vacuum for performance
resource configAutovacuum 'Microsoft.DBforPostgreSQL/flexibleServers/configurations@2024-08-01' = {
  parent: postgresqlServer
  name: 'autovacuum'
  properties: {
    value: 'on'
    source: 'user-override'
  }
}

// Set work_mem for better query performance (payment processing)
resource configWorkMem 'Microsoft.DBforPostgreSQL/flexibleServers/configurations@2024-08-01' = {
  parent: postgresqlServer
  name: 'work_mem'
  properties: {
    value: '16384'  // 16 MB
    source: 'user-override'
  }
}

// Enable logging for troubleshooting
resource configLogConnections 'Microsoft.DBforPostgreSQL/flexibleServers/configurations@2024-08-01' = {
  parent: postgresqlServer
  name: 'log_connections'
  properties: {
    value: 'on'
    source: 'user-override'
  }
}

resource configLogDisconnections 'Microsoft.DBforPostgreSQL/flexibleServers/configurations@2024-08-01' = {
  parent: postgresqlServer
  name: 'log_disconnections'
  properties: {
    value: 'on'
    source: 'user-override'
  }
}

// ============================================================================
// DIAGNOSTIC SETTINGS (Optional - for monitoring)
// ============================================================================

// Note: Diagnostic settings require Log Analytics workspace
// Uncomment below if logAnalyticsWorkspaceId parameter is provided

/*
resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${serverName}-diagnostics'
  scope: postgresqlServer
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'PostgreSQLLogs'
        enabled: true
      }
      {
        category: 'PostgreSQLFlexSessions'
        enabled: true
      }
      {
        category: 'PostgreSQLFlexQueryStoreRuntime'
        enabled: true
      }
      {
        category: 'PostgreSQLFlexQueryStoreWaitStats'
        enabled: true
      }
      {
        category: 'PostgreSQLFlexTableStats'
        enabled: true
      }
      {
        category: 'PostgreSQLFlexDatabaseXacts'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}
*/

// ============================================================================
// OUTPUTS
// ============================================================================

@description('The resource ID of the PostgreSQL server')
output serverId string = postgresqlServer.id

@description('The name of the PostgreSQL server')
output serverName string = postgresqlServer.name

@description('The FQDN of the PostgreSQL server')
output serverFqdn string = postgresqlServer.properties.fullyQualifiedDomainName

@description('The database name')
output databaseName string = database.name

@description('The administrator login')
output administratorLogin string = postgresqlServer.properties.administratorLogin

@description('High availability status')
output highAvailabilityStatus string = postgresqlServer.properties.highAvailability.state

@description('Primary availability zone')
output primaryAvailabilityZone string = postgresqlServer.properties.availabilityZone

@description('Standby availability zone')
output standbyAvailabilityZone string = postgresqlServer.properties.highAvailability.standbyAvailabilityZone

@description('Connection string (without password) for application configuration')
output connectionStringTemplate string = 'host=${postgresqlServer.properties.fullyQualifiedDomainName} port=5432 dbname=${database.name} user=${postgresqlServer.properties.administratorLogin} password=<PASSWORD> sslmode=require'

@description('JDBC connection string template')
output jdbcConnectionStringTemplate string = 'jdbc:postgresql://${postgresqlServer.properties.fullyQualifiedDomainName}:5432/${database.name}?user=${postgresqlServer.properties.administratorLogin}&password=<PASSWORD>&sslmode=require'
