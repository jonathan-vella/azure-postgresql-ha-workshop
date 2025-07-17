---
version: 1.0.0
last_updated: 2025-07-17
guide_type: student
challenge: 08
title: Defender for Containers – Securing Containerized Workloads
---

# Challenge 08: Defender for Containers – Securing Containerized Workloads

## Objective
Enhance the security posture of your containerized assets by enabling Microsoft Defender for Containers, performing vulnerability assessments, and validating runtime threat protection for Kubernetes clusters and container registries.

## Scenario
Your SAIF environment now includes containerized workloads running in Azure Kubernetes Service (AKS) or other supported platforms. To protect these assets, you must:
- Enable Microsoft Defender for Containers
- Assess vulnerabilities in container images and running containers
- Validate runtime threat protection and review security alerts

## Timeline & Milestones
| Suggested Duration | Recommended Milestones |
|--------------------|-----------------------|
| 1 hour             | Defender enabled, registry images assessed, vulnerabilities remediated |


## Instructions

1. **Enable Defender for Containers**
   - Follow the official guide: [Enable Defender for Containers](https://learn.microsoft.com/en-us/azure/defender-for-cloud/defender-for-containers-enable)
   - Ensure your Azure Container Registry (ACR) is onboarded and vulnerability scanning is enabled.

3. **Remediate Vulnerabilities**

## Rubric
| Criteria                        | Description                                                      | Points |
|----------------------------------|------------------------------------------------------------------|--------|
| Defender Enabled                 | Evidence of Defender for Containers enabled on ACR               |   20   |
| Vulnerability Assessment         | Registry images scanned, findings reviewed and documented        |   25   |
| Remediation Approach             | Clear, risk-based remediation plan for vulnerabilities           |   25   |
| Documentation & Evidence         | Screenshots, summaries, and lessons learned provided             |   20   |
| Reflection & Improvement         | Thoughtful reflection on process and future improvements         |   10   |
| **Total**                       |                                                                  | **100**|

**Notes:**
- Bonus points may be awarded for creative remediation strategies or advanced automation.
- Deductions for missing evidence, unclear documentation, or incomplete remediation steps.

---

For troubleshooting, see the [Student FAQ](./FAQ.md). For support, contact your hackathon coach.
   - Prioritize vulnerabilities based on risk level and contextual analysis.
   - Document your recommended approach to update container images to resolve vulnerabilities (e.g., patch base images, update dependencies).
   - Reference: [View and remediate vulnerabilities for registry images](https://learn.microsoft.com/en-us/azure/defender-for-cloud/view-and-remediate-vulnerability-registry-images)

4. **Summarize Your Findings**
   - Provide evidence of Defender for Containers being enabled and registry images scanned.
   - List vulnerabilities found, and recommended remediation actions.
   - Reflect on lessons learned and improvements for future container security.


## References
- [Defender for Containers Introduction](https://learn.microsoft.com/en-us/azure/defender-for-cloud/defender-for-containers-introduction)
- [Enable Defender for Containers](https://learn.microsoft.com/en-us/azure/defender-for-cloud/defender-for-containers-enable)
- [View and remediate vulnerabilities for registry images](https://learn.microsoft.com/en-us/azure/defender-for-cloud/view-and-remediate-vulnerability-registry-images)
- [Group recommendations by title](https://learn.microsoft.com/en-us/azure/defender-for-cloud/review-security-recommendations#group-recommendations-by-title)
- [Remediate recommendations](https://learn.microsoft.com/en-us/azure/defender-for-cloud/implement-security-recommendations)


---

For troubleshooting, see the [Student FAQ](./FAQ.md). For support, contact your hackathon coach.
