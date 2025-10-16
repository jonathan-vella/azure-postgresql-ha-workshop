<#
.SYNOPSIS
    Validate that load generator transactions are being written to PostgreSQL database

.DESCRIPTION
    This script connects to PostgreSQL and validates:
    - Transactions table exists
    - New transactions are being inserted in real-time
    - Transaction rate (inserts per second)
    - Transaction distribution across customers and merchants
    - Latest transaction details

.PARAMETER ServerName
    PostgreSQL server FQDN (e.g., pg-cus.postgres.database.azure.com)

.PARAMETER DatabaseName
    Database name (default: saifdb)

.PARAMETER Username
    Database username (default: jonathan)

.PARAMETER Password
    Database password (SecureString or plain string)

.PARAMETER UsePgBouncer
    Use PgBouncer port 6432 (default: true)

.PARAMETER ContinuousMonitoring
    Enable continuous monitoring mode (refreshes every 2 seconds)

.PARAMETER MonitorDuration
    Duration in seconds for continuous monitoring (default: 60)

.EXAMPLE
    .\Validate-Transactions.ps1 -ServerName "pg-cus.postgres.database.azure.com" -Username "jonathan"

.EXAMPLE
    .\Validate-Transactions.ps1 -ServerName "pg-cus.postgres.database.azure.com" -Username "jonathan" -ContinuousMonitoring -MonitorDuration 120

.NOTES
    Author: Azure Principal Architect Agent
    Version: 1.0.0
    Requires: psql (PostgreSQL client) or Npgsql library
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$ServerName,

    [Parameter(Mandatory=$false)]
    [string]$DatabaseName = "saifdb",

    [Parameter(Mandatory=$false)]
    [string]$Username = "jonathan",

    [Parameter(Mandatory=$false)]
    $Password,

    [Parameter(Mandatory=$false)]
    [bool]$UsePgBouncer = $true,

    [Parameter(Mandatory=$false)]
    [switch]$ContinuousMonitoring,

    [Parameter(Mandatory=$false)]
    [int]$MonitorDuration = 60
)

$ErrorActionPreference = "Stop"

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

function Write-Banner {
    param([string]$Message)
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host $Message -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Step {
    param([string]$Message)
    Write-Host "▶ $Message" -ForegroundColor Yellow
}

function Write-Success {
    param([string]$Message)
    Write-Host "✅ $Message" -ForegroundColor Green
}

function Write-Error {
    param([string]$Message)
    Write-Host "❌ $Message" -ForegroundColor Red
}

function Write-Info {
    param([string]$Message)
    Write-Host "ℹ️  $Message" -ForegroundColor Cyan
}

# ============================================================================
# MAIN
# ============================================================================

Write-Banner "🔍 VALIDATING DATABASE TRANSACTIONS"

# Get password if not provided
if (-not $Password) {
    Write-Step "Enter database credentials"
    Write-Host "Username: $Username" -ForegroundColor White
    $Password = Read-Host "Password" -AsSecureString
}

# Convert SecureString to plain text
if ($Password -is [SecureString]) {
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
    $plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
} else {
    $plainPassword = $Password
}

# Ensure server FQDN
if (-not $ServerName.Contains(".")) {
    $ServerName = "$ServerName.postgres.database.azure.com"
}

# Build connection string
$port = if ($UsePgBouncer) { 6432 } else { 5432 }
$connectionString = "Host=$ServerName;Port=$port;Database=$DatabaseName;Username=$Username;Password=$plainPassword;SSL Mode=Require;Timeout=10"

Write-Step "Configuration:"
Write-Host "   Server: $ServerName" -ForegroundColor White
Write-Host "   Database: $DatabaseName" -ForegroundColor White
Write-Host "   Username: $Username" -ForegroundColor White
Write-Host "   Port: $port $(if ($UsePgBouncer) { '(PgBouncer)' } else { '(Direct)' })" -ForegroundColor White
Write-Host ""

# Check if psql is available
$usePsql = $false
$psqlPath = Get-Command psql -ErrorAction SilentlyContinue
if ($psqlPath) {
    $usePsql = $true
    Write-Info "Using psql client: $($psqlPath.Source)"
} else {
    Write-Info "psql not found - will attempt to use Npgsql library"
}

# ============================================================================
# METHOD 1: Using psql (recommended)
# ============================================================================

if ($usePsql) {
    Write-Host ""
    Write-Step "Method 1: Querying with psql client"
    Write-Host ""
    
    # Set password environment variable for psql
    $env:PGPASSWORD = $plainPassword
    
    try {
        # Test 1: Check if transactions table exists
        Write-Info "Test 1: Checking if transactions table exists..."
        $tableCheck = psql -h $ServerName -p $port -U $Username -d $DatabaseName -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_name = 'transactions';" 2>&1
        
        if ($LASTEXITCODE -eq 0 -and $tableCheck -match '\d+' -and [int]$tableCheck -gt 0) {
            Write-Success "Transactions table exists"
        } else {
            Write-Error "Transactions table not found"
            Write-Host "   Create it using: .\scripts\Initialize-Database.ps1" -ForegroundColor Yellow
            exit 1
        }
        
        # Test 2: Get total transaction count
        Write-Host ""
        Write-Info "Test 2: Getting total transaction count..."
        $totalCount = psql -h $ServerName -p $port -U $Username -d $DatabaseName -t -c "SELECT COUNT(*) FROM transactions;" 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            $count = [int]($totalCount.Trim())
            Write-Success "Total transactions in database: $($count.ToString('N0'))"
        } else {
            Write-Error "Failed to count transactions: $totalCount"
        }
        
        # Test 3: Show latest 5 transactions
        Write-Host ""
        Write-Info "Test 3: Latest 5 transactions..."
        $latestQuery = @"
SELECT 
    transaction_id,
    customer_id,
    merchant_id,
    amount,
    status,
    transaction_date
FROM transactions
ORDER BY transaction_date DESC
LIMIT 5;
"@
        
        psql -h $ServerName -p $port -U $Username -d $DatabaseName -c $latestQuery 2>&1
        
        # Test 4: Transaction rate (last 10 seconds)
        Write-Host ""
        Write-Info "Test 4: Transaction rate (last 10 seconds)..."
        $rateQuery = @"
SELECT 
    COUNT(*) as count,
    ROUND(COUNT(*) / 10.0, 2) as tps
FROM transactions
WHERE transaction_date >= NOW() - INTERVAL '10 seconds';
"@
        
        psql -h $ServerName -p $port -U $Username -d $DatabaseName -c $rateQuery 2>&1
        
        # Test 5: Distribution by customer
        Write-Host ""
        Write-Info "Test 5: Transaction distribution by customer..."
        $customerQuery = @"
SELECT 
    customer_id,
    COUNT(*) as transaction_count,
    ROUND(AVG(amount), 2) as avg_amount,
    ROUND(SUM(amount), 2) as total_amount
FROM transactions
GROUP BY customer_id
ORDER BY customer_id;
"@
        
        psql -h $ServerName -p $port -U $Username -d $DatabaseName -c $customerQuery 2>&1
        
        # Test 6: Distribution by merchant
        Write-Host ""
        Write-Info "Test 6: Transaction distribution by merchant..."
        $merchantQuery = @"
SELECT 
    merchant_id,
    COUNT(*) as transaction_count,
    ROUND(AVG(amount), 2) as avg_amount,
    ROUND(SUM(amount), 2) as total_amount
FROM transactions
GROUP BY merchant_id
ORDER BY merchant_id;
"@
        
        psql -h $ServerName -p $port -U $Username -d $DatabaseName -c $merchantQuery 2>&1
        
        # Continuous monitoring mode
        if ($ContinuousMonitoring) {
            Write-Host ""
            Write-Banner "📊 CONTINUOUS MONITORING MODE"
            Write-Info "Monitoring for $MonitorDuration seconds (Ctrl+C to stop)"
            Write-Host ""
            
            $startTime = Get-Date
            $lastCount = [int]($totalCount.Trim())
            $lastTime = $startTime
            
            Write-Host "Time       | Total Txns | New Txns | TPS   | Status" -ForegroundColor Cyan
            Write-Host "-----------|------------|----------|-------|--------" -ForegroundColor Cyan
            
            while (((Get-Date) - $startTime).TotalSeconds -lt $MonitorDuration) {
                Start-Sleep -Seconds 2
                
                $currentTime = Get-Date
                $currentCountRaw = psql -h $ServerName -p $port -U $Username -d $DatabaseName -t -c "SELECT COUNT(*) FROM transactions;" 2>&1
                
                if ($LASTEXITCODE -eq 0) {
                    $currentCount = [int]($currentCountRaw.Trim())
                    $newTxns = $currentCount - $lastCount
                    $elapsed = ($currentTime - $lastTime).TotalSeconds
                    $tps = if ($elapsed -gt 0) { [math]::Round($newTxns / $elapsed, 2) } else { 0 }
                    
                    $status = if ($newTxns -gt 0) { "🟢 Active" } else { "🔴 No new" }
                    
                    Write-Host "$($currentTime.ToString('HH:mm:ss')) | $($currentCount.ToString().PadLeft(10)) | $($newTxns.ToString().PadLeft(8)) | $($tps.ToString().PadLeft(5)) | $status"
                    
                    $lastCount = $currentCount
                    $lastTime = $currentTime
                } else {
                    Write-Host "$($currentTime.ToString('HH:mm:ss')) | ERROR      | -        | -     | ❌ Query failed" -ForegroundColor Red
                }
            }
            
            Write-Host ""
            Write-Success "Monitoring completed"
        }
        
    } finally {
        # Clear password from environment
        $env:PGPASSWORD = $null
    }
    
} else {
    # ============================================================================
    # METHOD 2: Using Npgsql (fallback)
    # ============================================================================
    
    Write-Host ""
    Write-Info "Method 2: Attempting to use Npgsql library..."
    
    # Check if Npgsql is available in libs folder
    $scriptDir = $PSScriptRoot
    if ([string]::IsNullOrEmpty($scriptDir)) {
        $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
    }
    $libsFolder = Join-Path $scriptDir "libs"
    $npgsqlDll = Join-Path $libsFolder "Npgsql.dll"
    
    if (Test-Path $npgsqlDll) {
        try {
            # Load Npgsql
            Add-Type -Path $npgsqlDll -ErrorAction Stop
            
            Write-Success "Npgsql loaded successfully"
            Write-Host ""
            
            # Connect and run queries
            $conn = New-Object Npgsql.NpgsqlConnection($connectionString)
            $conn.Open()
            
            Write-Success "Connected to database"
            Write-Host ""
            
            # Query total count
            Write-Info "Total transaction count..."
            $cmd = $conn.CreateCommand()
            $cmd.CommandText = "SELECT COUNT(*) FROM transactions"
            $totalCount = $cmd.ExecuteScalar()
            Write-Host "   Total: $($totalCount.ToString('N0'))" -ForegroundColor White
            
        # Query latest transactions
        Write-Host ""
        Write-Info "Latest 5 transactions..."
        $cmd.CommandText = "SELECT transaction_id, customer_id, merchant_id, amount, status, transaction_date FROM transactions ORDER BY transaction_date DESC LIMIT 5"
        $reader = $cmd.ExecuteReader()
        
        Write-Host "   TxID | Customer | Merchant | Amount  | Status    | Transaction Date" -ForegroundColor Cyan
            Write-Host "   -----|----------|----------|---------|-----------|-------------------" -ForegroundColor Cyan
            
            while ($reader.Read()) {
                $txId = $reader["transaction_id"]
                $custId = $reader["customer_id"]
                $merchId = $reader["merchant_id"]
                $amount = [decimal]$reader["amount"]
                $status = $reader["status"]
                $created = $reader["transaction_date"]
                
                Write-Host "   $($txId.ToString().PadLeft(5)) | $($custId.ToString().PadLeft(8)) | $($merchId.ToString().PadLeft(8)) | $($amount.ToString('F2').PadLeft(7)) | $($status.PadRight(9)) | $($created.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor White
            }
            $reader.Close()
            
            $conn.Close()
            
        } catch {
            Write-Error "Failed to use Npgsql: $_"
            Write-Host ""
            Write-Info "To install Npgsql, run:"
            Write-Host "   .\scripts\Test-PostgreSQL-Failover.ps1 -ResourceGroupName '<your-rg>'" -ForegroundColor Yellow
            Write-Host "   (This will auto-download Npgsql to libs folder)" -ForegroundColor Yellow
        }
    } else {
        Write-Error "Npgsql library not found"
        Write-Host ""
        Write-Info "SOLUTIONS:" -ForegroundColor Yellow
        Write-Host "   Option 1: Install psql client" -ForegroundColor White
        Write-Host "     - Windows: choco install postgresql (or download from postgresql.org)" -ForegroundColor Yellow
        Write-Host "     - macOS: brew install postgresql" -ForegroundColor Yellow
        Write-Host "     - Linux: sudo apt-get install postgresql-client" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "   Option 2: Install Npgsql library" -ForegroundColor White
        Write-Host "     - Run: .\scripts\Test-PostgreSQL-Failover.ps1 -ResourceGroupName '<your-rg>'" -ForegroundColor Yellow
        Write-Host "     - This will auto-download Npgsql to libs folder" -ForegroundColor Yellow
    }
}

# ============================================================================
# MANUAL VALIDATION COMMANDS
# ============================================================================

Write-Host ""
Write-Banner "📝 MANUAL VALIDATION COMMANDS"

Write-Info "Quick SQL queries you can run manually:"
Write-Host ""

Write-Host "1. Total transaction count:" -ForegroundColor Yellow
Write-Host "   SELECT COUNT(*) FROM transactions;" -ForegroundColor White
Write-Host ""

Write-Host "2. Transaction rate (last minute):" -ForegroundColor Yellow
Write-Host "   SELECT COUNT(*) as count, COUNT(*) / 60.0 as tps" -ForegroundColor White
Write-Host "   FROM transactions" -ForegroundColor White
Write-Host "   WHERE transaction_date >= NOW() - INTERVAL '1 minute';" -ForegroundColor White
Write-Host ""

Write-Host "3. Latest 10 transactions:" -ForegroundColor Yellow
Write-Host "   SELECT * FROM transactions ORDER BY transaction_id DESC LIMIT 10;" -ForegroundColor White
Write-Host ""

Write-Host "4. Monitor new transactions in real-time:" -ForegroundColor Yellow
Write-Host "   SELECT COUNT(*), MAX(transaction_date) FROM transactions;" -ForegroundColor White
Write-Host "   -- Run this every few seconds to see count increasing" -ForegroundColor DarkGray
Write-Host ""

Write-Host "5. Transaction distribution:" -ForegroundColor Yellow
Write-Host "   SELECT customer_id, COUNT(*) as count FROM transactions GROUP BY customer_id;" -ForegroundColor White
Write-Host ""

# Connection command for psql
Write-Info "Connect manually with psql:"
Write-Host "   psql -h $ServerName -p $port -U $Username -d $DatabaseName" -ForegroundColor Cyan
Write-Host ""

# Connection command for Azure Data Studio / pgAdmin
Write-Info "Connection details for GUI tools (Azure Data Studio, pgAdmin, DBeaver):"
Write-Host "   Host: $ServerName" -ForegroundColor White
Write-Host "   Port: $port" -ForegroundColor White
Write-Host "   Database: $DatabaseName" -ForegroundColor White
Write-Host "   Username: $Username" -ForegroundColor White
Write-Host "   SSL Mode: Require" -ForegroundColor White
Write-Host ""

Write-Success "Validation complete!"
Write-Host ""

# Clean up password
$plainPassword = $null
$connectionString = $null
