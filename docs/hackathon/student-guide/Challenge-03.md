
---
version: 1.0.0
last_updated: 2025-07-17
guide_type: student
challenge: 03
title: Zero Trust by Design – Network Blueprint
---

# Challenge 03: Zero Trust by Design – Network Blueprint

## Objective
Design a zero trust network architecture for the SAIF solution, setting the foundation for implementation in Challenge 04.

## Scenario
You are responsible for architecting the network for SAIF. Your goal is to design a secure, scalable, and compliant network that supports the business case and enables defense-in-depth. Your design will be used as the blueprint for actual deployment in the next challenge.

## Instructions

1. **Review the Business Case**
   - Reference [IFS Customer Story](https://jonathan-vella.github.io/xlr8-e2eaisolutions/customer-story/).

2. **Research Zero Trust Principles**
   - Study [Azure Zero Trust Infrastructure Overview](https://learn.microsoft.com/en-us/security/zero-trust/azure-infrastructure-overview).
   - Identify key components and controls for a zero trust network.

3. **Design Your Network Architecture**
   - Create a high-level diagram (physical or virtual whiteboard; no specific tooling required) showing your proposed hub-and-spoke topology for SAIF in Azure.
   - Define segmentation, perimeter controls, identity-aware access, monitoring, and compliance features.
   - Specify the subnets, network/security services, and their placement (hub vs. spoke), justifying each choice.
   - For each network control or component, include a short written justification explaining its purpose and how it supports zero trust, compliance, or user experience.

4. **Document Your Design**
   - Submit a photo or screenshot of your diagram, plus a table or list of justifications for each control.
   - Reference best practices and documentation.

## Success Criteria

- A clear, well-structured network architecture diagram aligned to zero trust principles.
- Design addresses segmentation, perimeter controls, identity-aware access, and monitoring.
- Each network control is justified in writing.
- Compliance and user experience are considered.
- References to best practices or documentation included.

## Scoring Rubric

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

**Tip:**
Your design will be implemented in Challenge 04. Focus on “why” each network control is needed and how it supports business priorities.
