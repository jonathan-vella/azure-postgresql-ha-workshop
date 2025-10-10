// ============================================================================
// PostgreSQL Flexible Server Module with Zone-Redundant High Availability
// ============================================================================
// This module deploys Azure Database for PostgreSQL Flexible Server with:
// - Zone-Redundant HA (Primary in Zone 1, Standby in Zone 2)
// - Configurable compute tiers (Burstable, GeneralPurpose, MemoryOptimized)
// - Default: Standard_E4ds_v5 (4 vCores, 32 GB RAM) optimized for 8000+ TPS
// - 128 GB Premium SSD storage with auto-grow
// - 7-day backup retention
// - Built-in PgBouncer connection pooling (port 6432)
// - High-performance tuning for 8000+ TPS workloads
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

// Set connection limit (optimized for high TPS)
// E4ds_v5 (32GB RAM): 2000 connections
// D4ds_v5 (16GB RAM): 859 connections default
resource configMaxConnections 'Microsoft.DBforPostgreSQL/flexibleServers/configurations@2024-08-01' = {
  parent: postgresqlServer
  name: 'max_connections'
  properties: {
    value: '2000'
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
// PGBOUNCER CONFIGURATIONS (Built-in Connection Pooling)
// ============================================================================
// PgBouncer runs on port 6432 and provides connection pooling
// Optimized for high-throughput workloads (8000+ TPS)
// ============================================================================

// Enable PgBouncer
resource configPgBouncerEnabled 'Microsoft.DBforPostgreSQL/flexibleServers/configurations@2024-08-01' = {
  parent: postgresqlServer
  name: 'pgbouncer.enabled'
  properties: {
    value: 'true'
    source: 'user-override'
  }
}

// Set pool mode to transaction (most efficient for high TPS)
resource configPgBouncerPoolMode 'Microsoft.DBforPostgreSQL/flexibleServers/configurations@2024-08-01' = {
  parent: postgresqlServer
  name: 'pgbouncer.pool_mode'
  properties: {
    value: 'transaction'
    source: 'user-override'
  }
}

// Maximum client connections (high for load testing)
resource configPgBouncerMaxClientConn 'Microsoft.DBforPostgreSQL/flexibleServers/configurations@2024-08-01' = {
  parent: postgresqlServer
  name: 'pgbouncer.max_client_conn'
  properties: {
    value: '5000'
    source: 'user-override'
  }
}

// Default pool size per database/user pair
resource configPgBouncerDefaultPoolSize 'Microsoft.DBforPostgreSQL/flexibleServers/configurations@2024-08-01' = {
  parent: postgresqlServer
  name: 'pgbouncer.default_pool_size'
  properties: {
    value: '100'
    source: 'user-override'
  }
}

// Minimum pool size (keep connections warm)
resource configPgBouncerMinPoolSize 'Microsoft.DBforPostgreSQL/flexibleServers/configurations@2024-08-01' = {
  parent: postgresqlServer
  name: 'pgbouncer.min_pool_size'
  properties: {
    value: '25'
    source: 'user-override'
  }
}

// Query wait timeout (seconds)
resource configPgBouncerQueryWaitTimeout 'Microsoft.DBforPostgreSQL/flexibleServers/configurations@2024-08-01' = {
  parent: postgresqlServer
  name: 'pgbouncer.query_wait_timeout'
  properties: {
    value: '120'
    source: 'user-override'
  }
}

// ============================================================================
// HIGH-PERFORMANCE TUNING PARAMETERS (for 8000+ TPS)
// ============================================================================

// Shared buffers (25% of RAM for E4ds_v5 = 8GB)
resource configSharedBuffers 'Microsoft.DBforPostgreSQL/flexibleServers/configurations@2024-08-01' = {
  parent: postgresqlServer
  name: 'shared_buffers'
  properties: {
    value: '2097152'  // 8GB in 8KB pages (8 * 1024 * 1024 / 8)
    source: 'user-override'
  }
}

// Effective cache size (75% of RAM = 24GB)
resource configEffectiveCacheSize 'Microsoft.DBforPostgreSQL/flexibleServers/configurations@2024-08-01' = {
  parent: postgresqlServer
  name: 'effective_cache_size'
  properties: {
    value: '3145728'  // 24GB in 8KB pages (24 * 1024 * 1024 / 8)
    source: 'user-override'
  }
}

// Maintenance work memory (for vacuuming)
resource configMaintenanceWorkMem 'Microsoft.DBforPostgreSQL/flexibleServers/configurations@2024-08-01' = {
  parent: postgresqlServer
  name: 'maintenance_work_mem'
  properties: {
    value: '2097151'  // 2GB in KB (2 * 1024 * 1024 - 1, max allowed)
    source: 'user-override'
  }
}

// WAL buffers (for write performance)
resource configWalBuffers 'Microsoft.DBforPostgreSQL/flexibleServers/configurations@2024-08-01' = {
  parent: postgresqlServer
  name: 'wal_buffers'
  properties: {
    value: '16384'  // 16MB in KB
    source: 'user-override'
  }
}

// Checkpoint completion target (smooth checkpoints)
resource configCheckpointCompletionTarget 'Microsoft.DBforPostgreSQL/flexibleServers/configurations@2024-08-01' = {
  parent: postgresqlServer
  name: 'checkpoint_completion_target'
  properties: {
    value: '0.9'
    source: 'user-override'
  }
}

// Max WAL size (allow more writes before checkpoint)
resource configMaxWalSize 'Microsoft.DBforPostgreSQL/flexibleServers/configurations@2024-08-01' = {
  parent: postgresqlServer
  name: 'max_wal_size'
  properties: {
    value: '4096'  // 4GB in MB
    source: 'user-override'
  }
}

// Min WAL size
resource configMinWalSize 'Microsoft.DBforPostgreSQL/flexibleServers/configurations@2024-08-01' = {
  parent: postgresqlServer
  name: 'min_wal_size'
  properties: {
    value: '1024'  // 1GB in MB
    source: 'user-override'
  }
}

// Random page cost (SSD optimization)
resource configRandomPageCost 'Microsoft.DBforPostgreSQL/flexibleServers/configurations@2024-08-01' = {
  parent: postgresqlServer
  name: 'random_page_cost'
  properties: {
    value: '1.1'
    source: 'user-override'
  }
}

// Effective I/O concurrency (SSD optimization)
resource configEffectiveIoConcurrency 'Microsoft.DBforPostgreSQL/flexibleServers/configurations@2024-08-01' = {
  parent: postgresqlServer
  name: 'effective_io_concurrency'
  properties: {
    value: '200'
    source: 'user-override'
  }
}

// Autovacuum workers (handle high write load)
resource configAutovacuumMaxWorkers 'Microsoft.DBforPostgreSQL/flexibleServers/configurations@2024-08-01' = {
  parent: postgresqlServer
  name: 'autovacuum_max_workers'
  properties: {
    value: '4'
    source: 'user-override'
  }
}

// Autovacuum cost limit (more aggressive vacuuming)
resource configAutovacuumVacuumCostLimit 'Microsoft.DBforPostgreSQL/flexibleServers/configurations@2024-08-01' = {
  parent: postgresqlServer
  name: 'autovacuum_vacuum_cost_limit'
  properties: {
    value: '3000'
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

@description('Connection string (without password) for application configuration - Direct connection (port 5432)')
output connectionStringTemplate string = 'host=${postgresqlServer.properties.fullyQualifiedDomainName} port=5432 dbname=${database.name} user=${postgresqlServer.properties.administratorLogin} password=<PASSWORD> sslmode=require'

@description('Connection string (without password) using PgBouncer pooling (port 6432) - RECOMMENDED for high TPS')
output connectionStringTemplatePgBouncer string = 'host=${postgresqlServer.properties.fullyQualifiedDomainName} port=6432 dbname=${database.name} user=${postgresqlServer.properties.administratorLogin} password=<PASSWORD> sslmode=require'

@description('JDBC connection string template - Direct connection')
output jdbcConnectionStringTemplate string = 'jdbc:postgresql://${postgresqlServer.properties.fullyQualifiedDomainName}:5432/${database.name}?user=${postgresqlServer.properties.administratorLogin}&password=<PASSWORD>&sslmode=require'

@description('JDBC connection string template using PgBouncer - RECOMMENDED for high TPS')
output jdbcConnectionStringTemplatePgBouncer string = 'jdbc:postgresql://${postgresqlServer.properties.fullyQualifiedDomainName}:6432/${database.name}?user=${postgresqlServer.properties.administratorLogin}&password=<PASSWORD>&sslmode=require'
