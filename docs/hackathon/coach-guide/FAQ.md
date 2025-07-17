---
version: 1.0.0
last_updated: 2025-07-17
guide_type: coach
---

# SAIF Hackathon Coach FAQ

This FAQ provides detailed troubleshooting guidance and answers to common questions for coaches supporting hackathon students in the SAIF challenges. For additional support, collaborate with other coaches or refer to the student guides.

## Azure Access & Permissions
**Q: Students can't access Azure resources or deploy services. What should I check?**
- Confirm students have the correct Azure role (Resource Group Owner or Subscription Owner).
- Ensure they are working in the correct subscription and region.
- Check for Conditional Access policies, MFA requirements, or tenant restrictions.
- Advise students to register required resource providers (e.g., Microsoft.Web, Microsoft.Sql) if using a corporate account.

## Deployment & Resource Issues
**Q: Student deployments fail or resources are missing.**
- Review error messages in Azure Portal and deployment logs with students.
- Help validate configuration files (ARM/Bicep templates, parameters, scripts).
- Check for quota limits, naming conflicts, or missing dependencies.
- Guide students to use Azure CLI or PowerShell for diagnostics.
- Ensure students have updated tools (Azure CLI, PowerShell modules, Docker).

## Networking & Connectivity
**Q: Teams are struggling with VNet peering, firewall, or NSG rules.**
- Confirm VNet peering is established and configured for bidirectional traffic.
- Review NSG rules for correct priorities and allow/deny settings.
- Check Azure Firewall logs for blocked traffic and rule matches.
- Use Network Watcher and Connection Troubleshoot with students to test connectivity.
- Validate subnet address ranges and ensure no overlap.

## WAF & Security Controls
**Q: WAF is not blocking attacks as expected for students.**
- Ensure WAF policies are correctly associated with endpoints.
- Encourage testing with known attack payloads and reviewing WAF logs.
- Check WAF mode (Detection vs. Prevention) and rule set version.
- Help validate custom rules and their order.
- For the JavaScript challenge, confirm it is enabled and tested with automated tools/bots.

## Private Endpoints & DNS
**Q: Private endpoints or DNS are not resolving for students.**
- Verify Private Endpoint configuration and VNet integration.
- Ensure Private DNS Zone is linked to the VNet and contains required records.
- Check NSGs and firewalls for rules that may block internal traffic.
- Use `nslookup` or `dig` from a VM in the VNet to test DNS resolution.
- Validate that public access is disabled and only private connectivity is allowed.

## Evidence & Documentation
**Q: What evidence should students submit for each challenge?**
- Screenshots of Azure Portal showing deployed resources, configurations, and logs.
- Exported configuration files (ARM/Bicep templates, NSG rules, WAF policies).
- Logs demonstrating attack blocking, connectivity tests, or DNS resolution.
- Written summaries explaining their approach, challenges, and outcomes.

## Supporting Students
**Q: How can I best support students who are stuck or need help?**
- Use facilitation steps and prompts in each coach guide.
- Encourage collaboration, peer review, and use of support channels.
- Escalate persistent issues to hackathon organizers if needed.
- Reference Microsoft Learn, Azure documentation, and community forums for additional guidance.

---

For further troubleshooting, consult the Azure documentation or collaborate with other coaches and hackathon organizers.
