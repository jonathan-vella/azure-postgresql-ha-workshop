# API Component for SAIF

[![Python](https://img.shields.io/badge/Python-3.11-3776AB?logo=python&logoColor=white)](https://www.python.org/)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.103.1-009688?logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com/)
[![SQLAlchemy](https://img.shields.io/badge/SQLAlchemy-2.0-red?logo=sqlalchemy&logoColor=white)](https://www.sqlalchemy.org/)
[![Docker](https://img.shields.io/badge/Docker-Ready-2496ED?logo=docker&logoColor=white)](../docker-compose.yml)

Python-based API that provides various diagnostic endpoints for testing and learning about security concepts.

```mermaid
classDiagram
    class SAIFApi {
        +healthcheck() : Status
        +ip() : IPInfo
        +sqlversion() : Version
        +sqlsrcip() : IPAddress
        +dns(hostname) : Resolution
        +reversedns(ip) : Hostname
        +curl(url) : Response
        +printenv() : Variables
        +pi(digits) : Calculation
    }
    
    class Endpoint {
        <<interface>>
        +path : string
        +method : string
        +description : string
        +vulnerabilities : string[]
    }
    
    SAIFApi --> Endpoint
```

## Endpoints

The API provides the following endpoints:

- `/api/healthcheck` - Simple health check
- `/api/ip` - Returns IP address information
- `/api/sqlversion` - Returns the SQL Server version
- `/api/sqlsrcip` - Returns the source IP as seen by SQL Server
- `/api/dns` - Resolves a DNS name
- `/api/reversedns` - Performs reverse DNS lookup
- `/api/curl` - Makes an HTTP request to a specified URL
- `/api/printenv` - Returns environment variables
- `/api/pi` - Calculates PI to test CPU load

## Setup

```bash
pip install -r requirements.txt
```

## Running Locally

```bash
uvicorn app:app --reload
```

## Environment Variables

- `SQL_SERVER` - SQL Server hostname
- `SQL_DATABASE` - Database name
- `SQL_USERNAME` - SQL username
- `SQL_PASSWORD` - SQL password
- `API_KEY` - Optional API key for authentication (deliberately insecure)
