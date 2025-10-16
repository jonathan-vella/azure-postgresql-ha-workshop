<#
.SYNOPSIS
Deploy LoadGenerator to Azure App Service with Application Insights integration

.DESCRIPTION
Deploys a containerized LoadGenerator application to App Service on Linux with:
- Application Insights for real-time monitoring and logging
- ACR image integration with managed identity authentication
- Environment variables for PostgreSQL configuration
- Automatic Application Insights instrumentation

.PARAMETER Action
Operation to perform: Deploy, Stop, Start, Delete, Status

.PARAMETER ResourceGroup
Azure Resource Group name

.PARAMETER AppServiceName
Name for the App Service (will be created if not exists)

.PARAMETER AppServicePlan
Name for the App Service Plan

.PARAMETER ContainerRegistry
ACR name (without .azurecr.io)

.PARAMETER RegistryResourceGroup
Resource Group containing the ACR

.PARAMETER ImageName
Container image name in ACR - default: 'loadgenerator'

.PARAMETER ImageTag
Container image tag - default: 'latest'

.PARAMETER PostgreSQLServer
PostgreSQL server FQDN - e.g., 'pg-cus.postgres.database.azure.com'

.PARAMETER DatabaseName
PostgreSQL database name

.PARAMETER AdminUsername
PostgreSQL admin username

.PARAMETER AdminPassword
PostgreSQL admin password (will prompt if not provided)

.PARAMETER TargetTPS
Target transactions per second - default: 1000

.PARAMETER WorkerCount
Number of concurrent workers - default: 200

.PARAMETER TestDuration
Test duration in seconds - default: 300

.PARAMETER Port
Container port - default: 80

.PARAMETER InstanceCount
Number of App Service instances - default: 1

.EXAMPLE
.\Deploy-LoadGenerator-AppService.ps1 -Action Deploy `
    -ResourceGroup "rg-pgv2-usc01" `
    -AppServiceName "app-loadgen-001" `
    -AppServicePlan "plan-loadgen-001" `
    -ContainerRegistry "acrsaifpg10081025" `
    -RegistryResourceGroup "rg-saif-pgsql-swc-01" `
    -PostgreSQLServer "pg-cus.postgres.database.azure.com" `
    -DatabaseName "saifdb" `
    -AdminUsername "jonathan" `
    -AdminPassword (Read-Host -AsSecureString -Prompt "PostgreSQL Password") `
    -TargetTPS 1000 `
    -WorkerCount 200
#>

param(
    [Parameter(Mandatory = $false)]
    [ValidateSet("Deploy", "Stop", "Start", "Delete", "Status")]
    [string]$Action,

    [Parameter(Mandatory = $false)]
    [string]$ConfigFile = "./LoadGenerator-Config.ps1"
)

# ============================================================================
# RESOLVE CONFIG FILE PATH
# ============================================================================

# If config file is relative path, resolve it relative to script directory
if (-not [System.IO.Path]::IsPathRooted($ConfigFile)) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $ConfigFile = Join-Path $scriptDir $ConfigFile
}

# ============================================================================
# LOAD CONFIGURATION
# ============================================================================

if (-not (Test-Path $ConfigFile)) {
    Write-Host "❌ Configuration file not found: $ConfigFile" -ForegroundColor Red
    Write-Host "Please create LoadGenerator-Config.ps1 or specify -ConfigFile parameter" -ForegroundColor Yellow
    exit 1
}

# Source the configuration file
. $ConfigFile

# ============================================================================
# EXTRACT CONFIGURATION VARIABLES
# ============================================================================

# Common deployment variables (apply to ALL resources)
# $Region and $ResourceGroup are already loaded from config file

# App Service
$AppServiceName = $AppServiceConfig.AppServiceName
$AppServicePlan = $AppServiceConfig.AppServicePlan
$SKU = $AppServiceConfig.SKU
$InstanceCount = $AppServiceConfig.InstanceCount

# ============================================================================
# FIND EXISTING APP SERVICE (if one was already deployed)
# ============================================================================
# Since $RandomSuffix changes each script run, look for existing app-loadgen-* services
$existingAppServices = az webapp list --resource-group $ResourceGroup --query "[?starts_with(name, 'app-loadgen-')].name" -o tsv 2>$null
if ($existingAppServices) {
    # Use the first existing one found
    $AppServiceName = ($existingAppServices -split "`n")[0].Trim()
    Write-Host "ℹ  Found existing App Service: $AppServiceName" -ForegroundColor Yellow
}

# Container Registry
$ContainerRegistryName = $ContainerRegistry.Name
$ImageName = $ContainerRegistry.ImageName
$ImageTag = $ContainerRegistry.ImageTag

# PostgreSQL
$PostgreSQLServer = $PostgreSQLConfig.Server
$DatabaseName = $PostgreSQLConfig.Database
$AdminUsername = $PostgreSQLConfig.AdminUsername
$AdminPassword = $PostgreSQLConfig.AdminPassword

# Load Test
$TargetTPS = $LoadTestConfig.TargetTPS
$WorkerCount = $LoadTestConfig.WorkerCount
$TestDuration = $LoadTestConfig.TestDuration

# Application Insights
$AppInsightsName = if ($AppInsightsConfig.Name) { $AppInsightsConfig.Name } else { "$AppServiceName-ai" }

# ============================================================================
# PROMPT FOR MISSING VALUES
# ============================================================================

if (-not $Action) {
    Write-Host "`nSelect Action:" -ForegroundColor Cyan
    Write-Host "  1. Deploy" -ForegroundColor Yellow
    Write-Host "  2. Stop" -ForegroundColor Yellow
    Write-Host "  3. Start" -ForegroundColor Yellow
    Write-Host "  4. Status" -ForegroundColor Yellow
    Write-Host "  5. Delete" -ForegroundColor Yellow
    
    $selection = Read-Host "Enter choice (1-5)"
    $actions = @("Deploy", "Stop", "Start", "Status", "Delete")
    $Action = $actions[$selection - 1]
}

if (-not $AdminPassword -and $Action -eq "Deploy") {
    $AdminPassword = Read-Host -AsSecureString -Prompt "Enter PostgreSQL Password"
}

# Set error action preference
$ErrorActionPreference = "Stop"

function Write-Section {
    param([string]$Title)
    Write-Host "`n$Title" -ForegroundColor Cyan
    Write-Host ("━" * 70) -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "  ✓ $Message" -ForegroundColor Green
}

function Write-Info {
    param([string]$Message)
    Write-Host "  ℹ $Message" -ForegroundColor Yellow
}

function Write-Error-Custom {
    param([string]$Message)
    Write-Host "  ✗ $Message" -ForegroundColor Red
}

# ============================================================================
# STATUS ACTION
# ============================================================================
if ($Action -eq "Status") {
    Write-Section "📊 App Service Status"
    
    try {
        $appService = az webapp show --name $AppServiceName --resource-group $ResourceGroup 2>$null | ConvertFrom-Json
        if ($appService) {
            Write-Success "App Service found: $($appService.name)"
            Write-Host "  State: $($appService.state)" -ForegroundColor Cyan
            Write-Host "  Default Hostname: $($appService.defaultHostName)" -ForegroundColor Cyan
            Write-Host "  Plan: $($appService.appServicePlanId -split '/' | Select-Object -Last 1)" -ForegroundColor Cyan
            
            # Get instance count
            $plan = az appservice plan show --name $AppServicePlan --resource-group $ResourceGroup 2>$null | ConvertFrom-Json
            Write-Host "  SKU: $($plan.sku.name)" -ForegroundColor Cyan
            Write-Host "  Instance Count: $($plan.numberOfWorkers)" -ForegroundColor Cyan
        }
        else {
            Write-Info "App Service not found"
        }
    }
    catch {
        Write-Info "App Service not found"
    }
    exit 0
}

# ============================================================================
# STOP ACTION
# ============================================================================
if ($Action -eq "Stop") {
    Write-Section "⏸️  Stopping App Service"
    
    try {
        Write-Info "Stopping $AppServiceName..."
        az webapp stop --name $AppServiceName --resource-group $ResourceGroup
        Write-Success "App Service stopped"
    }
    catch {
        Write-Error-Custom $_
        throw
    }
    exit 0
}

# ============================================================================
# START ACTION
# ============================================================================
if ($Action -eq "Start") {
    Write-Section "▶️  Starting App Service"
    
    try {
        Write-Info "Starting $AppServiceName..."
        az webapp start --name $AppServiceName --resource-group $ResourceGroup
        Write-Success "App Service started"
    }
    catch {
        Write-Error-Custom $_
        throw
    }
    exit 0
}

# ============================================================================
# DELETE ACTION
# ============================================================================
if ($Action -eq "Delete") {
    Write-Section "🗑️  Deleting App Service"
    
    try {
        Write-Info "Deleting App Service: $AppServiceName"
        az webapp delete --name $AppServiceName --resource-group $ResourceGroup
        Write-Success "App Service deleted"
    }
    catch {
        Write-Error-Custom $_
        throw
    }
    exit 0
}

# ============================================================================
# DEPLOY ACTION
# ============================================================================
if ($Action -eq "Deploy") {
    Write-Section "🚀 Deploying LoadGenerator to App Service"
    
    # Validate required parameters
    if (-not $PostgreSQLServer) {
        throw "PostgreSQLServer is required for Deploy action"
    }
    if (-not $DatabaseName) {
        throw "DatabaseName is required for Deploy action"
    }
    if (-not $AdminUsername) {
        throw "AdminUsername is required for Deploy action"
    }
    if (-not $AdminPassword) {
        $AdminPassword = Read-Host -AsSecureString -Prompt "Enter PostgreSQL Password"
    }
    
    # Convert password to plain text for environment variable
    $plainPassword = [System.Net.NetworkCredential]::new("", $AdminPassword).Password
    
    # ========================================================================
    # Step 1: Validate ACR
    # ========================================================================
    Write-Section "✓ Step 1: Validating ACR"
    try {
        $acr = az acr show --name $ContainerRegistryName --resource-group $ResourceGroup | ConvertFrom-Json
        $loginServer = $acr.loginServer
        Write-Success "ACR found: $loginServer"
    }
    catch {
        Write-Error-Custom "ACR not found: $ContainerRegistryName in $ResourceGroup"
        throw
    }
    
    # ========================================================================
    # Step 2: Create App Service Plan if needed
    # ========================================================================
    Write-Section "✓ Step 2: App Service Plan Setup"
    try {
        $existingPlan = az appservice plan show --name $AppServicePlan --resource-group $ResourceGroup 2>$null
        if ($existingPlan) {
            Write-Info "Using existing App Service Plan: $AppServicePlan"
        }
        else {
            Write-Info "Creating App Service Plan: $AppServicePlan ($SKU Linux)..."
            az appservice plan create `
                --name $AppServicePlan `
                --resource-group $ResourceGroup `
                --sku $SKU `
                --is-linux
            Write-Success "App Service Plan created"
        }
    }
    catch {
        Write-Error-Custom "Failed to create/validate App Service Plan"
        throw
    }
    
    # ========================================================================
    # Step 3: Create Application Insights
    # ========================================================================
    Write-Section "✓ Step 3: Application Insights Setup (Linked to existing LAW)"
    $appInsightsName = "$AppServiceName-ai"
    try {
        Write-Info "Finding existing Log Analytics Workspace..."
        
        # Get existing LAW in the resource group
        $lawList = az monitor log-analytics workspace list --resource-group $ResourceGroup --query "[0]" | ConvertFrom-Json
        if (-not $lawList) {
            throw "No Log Analytics Workspace found in resource group $ResourceGroup"
        }
        
        $lawName = $lawList.name
        $lawResourceId = $lawList.id
        Write-Success "Found LAW: $lawName"
        
        $existingAI = az monitor app-insights component show --app $appInsightsName --resource-group $ResourceGroup 2>$null
        if ($existingAI) {
            Write-Info "Using existing Application Insights: $appInsightsName"
        }
        else {
            Write-Info "Creating Application Insights linked to LAW: $lawName..."
            
            # Create Application Insights linked to the existing LAW
            az monitor app-insights component create `
                --app $appInsightsName `
                --resource-group $ResourceGroup `
                --location $Region `
                --application-type web `
                --workspace $lawResourceId
            
            Write-Success "Application Insights created and linked to LAW"
        }
        
        # Get Application Insights connection string and key
        $aiComponent = az monitor app-insights component show --app $appInsightsName --resource-group $ResourceGroup | ConvertFrom-Json
        $aiConnectionString = $aiComponent.connectionString
        $aiInstrumentationKey = $aiComponent.instrumentationKey
        Write-Success "Application Insights configured"
        Write-Info "Instrumentation Key: $aiInstrumentationKey"
        Write-Info "Linked LAW: $lawName"
    }
    catch {
        Write-Error-Custom "Failed to create/validate Application Insights"
        throw
    }
    
    # ========================================================================
    # Step 4: Create App Service
    # ========================================================================
    Write-Section "✓ Step 4: App Service Creation"
    try {
        $existingApp = az webapp show --name $AppServiceName --resource-group $ResourceGroup 2>$null
        if ($existingApp) {
            Write-Info "App Service already exists: $AppServiceName"
        }
        else {
            Write-Info "Creating App Service: $AppServiceName..."
            
            # Create basic Linux App Service for containers
            # Use --deployment-container-image-name with a placeholder image
            az webapp create `
                --name $AppServiceName `
                --resource-group $ResourceGroup `
                --plan $AppServicePlan `
                --deployment-container-image-name "nginx"
            
            Write-Success "App Service created"
            
            # Wait for creation to complete and App Service to be queryable
            Write-Info "Waiting for App Service to be ready..."
            $maxRetries = 10
            $retryCount = 0
            $appReady = $false
            
            while ($retryCount -lt $maxRetries -and -not $appReady) {
                Start-Sleep -Seconds 2
                $checkApp = az webapp show --name $AppServiceName --resource-group $ResourceGroup 2>$null
                if ($checkApp) {
                    $appReady = $true
                    Write-Success "App Service is ready"
                }
                $retryCount++
            }
            
            if (-not $appReady) {
                throw "App Service creation timed out"
            }
        }
    }
    catch {
        Write-Error-Custom "Failed to create App Service"
        throw
    }
    
    # ========================================================================
    # Step 5: Configure Managed Identity First (BEFORE container config)
    # ========================================================================
    Write-Section "✓ Step 5: System-Assigned Managed Identity Setup"
    try {
        Write-Info "Verifying App Service exists..."
        $appCheck = az webapp show --name $AppServiceName --resource-group $ResourceGroup 2>$null
        if (-not $appCheck) {
            throw "App Service not found: $AppServiceName"
        }
        
        Write-Info "Assigning system-managed identity to App Service..."
        
        # Assign system-managed identity
        az webapp identity assign `
            --name $AppServiceName `
            --resource-group $ResourceGroup | Out-Null
        
        # Wait and then retrieve the identity
        Start-Sleep -Seconds 3
        
        $identityResult = az webapp identity show `
            --name $AppServiceName `
            --resource-group $ResourceGroup | ConvertFrom-Json
        
        $principalId = $identityResult.principalId
        if (-not $principalId) {
            throw "Failed to get principal ID from managed identity"
        }
        
        Write-Success "Managed identity assigned"
        Write-Info "Principal ID: $principalId"
        
        # Wait for identity to propagate
        Write-Info "Waiting for managed identity to propagate..."
        Start-Sleep -Seconds 5
        
        Write-Info "Granting AcrPull role on ACR..."
        
        # Get ACR resource ID
        $acrResourceId = az acr show --name $ContainerRegistryName --resource-group $ResourceGroup --query id -o tsv
        Write-Info "ACR Resource ID: $acrResourceId"
        
        # Grant AcrPull role to managed identity
        az role assignment create `
            --role AcrPull `
            --assignee-object-id $principalId `
            --assignee-principal-type ServicePrincipal `
            --scope $acrResourceId
        
        Write-Success "AcrPull role assigned to managed identity"
    }
    catch {
        Write-Error-Custom "Failed to configure managed identity: $_"
        throw
    }
    
    # ========================================================================
    # Step 6: Configure Container Settings (using managed identity)
    # ========================================================================
    Write-Section "✓ Step 6: Container Configuration with Managed Identity"
    try {
        Write-Info "Configuring container with managed identity authentication..."
        
        # First, disable admin credentials to force managed identity usage
        Write-Info "Disabling admin credentials..."
        az webapp update `
            --name $AppServiceName `
            --resource-group $ResourceGroup `
            --set "properties.publicNetworkAccess=Enabled" | Out-Null
        
        # Configure container settings - managed identity will be used automatically
        # Using newer parameter names (docker-* are deprecated)
        az webapp config container set `
            --name $AppServiceName `
            --resource-group $ResourceGroup `
            --container-image-name "$loginServer/$ImageName`:$ImageTag" `
            --container-registry-url "https://$loginServer"
        
        Write-Success "Container configured with managed identity"
    }
    catch {
        Write-Error-Custom "Failed to configure container"
        throw
    }
    
    # ========================================================================
    # Step 7: Configure App Settings (Environment Variables)
    # ========================================================================
    Write-Section "✓ Step 7: Application Settings Configuration"
    try {
        Write-Info "Setting environment variables and managed identity config..."
        
        az webapp config appsettings set `
            --name $AppServiceName `
            --resource-group $ResourceGroup `
            --settings `
                POSTGRESQL_SERVER=$PostgreSQLServer `
                POSTGRESQL_PORT=5432 `
                POSTGRESQL_DATABASE=$DatabaseName `
                POSTGRESQL_USERNAME=$AdminUsername `
                POSTGRESQL_PASSWORD=$plainPassword `
                TARGET_TPS=$TargetTPS `
                WORKER_COUNT=$WorkerCount `
                TEST_DURATION=$TestDuration `
                APPLICATIONINSIGHTS_CONNECTION_STRING=$aiConnectionString `
                ApplicationInsightsAgent_EXTENSION_VERSION=~3 `
                XDT_MicrosoftApplicationInsights_Mode=recommended `
                WEBSITES_ENABLE_APP_SERVICE_STORAGE=false `
                DOCKER_REGISTRY_SERVER_URL="" `
                DOCKER_REGISTRY_SERVER_USERNAME="" `
                DOCKER_REGISTRY_SERVER_PASSWORD=""
        
        Write-Success "Environment variables configured"
        Write-Info "Cleared docker registry credentials to enable managed identity"
    }
    catch {
        Write-Error-Custom "Failed to configure app settings"
        throw
    }
    
    # ========================================================================
    # Step 8: Scaling App Service
    # ========================================================================
    Write-Section "✓ Step 8: Scaling App Service"
    try {
        if ($InstanceCount -gt 1) {
            Write-Info "Scaling to $InstanceCount instances..."
            az appservice plan update `
                --name $AppServicePlan `
                --resource-group $ResourceGroup `
                --number-of-workers $InstanceCount
            Write-Success "Scaled to $InstanceCount instances"
        }
        else {
            Write-Info "Using single instance"
        }
    }
    catch {
        Write-Error-Custom "Failed to scale App Service"
        throw
    }
    
    # ========================================================================
    # Step 9: Enable Diagnostics Logging
    # ========================================================================
    Write-Section "✓ Step 9: Diagnostics Logging Setup"
    try {
        Write-Info "Enabling container logging..."
        az webapp log config `
            --name $AppServiceName `
            --resource-group $ResourceGroup `
            --web-server-logging filesystem `
            --docker-container-logging filesystem `
            --level verbose
        
        Write-Success "Diagnostics logging enabled"
    }
    catch {
        Write-Error-Custom "Failed to enable diagnostics"
        Write-Info "Continuing anyway..."
    }
    
    # ========================================================================
    # Step 10: Output Summary
    # ========================================================================
    Write-Section "✅ Deployment Complete!"
    
    $appService = az webapp show --name $AppServiceName --resource-group $ResourceGroup | ConvertFrom-Json
    $appUrl = "https://$($appService.defaultHostName)"
    
    Write-Host "`n📍 Deployment Summary:" -ForegroundColor Green
    Write-Host "  App Service: $AppServiceName" -ForegroundColor Cyan
    Write-Host "  URL: $appUrl" -ForegroundColor Cyan
    Write-Host "  Container Image: $loginServer/$ImageName`:$ImageTag" -ForegroundColor Cyan
    Write-Host "  Application Insights: $appInsightsName" -ForegroundColor Cyan
    Write-Host "  SKU: $SKU (Linux)" -ForegroundColor Cyan
    Write-Host "  Instances: $InstanceCount" -ForegroundColor Cyan
    
    Write-Host "`n⚙️  Configuration:" -ForegroundColor Green
    Write-Host "  PostgreSQL: $PostgreSQLServer" -ForegroundColor Cyan
    Write-Host "  Database: $DatabaseName" -ForegroundColor Cyan
    Write-Host "  Target TPS: $TargetTPS" -ForegroundColor Cyan
    Write-Host "  Workers: $WorkerCount" -ForegroundColor Cyan
    Write-Host "  Duration: ${TestDuration}s" -ForegroundColor Cyan
    
    Write-Host "`n📊 Next Steps:" -ForegroundColor Green
    Write-Host "  1. Monitor with: Monitor-AppService-Logs.ps1" -ForegroundColor Yellow
    Write-Host "  2. View logs: $appUrl/api/logs (if available)" -ForegroundColor Yellow
    Write-Host "  3. Azure Portal: $([string]::Format('https://portal.azure.com/#@microsoft.onmicrosoft.com/resource/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.Web/sites/{2}', (az account show --query id -o tsv), $ResourceGroup, $AppServiceName))" -ForegroundColor Yellow
}
