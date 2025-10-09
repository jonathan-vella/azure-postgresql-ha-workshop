<#
.SYNOPSIS
    Updates the SAIF-PostgreSQL database with the parameterless load testing function.

.DESCRIPTION
    Adds the create_test_transaction() function without parameters to enable
    simple load testing and failover tests. This function creates transactions
    with random customers, merchants, and amounts.

.PARAMETER ResourceGroupName
    The resource group containing the PostgreSQL server.

.PARAMETER ServerName
    Optional. PostgreSQL server name. Auto-discovered if not specified.

.EXAMPLE
    .\Update-LoadTestFunction.ps1 -ResourceGroupName "rg-saif-pgsql-swc-01"

.NOTES
    Author: Azure Principal Architect
    Version: 1.0.0
    Date: 2025-10-08
    Requires: Azure CLI, PowerShell 7+, Docker
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$false)]
    [string]$ServerName
)

$ErrorActionPreference = "Stop"

#region Helper Functions

function Write-Step {
    param([string]$message)
    Write-Host "📍 $message" -ForegroundColor Yellow
}

function Write-Success {
    param([string]$message)
    Write-Host "✅ $message" -ForegroundColor Green
}

function Write-Error-Custom {
    param([string]$message)
    Write-Host "❌ $message" -ForegroundColor Red
}

function Write-Info {
    param([string]$message)
    Write-Host "ℹ️  $message" -ForegroundColor Cyan
}

#endregion

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host " 📊 Update Load Testing Function" -ForegroundColor White
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Check Azure CLI
Write-Step "Checking Azure CLI authentication..."
try {
    $currentAccount = az account show --query "name" -o tsv
    Write-Success "Authenticated to: $currentAccount"
} catch {
    Write-Error-Custom "Please run 'az login' first"
    exit 1
}

# Discover PostgreSQL server if not specified
if (-not $ServerName) {
    Write-Step "Discovering PostgreSQL server..."
    
    # Get all servers in the resource group
    $serversJson = az postgres flexible-server list `
        --resource-group $ResourceGroupName `
        --output json
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error-Custom "Failed to list PostgreSQL servers"
        exit 1
    }
    
    $servers = $serversJson | ConvertFrom-Json
    
    if ($servers.Count -eq 0) {
        Write-Error-Custom "No PostgreSQL servers found in resource group: $ResourceGroupName"
        exit 1
    }
    
    # Look for SAIF-related server names
    $saifServers = $servers | Where-Object { $_.name -match 'saif|psql' }
    
    if ($saifServers.Count -eq 0) {
        # If no SAIF servers found, use the first one
        $ServerName = $servers[0].name
        Write-Info "No SAIF-specific server found, using: $ServerName"
    } else {
        $ServerName = $saifServers[0].name
        Write-Success "Found server: $ServerName"
    }
}

# Get server FQDN
Write-Step "Getting server details..."
$server = az postgres flexible-server show `
    --resource-group $ResourceGroupName `
    --name $ServerName `
    --query "fullyQualifiedDomainName" `
    --output tsv

Write-Info "Server: $server"

# Get credentials
Write-Step "Enter database connection credentials"
$dbUser = Read-Host "Database username (default: saifadmin)"
if ([string]::IsNullOrWhiteSpace($dbUser)) {
    $dbUser = "saifadmin"
}

$dbPassword = Read-Host "Database password" -AsSecureString
$dbPasswordText = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($dbPassword)
)

# Check Docker
Write-Step "Checking Docker availability..."
try {
    docker --version | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Error-Custom "Docker is not running. Please start Docker Desktop."
        exit 1
    }
    Write-Success "Docker is available"
} catch {
    Write-Error-Custom "Docker not found. Please install Docker Desktop."
    exit 1
}

# Test connection
Write-Step "Testing database connection..."
$testResult = docker run --rm `
    -e PGPASSWORD="$dbPasswordText" `
    postgres:16-alpine `
    psql -h $server -U $dbUser -d saifdb -t -c "SELECT 1;" 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Error-Custom "Database connection failed"
    Write-Host "Error: $testResult" -ForegroundColor Red
    exit 1
}

Write-Success "Connected to database"

# Create the SQL for the new function
$sqlFunction = @"
-- Parameterless load testing function
CREATE OR REPLACE FUNCTION create_test_transaction()
RETURNS UUID AS `$`$
DECLARE
    v_transaction_id UUID;
    v_customer_id INTEGER;
    v_merchant_id INTEGER;
    v_amount DECIMAL(10, 2);
    v_merchant_fee DECIMAL(10, 2);
    v_net_amount DECIMAL(10, 2);
BEGIN
    -- Select random active customer
    SELECT customer_id INTO v_customer_id
    FROM customers
    WHERE status = 'active'
    ORDER BY RANDOM()
    LIMIT 1;
    
    -- Select random active merchant
    SELECT merchant_id INTO v_merchant_id
    FROM merchants
    WHERE status = 'active'
    ORDER BY RANDOM()
    LIMIT 1;
    
    -- Generate random amount between `$5 and `$500
    v_amount := (RANDOM() * 495 + 5)::DECIMAL(10, 2);
    
    -- Calculate fees
    SELECT (fee_percentage / 100) * v_amount + fee_fixed
    INTO v_merchant_fee
    FROM merchants
    WHERE merchant_id = v_merchant_id;
    
    v_net_amount := v_amount - v_merchant_fee;
    
    -- Insert transaction
    INSERT INTO transactions (
        customer_id,
        merchant_id,
        amount,
        merchant_fee,
        net_amount,
        status,
        risk_score
    ) VALUES (
        v_customer_id,
        v_merchant_id,
        v_amount,
        v_merchant_fee,
        v_net_amount,
        'completed',
        FLOOR(RANDOM() * 50)
    ) RETURNING transaction_id INTO v_transaction_id;
    
    RETURN v_transaction_id;
END;
`$`$ LANGUAGE plpgsql;
"@

# Execute the SQL
Write-Step "Creating/updating load testing function..."

# Save SQL to temp file (to handle special characters properly)
$tempSqlFile = [System.IO.Path]::GetTempFileName() + ".sql"
$sqlFunction | Out-File -FilePath $tempSqlFile -Encoding UTF8

try {
    # Execute SQL file using Docker
    $result = docker run --rm `
        -v "${tempSqlFile}:/tmp/update.sql" `
        -e PGPASSWORD="$dbPasswordText" `
        postgres:16-alpine `
        psql -h $server -U $dbUser -d saifdb -f /tmp/update.sql 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Function created/updated successfully"
    } else {
        Write-Error-Custom "Failed to create function"
        Write-Host "Error: $result" -ForegroundColor Red
        exit 1
    }
} finally {
    # Clean up temp file
    if (Test-Path $tempSqlFile) {
        Remove-Item $tempSqlFile -Force -ErrorAction SilentlyContinue
    }
}

# Test the function
Write-Step "Testing the new function..."
$testTxResult = docker run --rm `
    -e PGPASSWORD="$dbPasswordText" `
    postgres:16-alpine `
    psql -h $server -U $dbUser -d saifdb -t -c "SELECT create_test_transaction();" 2>&1

if ($LASTEXITCODE -eq 0) {
    $transactionId = $testTxResult.ToString().Trim()
    Write-Success "Function test successful"
    Write-Info "Created test transaction: $transactionId"
} else {
    Write-Error-Custom "Function test failed"
    Write-Host "Error: $testTxResult" -ForegroundColor Red
    exit 1
}

# Verify transaction count
Write-Step "Verifying transaction count..."
$countResult = docker run --rm `
    -e PGPASSWORD="$dbPasswordText" `
    postgres:16-alpine `
    psql -h $server -U $dbUser -d saifdb -t -c "SELECT COUNT(*) FROM transactions;" 2>&1

if ($LASTEXITCODE -eq 0) {
    $count = $countResult.ToString().Trim()
    Write-Info "Total transactions in database: $count"
}

# Summary
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host " ✅ Update Complete!" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

Write-Info "Usage in failover tests:"
Write-Host '  SELECT create_test_transaction();  -- Creates transaction with random data' -ForegroundColor Gray
Write-Host ""

Write-Info "Usage in PowerShell:"
Write-Host '  docker run --rm -e PGPASSWORD="..." postgres:16-alpine \' -ForegroundColor Gray
Write-Host '    psql -h $serverFqdn -U $dbUser -d saifdb -t -c "SELECT create_test_transaction();"' -ForegroundColor Gray
Write-Host ""

Write-Info "Next steps:"
Write-Host "  1. Run failover test: .\Test-PostgreSQL-Failover.ps1 -ResourceGroupName '$ResourceGroupName'" -ForegroundColor White
Write-Host "  2. Watch dashboard auto-refresh (transactions should increment)" -ForegroundColor White
Write-Host "  3. Verify transaction count increases during load generation" -ForegroundColor White
Write-Host ""

# Clean up sensitive data
$dbPasswordText = $null

Write-Success "Database updated successfully!"
