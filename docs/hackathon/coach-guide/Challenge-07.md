---
version: 1.0.0
last_updated: 2025-07-17
guide_type: coach
challenge: 07
title: Facilitating Private Endpoint and DNS Implementation
---

# Challenge 07 Coach Guide: Facilitating Private Endpoint and DNS Implementation

## Purpose
Support students in executing their remediation plan by removing public endpoints and implementing Private Endpoints and Private DNS Zones for SAIF. Guide them through validation and documentation of their work.

## Facilitation Steps

1. **Kickoff Discussion**
   - Review each team's remediation plan from Challenge 06.
   - Emphasize the importance of thorough implementation and validation.

2. **Guide Implementation**
   - Encourage students to follow their plan closely and document any deviations or challenges.
   - Ask probing questions: “How are you ensuring all endpoints are private?”, “Are Private Endpoints and DNS Zones configured for every service?”
   - Remind students to update NSGs and other controls to block public access.

3. **Support Validation and Documentation**
   - Prompt students to test connectivity and provide evidence that public access is blocked.
   - Encourage use of screenshots, logs, and configuration files for validation.
   - Remind students to summarize their implementation and reference Azure best practices.

4. **Review and Feedback**
   - Use the scoring rubric to assess endpoint removal, private endpoint and DNS configuration, validation evidence, and documentation quality.
   - Provide feedback on missing components, incomplete validation, or poor documentation.

## Common Pitfalls

- Public endpoints not fully removed or still accessible.
- Private Endpoints or DNS Zones missing or misconfigured.
- Incomplete validation or lack of evidence.
- Poor documentation or missing references.

## Example Prompts

- “Show how you validated that public access is blocked for all services.”
- “How did you configure Private Endpoints and DNS Zones for each service?”
- “What challenges did you encounter during implementation?”

## Scoring Rubric (for reference)

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

**Coach Tip:**
Focus feedback on thorough implementation, validation, and documentation. Encourage students to reference Azure best practices and provide clear evidence of private connectivity.
