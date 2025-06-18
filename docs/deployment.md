# SAIF: Deployment Guide

## Overview

This document provides detailed instructions for deploying the SAIF (Secure AI Foundations) application to Azure. SAIF is a 3-tier application designed for hands-on learning about securing AI systems across identity, network, application, and content safety domains.

## Deployment Options

SAIF can be deployed in two ways:

```mermaid
graph TD
    Start((Start)) --> Local[Local Development]
    Start --> Cloud[Azure Deployment]
    
    subgraph "Local Path"
        Local --> DockerCompose[Docker Compose]
        DockerCompose --> LocalWeb[Web Container]
        DockerCompose --> LocalAPI[API Container]
        DockerCompose --> LocalDB[DB Container]
        LocalWeb & LocalAPI & LocalDB --> Test[Test Application]
    end
    
    subgraph "Azure Path"
        Cloud --> Script[Run Deploy-SAIF.ps1]
        Script --> Infrastructure[Deploy Infrastructure]
        Infrastructure --> BuildImages[Build Container Images]
        BuildImages --> PushImages[Push to Azure Container Registry]
        PushImages --> DeployWebApp[Deploy Web App]
        PushImages --> DeployAPIApp[Deploy API App]
        DeployWebApp & DeployAPIApp --> ConfigureSettings[Configure App Settings]
    end
    
    classDef start fill:#f96,stroke:#333,color:black;
    classDef local fill:#9ff,stroke:#333,color:black;
    classDef cloud fill:#9cf,stroke:#333,color:black;
    class Start start;
    class Local,DockerCompose,LocalWeb,LocalAPI,LocalDB,Test local;
    class Cloud,Script,Infrastructure,BuildImages,PushImages,DeployWebApp,DeployAPIApp,ConfigureSettings cloud;
```

1. **Local Development**: Using Docker for local testing
2. **Azure Deployment**: Using Azure App Services and Azure Container Registry

## Prerequisites

- Azure Subscription
- Azure CLI (latest version)
- PowerShell 7.0+
- Docker and Docker Compose (for local development)
- Git

## Local Development Setup

To run SAIF locally for development or testing:

1. Clone the repository:
   ```
   git clone <repository-url>
   cd SAIF
   ```

2. Run the local testing script:
   ```powershell
   cd scripts
   .\Test-SAIFLocal.ps1
   ```

3. Access the application:
   - Web Front End: http://localhost
   - API: http://localhost:8000

4. To stop the application:
   ```powershell
   cd ..
   docker-compose down
   ```

## Azure Deployment

### Default Deployment

To deploy SAIF to Azure with default settings:

1. Clone the repository:
   ```
   git clone <repository-url>
   cd SAIF
   ```

2. Run the deployment script:
   ```powershell
   cd scripts
   .\Deploy-SAIF.ps1
   ```

This will deploy to Sweden Central using the resource group name `rg-aiseclab-swc01`.

### Custom Deployment

To customize your deployment:

```powershell
cd scripts
.\Deploy-SAIF.ps1 -resourceGroupName "my-custom-rg" -location "germanywestcentral" -environmentName "saif-prod"
```

### Deployment Parameters

- `resourceGroupName`: (Optional) Azure resource group name. If not specified, it defaults to `rg-aiseclab-swc01` for Sweden Central or `rg-aiseclab-gwc01` for Germany West Central.
- `location`: (Optional) Azure region for deployment. Default is 'swedencentral'. Allowed values: 'swedencentral', 'germanywestcentral'.
- `environmentName`: (Optional) Environment name used for resource naming. Default is 'saif'.

## Architecture

SAIF is a 3-tier application with the following components:

```mermaid
graph LR
    subgraph "Front End"
        Web["Web Frontend<br/>(PHP 8.2)"]
    end
    subgraph "Middle Tier"
        API["API Backend<br/>(Python FastAPI)"]
    end
    subgraph "Data Tier"
        DB["Database<br/>(SQL Server)"]
    end
    User((User)) --> Web
    Web --> API
    API --> DB
    
    classDef azure fill:#0072C6,stroke:#0072C6,color:white;
    classDef user fill:#5C5C5C,stroke:#5C5C5C,color:white;
    class Web,API,DB azure;
    class User user;
```

- **Web Frontend**: PHP 8.2 container running on Azure App Service (B1)
- **API Backend**: Python FastAPI container running on Azure App Service (B1)
- **Database**: Azure SQL Database (Basic tier)

## Azure Resources

The deployment creates the following Azure resources:

```mermaid
flowchart TD
    RG[Resource Group] --> ACR[Azure Container Registry]
    RG --> ASP[App Service Plan]
    RG --> SQL[Azure SQL Server]
    SQL --> SQLDB[SQL Database]
    RG --> LAW[Log Analytics Workspace]
    ASP --> WebApp[Web App Service]
    ASP --> ApiApp[API App Service]
    LAW --> AppInsights[Application Insights]
    ACR --> WebApp
    ACR --> ApiApp
    WebApp --> AppInsights
    ApiApp --> AppInsights
    WebApp --> ApiApp
    ApiApp --> SQLDB

    classDef azureResource fill:#0078D4,stroke:#0078D4,color:white,rx:5px,ry:5px;
    class RG,ACR,ASP,SQL,SQLDB,LAW,WebApp,ApiApp,AppInsights azureResource;
```

- **Resource Group**: Contains all deployment resources
- **Azure Container Registry (Basic tier)**: Stores container images
- **App Service Plan (B1)**: Hosts the App Services
- **Web App Service**: Runs the PHP web frontend
- **API App Service**: Runs the Python FastAPI backend
- **SQL Server and Database**: Stores application data
- **Log Analytics Workspace**: Central log collection
- **Application Insights**: Application monitoring and diagnostics

## Resource Naming Convention

All resources are named using the following pattern:
`{environmentName}-{resourceType}-{randomSuffix}`

Where:
- `environmentName` is the name provided during deployment (default: 'saif')
- `resourceType` describes the resource (e.g., 'api', 'web', 'sql')
- `randomSuffix` is a unique 6-character string based on the resource group ID

## Security Challenges

This application is deliberately insecure for educational purposes. Students are expected to identify and fix security vulnerabilities including:

- Insecure API key handling
- Lack of proper authentication and authorization
- Overly permissive CORS settings
- SQL injection vulnerabilities
- Information disclosure
- And more...

## Troubleshooting

### Docker Issues
- Ensure Docker Desktop is running
- Check container logs: `docker-compose logs`
- Restart containers: `docker-compose restart`

### Azure Deployment Issues
- Check Azure CLI is installed and updated
- Ensure you have the proper permissions in your Azure subscription
- Verify resource quotas and limits for your subscription

## Clean Up Resources

To remove all Azure resources:

```powershell
az group delete --name <resource-group-name> --yes --no-wait
```

## Version Information

- Current Version: 1.0.0
- Last Updated: 2025-06-18
