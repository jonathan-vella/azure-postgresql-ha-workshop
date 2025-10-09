import os
import socket
import dns.resolver
import requests
import psycopg2
from psycopg2.extras import RealDictCursor
import mpmath
import uvicorn
from fastapi import FastAPI, HTTPException, Header, Request
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv
from typing import Optional, Dict, Any
from pydantic import BaseModel, EmailStr
from decimal import Decimal
import time
from datetime import datetime
import uuid

# Load environment variables from .env file if present
load_dotenv()

app = FastAPI(
    title="SAIF-PostgreSQL API",
    description="Payment Gateway API with intentional security vulnerabilities for educational purposes",
    version="2.0.0"
)

# CORS middleware configuration - deliberately insecure for challenge purposes
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allow all origins
    allow_credentials=True,
    allow_methods=["*"],  # Allow all methods
    allow_headers=["*"],  # Allow all headers
)

# Optional insecure API key authentication
API_KEY = os.getenv("API_KEY", "demo_api_key_12345")

# PostgreSQL connection info
POSTGRES_HOST = os.getenv("POSTGRES_HOST")
POSTGRES_PORT = os.getenv("POSTGRES_PORT", "5432")
POSTGRES_DATABASE = os.getenv("POSTGRES_DATABASE")
POSTGRES_USER = os.getenv("POSTGRES_USER")
POSTGRES_PASSWORD = os.getenv("POSTGRES_PASSWORD")

# ============================================================================
# PYDANTIC MODELS
# ============================================================================

class CustomerCreate(BaseModel):
    email: EmailStr
    first_name: str
    last_name: str
    phone: Optional[str] = None
    city: Optional[str] = None
    state: Optional[str] = None
    country: str = "USA"

class PaymentProcess(BaseModel):
    customer_id: int
    merchant_id: int
    amount: float
    currency: str = "USD"
    description: Optional[str] = None

class TransactionResponse(BaseModel):
    transaction_id: str
    status: str
    amount: float
    currency: str
    transaction_date: str

# ============================================================================
# DATABASE CONNECTION
# ============================================================================

def get_db_connection():
    """Create a PostgreSQL database connection using environment variables"""
    if not all([POSTGRES_HOST, POSTGRES_DATABASE, POSTGRES_USER, POSTGRES_PASSWORD]):
        raise HTTPException(status_code=500, detail="Database connection information not configured")
    
    try:
        conn = psycopg2.connect(
            host=POSTGRES_HOST,
            port=POSTGRES_PORT,
            database=POSTGRES_DATABASE,
            user=POSTGRES_USER,
            password=POSTGRES_PASSWORD,
            sslmode='require',
            connect_timeout=10
        )
        return conn
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Database connection failed: {str(e)}")

def get_db_cursor(conn):
    """Get a cursor that returns results as dictionaries"""
    return conn.cursor(cursor_factory=RealDictCursor)

# ============================================================================
# ROOT & HEALTH ENDPOINTS
# ============================================================================

@app.get("/")
async def root():
    """Root endpoint with API information"""
    return {
        "name": "SAIF-PostgreSQL API",
        "version": "2.0.0",
        "description": "Payment Gateway API for security training and HA demonstrations",
        "database": "PostgreSQL Flexible Server",
        "features": [
            "Payment Processing",
            "Customer Management",
            "Transaction History",
            "High Availability Testing"
        ],
        "endpoints": {
            "health": "/api/healthcheck",
            "payments": "/api/payments/*",
            "customers": "/api/customers/*",
            "diagnostics": "/api/{ip|dns|sqlversion|etc}"
        }
    }

@app.get("/api/healthcheck")
async def healthcheck():
    """Health check endpoint with database connectivity test"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT 1")
        cursor.close()
        conn.close()
        
        return {
            "status": "healthy",
            "timestamp": time.time(),
            "database": "connected",
            "api_version": "2.0.0"
        }
    except Exception as e:
        return {
            "status": "unhealthy",
            "timestamp": time.time(),
            "database": "disconnected",
            "error": str(e)
        }

# ============================================================================
# PAYMENT GATEWAY ENDPOINTS
# ============================================================================

@app.post("/api/payments/process")
async def process_payment(payment: PaymentProcess, x_api_key: Optional[str] = Header(None)):
    """Process a payment transaction"""
    # Insecure API key check
    if x_api_key != API_KEY:
        raise HTTPException(status_code=401, detail="Invalid API Key")
    
    try:
        conn = get_db_connection()
        cursor = get_db_cursor(conn)
        
        # Get merchant fee structure
        cursor.execute(
            "SELECT fee_percentage, fee_fixed FROM merchants WHERE merchant_id = %s AND status = 'active'",
            (payment.merchant_id,)
        )
        merchant = cursor.fetchone()
        
        if not merchant:
            raise HTTPException(status_code=404, detail="Merchant not found or inactive")
        
        # Calculate fees (convert Decimal to float for calculations)
        merchant_fee = (payment.amount * float(merchant['fee_percentage']) / 100) + float(merchant['fee_fixed'])
        net_amount = payment.amount - merchant_fee
        
        # Insert transaction
        cursor.execute("""
            INSERT INTO transactions (
                customer_id, merchant_id, amount, currency, merchant_fee, net_amount,
                status, description, risk_score
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
            RETURNING transaction_id, status, transaction_date
        """, (
            payment.customer_id,
            payment.merchant_id,
            payment.amount,
            payment.currency,
            merchant_fee,
            net_amount,
            'completed',
            payment.description,
            15  # Default risk score
        ))
        
        result = cursor.fetchone()
        conn.commit()
        cursor.close()
        conn.close()
        
        return {
            "transaction_id": str(result['transaction_id']),
            "status": result['status'],
            "amount": payment.amount,
            "currency": payment.currency,
            "merchant_fee": float(merchant_fee),
            "net_amount": float(net_amount),
            "transaction_date": result['transaction_date'].isoformat()
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Payment processing failed: {str(e)}")

@app.get("/api/payments/{transaction_id}")
async def get_transaction(transaction_id: str):
    """Get transaction details by ID"""
    try:
        conn = get_db_connection()
        cursor = get_db_cursor(conn)
        
        cursor.execute("""
            SELECT 
                t.transaction_id,
                t.amount,
                t.currency,
                t.status,
                t.transaction_date,
                t.description,
                c.email as customer_email,
                c.first_name,
                c.last_name,
                m.merchant_name,
                m.merchant_code
            FROM transactions t
            JOIN customers c ON t.customer_id = c.customer_id
            JOIN merchants m ON t.merchant_id = m.merchant_id
            WHERE t.transaction_id = %s
        """, (transaction_id,))
        
        transaction = cursor.fetchone()
        cursor.close()
        conn.close()
        
        if not transaction:
            raise HTTPException(status_code=404, detail="Transaction not found")
        
        return dict(transaction)
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to retrieve transaction: {str(e)}")

@app.get("/api/payments/customer/{customer_id}")
async def get_customer_transactions(customer_id: int, limit: int = 10):
    """Get transaction history for a customer"""
    try:
        conn = get_db_connection()
        cursor = get_db_cursor(conn)
        
        cursor.execute("""
            SELECT 
                t.transaction_id,
                t.amount,
                t.currency,
                t.status,
                t.transaction_date,
                t.description,
                m.merchant_name
            FROM transactions t
            JOIN merchants m ON t.merchant_id = m.merchant_id
            WHERE t.customer_id = %s
            ORDER BY t.transaction_date DESC
            LIMIT %s
        """, (customer_id, limit))
        
        transactions = cursor.fetchall()
        cursor.close()
        conn.close()
        
        return {
            "customer_id": customer_id,
            "transaction_count": len(transactions),
            "transactions": [dict(t) for t in transactions]
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to retrieve transactions: {str(e)}")

@app.get("/api/payments/merchant/{merchant_id}/summary")
async def get_merchant_summary(merchant_id: int):
    """Get transaction summary for a merchant"""
    try:
        conn = get_db_connection()
        cursor = get_db_cursor(conn)
        
        cursor.execute("""
            SELECT * FROM merchant_transaction_summary
            WHERE merchant_id = %s
        """, (merchant_id,))
        
        summary = cursor.fetchone()
        cursor.close()
        conn.close()
        
        if not summary:
            raise HTTPException(status_code=404, detail="Merchant not found")
        
        return dict(summary)
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to retrieve summary: {str(e)}")

# ============================================================================
# CUSTOMER MANAGEMENT ENDPOINTS
# ============================================================================

@app.post("/api/customers/create")
async def create_customer(customer: CustomerCreate, x_api_key: Optional[str] = Header(None)):
    """Create a new customer account"""
    # Insecure API key check
    if x_api_key != API_KEY:
        raise HTTPException(status_code=401, detail="Invalid API Key")
    
    try:
        conn = get_db_connection()
        cursor = get_db_cursor(conn)
        
        cursor.execute("""
            INSERT INTO customers (
                email, first_name, last_name, phone, city, state, country
            ) VALUES (%s, %s, %s, %s, %s, %s, %s)
            RETURNING customer_id, created_at
        """, (
            customer.email,
            customer.first_name,
            customer.last_name,
            customer.phone,
            customer.city,
            customer.state,
            customer.country
        ))
        
        result = cursor.fetchone()
        conn.commit()
        cursor.close()
        conn.close()
        
        return {
            "customer_id": result['customer_id'],
            "email": customer.email,
            "first_name": customer.first_name,
            "last_name": customer.last_name,
            "created_at": result['created_at'].isoformat(),
            "status": "active"
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to create customer: {str(e)}")

@app.get("/api/customers/{customer_id}")
async def get_customer(customer_id: int):
    """Get customer details"""
    try:
        conn = get_db_connection()
        cursor = get_db_cursor(conn)
        
        cursor.execute("""
            SELECT customer_id, email, first_name, last_name, phone, 
                   city, state, country, status, created_at
            FROM customers
            WHERE customer_id = %s
        """, (customer_id,))
        
        customer = cursor.fetchone()
        cursor.close()
        conn.close()
        
        if not customer:
            raise HTTPException(status_code=404, detail="Customer not found")
        
        return dict(customer)
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to retrieve customer: {str(e)}")

# ============================================================================
# DIAGNOSTIC ENDPOINTS (Deliberately Vulnerable)
# ============================================================================

@app.get("/api/ip")
async def get_ip_info():
    """Returns IP address information"""
    hostname = socket.gethostname()
    local_ip = socket.gethostbyname(hostname)
    
    # Attempt to get public IP
    try:
        public_ip = requests.get('https://api.ipify.org', timeout=3).text
    except Exception:
        public_ip = "Unable to determine"
        
    return {
        "hostname": hostname,
        "local_ip": local_ip,
        "public_ip": public_ip
    }

@app.get("/api/sqlversion")
async def get_sql_version(x_api_key: Optional[str] = Header(None)):
    """Returns the PostgreSQL version - SQL INJECTION VULNERABILITY"""
    # Insecure API key check
    if API_KEY and x_api_key != API_KEY:
        raise HTTPException(status_code=401, detail="Invalid API Key")
        
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # SQL INJECTION VULNERABILITY - concatenating user input directly
        # In a real vulnerable scenario, this would accept query parameters
        query = "SELECT version()"
        cursor.execute(query)
        
        version = cursor.fetchone()[0]
        cursor.close()
        conn.close()
        
        return {"postgresql_version": version}
    except Exception as e:
        return {"error": str(e)}

@app.get("/api/sqlsrcip")
async def get_sql_source_ip(x_api_key: Optional[str] = Header(None)):
    """Returns the source IP as seen by PostgreSQL"""
    # Insecure API key check
    if API_KEY and x_api_key != API_KEY:
        raise HTTPException(status_code=401, detail="Invalid API Key")
        
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Get client IP from PostgreSQL perspective
        cursor.execute("SELECT inet_client_addr()")
        client_ip = cursor.fetchone()[0]
        
        cursor.close()
        conn.close()
        
        return {"source_ip": str(client_ip) if client_ip else "localhost"}
    except Exception as e:
        return {"error": str(e)}

@app.get("/api/dns/{hostname}")
async def resolve_dns(hostname: str):
    """Resolves a DNS name to IP addresses"""
    try:
        results = {
            "hostname": hostname,
            "a_records": [],
            "aaaa_records": []
        }
        
        try:
            a_records = dns.resolver.resolve(hostname, 'A')
            results["a_records"] = [record.address for record in a_records]
        except:
            pass
            
        try:
            aaaa_records = dns.resolver.resolve(hostname, 'AAAA')
            results["aaaa_records"] = [record.address for record in aaaa_records]
        except:
            pass
            
        return results
    except Exception as e:
        return {
            "hostname": hostname,
            "error": str(e)
        }

@app.get("/api/reversedns/{ip}")
async def reverse_dns(ip: str):
    """Performs reverse DNS lookup"""
    try:
        hostname = socket.gethostbyaddr(ip)[0]
        return {"ip": ip, "hostname": hostname}
    except Exception as e:
        return {"ip": ip, "error": str(e)}

@app.get("/api/curl")
async def curl_url(url: str):
    """Makes an HTTP request to a specified URL - SSRF VULNERABILITY"""
    try:
        # SSRF/Command Injection vulnerability - no validation of URL
        response = requests.get(url, timeout=5)
        return {
            "url": url,
            "status_code": response.status_code,
            "content_type": response.headers.get('Content-Type'),
            "body_preview": response.text[:500]  # First 500 chars only
        }
    except Exception as e:
        return {"url": url, "error": str(e)}

@app.get("/api/printenv")
async def print_env(x_api_key: Optional[str] = Header(None)):
    """Returns environment variables - INFORMATION DISCLOSURE VULNERABILITY"""
    # Insecure API key check
    if API_KEY and x_api_key != API_KEY:
        raise HTTPException(status_code=401, detail="Invalid API Key")
        
    # Information disclosure vulnerability - exposing all environment variables
    return dict(os.environ)

@app.get("/api/pi")
async def calculate_pi(digits: int = 1000):
    """Calculates PI to test CPU load"""
    try:
        if digits > 100000:
            raise HTTPException(status_code=400, detail="Maximum allowed digits is 100,000")
            
        # Set precision and calculate PI
        mpmath.mp.dps = digits + 2
        pi_value = str(mpmath.mp.pi)[:digits+2]  # +2 for "3."
        
        return {
            "digits": digits,
            "pi": pi_value,
            "computation_time": f"{time.time()}"
        }
    except HTTPException:
        raise
    except Exception as e:
        return {"error": str(e)}

# ============================================================================
# TRANSACTION LISTING ENDPOINTS (for web dashboard)
# ============================================================================

@app.get("/api/transactions/recent")
async def get_recent_transactions(limit: int = 20):
    """Get recent transactions across all customers"""
    try:
        conn = get_db_connection()
        cursor = get_db_cursor(conn)
        
        cursor.execute("""
            SELECT 
                t.transaction_id::text as id,
                t.customer_id,
                t.merchant_id,
                t.amount,
                t.currency,
                t.status,
                t.transaction_date as created_at,
                t.description,
                c.first_name || ' ' || c.last_name as customer_name,
                m.merchant_name
            FROM transactions t
            LEFT JOIN customers c ON t.customer_id = c.customer_id
            LEFT JOIN merchants m ON t.merchant_id = m.merchant_id
            ORDER BY t.transaction_date DESC
            LIMIT %s
        """, (limit,))
        
        transactions = cursor.fetchall()
        cursor.close()
        conn.close()
        
        return {
            "count": len(transactions),
            "transactions": [dict(tx) for tx in transactions]
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to retrieve transactions: {str(e)}")

@app.get("/api/db-status")
async def get_db_status_dashboard():
    """Get database status for dashboard (compatible with web frontend)"""
    try:
        conn = get_db_connection()
        cursor = get_db_cursor(conn)
        
        # Get version
        cursor.execute("SELECT version()")
        version_result = cursor.fetchone()
        
        # Get transaction count
        cursor.execute("SELECT COUNT(*) as count FROM transactions")
        tx_count = cursor.fetchone()
        
        cursor.close()
        conn.close()
        
        return {
            "status": "connected",
            "version": version_result['version'].split(',')[0] if version_result else "PostgreSQL 16",
            "transaction_count": tx_count['count'] if tx_count else 0
        }
        
    except Exception as e:
        return {
            "status": "error",
            "error": str(e),
            "version": "Unknown",
            "transaction_count": 0
        }

# ============================================================================
# LOAD TESTING & HA TESTING ENDPOINTS
# ============================================================================

@app.post("/api/test/create-transaction")
async def create_test_transaction(customer_id: int = 1, merchant_id: int = 1, amount: float = 99.99):
    """Create a test transaction for load testing"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Use the stored function for creating test transactions
        cursor.execute(
            "SELECT create_test_transaction(%s, %s, %s)",
            (customer_id, merchant_id, amount)
        )
        
        transaction_id = cursor.fetchone()[0]
        conn.commit()
        cursor.close()
        conn.close()
        
        return {
            "transaction_id": str(transaction_id),
            "status": "completed",
            "amount": amount,
            "timestamp": datetime.utcnow().isoformat()
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to create test transaction: {str(e)}")

@app.get("/api/test/db-status")
async def get_db_status():
    """Get detailed database status for HA monitoring"""
    try:
        conn = get_db_connection()
        cursor = get_db_cursor(conn)
        
        # Get connection info
        cursor.execute("SELECT inet_server_addr(), inet_server_port(), current_database(), current_user, version()")
        server_info = cursor.fetchone()
        
        # Get transaction count
        cursor.execute("SELECT COUNT(*) as total_transactions FROM transactions")
        tx_count = cursor.fetchone()
        
        # Get recent transactions
        cursor.execute("SELECT COUNT(*) as recent FROM transactions WHERE transaction_date > NOW() - INTERVAL '1 minute'")
        recent_tx = cursor.fetchone()
        
        cursor.close()
        conn.close()
        
        return {
            "database_status": "connected",
            "server_address": str(server_info['inet_server_addr']) if server_info['inet_server_addr'] else "N/A",
            "server_port": server_info['inet_server_port'],
            "database_name": server_info['current_database'],
            "connected_user": server_info['current_user'],
            "postgresql_version": server_info['version'],
            "total_transactions": tx_count['total_transactions'],
            "transactions_last_minute": recent_tx['recent'],
            "timestamp": datetime.utcnow().isoformat()
        }
        
    except Exception as e:
        return {
            "database_status": "error",
            "error": str(e),
            "timestamp": datetime.utcnow().isoformat()
        }

# ============================================================================
# MAIN
# ============================================================================

if __name__ == "__main__":
    uvicorn.run("app:app", host="0.0.0.0", port=8000, reload=True)
