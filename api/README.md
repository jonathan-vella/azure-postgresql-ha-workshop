# SAIF-PostgreSQL API

## Overview

Python FastAPI application providing a payment gateway REST API with intentional security vulnerabilities for educational purposes.

## Features

### Payment Gateway APIs
- `POST /api/payments/process` - Process payment transactions
- `GET /api/payments/{transaction_id}` - Get transaction details
- `GET /api/payments/customer/{customer_id}` - Get customer transaction history
- `GET /api/payments/merchant/{merchant_id}/summary` - Get merchant transaction summary

### Customer Management APIs
- `POST /api/customers/create` - Create new customer account
- `GET /api/customers/{customer_id}` - Get customer details

### Diagnostic APIs
- `GET /api/healthcheck` - Health check with database connectivity test
- `GET /api/ip` - Server IP information
- `GET /api/sqlversion` - PostgreSQL version (⚠️ SQL injection vulnerability)
- `GET /api/sqlsrcip` - Source IP from PostgreSQL perspective
- `GET /api/dns/{hostname}` - DNS resolution
- `GET /api/reversedns/{ip}` - Reverse DNS lookup
- `GET /api/curl?url=<url>` - Fetch URL (⚠️ SSRF vulnerability)
- `GET /api/printenv` - Environment variables (⚠️ Information disclosure)
- `GET /api/pi?digits=<n>` - Calculate PI (CPU load test)

### Load Testing APIs
- `POST /api/test/create-transaction` - Create test transaction for load testing
- `GET /api/test/db-status` - Detailed database status for HA monitoring

## Local Development

### Prerequisites
- Python 3.11+
- PostgreSQL 14+ (local or Azure)

### Setup

1. Create virtual environment:
```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

2. Install dependencies:
```bash
pip install -r requirements.txt
```

3. Configure environment:
```bash
cp .env.example .env
# Edit .env with your PostgreSQL connection details
```

4. Run the application:
```bash
uvicorn app:app --reload --host 0.0.0.0 --port 8000
```

5. Access API documentation:
- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

## Docker

### Build Image
```bash
docker build -t saif-pgsql-api .
```

### Run Container
```bash
docker run -p 8000:8000 \
  -e POSTGRES_HOST=your-postgres-server.postgres.database.azure.com \
  -e POSTGRES_DATABASE=saifdb \
  -e POSTGRES_USER=saifadmin \
  -e POSTGRES_PASSWORD=YourPassword \
  saif-pgsql-api
```

## API Authentication

Most endpoints require an API key passed via the `X-API-Key` header:

```bash
curl -H "X-API-Key: demo_api_key_12345" \
  https://your-api.azurewebsites.net/api/customers/1
```

⚠️ **Warning**: API key authentication is deliberately weak for educational purposes.

## Database Schema

The API expects the following PostgreSQL schema (created by `init-db.sql`):

- `customers` - Customer accounts
- `merchants` - Merchant profiles
- `payment_methods` - Payment instruments
- `transactions` - Payment transactions
- `orders` - E-commerce orders
- `order_items` - Order line items
- `transaction_logs` - Audit trail

## Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `POSTGRES_HOST` | PostgreSQL server hostname | Yes |
| `POSTGRES_PORT` | PostgreSQL port (5432=direct, 6432=PgBouncer, default: 5432) | No |
| `POSTGRES_DATABASE` | Database name | Yes |
| `POSTGRES_USER` | Database username | Yes |
| `POSTGRES_PASSWORD` | Database password | Yes |
| `API_KEY` | API authentication key | No |
| `APPLICATIONINSIGHTS_CONNECTION_STRING` | Azure Application Insights | No |

## Security Vulnerabilities (Intentional)

This application contains the following vulnerabilities for educational purposes:

1. **SQL Injection** - `/api/sqlversion` endpoint
2. **SSRF** - `/api/curl` endpoint allows fetching arbitrary URLs
3. **Information Disclosure** - `/api/printenv` exposes environment variables
4. **Weak Authentication** - Simple API key in header
5. **No Rate Limiting** - APIs can be hammered
6. **Permissive CORS** - Allows all origins

⚠️ **DO NOT use this code in production without proper security hardening.**

## Testing

### Run Tests
```bash
pytest
```

### Load Testing
Use the test endpoints to generate synthetic load:

```bash
# Create 100 test transactions
for i in {1..100}; do
  curl -X POST "http://localhost:8000/api/test/create-transaction?amount=99.99"
done
```

## Deployment

See the main [Deployment Guide](../docs/v1.0.0/deployment-guide.md) for complete deployment instructions.

## License

MIT
