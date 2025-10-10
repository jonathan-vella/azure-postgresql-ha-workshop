# SAIF-PostgreSQL Architecture

## System Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          Azure Cloud - Sweden Central                        │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │                        Availability Zone 1                              │ │
│  │  ┌──────────────────┐    ┌──────────────────┐    ┌─────────────────┐  │ │
│  │  │  Web App Service │    │  API App Service │    │   PostgreSQL    │  │ │
│  │  │   (PHP/Apache)   │───▶│   (FastAPI)      │───▶│  Primary Server │  │ │
│  │  │   Port 80        │    │   Port 8000      │    │   Port 5432     │  │ │
│  │  └──────────────────┘    └──────────────────┘    └─────────────────┘  │ │
│  │           │                       │                        │            │ │
│  │           │                       │                        │            │ │
│  │           ▼                       ▼                        ▼            │ │
│  │  ┌────────────────────────────────────────────────────────────────┐    │ │
│  │  │              Application Insights & Log Analytics              │    │ │
│  │  └────────────────────────────────────────────────────────────────┘    │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                                    │                                         │
│                                    │ Synchronous                             │
│                                    │ Replication                             │
│                                    │ (RPO = 0)                               │
│                                    ▼                                         │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │                        Availability Zone 2                              │ │
│  │  ┌─────────────────┐                                                    │ │
│  │  │   PostgreSQL    │                                                    │ │
│  │  │ Standby Server  │  Automatic Failover (RTO: 60-120s)                │ │
│  │  │   Hot Standby   │  Zero Data Loss (RPO: 0)                          │ │
│  │  └─────────────────┘                                                    │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │                      Supporting Services                                │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐                 │ │
│  │  │ Azure Key    │  │   Azure      │  │  Azure       │                 │ │
│  │  │   Vault      │  │  Container   │  │  Backup      │                 │ │
│  │  │  (Secrets)   │  │  Registry    │  │  (7-day)     │                 │ │
│  │  └──────────────┘  └──────────────┘  └──────────────┘                 │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘
                                    ▲
                                    │
                                    │ HTTPS
                                    │
                            ┌───────┴────────┐
                            │   End Users    │
                            │   (Browsers)   │
                            └────────────────┘
```

## Database Schema Architecture

**See full schema in database/init-db.sql**

8 Tables: customers, merchants, payment_methods, transactions, orders, order_items, transaction_logs  
2 Views: merchant_transaction_summary  
1 Function: create_test_transaction()

## High Availability Configuration

```yaml
Database: Azure PostgreSQL Flexible Server 16
HA Mode: Zone-Redundant
Compute: Standard_D4ds_v5 (4 vCore, 16 GB RAM)
Storage: 128 GB Premium SSD
SLA: 99.99% uptime, RPO=0, RTO=60-120s
```

---

For complete architecture diagrams, see [Deployment Guide](deployment-guide.md) and [README.md](../../README.md).
