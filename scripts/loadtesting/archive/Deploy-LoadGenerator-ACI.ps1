<#
.SYNOPSIS
    Deploy and manage high-performance load testing with Azure Container Instances

.DESCRIPTION
    This script deploys a C# load generator to Azure Container Instances (ACI) 
    for high-throughput PostgreSQL failover testing. Supports:
    - Automatic ACI deployment with custom configurations
    - Real-time log monitoring
    - Results download and analysis
    - Multiple concurrent test runs
    - PgBouncer connection support (port 6432)

.PARAMETER Action
    Action to perform: Deploy, Monitor, Download, Cleanup, List

.PARAMETER ResourceGroup
    Azure resource group name

.PARAMETER PostgreSQLServer
    PostgreSQL server name (without .postgres.database.azure.com)

.PARAMETER PostgreSQLPassword
    PostgreSQL admin password (SecureString)

.PARAMETER TargetTPS
    Target transactions per second (default: 8000)

.PARAMETER WorkerCount
    Number of parallel workers (default: 200)

.PARAMETER TestDuration
    Test duration in seconds (default: 300)

.PARAMETER ContainerCPU
    Container CPU cores (default: 16)

.PARAMETER ContainerMemory
    Container memory in GB (default: 32)

.PARAMETER ContainerName
    Custom container name (auto-generated if not specified)

.PARAMETER UsePgBouncer
    Use PgBouncer port 6432 (default: true)

.PARAMETER Location
    Azure region (default: swedencentral)

.EXAMPLE
    .\Deploy-LoadGenerator-ACI.ps1 -Action Deploy -ResourceGroup "rg-saif-pgsql-swc-01" -PostgreSQLServer "psql-saifpg-abc123"

.EXAMPLE
    .\Deploy-LoadGenerator-ACI.ps1 -Action Monitor -ResourceGroup "rg-saif-pgsql-swc-01" -ContainerName "aci-loadgen-20251010-183000"

.EXAMPLE
    .\Deploy-LoadGenerator-ACI.ps1 -Action List -ResourceGroup "rg-saif-pgsql-swc-01"

.NOTES
    Author: Azure Principal Architect Agent
    Version: 1.0.0
    Requires: Azure CLI, Az PowerShell Module
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('Deploy', 'Monitor', 'Download', 'Cleanup', 'List')]
    [string]$Action,

    [Parameter(Mandatory=$true)]
    [string]$ResourceGroup,

    [Parameter(Mandatory=$false)]
    [string]$PostgreSQLServer,

    [Parameter(Mandatory=$false)]
    [SecureString]$PostgreSQLPassword,

    [Parameter(Mandatory=$false)]
    [int]$TargetTPS = 8000,

    [Parameter(Mandatory=$false)]
    [int]$WorkerCount = 200,

    [Parameter(Mandatory=$false)]
    [int]$TestDuration = 300,

    [Parameter(Mandatory=$false)]
    [int]$ContainerCPU = 16,

    [Parameter(Mandatory=$false)]
    [int]$ContainerMemory = 32,

    [Parameter(Mandatory=$false)]
    [string]$ContainerName,

    [Parameter(Mandatory=$false)]
    [bool]$UsePgBouncer = $true,

    [Parameter(Mandatory=$false)]
    [string]$Location = "swedencentral",

    [Parameter(Mandatory=$false)]
    [string]$DatabaseName = "saifdb",

    [Parameter(Mandatory=$false)]
    [string]$AdminUsername = "saifadmin"
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

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

function Test-Prerequisites {
    Write-Step "Checking prerequisites..."
    
    # Check Azure CLI
    if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
        Write-Error "Azure CLI not found. Please install from https://aka.ms/InstallAzureCLIDirect"
        exit 1
    }
    
    # Check if logged in
    $account = az account show 2>$null | ConvertFrom-Json
    if (-not $account) {
        Write-Error "Not logged into Azure CLI. Run 'az login' first."
        exit 1
    }
    
    Write-Success "Prerequisites OK"
    Write-Info "Subscription: $($account.name) ($($account.id))"
}

function Get-LoadGeneratorScript {
    $scriptPath = Join-Path $PSScriptRoot "LoadGenerator.csx"
    
    if (-not (Test-Path $scriptPath)) {
        Write-Error "LoadGenerator.csx not found at: $scriptPath"
        exit 1
    }
    
    return $scriptPath
}

function Deploy-LoadGenerator {
    Write-Banner "🚀 DEPLOYING LOAD GENERATOR TO AZURE CONTAINER INSTANCES"
    
    # Validate required parameters
    if (-not $PostgreSQLServer) {
        Write-Error "PostgreSQLServer parameter is required for Deploy action"
        exit 1
    }
    
    if (-not $PostgreSQLPassword) {
        Write-Error "PostgreSQLPassword parameter is required for Deploy action"
        exit 1
    }
    
    # Generate container name if not provided
    if (-not $ContainerName) {
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $ContainerName = "aci-loadgen-$timestamp"
    }
    
    Write-Step "Configuration:"
    Write-Host "   Resource Group: $ResourceGroup"
    Write-Host "   Container Name: $ContainerName"
    Write-Host "   PostgreSQL Server: $PostgreSQLServer"
    Write-Host "   Database: $DatabaseName"
    Write-Host "   Target TPS: $TargetTPS"
    Write-Host "   Workers: $WorkerCount"
    Write-Host "   Duration: $TestDuration seconds"
    Write-Host "   CPU: $ContainerCPU cores"
    Write-Host "   Memory: $ContainerMemory GB"
    Write-Host "   PgBouncer: $(if ($UsePgBouncer) { 'Enabled (port 6432)' } else { 'Disabled (port 5432)' })"
    Write-Host ""
    
    # Convert SecureString to plain text for connection string
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($PostgreSQLPassword)
    $plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
    
    # Build connection string
    $port = if ($UsePgBouncer) { 6432 } else { 5432 }
    $connectionString = "Host=$PostgreSQLServer.postgres.database.azure.com;Port=$port;Database=$DatabaseName;Username=$AdminUsername;Password=$plainPassword;SSL Mode=Require;Pooling=true;Minimum Pool Size=$([int]($WorkerCount * 0.25));Maximum Pool Size=$($WorkerCount + 100);Connection Idle Lifetime=300"
    
    # Read LoadGenerator.csx with explicit UTF-8 encoding
    Write-Step "Reading LoadGenerator.csx script..."
    $scriptPath = Get-LoadGeneratorScript
    # Use .NET method to ensure proper UTF-8 reading (handles emoji correctly)
    $scriptContent = [System.IO.File]::ReadAllText($scriptPath, [System.Text.Encoding]::UTF8)
    
    Write-Success "Script loaded ($(([Math]::Round($scriptContent.Length / 1KB, 2))) KB)"
    
    # Create temporary directory for deployment files
    $tempDir = Join-Path $env:TEMP "aci-loadgen-$([Guid]::NewGuid().ToString().Substring(0,8))"
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    
    Write-Step "Creating deployment files in temp directory..."
    
    # Save LoadGenerator.csx to temp directory
    $tempScriptPath = Join-Path $tempDir "LoadGenerator.csx"
    $scriptContent | Out-File -FilePath $tempScriptPath -Encoding UTF8 -NoNewline
    
    # Create YAML deployment template
    $yamlContent = @"
apiVersion: 2023-05-01
location: $Location
name: $ContainerName
properties:
  containers:
  - name: loadgen
    properties:
      image: mcr.microsoft.com/dotnet/sdk:8.0
      resources:
        requests:
          cpu: $ContainerCPU
          memoryInGb: $ContainerMemory
      environmentVariables:
      - name: POSTGRES_CONNECTION_STRING
        secureValue: $connectionString
      - name: TARGET_TPS
        value: '$TargetTPS'
      - name: WORKER_COUNT
        value: '$WorkerCount'
      - name: TEST_DURATION
        value: '$TestDuration'
      - name: OUTPUT_CSV
        value: '/mnt/scripts/loadtest_results.csv'
      command:
      - /bin/bash
      - -c
      - |
        echo "Installing dotnet-script..."
        dotnet tool install -g dotnet-script
        export PATH=`$PATH:/root/.dotnet/tools
        echo "Starting load generator..."
        cd /mnt/scripts
        dotnet script LoadGenerator.csx
      volumeMounts:
      - name: scripts
        mountPath: /mnt/scripts
  volumes:
  - name: scripts
    emptyDir: {}
  osType: Linux
  restartPolicy: Never
tags:
  Purpose: LoadTesting
  CreatedBy: Deploy-LoadGenerator-ACI
type: Microsoft.ContainerInstance/containerGroups
"@
    
    $yamlPath = Join-Path $tempDir "aci-deploy.yaml"
    $yamlContent | Out-File -FilePath $yamlPath -Encoding UTF8
    
    Write-Success "Deployment files created"
    
    # We need to use a different approach since we can't upload to emptyDir before container starts
    # Instead, embed the script in the command using a here-doc
    Write-Step "Creating optimized deployment with embedded script..."
    
    # Escape special characters in script for bash here-doc
    $escapedScript = $scriptContent -replace '\\', '\\' -replace '\$', '\$' -replace '`', '\`' -replace '"', '\"'
    
    # Create optimized YAML with embedded script
    # Use proper YAML escaping for the script content
    $yamlContent = @"
apiVersion: 2023-05-01
location: $Location
name: $ContainerName
properties:
  containers:
  - name: loadgen
    properties:
      image: mcr.microsoft.com/dotnet/sdk:8.0
      resources:
        requests:
          cpu: $ContainerCPU
          memoryInGb: $ContainerMemory
      environmentVariables:
      - name: POSTGRES_CONNECTION_STRING
        secureValue: $connectionString
      - name: TARGET_TPS
        value: '$TargetTPS'
      - name: WORKER_COUNT
        value: '$WorkerCount'
      - name: TEST_DURATION
        value: '$TestDuration'
      - name: OUTPUT_CSV
        value: '/app/loadtest_results.csv'
      command:
      - /bin/bash
      - -c
      - |
        set -e
        echo "Installing dotnet-script..."
        dotnet tool install -g dotnet-script
        export PATH=${'$'}PATH:/root/.dotnet/tools
        
        echo "Creating LoadGenerator.csx..."
        cat > /app/LoadGenerator.csx << 'SCRIPT_EOF'
$scriptContent
SCRIPT_EOF
        
        echo "Starting load generator..."
        cd /app
        dotnet script LoadGenerator.csx
  osType: Linux
  restartPolicy: Never
tags:
  Purpose: LoadTesting
  CreatedBy: Deploy-LoadGenerator-ACI
type: Microsoft.ContainerInstance/containerGroups
"@
    
    $yamlPath = Join-Path $tempDir "aci-deploy.yaml"
    # Use UTF8 without BOM for Azure CLI compatibility
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($yamlPath, $yamlContent, $utf8NoBom)
    
    Write-Step "Deploying container instance..."
    Write-Info "This may take 2-3 minutes..."
    
    # Azure CLI on Windows has encoding issues with YAML files containing UTF-8 characters
    # Workaround: Use JSON deployment instead (better UTF-8 support)
    Write-Info "Using JSON deployment (better UTF-8 compatibility)..."
    
    # Create ARM template for deployment
    $armTemplate = @{
        '$schema' = "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#"
        contentVersion = "1.0.0.0"
        resources = @(
            @{
                type = "Microsoft.ContainerInstance/containerGroups"
                apiVersion = "2023-05-01"
                name = $ContainerName
                location = $Location
                tags = @{
                    Purpose = "LoadTesting"
                    CreatedBy = "Deploy-LoadGenerator-ACI"
                }
                properties = @{
                    containers = @(
                        @{
                            name = "loadgen"
                            properties = @{
                                image = "mcr.microsoft.com/dotnet/sdk:8.0"
                                resources = @{
                                    requests = @{
                                        cpu = $ContainerCPU
                                        memoryInGB = $ContainerMemory
                                    }
                                }
                                environmentVariables = @(
                                    @{
                                        name = "POSTGRES_CONNECTION_STRING"
                                        secureValue = $connectionString
                                    }
                                    @{
                                        name = "TARGET_TPS"
                                        value = "$TargetTPS"
                                    }
                                    @{
                                        name = "WORKER_COUNT"
                                        value = "$WorkerCount"
                                    }
                                    @{
                                        name = "TEST_DURATION"
                                        value = "$TestDuration"
                                    }
                                    @{
                                        name = "OUTPUT_CSV"
                                        value = "/app/loadtest_results.csv"
                                    }
                                    @{
                                        name = "SCRIPT_CONTENT_B64"
                                        value = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($scriptContent))
                                    }
                                )
                                command = @(
                                    "/bin/bash"
                                    "-c"
                                    "set -e && echo 'Installing dotnet-script...' && dotnet tool install -g dotnet-script && echo 'Creating LoadGenerator.csx...' && mkdir -p /app && echo `${SCRIPT_CONTENT_B64} | base64 -d > /app/LoadGenerator.csx && ls -lh /app/LoadGenerator.csx && echo 'Starting load generator...' && cd /app && /root/.dotnet/tools/dotnet-script LoadGenerator.csx"
                                )
                            }
                        }
                    )
                    osType = "Linux"
                    restartPolicy = "Never"
                }
            }
        )
    } | ConvertTo-Json -Depth 10
    
    $jsonPath = Join-Path $tempDir "aci-deploy.json"
    [System.IO.File]::WriteAllText($jsonPath, $armTemplate, [System.Text.Encoding]::UTF8)
    
    # Deploy using Azure Resource Manager (ARM) template deployment
    # Note: az container create --file expects YAML, so we use deployment group create instead
    Write-Info "Deploying via ARM template..."
    $deployResult = az deployment group create `
        --resource-group $ResourceGroup `
        --template-file $jsonPath `
        --output json 2>&1
    
    # Clean up temp directory
    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to deploy container instance"
        Write-Host $deployResult
        exit 1
    }
    
    $containerInfo = $deployResult | ConvertFrom-Json
    
    Write-Success "Container deployed successfully!"
    Write-Host ""
    Write-Info "Container Details:"
    Write-Host "   Name: $($containerInfo.name)"
    Write-Host "   State: $($containerInfo.instanceView.state)"
    Write-Host "   Location: $($containerInfo.location)"
    Write-Host ""
    Write-Info "To monitor logs, run:"
    Write-Host "   .\Deploy-LoadGenerator-ACI.ps1 -Action Monitor -ResourceGroup $ResourceGroup -ContainerName $ContainerName" -ForegroundColor White
    Write-Host ""
    Write-Info "Or use Azure CLI directly:"
    Write-Host "   az container logs --resource-group $ResourceGroup --name $ContainerName --follow" -ForegroundColor White
    
    # Start monitoring automatically
    Write-Host ""
    $response = Read-Host "Start monitoring now? (Y/n)"
    if ($response -ne 'n' -and $response -ne 'N') {
        Monitor-LoadGenerator
    }
}

function Monitor-LoadGenerator {
    Write-Banner "📊 MONITORING LOAD GENERATOR"
    
    if (-not $ContainerName) {
        Write-Error "ContainerName parameter is required for Monitor action"
        exit 1
    }
    
    Write-Step "Fetching container status..."
    
    $containerInfo = az container show `
        --resource-group $ResourceGroup `
        --name $ContainerName `
        --output json 2>&1 | ConvertFrom-Json
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Container not found: $ContainerName"
        exit 1
    }
    
    Write-Info "Container: $($containerInfo.name)"
    Write-Info "State: $($containerInfo.instanceView.state)"
    Write-Info "Started: $($containerInfo.instanceView.currentState.startTime)"
    Write-Host ""
    Write-Step "Streaming logs (Ctrl+C to stop)..."
    Write-Host ""
    
    # Stream logs with follow
    az container logs --resource-group $ResourceGroup --name $ContainerName --follow
}

function Download-Results {
    Write-Banner "💾 DOWNLOADING LOAD TEST RESULTS"
    
    if (-not $ContainerName) {
        Write-Error "ContainerName parameter is required for Download action"
        exit 1
    }
    
    Write-Step "Fetching container logs..."
    
    $logs = az container logs --resource-group $ResourceGroup --name $ContainerName 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to fetch logs"
        exit 1
    }
    
    # Save logs to file
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $logsFile = "loadtest_logs_$timestamp.txt"
    $logs | Out-File -FilePath $logsFile -Encoding UTF8
    
    Write-Success "Logs saved to: $logsFile"
    
    # Try to extract CSV data from logs
    Write-Step "Extracting metrics..."
    
    # Note: CSV extraction from container filesystem would require azure-storage-file-share
    # For now, we parse the logs for key metrics
    
    if ($logs -match "Average TPS: ([\d.]+)") {
        $avgTps = $Matches[1]
        Write-Info "Average TPS: $avgTps"
    }
    
    if ($logs -match "Total Transactions: ([\d,]+)") {
        $totalTx = $Matches[1]
        Write-Info "Total Transactions: $totalTx"
    }
    
    if ($logs -match "RTO.*?: ([\d.]+) seconds") {
        $rto = $Matches[1]
        Write-Info "RTO: $rto seconds"
    }
    
    Write-Host ""
    Write-Info "Full log analysis saved to: $logsFile"
}

function Remove-LoadGenerator {
    Write-Banner "🗑️  CLEANUP LOAD GENERATOR CONTAINERS"
    
    Write-Step "Listing all load generator containers..."
    
    $containers = az container list `
        --resource-group $ResourceGroup `
        --query "[?starts_with(name, 'aci-loadgen-')]" `
        --output json | ConvertFrom-Json
    
    if ($containers.Count -eq 0) {
        Write-Info "No load generator containers found"
        return
    }
    
    Write-Host ""
    Write-Host "Found $($containers.Count) container(s):" -ForegroundColor Yellow
    foreach ($container in $containers) {
        $state = $container.instanceView.state
        $stateColor = switch ($state) {
            "Succeeded" { "Green" }
            "Running" { "Yellow" }
            "Failed" { "Red" }
            default { "Gray" }
        }
        Write-Host "   - $($container.name) " -NoNewline
        Write-Host "[$state]" -ForegroundColor $stateColor
    }
    
    Write-Host ""
    $response = Read-Host "Delete ALL these containers? (y/N)"
    
    if ($response -eq 'y' -or $response -eq 'Y') {
        foreach ($container in $containers) {
            Write-Step "Deleting $($container.name)..."
            az container delete `
                --resource-group $ResourceGroup `
                --name $container.name `
                --yes `
                --output none
            
            if ($LASTEXITCODE -eq 0) {
                Write-Success "Deleted $($container.name)"
            } else {
                Write-Error "Failed to delete $($container.name)"
            }
        }
        Write-Success "Cleanup complete"
    } else {
        Write-Info "Cleanup cancelled"
    }
}

function List-LoadGenerators {
    Write-Banner "📋 LOAD GENERATOR CONTAINERS"
    
    Write-Step "Querying containers in resource group: $ResourceGroup"
    
    $containers = az container list `
        --resource-group $ResourceGroup `
        --query "[?starts_with(name, 'aci-loadgen-')]" `
        --output json | ConvertFrom-Json
    
    if ($containers.Count -eq 0) {
        Write-Info "No load generator containers found"
        return
    }
    
    Write-Host ""
    Write-Host "Found $($containers.Count) container(s):" -ForegroundColor Cyan
    Write-Host ""
    
    foreach ($container in $containers) {
        $state = $container.instanceView.state
        $stateColor = switch ($state) {
            "Succeeded" { "Green" }
            "Running" { "Yellow" }
            "Failed" { "Red" }
            "Pending" { "Gray" }
            default { "White" }
        }
        
        Write-Host "Container: " -NoNewline
        Write-Host $container.name -ForegroundColor White
        Write-Host "  State: " -NoNewline
        Write-Host $state -ForegroundColor $stateColor
        Write-Host "  CPU: $($container.containers[0].resources.requests.cpu) cores"
        Write-Host "  Memory: $($container.containers[0].resources.requests.memoryInGB) GB"
        Write-Host "  Started: $($container.instanceView.currentState.startTime)"
        
        if ($container.instanceView.currentState.finishTime) {
            Write-Host "  Finished: $($container.instanceView.currentState.finishTime)"
        }
        
        Write-Host ""
    }
    
    Write-Info "To monitor a container:"
    Write-Host "   .\Deploy-LoadGenerator-ACI.ps1 -Action Monitor -ResourceGroup $ResourceGroup -ContainerName <name>" -ForegroundColor White
    Write-Host ""
    Write-Info "To download results:"
    Write-Host "   .\Deploy-LoadGenerator-ACI.ps1 -Action Download -ResourceGroup $ResourceGroup -ContainerName <name>" -ForegroundColor White
}

# ============================================================================
# MAIN
# ============================================================================

Test-Prerequisites

switch ($Action) {
    'Deploy' { Deploy-LoadGenerator }
    'Monitor' { Monitor-LoadGenerator }
    'Download' { Download-Results }
    'Cleanup' { Remove-LoadGenerator }
    'List' { List-LoadGenerators }
}

Write-Host ""
