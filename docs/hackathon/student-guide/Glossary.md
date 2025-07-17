---
version: 1.0.0
last_updated: 2025-07-17
guide_type: student
---

# SAIF Hackathon Glossary

This glossary provides definitions and explanations for key terms and concepts used throughout the SAIF hackathon challenges. Use it as a quick reference to support your learning and troubleshooting.

## Glossary of Key Terms

**Zero Trust**: A security model that assumes no user or device is trusted by default, requiring strict identity verification and least-privilege access for every request. Focuses on continuous verification and segmentation.

**WAF (Web Application Firewall)**: A security solution that protects web applications by filtering and monitoring HTTP traffic, blocking malicious requests and common attack patterns such as SQL injection and XSS.

**Private Endpoint**: An Azure network interface that connects you privately and securely to Azure services, using a private IP address from your VNet. Eliminates public exposure of resources.

**Private DNS Zone**: An Azure DNS zone that enables name resolution for resources within a virtual network, supporting private connectivity and service discovery. Used with Private Endpoints for secure access.

**NSG (Network Security Group)**: An Azure resource that contains security rules to allow or deny network traffic to resources in a virtual network. Used to segment and protect resources at the subnet or NIC level.

**VNet Peering**: A networking feature that connects two Azure virtual networks, allowing resources in each VNet to communicate with each other securely and efficiently.

**Conditional Access**: Azure AD policies that control access to resources based on user, device, location, and risk factors. Used to enforce security requirements and reduce risk.

**ARM/Bicep Template**: Infrastructure-as-code files used to define and deploy Azure resources in a repeatable, declarative manner. ARM (Azure Resource Manager) and Bicep are common formats.

**Azure Firewall**: A managed, cloud-based network security service that protects Azure Virtual Network resources. Provides centralized policy enforcement and logging.

**Application Gateway**: An Azure load balancer with built-in WAF capabilities for web applications. Supports SSL termination, path-based routing, and web traffic inspection.

**Azure Front Door**: A global, scalable entry point for web applications, providing load balancing, WAF, and acceleration features. Used for high-availability and global reach.

**SQL Injection**: A type of attack that exploits vulnerabilities in database queries by injecting malicious SQL code. WAFs and input validation help prevent this.

**XSS (Cross-Site Scripting)**: A web security vulnerability that allows attackers to inject malicious scripts into web pages viewed by other users. Mitigated by WAFs and secure coding practices.

**Least Privilege**: A security principle that ensures users and services have only the minimum permissions necessary to perform their tasks, reducing risk of misuse or compromise.

**Defense-in-Depth**: A layered security approach that uses multiple controls and safeguards to protect resources, so that if one layer fails, others still provide protection.

**Service Principal**: An identity used by applications, services, or automation tools to access Azure resources securely.

**Resource Group**: A container in Azure that holds related resources for a solution, enabling management and access control.

**Azure CLI**: A command-line tool for managing Azure resources, deployments, and configurations.

**PowerShell**: A scripting language and shell for automating Azure resource management and troubleshooting.

**Network Watcher**: An Azure service for monitoring and diagnosing network issues, including connection troubleshooting and packet capture.

**MFA (Multi-Factor Authentication)**: A security mechanism that requires users to provide two or more verification factors to access resources, increasing account security.

**Subnet**: A range of IP addresses within a virtual network, used to segment resources and apply security controls.

**Resource Provider**: A service in Azure that supplies specific types of resources (e.g., Microsoft.Web for web apps, Microsoft.Sql for SQL databases). Must be registered in your subscription.

**Azure AD (Active Directory)**: Microsoft’s cloud-based identity and access management service, used for authentication and authorization.

---

For additional terms or questions, consult the Azure documentation or ask your coach.
