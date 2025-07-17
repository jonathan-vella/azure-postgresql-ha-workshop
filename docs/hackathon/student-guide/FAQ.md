---
version: 1.0.0
last_updated: 2025-07-17
guide_type: student
---

# SAIF Hackathon Student FAQ

This FAQ provides detailed troubleshooting guidance and answers to common questions for hackathon students working through the SAIF challenges. For additional support, contact your coach or refer to the coach guides.

## Azure Access & Permissions
**Q: I can't access Azure resources or deploy services. What should I check?**
- Ensure your Azure account is assigned the correct role (Resource Group Owner or Subscription Owner).
- Verify you are working in the correct subscription and region.
- Check if your account is subject to Conditional Access policies or MFA requirements.
- If using a corporate account, confirm that required resource providers are registered (e.g., Microsoft.Web, Microsoft.Sql).

## Deployment & Resource Issues
**Q: My deployment fails or resources are missing.**
- Review the error messages in Azure Portal and deployment logs.
- Validate your configuration files (ARM/Bicep templates, parameters, scripts).
- Check for quota limits, naming conflicts, or missing dependencies.
- Use Azure CLI or PowerShell to run diagnostic commands (e.g., `az resource list`, `az deployment group show`).
- Ensure you have the latest versions of required tools (Azure CLI, PowerShell modules, Docker).

## Networking & Connectivity
**Q: My VNet peering, firewall, or NSG rules are not working.**
- Confirm that VNet peering is established and configured for bidirectional traffic.
- Review NSG rules for correct priorities and allow/deny settings.
- Check Azure Firewall logs for blocked traffic and rule matches.
- Use Network Watcher and Connection Troubleshoot to test connectivity between resources.
- Validate subnet address ranges and ensure no overlap.

## WAF & Security Controls
**Q: WAF is not blocking attacks as expected.**
- Ensure WAF policies are correctly associated with your endpoints (Application Gateway, Front Door).
- Test with known attack payloads (SQL injection, XSS, path traversal) and review WAF logs for detection.
- Check WAF mode (Detection vs. Prevention) and rule set version.
- If using custom rules, validate their logic and order.
- For the JavaScript challenge, confirm it is enabled and test with automated tools/bots.

## Private Endpoints & DNS
**Q: Private endpoints or DNS are not resolving.**
- Verify Private Endpoint configuration and that the resource is integrated with the correct VNet.
- Ensure Private DNS Zone is linked to the VNet and contains the required records.
- Check NSGs and firewalls for rules that may block internal traffic.
- Use `nslookup` or `dig` from a VM in the VNet to test DNS resolution.
- Validate that public access is disabled and only private connectivity is allowed.

## Evidence & Documentation
**Q: What evidence should I submit for each challenge?**
- Screenshots of Azure Portal showing deployed resources, configurations, and logs.
- Exported configuration files (ARM/Bicep templates, NSG rules, WAF policies).
- Logs demonstrating attack blocking, connectivity tests, or DNS resolution.
- Written summaries explaining your approach, challenges, and outcomes.

## Getting Help
**Q: Where can I get help or ask questions?**
- Contact your hackathon coach via the designated support channel (Teams, Slack, email).
- Reference the coach guides for facilitation tips and troubleshooting steps.
- Use Microsoft Learn, Azure documentation, and community forums for additional guidance.

---


---

## Glossary of Key Terms

**Zero Trust**: A security model that assumes no user or device is trusted by default, requiring strict identity verification and least-privilege access for every request.

**WAF (Web Application Firewall)**: A security solution that protects web applications by filtering and monitoring HTTP traffic, blocking malicious requests and common attack patterns.

**Private Endpoint**: An Azure network interface that connects you privately and securely to Azure services, using a private IP address from your VNet.

**Private DNS Zone**: An Azure DNS zone that enables name resolution for resources within a virtual network, supporting private connectivity and service discovery.

**NSG (Network Security Group)**: An Azure resource that contains security rules to allow or deny network traffic to resources in a virtual network.

**VNet Peering**: A networking feature that connects two Azure virtual networks, allowing resources in each VNet to communicate with each other.

**Conditional Access**: Azure AD policies that control access to resources based on user, device, location, and risk factors.

**ARM/Bicep Template**: Infrastructure-as-code files used to define and deploy Azure resources in a repeatable, declarative manner.

**Azure Firewall**: A managed, cloud-based network security service that protects Azure Virtual Network resources.

**Application Gateway**: An Azure load balancer with built-in WAF capabilities for web applications.

**Azure Front Door**: A global, scalable entry point for web applications, providing load balancing, WAF, and acceleration features.
