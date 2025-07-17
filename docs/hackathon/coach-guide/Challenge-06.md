---
version: 1.0.0
last_updated: 2025-07-17
guide_type: coach
challenge: 06
title: Facilitating Private Endpoint and DNS Planning
---

# Challenge 06 Coach Guide: Facilitating Private Endpoint and DNS Planning

## Purpose
Support students in developing a remediation plan to remove public endpoints and design an actionable Private DNS Zone implementation strategy for SAIF.

## Facilitation Steps

1. **Kickoff Discussion**
   - Review the risks and business impacts of public endpoints.
   - Emphasize the importance of planning for secure, private connectivity.

2. **Guide Assessment and Planning**
   - Encourage students to identify all public endpoints and document associated risks.
   - Ask probing questions: “What Azure features will you use to remove public access?”, “How will you handle migration and downtime?”
   - Remind students to address integration points and dependencies in their plan.

3. **Support Private DNS Zone Design**
   - Prompt students to map out how private DNS will resolve internal service names and support secure connectivity.
   - Encourage use of diagrams, tables, or checklists for clarity.

4. **Review and Feedback**
   - Use the scoring rubric to assess endpoint identification, remediation planning, DNS strategy, and documentation quality.
   - Provide feedback on missing endpoints, vague plans, or unclear DNS strategies.

## Common Pitfalls

- Missing or incomplete identification of public endpoints.
- Remediation plan lacks actionable steps or omits key Azure features.
- Private DNS Zone strategy is vague or missing integration details.
- Poor documentation or lack of references.

## Example Prompts

- “How will you ensure all endpoints are private and secure?”
- “What Azure services will you use to implement private connectivity?”
- “How will your DNS strategy support internal service resolution?”

## Scoring Rubric (for reference)

| Criteria                        | Excellent (5) | Good (3) | Needs Improvement (1) |
|---------------------------------|---------------|----------|-----------------------|
| Endpoint Identification         | All endpoints identified, risks documented | Most endpoints identified | Few/no endpoints identified |
| Remediation Plan                | Clear, actionable, covers all endpoints | Partial plan, some gaps | Vague or missing plan |
| Private DNS Zone Strategy       | Detailed, covers integration and dependencies | Partial strategy | Missing or unclear strategy |
| Documentation                   | Diagrams/tables, clear references | Partial documentation | No documentation |

## References
- [Azure Private Endpoint Documentation](https://learn.microsoft.com/en-us/azure/private-link/private-endpoint-overview)
- [Azure Private DNS Zone Documentation](https://learn.microsoft.com/en-us/azure/dns/private-dns-overview)

---

**Coach Tip:**
Focus feedback on the completeness and actionability of the remediation plan and DNS strategy. Encourage students to use diagrams and reference Azure best practices.
