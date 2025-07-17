
---
version: 1.0.0
last_updated: 2025-07-17
guide_type: coach
challenge: 03
title: Facilitating Zero Trust Network Design
---

# Challenge 03 Coach Guide: Facilitating Zero Trust Network Design

## Purpose
Guide students in designing a zero trust network architecture for SAIF that will serve as the blueprint for implementation in Challenge 04. Ensure their design is actionable, justified, and aligned with business priorities and Microsoft best practices.

## Facilitation Steps

1. **Kickoff Discussion**
   - Review the business case and scenario with students.
   - Emphasize that their design will be implemented in the next challenge, so clarity and justification are critical.

2. **Prompt Research and Ideation**
   - Encourage students to explore the provided references and Microsoft documentation.
   - Ask probing questions: “How does segmentation improve security?”, “Why is identity-aware access critical?”, “What are the trade-offs in your design?”

3. **Guide Diagramming and Documentation**
   - Remind students to use a physical or virtual whiteboard (no specific tooling required).
   - Ensure diagrams show segmentation, perimeter controls, identity-aware access, monitoring, and compliance.
   - Check that each network control/component is accompanied by a written justification, and that the design is detailed enough for implementation.

4. **Review and Feedback**
   - Use the scoring rubric to assess clarity, completeness, and alignment to zero trust.
   - Provide feedback on missing layers, vague justifications, or unclear diagrams.
   - Encourage students to reference best practices and documentation, and to think ahead to implementation.

## Common Pitfalls

- Diagrams missing key layers (e.g., DMZ, identity provider, monitoring).
- Justifications that simply restate the control (“Firewall blocks traffic”) instead of explaining its business/security value.
- Lack of references to Microsoft documentation or best practices.
- Overly complex diagrams that obscure the main architecture.
- Designs that are too vague or lack actionable detail for implementation.

## Example Prompts

- “Explain why you chose this segmentation approach.”
- “How does your design support compliance requirements?”
- “What monitoring controls are in place, and why?”
- “How does identity-aware access improve user experience and security?”
- “Is your design detailed enough for someone else to implement in Azure?”

## Scoring Rubric (for reference)

| Criteria                        | Excellent (5) | Good (3) | Needs Improvement (1) |
|---------------------------------|---------------|----------|-----------------------|
| Alignment to Zero Trust         | Design fully aligns with zero trust principles | Mostly aligned, some gaps | Little/no alignment |
| Coverage of Network Layers      | All layers and controls addressed | Most layers covered, some details missing | Major layers missing or vague |
| Written Justification           | Each control clearly justified | Most controls justified | Few/no justifications |
| Focus on Compliance & UX        | Priorities clearly highlighted and explained | Mentioned but not explained | Not addressed |
| Use of References               | Multiple relevant references included | Some references | No references |
| Diagram Format & Clarity        | Diagram is clear, organized, easy to read | Present but could be improved | Missing or unclear |

## References
- [IFS Customer Story](https://jonathan-vella.github.io/xlr8-e2eaisolutions/customer-story/)
- [Azure Zero Trust Infrastructure Overview](https://learn.microsoft.com/en-us/security/zero-trust/azure-infrastructure-overview)
- [Microsoft Cloud Adoption Framework](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/)

---

**Coach Tip:**
Remind students that their design will be implemented in Challenge 04. Focus feedback on the “why” behind each control and whether the design is actionable and supports business priorities, compliance, and user experience.
