# LoadGenerator App Service Configuration
# Update these values before deployment

# ============================================================================
# COMMON DEPLOYMENT VARIABLES (applies to ALL resources)
# ============================================================================
# All resources (App Service, ACR, Application Insights) will be deployed to the SAME region and resource group

$Region = "centralus"
$ResourceGroup = "rg-pgv2-usc01"

# Alternative regions:
# $Region = "swedencentral"
# $Region = "eastus"
# $Region = "westeurope"

# ============================================================================
# GENERATE RANDOM SUFFIX FOR UNIQUENESS
# ============================================================================
# Generates a random suffix for App Service and ACR names to ensure global uniqueness
$RandomSuffix = -join ((48..57) + (97..122) | Get-Random -Count 5 | ForEach-Object {[char]$_})
# Example: app-loadgen-a1b2c or plan-loadgen-x9y8z

# ============================================================================
# APP SERVICE CONFIGURATION
# ============================================================================
$AppServiceConfig = @{
    # App Service name (must be globally unique)
    # Option 1: Use fixed name
    # AppServiceName = "app-loadgen-001"
    
    # Option 2: Use random suffix for uniqueness (RECOMMENDED)
    AppServiceName = "app-loadgen-$RandomSuffix"
    
    # App Service Plan name
    # Option 1: Use fixed name
    # AppServicePlan = "plan-loadgen-001"
    
    # Option 2: Use random suffix for uniqueness (RECOMMENDED)
    AppServicePlan = "plan-loadgen-$RandomSuffix"
    
    # SKU: Valid options are P0V3, P1V3, P2V3, B1, B2, B3, S1, S2, S3, etc.
    # P0V3 is the entry-level premium with 1 core, 4GB RAM (good for load testing)
    SKU = "P0V3"
    
    # Number of instances (1-10 for P0)
    InstanceCount = 1
    
    # NOTE: Deployed to $Region and $ResourceGroup (defined above)
}

# ============================================================================
# CONTAINER REGISTRY
# ============================================================================
$ContainerRegistry = @{
    # ACR name (without .azurecr.io)
    # IMPORTANT: ACR names must be lowercase alphanumeric only, globally unique
    
    # NOTE: Build script will auto-detect existing ACR or create new one if missing
    # The newly created ACR name (if auto-provisioned)
    Name = "acrsaifpg100815203"
    
    # Container image details
    ImageName = "loadgenerator"
    ImageTag = "latest"
    
    # NOTE: Deployed to $Region and $ResourceGroup (defined above)
}

# ============================================================================
# POSTGRESQL DATABASE
# ============================================================================
$PostgreSQLConfig = @{
    # PostgreSQL server FQDN
    Server = "pg-cus.postgres.database.azure.com"
    
    # Database name
    Database = "saifdb"
    
    # Admin username
    AdminUsername = "jonathan"
    
    # Admin password - will be prompted if not provided
    # AdminPassword = ""  # Leave empty to prompt
}

# ============================================================================
# LOAD TEST PARAMETERS
# ============================================================================
$LoadTestConfig = @{
    # Target transactions per second
    TargetTPS = 1000
    
    # Number of concurrent worker threads
    WorkerCount = 200
    
    # Test duration in seconds
    TestDuration = 300
}

# ============================================================================
# APPLICATION INSIGHTS
# ============================================================================
$AppInsightsConfig = @{
    # Auto-generate name based on AppServiceName
    # Name = "app-loadgen-001-ai"
    
    # Retention period (days)
    RetentionDays = 30
    
    # Application type: web, other
    ApplicationType = "web"
}

# ============================================================================
# Export for use in scripts (DO NOT MODIFY - for internal use)
# ============================================================================
# Variables are loaded via ". $ConfigFile" in deployment scripts

# ============================================================================
# NAMING OPTIONS & EXAMPLES
# ============================================================================
<#

## App Service Names

### Option 1: Fixed Names (Simple, predictable)
AppServiceName = "app-loadgen-001"
AppServicePlan = "plan-loadgen-001"

Issues: Name conflicts if deploying multiple times or across teams


### Option 2: Random Suffix (Recommended)
AppServiceName = "app-loadgen-$RandomSuffix"      # Example: app-loadgen-a1b2c
AppServicePlan = "plan-loadgen-$RandomSuffix"     # Example: plan-loadgen-x9y8z

Benefits:
- Globally unique names
- Multiple deployments without conflicts
- Team-friendly for shared subscriptions


### Option 3: Timestamp-based
AppServiceName = "app-loadgen-$(Get-Date -Format 'yyyyMMddHHmm')"
AppServicePlan = "plan-loadgen-$(Get-Date -Format 'yyyyMMddHHmm')"

Example: app-loadgen-202510161530


## ACR Names

IMPORTANT: Azure Container Registry names must be:
- Lowercase letters and numbers ONLY (no hyphens)
- 5-50 characters
- Globally unique across Azure


### Option 1: Fixed Name (Use existing registry)
Name = "acrsaifpg10081025"

Issues: Must exist already, cannot reuse across projects


### Option 2: Timestamp + Random (New registry)
Name = "acr$(Get-Date -Format 'yyMMdd')$([Math]::Abs($(Get-Random))%10000)"

Example: acr251016a1b2c

Benefits:
- Auto-generates unique names
- Can deploy fresh registry each time
- Cleanup-friendly (date in name)


## Usage Examples

# Single deployment with fixed names
.\Deploy-LoadGenerator-AppService.ps1 -Action Deploy

# Multiple deployments with auto-generated unique names
# Just run the script multiple times - each gets unique suffix

# Override in command line if needed
.\Deploy-LoadGenerator-AppService.ps1 -AppServiceName "app-mytest-001" -Action Deploy

#>

