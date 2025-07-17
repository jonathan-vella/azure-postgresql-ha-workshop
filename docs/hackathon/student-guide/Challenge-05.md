
---
version: 1.0.0
last_updated: 2025-07-17
guide_type: student
challenge: 05
title: Implementing a Web Application Firewall (WAF)
---

# Challenge 05: Implementing a Web Application Firewall (WAF)

## Objective
Deploy and configure a Web Application Firewall (WAF) for SAIF, and demonstrate its effectiveness in blocking attacks. Bonus: Implement the JavaScript challenge feature for advanced protection.

## Scenario

Your SAIF environment is exposed to the internet and at risk of web-based attacks. You must implement a WAF to protect your web application and API endpoints, and show that it is actively blocking malicious traffic.

## Instructions

1. **Deploy and Configure WAF**
   - Choose an appropriate Azure WAF deployment model (e.g., Application Gateway WAF, Azure Front Door WAF).
   - Configure WAF policies to protect your web and API endpoints.
   - Document your WAF configuration and rules.

2. **Demonstrate Attack Blocking**
   - Simulate common web attacks (e.g., SQL injection, XSS, path traversal) against your endpoints.
   - Capture evidence (logs, screenshots) showing that the WAF is blocking these attacks.

3. **Bonus: Implement JavaScript Challenge**
   - Enable and configure the [WAF JavaScript challenge](https://learn.microsoft.com/en-us/azure/web-application-firewall/waf-javascript-challenge) feature for your endpoints.
   - Demonstrate how the JavaScript challenge blocks automated bots or suspicious traffic.

4. **Document Your Work**
   - Submit screenshots, logs, and a brief summary explaining your WAF configuration and how it blocks attacks.
   - If you completed the bonus, include evidence and a short explanation of the JavaScript challenge feature.

## Success Criteria

- WAF deployed and configured for web and API endpoints.
- Evidence provided that WAF is blocking attacks.
- Bonus: JavaScript challenge implemented and demonstrated.
- Documentation includes configuration details, attack evidence, and explanations.

## Scoring Rubric

| Criteria                        | Excellent (5) | Good (3) | Needs Improvement (1) |
|---------------------------------|---------------|----------|-----------------------|
| WAF Deployment & Configuration  | Fully deployed and documented | Partially deployed/configured | Not deployed or misconfigured |
| Attack Blocking Evidence        | Multiple attacks blocked, clear evidence | Some attacks blocked, partial evidence | No evidence or attacks not blocked |
| Bonus: JavaScript Challenge     | Implemented and demonstrated | Mentioned but not implemented | Not addressed |
| Documentation                   | Clear, complete, includes evidence | Partial documentation | No documentation |

## References

- [Azure WAF Documentation](https://learn.microsoft.com/en-us/azure/web-application-firewall/)
- [WAF JavaScript Challenge](https://learn.microsoft.com/en-us/azure/web-application-firewall/waf-javascript-challenge)

---

**Tip:**
Focus on demonstrating real attack blocking and explaining how your WAF configuration protects SAIF.
