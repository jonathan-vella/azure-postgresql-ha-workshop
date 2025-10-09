# Database Scripts

This folder contains SQL initialization and maintenance scripts for the SAIF PostgreSQL database.

## Files

### init-db.sql
**Purpose**: Complete database schema initialization

**Contains**:
- `uuid-ossp` extension enablement
- Table schemas: `customers`, `merchants`, `transactions`
- Indexes for performance optimization
- Test data generation functions:
  - `create_test_transaction()` - Parameterless overload for automated testing
  - `create_test_transaction(num_transactions, initial_id)` - Bulk generation with ID control
  - `generate_test_data(num_customers, num_merchants)` - Initial dataset creation
- Sample data insertion (10 customers, 5 merchants)

**Usage**:
```bash
# Initialize database from Azure Cloud Shell or local environment
psql -h <server-name>.postgres.database.azure.com -U <username> -d saifdb -f init-db.sql

# Or using Docker container
docker exec -i saif-api-1 psql -U postgres -d saifdb < init-db.sql
```

**Key Features**:
- UUID-based transaction IDs for distributed systems
- Indexed columns for query performance
- Automatic timestamp generation
- Foreign key relationships for data integrity

---

### cleanup-db.sql
**Purpose**: Database cleanup and reset procedures

**Contains**:
- Transaction table cleanup
- Reset sequences and counters
- Remove test data
- Prepare database for fresh testing

**Usage**:
```bash
# Clean up test data
psql -h <server-name>.postgres.database.azure.com -U <username> -d saifdb -f cleanup-db.sql

# Or using Docker
docker exec -i saif-api-1 psql -U postgres -d saifdb < cleanup-db.sql
```

**When to Use**:
- Before performance testing
- After completing failover tests
- When resetting to baseline state

---

### enable-uuid.sql
**Purpose**: Enable UUID extension for transaction ID generation

**Contains**:
- `CREATE EXTENSION IF NOT EXISTS "uuid-ossp"`
- Required for `init-db.sql` to function

**Usage**:
```bash
# Standalone enablement (only needed if init-db.sql hasn't been run)
psql -h <server-name>.postgres.database.azure.com -U <username> -d saifdb -f enable-uuid.sql
```

**Note**: This extension is automatically enabled by `init-db.sql`, so standalone execution is rarely needed.

---

## Execution Order

For initial database setup:
1. `enable-uuid.sql` (optional - included in init-db.sql)
2. `init-db.sql` (required - creates schema and test data)
3. `cleanup-db.sql` (optional - only when resetting)

## Related Scripts

- `scripts/Initialize-Database.ps1` - Automated database initialization with Azure resource discovery
- `scripts/Test-PostgreSQL-Failover.ps1` - Uses `create_test_transaction()` for load generation
- `scripts/Update-LoadTestFunction.ps1` - Deploys updated database functions

## Connection Information

See the main [README.md](../README.md) for server details and connection instructions.
