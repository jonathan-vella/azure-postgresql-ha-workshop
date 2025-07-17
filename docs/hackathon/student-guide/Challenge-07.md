---
version: 1.0.0
last_updated: 2025-07-17
guide_type: student
challenge: 07
title: Implementing Private Endpoints and Private DNS Zone
---

# Challenge 07: Implementing Private Endpoints and Private DNS Zone

## Objective
Execute your remediation plan from Challenge 06 by removing public endpoints and implementing Private DNS Zones for SAIF in Azure.

## Scenario

You have developed a plan to eliminate public access to your web, API, and SQL endpoints and transition to private connectivity. Now, you must implement your plan, configure Azure Private Endpoints and Private DNS Zones, and validate that all services are accessible only via private connections.

## Instructions

1. **Implement Private Connectivity**
   - Remove public access for all identified endpoints (Web, API, SQL) as per your plan.
   - Create and configure Azure Private Endpoints for each service.
   - Set up Private DNS Zones to resolve internal service names.
   - Update NSGs and other security controls to restrict public access.

2. **Validate Implementation**
   - Test connectivity to all services from within the private network.
   - Confirm that public access is blocked and only private connections are allowed.
   - Document your validation steps and results (screenshots, logs, configuration files).

3. **Document Your Work**
   - Submit a summary of your implementation, including configuration details, validation evidence, and any challenges encountered.
   - Reference Azure documentation and best practices.

## Success Criteria

- All public endpoints removed and replaced with private connectivity.
- Private Endpoints and Private DNS Zones configured for all services.
- Validation evidence provided (screenshots, logs, configs).
- Documentation includes summary, configuration details, and references.

## Scoring Rubric

| Criteria                        | Excellent (5) | Good (3) | Needs Improvement (1) |
|---------------------------------|---------------|----------|-----------------------|
| Public Endpoint Removal         | All endpoints private, public access blocked | Most endpoints private | Few/no endpoints private |
| Private Endpoint Implementation | Fully configured for all services | Partial implementation | Missing or misconfigured |
| Private DNS Zone Configuration  | Fully configured, resolves all services | Partial configuration | Missing or misconfigured |
| Validation Evidence             | Clear, complete, includes tests | Partial evidence | No evidence |
| Documentation                   | Summary, configs, references included | Partial documentation | No documentation |

## References

- [Azure Private Endpoint Documentation](https://learn.microsoft.com/en-us/azure/private-link/private-endpoint-overview)
- [Azure Private DNS Zone Documentation](https://learn.microsoft.com/en-us/azure/dns/private-dns-overview)

---

**Tip:**
Focus on thorough implementation and validation to ensure all services are private and secure.
