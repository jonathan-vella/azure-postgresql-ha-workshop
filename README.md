# SAIF: Secure AI Foundations

A 3-tier diagnostic application designed for hands-on learning about securing AI systems across identity, network, application, and content safety domains.

## Project Overview

SAIF is an intentionally insecure application that provides a platform for students to identify security gaps and implement remediation strategies. The application consists of:

1. **Web Frontend**: PHP-based diagnostic interface
2. **API Backend**: Python REST API with various diagnostic endpoints
3. **Database**: SQL Server database for data storage and queries

## Architecture

```
┌───────────┐     ┌───────────┐     ┌───────────┐
│           │     │           │     │           │
│    Web    │────▶│    API    │────▶│    DB     │
│           │     │           │     │           │
└───────────┘     └───────────┘     └───────────┘
```

### Containerized Architecture

The application can be deployed using either traditional App Services or containerized using:

- Web Frontend: PHP 8.2 container
- API Backend: Python FastAPI container in Azure Container Apps
- Database: Azure SQL Database

### Traditional Architecture

- Web Frontend: PHP 8.2 on App Service
- API Backend: Python FastAPI on App Service
- Database: Azure SQL Database

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

By default, deployment uses Sweden Central region (`swedencentral`) with resource group name `rg-aiseclab-swc01`. For Germany West Central, use:

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
