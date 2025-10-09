# Security Notice

## ⚠️ Important: Educational Security Vulnerabilities

This repository contains **intentional security vulnerabilities** designed for training and educational purposes as part of a database security workshop.

### Intentional Vulnerabilities Include:

- SQL injection vulnerabilities in database queries
- Insecure authentication patterns (SQL authentication vs. Managed Identity)
- Exposed environment variables through diagnostic endpoints
- Overly permissive CORS settings
- Command injection possibilities in URL fetching endpoints
- Missing input validation and sanitization
- Excessive error information disclosure

### 🚫 DO NOT:

- ❌ Deploy this in production environments
- ❌ Use these patterns in real applications
- ❌ Expose these applications to the public internet without proper security controls
- ❌ Store real customer data in these systems

### ✅ DO:

- ✅ Use in isolated training environments only
- ✅ Learn from the vulnerabilities to improve security knowledge
- ✅ Practice secure coding techniques by fixing the issues
- ✅ Deploy in Azure subscriptions with proper access controls
- ✅ Delete resources after workshop completion

## 🎓 Educational Purpose

This workshop is designed to teach:

1. **Azure PostgreSQL Flexible Server** deployment and configuration
2. **Zone-Redundant High Availability** architecture
3. **Failover testing** and RTO/RPO measurement
4. **Security vulnerability identification** and remediation
5. **Managed Identity authentication** implementation
6. **Database security best practices**

## 🔒 Reporting Real Security Issues

If you discover an **unintentional** security vulnerability (i.e., a security issue not documented as part of the training materials), please report it responsibly:

**Email:** jonathan.vella@microsoft.com

Please include:
- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested remediation (if any)

We will respond within 48 hours and credit researchers who report valid issues.

## 📚 Security Resources

For secure implementation guidance, please refer to:

- [Azure Security Best Practices](https://docs.microsoft.com/azure/security/fundamentals/best-practices-and-patterns)
- [PostgreSQL Security Documentation](https://www.postgresql.org/docs/current/security.html)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [Azure Database Security Checklist](https://docs.microsoft.com/azure/postgresql/flexible-server/concepts-security)

## ⚖️ Disclaimer

This software is provided "as is" for educational purposes. The maintainers are not responsible for any misuse of the intentionally vulnerable code or any damages resulting from its use outside of educational contexts.

**Last Updated:** 2025-10-09
