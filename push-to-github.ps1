# Commands to Push to New GitHub Repository
# Run these commands AFTER creating the repository on GitHub

# Stage all changes including new files
git add -A

# Commit all changes
git commit -m "Initial commit: Azure PostgreSQL HA Workshop

- High-performance C# failover testing script (1000+ TPS capable)
- Complete PostgreSQL Flexible Server deployment with Zone-Redundant HA
- Comprehensive workshop documentation and guides
- Security vulnerability training materials (intentional for education)
- Bicep infrastructure-as-code templates
- PowerShell deployment automation scripts

Includes:
- Test-PostgreSQL-Failover.csx for Cloud Shell execution
- Deploy-SAIF-PostgreSQL.ps1 for full environment setup
- LICENSE (MIT) and SECURITY.md for responsible disclosure
- Complete documentation in docs/ folder
"

# Set the new remote (replace with your actual new repo URL)
git remote set-url origin https://github.com/jonathan-vella/azure-postgresql-ha-workshop.git

# Push to GitHub
git push -u origin main

# Verify
git remote -v
