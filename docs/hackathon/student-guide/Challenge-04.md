
---
version: 1.0.0
last_updated: 2025-07-17
guide_type: student
challenge: 04
title: Baseline Network Deployment – Implementing Zero Trust Architecture
---

# Challenge 04: Baseline Network Deployment – Implementing Zero Trust Architecture
# Timeline & Milestones
| Suggested Duration | Recommended Milestones |
|--------------------|-----------------------|
| 2 hours            | Network deployed, security controls configured |

## Objective
Deploy the zero trust network you designed in Challenge 03, using Azure hub-and-spoke architecture and best practices for segmentation and security controls.

## Scenario

You are tasked with implementing the network blueprint for SAIF. The goal is to deploy a hub-and-spoke network in Azure, configure all required subnets, and apply security controls to support zero trust principles.

## Instructions

1. **Review Your Design**
   - Reference your Challenge 03 network diagram and justifications.

2. **Design and Deploy Your Network Architecture**
   - Based on your Challenge 03 blueprint, plan a hub-and-spoke network topology suitable for SAIF in Azure.
   - Determine how you will segment the network to support zero trust principles, including the use of multiple subnets for key security and application components.
   - Decide which network and security services should be placed in the hub and which in the spoke, justifying your choices.

3. **Implement Security Controls and Connectivity**
   - Establish secure connectivity between your hub and spoke networks using Azure-native features.
   - Select and configure appropriate security controls (e.g., firewalls, gateways, WAF, NSGs) for each subnet and document your rationale.
   - Ensure your configuration supports segmentation, monitoring, and compliance requirements.
   - Document your network topology, security rules, and peering setup, explaining how each supports zero trust.

4. **Document Your Deployment**
   - Submit screenshots or exported configuration files showing:
     - Network topology
     - Subnet and peering configuration
     - Security controls (firewall, NSGs, WAF)
   - Include a brief written summary explaining how your deployment supports zero trust principles and business priorities.

## Success Criteria

- Hub and Spoke networks deployed in Azure.
- Hub network contains Azure Firewall and VPN Gateway subnets.
- Spoke network contains WAF, Web Front End, API Layer, and Data Layer subnets.
- VNet peering configured between Hub and Spoke.
- Azure Firewall, VPN Gateway, and WAF deployed and configured.
- NSGs applied to all subnets with documented rules.
- Deployment is documented with screenshots/config files and a summary.

## Scoring Rubric

| Criteria                        | Excellent (5) | Good (3) | Needs Improvement (1) |
|---------------------------------|---------------|----------|-----------------------|
| Network Topology                | Hub and Spoke fully implemented | Most components present | Major components missing |
| Subnet Configuration            | All subnets correctly configured | Most subnets present | Few/no subnets configured |
| Security Controls               | Firewall, WAF, NSGs fully configured | Some controls present | Controls missing or misconfigured |
| VNet Peering                    | Peering correctly set up | Peering present but incomplete | No peering |
| Documentation                   | Screenshots/configs and summary included | Partial documentation | No documentation |
| Zero Trust Alignment            | Deployment clearly supports zero trust | Some alignment | No alignment |

## References

- [Azure Hub-Spoke Network Reference Architecture](https://learn.microsoft.com/en-us/azure/architecture/reference-architectures/hybrid-networking/hub-spoke)
- [Azure Firewall Documentation](https://learn.microsoft.com/en-us/azure/firewall/)
- [Azure VPN Gateway Documentation](https://learn.microsoft.com/en-us/azure/vpn-gateway/)
- [Azure WAF Documentation](https://learn.microsoft.com/en-us/azure/web-application-firewall/)
- [Network Security Groups (NSG)](https://learn.microsoft.com/en-us/azure/virtual-network/network-security-groups-overview)

---

**Tip:**
Focus on clear segmentation, security controls, and documentation to demonstrate zero trust implementation.
