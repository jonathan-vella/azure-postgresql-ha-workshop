# SAIF: Secure AI Foundations

[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)](https://github.com/yourusername/SAIF)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Deployment Status](https://img.shields.io/badge/deployment-ready-success.svg)](docs/deployment.md)
[![Security Challenges](https://img.shields.io/badge/security%20challenges-15%2B-orange.svg)](docs/security-challenges.md)
[![Docker](https://img.shields.io/badge/docker-ready-brightgreen.svg)](docker-compose.yml)
![GitHub stars](https://img.shields.io/github/stars/yourusername/SAIF?style=social)

A 3-tier diagnostic application designed for hands-on learning about securing AI systems across identity, network, application, and content safety domains.

## Project Overview

![PHP](https://img.shields.io/badge/PHP-8.2-777BB4?logo=php&logoColor=white)
![Python](https://img.shields.io/badge/Python-3.11-3776AB?logo=python&logoColor=white)
![FastAPI](https://img.shields.io/badge/FastAPI-0.103.1-009688?logo=fastapi&logoColor=white)
![SQL Server](https://img.shields.io/badge/SQL%20Server-2019-CC2927?logo=microsoft-sql-server&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-24.0.6-2496ED?logo=docker&logoColor=white)
![Azure](https://img.shields.io/badge/Azure-Cloud-0078D4?logo=microsoft-azure&logoColor=white)

SAIF is an intentionally insecure application that provides a platform for students to identify security gaps and implement remediation strategies. The application consists of:

1. **Web Frontend**: PHP-based diagnostic interface
2. **API Backend**: Python REST API with various diagnostic endpoints
3. **Database**: SQL Server database for data storage and queries

## Architecture

```mermaid
graph LR
    User((User)) --> Web
    Web --> API
    API --> DB
    
    subgraph "SAIF Application"
        Web["Web Frontend<br/>(PHP 8.2)"]
        API["API Backend<br/>(Python FastAPI)"]
        DB[(Database<br/>SQL Server)]
    end
    
    classDef component fill:#0078D4,stroke:#005A9E,color:white,rx:5px,ry:5px;
    classDef database fill:#0078D4,stroke:#005A9E,color:white,rx:10px,ry:10px;
    classDef user fill:#5C5C5C,stroke:#5C5C5C,color:white;
    class Web,API component;
    class DB database;
    class User user;
```

### Containerized Architecture

The application uses Docker containers for all components:

- **Web Frontend**: PHP 8.2 container
- **API Backend**: Python FastAPI container
- **Database**: SQL Server container (development) / Azure SQL Database (production)

### Azure Deployment Options

When deployed to Azure, the application can use:

- **Web Frontend**: Containerized App Service or Azure Container Apps
- **API Backend**: Containerized App Service or Azure Container Apps
- **Database**: Azure SQL Database

## Deployment

### Local Development

Run SAIF locally using Docker for testing:

```powershell
cd scripts
.\Test-SAIFLocal.ps1
```

### Azure Deployment

SAIF can be deployed to Azure App Service (B1) with a single command:

```powershell
cd scripts
.\Deploy-SAIF.ps1
```

By default, deployment uses Sweden Central region (`swedencentral`) with resource group name `rg-saif-swc01`. For Germany West Central, use:

```powershell
cd scripts
.\Deploy-SAIF.ps1 -location germanywestcentral
```

For a custom deployment:

```powershell
cd scripts
.\Deploy-SAIF.ps1 -resourceGroupName "my-custom-rg" -location "germanywestcentral" -environmentName "saif-prod"
```

For detailed deployment instructions, see the [Deployment Guide](docs/deployment.md).

## Security Challenges

This application contains multiple security vulnerabilities for students to identify and fix, including:

- Identity and Access Management vulnerabilities
- Network security gaps
- Application security issues
- Data protection weaknesses
- API security concerns
- Content safety risks

## Workshop Structure

1. **Deployment**: Deploy the insecure application
2. **Discovery**: Identify security vulnerabilities
3. **Remediation**: Implement fixes for the discovered issues
4. **Verification**: Confirm that the security improvements are effective

## Repository Structure

```mermaid
graph TD
    Root[SAIF Repository] --> API[/api]
    Root --> Web[/web]
    Root --> Infra[/infra]
    Root --> Scripts[/scripts]
    Root --> Docs[/docs]
    Root --> DockerCompose[docker-compose.yml]
    
    API --> APICode[Python FastAPI Code]
    API --> Requirements[requirements.txt]
    
    Web --> WebCode[PHP Frontend]
    Web --> Assets[/assets]
    
    Infra --> BicepTemplates[Bicep Templates]
    Infra --> Modules[/modules]
    
    Scripts --> DeployScript[Deploy-SAIF.ps1]
    Scripts --> TestScript[Test-SAIFLocal.ps1]
    
    Docs --> DeploymentDoc[deployment.md]
    Docs --> SecurityDoc[security-challenges.md]
    
    classDef folder fill:#f9d75e,stroke:#333,color:black;
    classDef file fill:#78b2f2,stroke:#333,color:black;
    classDef component fill:#91ca76,stroke:#333,color:black;
    
    class API,Web,Infra,Scripts,Docs,Modules folder;
    class DockerCompose,Requirements,DeployScript,TestScript,DeploymentDoc,SecurityDoc file;
    class APICode,WebCode,Assets,BicepTemplates component;
```

- `/api`: Python FastAPI backend
- `/web`: PHP web frontend
- `/infra`: Bicep infrastructure templates
  - `/modules`: Modular Bicep components
- `/scripts`: PowerShell deployment and utility scripts
- `/docs`: Documentation and guides
- `docker-compose.yml`: Local development configuration

## Prerequisites

- Azure subscription
- Azure CLI
- PowerShell 7.0+
- Docker and Docker Compose (for local development)
- Visual Studio Code (recommended)

## License

MIT
