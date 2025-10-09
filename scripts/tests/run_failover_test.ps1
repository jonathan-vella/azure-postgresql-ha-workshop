#!/usr/bin/env pwsh
<#
.SYNOPSIS
    PostgreSQL Failover Load Test Runner - Demo Configuration

.DESCRIPTION
    This script automatically configures and runs the PostgreSQL failover load test
    with all necessary connection parameters pre-configured.

.PARAMETER Duration
    Test duration in seconds (default: 300 = 5 minutes)

.PARAMETER Workers
    Number of concurrent write workers (default: 10)

.PARAMETER WritesPerSecond
    Target write operations per second (default: 50)

.PARAMETER FailoverPromptSeconds
    When to prompt user to trigger failover (default: 90 seconds)
    Set to 0 to disable the prompt

.EXAMPLE
    .\run_failover_test.ps1
    Runs the test with default settings for 5 minutes (300 seconds)
    Prompts to trigger failover at 90 seconds

.EXAMPLE
    .\run_failover_test.ps1 -Duration 600 -Workers 20 -WritesPerSecond 100
    Runs for 10 minutes with higher load

.EXAMPLE
    .\run_failover_test.ps1 -Duration 120
    Runs a quick 2-minute test

.EXAMPLE
    .\run_failover_test.ps1 -FailoverPromptSeconds 60
    Prompts to trigger failover after 60 seconds instead of 90

.EXAMPLE
    .\run_failover_test.ps1 -FailoverPromptSeconds 0
    Disables the failover prompt (manual failover only)
#>

param(
    [int]$Duration = 300,
    [int]$Workers = 10,
    [int]$WritesPerSecond = 50,
    [string]$ResourceGroup = "",
    [string]$ServerName = "",
    [int]$FailoverPromptSeconds = 90
)

# ============================================================================
# Automatic Resource Discovery from AZD Environment
# ============================================================================
Write-Host "🔍 Discovering Azure resources from azd environment..." -ForegroundColor Yellow

# Try to get azd environment variables
$azdEnvOutput = azd env get-values 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "   ✓ Found azd environment" -ForegroundColor Green
    
    # Parse azd environment variables
    $azdVars = @{}
    $azdEnvOutput | ForEach-Object {
        if ($_ -match '^([^=]+)="?([^"]*)"?$') {
            $azdVars[$matches[1]] = $matches[2] -replace '"', ''
        }
    }
    
    # Get environment name and subscription
    $envName = $azdVars['AZURE_ENV_NAME']
    $subscriptionId = $azdVars['AZURE_SUBSCRIPTION_ID']
    
    if ($envName -and $subscriptionId) {
        Write-Host "   ✓ Environment: $envName" -ForegroundColor Green
        
        # Try to discover resources using Azure CLI
        try {
            # Find resource group (typically rg-{envName})
            if (-not $ResourceGroup) {
                $rgName = "rg-$envName"
                $rgCheck = az group exists --name $rgName --subscription $subscriptionId 2>&1
                if ($rgCheck -eq "true") {
                    $ResourceGroup = $rgName
                    Write-Host "   ✓ Resource Group: $ResourceGroup" -ForegroundColor Green
                } else {
                    # Try alternative pattern: {envName}-rg
                    $rgName = "$envName-rg"
                    $rgCheck = az group exists --name $rgName --subscription $subscriptionId 2>&1
                    if ($rgCheck -eq "true") {
                        $ResourceGroup = $rgName
                        Write-Host "   ✓ Resource Group: $ResourceGroup" -ForegroundColor Green
                    }
                }
            }
            
            # Find PostgreSQL server in the resource group
            if ($ResourceGroup -and -not $ServerName) {
                $servers = az postgres flexible-server list --resource-group $ResourceGroup --subscription $subscriptionId --query "[].{name:name, fqdn:fullyQualifiedDomainName}" -o json 2>&1 | ConvertFrom-Json
                if ($servers -and $servers.Count -gt 0) {
                    $server = $servers[0]
                    $ServerName = $server.name
                    $env:POSTGRES_HOST = $server.fqdn
                    Write-Host "   ✓ Server Name: $ServerName" -ForegroundColor Green
                    Write-Host "   ✓ Server FQDN: $env:POSTGRES_HOST" -ForegroundColor Green
                }
            }
            
            # Get database name from Key Vault (if available)
            if ($azdVars.ContainsKey('AZURE_KEY_VAULT_NAME')) {
                $kvName = $azdVars['AZURE_KEY_VAULT_NAME']
                $dbName = az keyvault secret show --name POSTGRES-DATABASE --vault-name $kvName --query "value" -o tsv 2>$null
                if ($dbName) {
                    $env:POSTGRES_DATABASE = $dbName
                    Write-Host "   ✓ Database: $env:POSTGRES_DATABASE" -ForegroundColor Green
                }
                
                $dbUser = az keyvault secret show --name POSTGRES-USERNAME --vault-name $kvName --query "value" -o tsv 2>$null
                if ($dbUser) {
                    $env:POSTGRES_USERNAME = $dbUser
                    Write-Host "   ✓ Username: $env:POSTGRES_USERNAME" -ForegroundColor Green
                }
            }
            
        } catch {
            Write-Host "   ⚠️  Could not auto-discover all resources" -ForegroundColor Yellow
        }
    }
    
} else {
    Write-Host "   ⚠️  azd environment not found, will prompt for details" -ForegroundColor Yellow
}

# Prompt for missing information
if (-not $ResourceGroup) {
    $ResourceGroup = Read-Host "Enter Resource Group name"
}

if (-not $ServerName) {
    $ServerName = Read-Host "Enter PostgreSQL Server name (without .postgres.database.azure.com)"
}

if (-not $env:POSTGRES_HOST) {
    $env:POSTGRES_HOST = Read-Host "Enter PostgreSQL Host (FQDN)"
}

if (-not $env:POSTGRES_DATABASE) {
    $env:POSTGRES_DATABASE = "relecloud"
}

if (-not $env:POSTGRES_USERNAME) {
    $env:POSTGRES_USERNAME = Read-Host "Enter PostgreSQL Username"
}

# Always prompt for password (secure input)
Write-Host "`nEnter PostgreSQL Password:" -ForegroundColor Yellow
$securePassword = Read-Host -AsSecureString
$env:POSTGRES_PASSWORD = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
)

# Set standard values
$env:POSTGRES_PORT = "5432"
$env:POSTGRES_SSL = "require"

# Store for later use
$RESOURCE_GROUP = $ResourceGroup
$SERVER_NAME = $ServerName

# ============================================================================
# Script Setup
# ============================================================================
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$TestsDir = Join-Path $ScriptDir "tests"
$TestScript = Join-Path $TestsDir "failover_load_test.py"

# Colors for output
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

# ============================================================================
# Pre-flight Checks
# ============================================================================
Write-ColorOutput "`n════════════════════════════════════════════════════════════════════════════════" "Cyan"
Write-ColorOutput "PostgreSQL FAILOVER LOAD TEST - AUTOMATED RUNNER" "Cyan"
Write-ColorOutput "════════════════════════════════════════════════════════════════════════════════`n" "Cyan"

Write-ColorOutput "⚙️  Configuration:" "Yellow"
Write-ColorOutput "   Resource Group:    $RESOURCE_GROUP"
Write-ColorOutput "   Server Name:       $SERVER_NAME"
Write-ColorOutput "   Server FQDN:       $env:POSTGRES_HOST"
Write-ColorOutput "   Database:          $env:POSTGRES_DATABASE"
Write-ColorOutput "   Username:          $env:POSTGRES_USERNAME"
Write-ColorOutput "   Password:          ********"
Write-ColorOutput "   Workers:           $Workers"
Write-ColorOutput "   Writes/sec:        $WritesPerSecond"
Write-ColorOutput "   Test Duration:     $Duration seconds ($([math]::Round($Duration/60, 1)) minutes)"
Write-ColorOutput ""

# Check if Python is available
Write-ColorOutput "🔍 Checking prerequisites..." "Yellow"
try {
    $pythonVersion = python --version 2>&1
    Write-ColorOutput "   ✓ Python: $pythonVersion" "Green"
} catch {
    Write-ColorOutput "   ✗ Python not found! Please install Python 3.12+" "Red"
    exit 1
}

# Check if test script exists (look in current directory)
$TestScript = Join-Path $ScriptDir "failover_load_test.py"
if (-not (Test-Path $TestScript)) {
    Write-ColorOutput "   ✗ Test script not found: $TestScript" "Red"
    exit 1
}
Write-ColorOutput "   ✓ Test script found" "Green"

# Check if dependencies are installed
try {
    python -c "import sqlmodel" 2>&1 | Out-Null
    Write-ColorOutput "   ✓ Dependencies installed" "Green"
} catch {
    Write-ColorOutput "   ⚠️  Installing dependencies..." "Yellow"
    pip install -e "$ScriptDir\src" | Out-Null
    Write-ColorOutput "   ✓ Dependencies installed" "Green"
}

# Test database connectivity
Write-ColorOutput "`n🔌 Testing database connectivity..." "Yellow"
try {
    python -c @"
import psycopg2
conn = psycopg2.connect(
    host='$env:POSTGRES_HOST',
    port=$env:POSTGRES_PORT,
    database='$env:POSTGRES_DATABASE',
    user='$env:POSTGRES_USERNAME',
    password='$env:POSTGRES_PASSWORD',
    sslmode='$env:POSTGRES_SSL',
    connect_timeout=10
)
conn.close()
print('✓ Connection successful')
"@
    Write-ColorOutput "   ✓ Database connection verified" "Green"
} catch {
    Write-ColorOutput "   ✗ Cannot connect to database!" "Red"
    Write-ColorOutput "   Error: $_" "Red"
    Write-ColorOutput "`n   Troubleshooting:" "Yellow"
    Write-ColorOutput "   1. Check if your IP is allowed in the firewall" "Yellow"
    Write-ColorOutput "   2. Verify the server is running" "Yellow"
    Write-ColorOutput "   3. Check credentials are correct" "Yellow"
    exit 1
}

# Check Azure CLI (optional, for failover command)
try {
    az version | Out-Null
    Write-ColorOutput "   ✓ Azure CLI available" "Green"
    $azureCliAvailable = $true
} catch {
    Write-ColorOutput "   ⚠️  Azure CLI not found (optional)" "Yellow"
    $azureCliAvailable = $false
}

# ============================================================================
# Instructions
# ============================================================================
Write-ColorOutput "`n════════════════════════════════════════════════════════════════════════════════" "Cyan"
Write-ColorOutput "📋 FAILOVER TEST INSTRUCTIONS" "Cyan"
Write-ColorOutput "════════════════════════════════════════════════════════════════════════════════`n" "Cyan"

Write-ColorOutput "The load test will now start. To measure failover:" "White"
Write-ColorOutput ""
Write-ColorOutput "  1️⃣  Wait for the test to stabilize (watch for consistent SUCCESS messages)" "White"
Write-ColorOutput ""
Write-ColorOutput "  2️⃣  Trigger a PLANNED FAILOVER using one of these methods:" "White"
Write-ColorOutput ""
Write-ColorOutput "     🖥️  Azure Portal:" "Yellow"
Write-ColorOutput "        • Navigate to: https://portal.azure.com" "Gray"
Write-ColorOutput "        • Go to resource: $SERVER_NAME" "Gray"
Write-ColorOutput "        • Settings → High availability → Planned failover" "Gray"
Write-ColorOutput ""

if ($azureCliAvailable) {
    Write-ColorOutput "     💻 Azure CLI (in a NEW terminal window):" "Yellow"
    Write-ColorOutput "        az postgres flexible-server restart ``" "Green"
    Write-ColorOutput "          --resource-group $RESOURCE_GROUP ``" "Green"
    Write-ColorOutput "          --name $SERVER_NAME ``" "Green"
    Write-ColorOutput "          --failover Planned" "Green"
    Write-ColorOutput ""
}

Write-ColorOutput "  3️⃣  The script will automatically detect the failover and measure timing" "White"
Write-ColorOutput ""
Write-ColorOutput "  4️⃣  After recovery, let it run for 30-60 more seconds" "White"
Write-ColorOutput ""
Write-ColorOutput "  5️⃣  Press Ctrl+C to stop and view results" "White"
Write-ColorOutput ""

Write-ColorOutput "⚠️  IMPORTANT NOTES:" "Yellow"
Write-ColorOutput "   • Zone-redundant HA must be enabled (General Purpose or Memory Optimized SKU)" "Yellow"
Write-ColorOutput "   • Default deployment uses Standard_D4ds_v5 (General Purpose) with HA enabled" "Green"
Write-ColorOutput "   • Verify HA is enabled in Azure Portal before testing" "Yellow"
Write-ColorOutput ""

Write-ColorOutput "════════════════════════════════════════════════════════════════════════════════`n" "Cyan"

# Prompt to continue
Write-ColorOutput "Press ENTER to start the load test (Ctrl+C to cancel)..." "Yellow"
$null = Read-Host

# ============================================================================
# Run the Load Test
# ============================================================================
Write-ColorOutput "`n🚀 Starting load test...`n" "Green"

# Update test configuration if parameters were provided
$tempTestScript = $TestScript
if ($Duration -ne 300 -or $Workers -ne 10 -or $WritesPerSecond -ne 50) {
    Write-ColorOutput "📝 Applying custom configuration..." "Yellow"
    $testContent = Get-Content $TestScript -Raw
    $testContent = $testContent -replace 'NUM_WORKERS = 10', "NUM_WORKERS = $Workers"
    $testContent = $testContent -replace 'WRITES_PER_SECOND = 50', "WRITES_PER_SECOND = $WritesPerSecond"
    $testContent = $testContent -replace 'TEST_DURATION = 300', "TEST_DURATION = $Duration"
    
    $tempTestScript = Join-Path $ScriptDir "failover_load_test_temp.py"
    $testContent | Set-Content $tempTestScript
    Write-ColorOutput "   ✓ Configuration applied" "Green"
}

try {
    if ($FailoverPromptSeconds -gt 0) {
        # Create a runspace to monitor time and prompt
        $runspace = [runspacefactory]::CreateRunspace()
        $runspace.Open()
        
        # Pass variables to runspace
        $runspace.SessionStateProxy.SetVariable("FailoverPromptSeconds", $FailoverPromptSeconds)
        $runspace.SessionStateProxy.SetVariable("RESOURCE_GROUP", $RESOURCE_GROUP)
        $runspace.SessionStateProxy.SetVariable("SERVER_NAME", $SERVER_NAME)
        $runspace.SessionStateProxy.SetVariable("subscriptionId", $subscriptionId)
        
        # Create PowerShell instance
        $ps = [powershell]::Create()
        $ps.Runspace = $runspace
        
        # Add script to run in background
        [void]$ps.AddScript({
            param($FailoverPromptSeconds, $RESOURCE_GROUP, $SERVER_NAME, $subscriptionId)
            
            Start-Sleep -Seconds $FailoverPromptSeconds
            
            # Make multiple beeps to get attention
            [Console]::Beep(800, 300)
            Start-Sleep -Milliseconds 200
            [Console]::Beep(1000, 300)
            Start-Sleep -Milliseconds 200
            [Console]::Beep(800, 300)
            
            Write-Host ""
            Write-Host ""
            Write-Host ""
            Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Yellow -BackgroundColor Red
            Write-Host "⚡⚡⚡ TIME TO TRIGGER FAILOVER NOW! ⚡⚡⚡" -ForegroundColor Yellow -BackgroundColor Red
            Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Yellow -BackgroundColor Red
            Write-Host ""
            Write-Host "Test running for $FailoverPromptSeconds seconds - should be stable now." -ForegroundColor Black -BackgroundColor Yellow
            Write-Host ""
            Write-Host "💻 AZURE CLI (Copy and paste in NEW terminal window):" -ForegroundColor Black -BackgroundColor Cyan
            Write-Host ""
            Write-Host "   az postgres flexible-server restart ``" -ForegroundColor Black -BackgroundColor White
            Write-Host "     --resource-group $RESOURCE_GROUP ``" -ForegroundColor Black -BackgroundColor White
            Write-Host "     --name $SERVER_NAME ``" -ForegroundColor Black -BackgroundColor White
            Write-Host "     --failover Planned" -ForegroundColor Black -BackgroundColor White
            Write-Host ""
            Write-Host "�️  OR use Azure Portal:" -ForegroundColor Black -BackgroundColor Cyan
            Write-Host "   • Portal: https://portal.azure.com" -ForegroundColor DarkGray
            Write-Host "   • Search: $SERVER_NAME" -ForegroundColor DarkGray
            Write-Host "   • Settings → High availability → Planned failover" -ForegroundColor DarkGray
            Write-Host ""
            Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Yellow -BackgroundColor Red
            Write-Host "Test continues running below. Press Ctrl+C to stop when done." -ForegroundColor Green
            Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Yellow -BackgroundColor Red
            Write-Host ""
            Write-Host ""
        }).AddArgument($FailoverPromptSeconds).AddArgument($RESOURCE_GROUP).AddArgument($SERVER_NAME).AddArgument($subscriptionId)
        
        # Start the background prompt
        $handle = $ps.BeginInvoke()
        
        Write-ColorOutput "⏱️  Load test starting... will prompt you to trigger failover at $FailoverPromptSeconds seconds" "Cyan"
        Write-ColorOutput ""
    }
    
    # Run the test normally (user can see output and use Ctrl+C)
    # Set UTF-8 encoding for Python
    $env:PYTHONIOENCODING = "utf-8"
    $env:PYTHONUNBUFFERED = "1"
    
    # Just run Python directly - let it handle its own output
    # Python script has a finally block that will show results even on Ctrl+C
    python $tempTestScript
    $exitCode = $LASTEXITCODE
    
} finally {
    # Cleanup background prompt if it exists
    if ($ps) {
        $ps.Dispose()
    }
    if ($runspace) {
        $runspace.Close()
        $runspace.Dispose()
    }
    
    # Cleanup temp file if created
    if ($tempTestScript -ne $TestScript -and (Test-Path $tempTestScript)) {
        Remove-Item $tempTestScript -Force
    }
}

# Check if test was interrupted
if ($exitCode -eq 0) {
    Write-ColorOutput "`n✅ Test completed!" "Green"
} else {
    Write-ColorOutput "`n⚠️  Test stopped (Ctrl+C pressed)" "Yellow"
}

# ============================================================================
# Post-test Information
# ============================================================================
Write-ColorOutput "`n════════════════════════════════════════════════════════════════════════════════" "Cyan"
Write-ColorOutput "📊 NEXT STEPS" "Cyan"
Write-ColorOutput "════════════════════════════════════════════════════════════════════════════════`n" "Cyan"

Write-ColorOutput "Results have been exported to CSV file in the tests directory." "White"
Write-ColorOutput ""
Write-ColorOutput "To analyze results:" "Yellow"
Write-ColorOutput "  • Open the CSV file in Excel or PowerBI" "White"
Write-ColorOutput "  • Create a timeline chart to visualize the failover gap" "White"
Write-ColorOutput "  • Review the summary metrics printed above" "White"
Write-ColorOutput ""

if (-not $azureCliAvailable) {
    Write-ColorOutput "💡 Tip: Install Azure CLI for automated failover commands" "Yellow"
    Write-ColorOutput "   https://learn.microsoft.com/cli/azure/install-azure-cli" "Gray"
    Write-ColorOutput ""
}

Write-ColorOutput "════════════════════════════════════════════════════════════════════════════════" "Cyan"
Write-Host ""
