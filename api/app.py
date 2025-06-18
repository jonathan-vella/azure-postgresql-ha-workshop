import os
import socket
import dns.resolver
import requests
import pyodbc
import mpmath
import uvicorn
from fastapi import FastAPI, HTTPException, Header, Request
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv
from typing import Optional, Dict, Any
import time

# Load environment variables from .env file if present
load_dotenv()

app = FastAPI(title="SAIF API", description="Secure AI Foundations API for diagnostic testing")

# CORS middleware configuration - deliberately insecure for challenge purposes
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allow all origins
    allow_credentials=True,
    allow_methods=["*"],  # Allow all methods
    allow_headers=["*"],  # Allow all headers
)

# Optional insecure API key authentication
API_KEY = os.getenv("API_KEY")

# Database connection info
SQL_SERVER = os.getenv("SQL_SERVER")
SQL_DATABASE = os.getenv("SQL_DATABASE")
SQL_USERNAME = os.getenv("SQL_USERNAME")
SQL_PASSWORD = os.getenv("SQL_PASSWORD")

def get_db_connection():
    """Create a database connection using environment variables"""
    if not all([SQL_SERVER, SQL_DATABASE, SQL_USERNAME, SQL_PASSWORD]):
        raise HTTPException(status_code=500, detail="Database connection information not configured")
    
    conn_str = f"DRIVER={{ODBC Driver 17 for SQL Server}};SERVER={SQL_SERVER};DATABASE={SQL_DATABASE};UID={SQL_USERNAME};PWD={SQL_PASSWORD};TrustServerCertificate=yes"
    try:
        return pyodbc.connect(conn_str)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Database connection failed: {str(e)}")

@app.get("/")
async def root():
    """Root endpoint with API information"""
    return {
        "name": "SAIF API",
        "version": "1.0.0",
        "description": "Diagnostic API for security testing and training"
    }

@app.get("/api/healthcheck")
async def healthcheck():
    """Simple health check endpoint"""
    return {"status": "healthy", "timestamp": time.time()}

@app.get("/api/ip")
async def get_ip_info():
    """Returns IP address information"""
    hostname = socket.gethostname()
    local_ip = socket.gethostbyname(hostname)
    
    # Attempt to get public IP
    try:
        public_ip = requests.get('https://api.ipify.org').text
    except Exception:
        public_ip = "Unable to determine"
        
    return {
        "hostname": hostname,
        "local_ip": local_ip,
        "public_ip": public_ip
    }

@app.get("/api/sqlversion")
async def get_sql_version(x_api_key: Optional[str] = Header(None)):
    """Returns the SQL Server version"""
    # Insecure API key check
    if API_KEY and x_api_key != API_KEY:
        raise HTTPException(status_code=401, detail="Invalid API Key")
        
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT @@VERSION")
        version = cursor.fetchone()[0]
        cursor.close()
        conn.close()
        return {"sql_version": version}
    except Exception as e:
        return {"error": str(e)}

@app.get("/api/sqlsrcip")
async def get_sql_source_ip(x_api_key: Optional[str] = Header(None)):
    """Returns the source IP as seen by SQL Server"""
    # Insecure API key check
    if API_KEY and x_api_key != API_KEY:
        raise HTTPException(status_code=401, detail="Invalid API Key")
        
    try:
        conn = get_db_connection()
        cursor = conn.cursor()        # SQL Injection vulnerability - using string concatenation for SQL query
        query = "SELECT CAST(CONNECTIONPROPERTY('client_net_address') AS VARCHAR(50)) as client_ip"
        cursor.execute(query)
        client_ip = cursor.fetchone()[0]
        cursor.close()
        conn.close()
        return {"source_ip": client_ip}
    except Exception as e:
        return {"error": str(e)}

@app.get("/api/dns/{hostname}")
async def resolve_dns(hostname: str):
    """Resolves a DNS name to IP addresses"""
    try:
        a_records = dns.resolver.resolve(hostname, 'A')
        aaaa_records = dns.resolver.resolve(hostname, 'AAAA')
        
        result = {
            "hostname": hostname,
            "a_records": [record.address for record in a_records],
            "aaaa_records": [record.address for record in aaaa_records]
        }
    except Exception as e:
        result = {
            "hostname": hostname,
            "error": str(e)
        }
    
    return result

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
    """Makes an HTTP request to a specified URL - deliberately insecure"""
    try:
        # Command Injection vulnerability - no validation of URL
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
    """Returns environment variables - deliberately insecure"""
    # Insecure API key check
    if API_KEY and x_api_key != API_KEY:
        raise HTTPException(status_code=401, detail="Invalid API Key")
        
    # Information disclosure vulnerability
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
    except Exception as e:
        if isinstance(e, HTTPException):
            raise e
        return {"error": str(e)}

if __name__ == "__main__":
    uvicorn.run("app:app", host="0.0.0.0", port=8000, reload=True)
