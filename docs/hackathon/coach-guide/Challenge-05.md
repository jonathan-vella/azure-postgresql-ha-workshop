# Challenge 05 Coach Guide: Facilitating WAF Implementation and Validation

## Purpose
Support students in deploying and configuring a Web Application Firewall (WAF) for SAIF, and guide them in demonstrating its effectiveness against attacks. Encourage bonus implementation of the JavaScript challenge feature.

## Facilitation Steps

1. **Kickoff Discussion**
   - Review the importance of WAFs in protecting web applications and APIs.
   - Emphasize the need for evidence-based validation of attack blocking.

2. **Guide Deployment and Configuration**
   - Encourage students to select the most suitable Azure WAF deployment model for their environment.
   - Ask probing questions: “How are you configuring WAF rules to protect your endpoints?”, “What types of attacks are you testing?”
   - Remind students to document their configuration and rules.

3. **Validate Attack Blocking**
   - Prompt students to simulate a variety of attacks and capture evidence of WAF blocking.
   - Encourage thorough documentation (logs, screenshots, explanations).

4. **Bonus: JavaScript Challenge**
   - Suggest students explore and implement the WAF JavaScript challenge feature.
   - Ask: “How does the JavaScript challenge improve protection against bots and automated attacks?”

5. **Review and Feedback**
   - Use the scoring rubric to assess deployment, attack blocking, bonus implementation, and documentation quality.
   - Provide feedback on missing evidence, misconfigured WAF, or unclear documentation.

## Common Pitfalls

- WAF deployed but not properly configured for all endpoints.
- Insufficient or unclear evidence of attack blocking.
- Bonus feature mentioned but not implemented or demonstrated.
- Poor documentation of configuration and results.

## Example Prompts

- “Show how your WAF blocks a SQL injection or XSS attack.”
- “What evidence do you have that the WAF is working as intended?”
- “How did you implement and test the JavaScript challenge feature?”

## Scoring Rubric (for reference)

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

**Coach Tip:**
Focus feedback on evidence of attack blocking and the effectiveness of WAF configuration. Encourage students to go beyond basic deployment and demonstrate advanced features like the JavaScript challenge.
