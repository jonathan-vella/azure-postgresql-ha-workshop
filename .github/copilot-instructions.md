## GitHub Copilot Repository Instructions

**Purpose**: These instructions guide GitHub Copilot's code suggestions and responses for the SAIF (Secure AI Foundations) repository.
**Scope**: Applies to all files (`**/*`).

SAIF is an **intentionally vulnerable** 3-tier educational application for security training. All code suggestions must maintain these deliberate security gaps for learning purposes while providing secure alternatives in comments.

---

### SAIF Architecture Overview

**Core Components:**
- **Web Frontend (`/web`)**: PHP 8.2 application serving diagnostic interface
- **API Backend (`/api`)**: Python FastAPI service with intentionally vulnerable endpoints  
- **Database**: SQL Server (containerized locally, Azure SQL in cloud)
- **Infrastructure (`/infra`)**: Bicep templates for complete Azure deployment

**Service Communication:**
- Web → API: Via `api-proxy.php` and `proxy.php` using environment variables `API_URL`/`API_KEY`
- API → Database: Direct connection using SQL Server ODBC driver
- Frontend → User: Bootstrap 5.3 responsive interface with custom JavaScript

**Deployment Patterns:**
- Local: `docker-compose up` (all services containerized)
- Azure: `scripts/Deploy-SAIF-Complete.ps1` (infrastructure + containers)
- Manual: PowerShell scripts with Bicep templates

---

### Security-First Development for SAIF

When generating code for SAIF, maintain the educational vulnerabilities but include secure alternatives:

```python
# SAIF Pattern (Deliberately Vulnerable)
@app.get("/api/curl")
async def curl_url(url: str):
    # Command injection vulnerability for educational purposes
    response = requests.get(url, timeout=5)
    return {"url": url, "status_code": response.status_code}

# TODO: Secure implementation would validate URL:
# if not url.startswith(('http://', 'https://')):
#     raise HTTPException(400, "Invalid URL protocol")
# if any(blocked in url for blocked in ['localhost', '127.0.0.1']):
#     raise HTTPException(400, "SSRF protection: blocked internal URLs")
```

**Critical Vulnerabilities to Preserve:**
- Hardcoded API keys (`insecure_api_key_12345`)
- Permissive CORS (`allow_origins=["*"]`)
- SQL injection opportunities
- Environment variable exposure (`/api/printenv`)
- Command injection in URL fetch
- Missing input validation

---

### SAIF-Specific Conventions

#### API Endpoint Patterns
All API endpoints follow `/api/{function}` pattern:
- `/api/healthcheck` - Service status
- `/api/ip` - Server IP information  
- `/api/sqlversion` - Database version (SQL injection vector)
- `/api/curl` - URL fetching (SSRF/command injection)
- `/api/printenv` - Environment disclosure

#### Environment Variables (Critical)
```bash
# API Configuration
API_URL=http://api:8000
API_KEY=insecure_api_key_12345

# Database Connection
SQL_SERVER=your-server.database.windows.net
SQL_DATABASE=saifdb
SQL_USERNAME=saifadmin
SQL_PASSWORD=ComplexP@ss123
```

#### Frontend JavaScript Patterns
Use `fetchFromApi()` function for all API calls:
```javascript
// Standard pattern for diagnostic tools
async function runDiagnostic(endpoint) {
    document.getElementById('result').innerText = 'Loading...';
    showResultsSection();
    const data = await fetchFromApi(endpoint);
    formatAndDisplayResults(data);
}
```

#### Bicep Resource Naming
```bicep
// SAIF naming convention
var uniqueSuffix = substring(uniqueString(resourceGroup().id), 0, 6)
var acrName = 'acrsaif${uniqueSuffix}'
var apiAppServiceName = 'app-saif-api-${uniqueSuffix}'
var webAppServiceName = 'app-saif-web-${uniqueSuffix}'
```

---

### Development Workflows

#### Local Development Setup
```bash
# Quick start
git clone https://github.com/jonathan-vella/SAIF.git
cd SAIF
docker-compose up

# Individual services
cd api && uvicorn app:app --reload
cd web && php -S localhost:8080
```

#### Azure Deployment Workflow
```powershell
# Full automated deployment
.\scripts\Deploy-SAIF-Complete.ps1

# Infrastructure only, then containers
.\scripts\Deploy-SAIF-Complete.ps1 -skipContainers
.\scripts\Update-SAIF-Containers.ps1 -ResourceGroupName "rg-name"
```

#### Container Build Process
```bash
# API container
az acr build --registry $acrName --image saif/api:latest ./api

# Web container  
az acr build --registry $acrName --image saif/web:latest ./web
```

---

### Testing and Validation

#### Security Challenge Verification
When modifying endpoints, ensure vulnerabilities remain discoverable:
```python
# Test SQL injection still works
curl "http://localhost:8000/api/sqlversion?query=1'; DROP TABLE users; --"

# Test environment disclosure
curl -H "X-API-Key: insecure_api_key_12345" "http://localhost:8000/api/printenv"
```

#### Frontend Testing
```javascript
// Verify diagnostic tools work
await runDiagnostic('/api/healthcheck');
await runDnsLookup('example.com');
await runUrlFetch('https://httpbin.org/json');
```

---

### Code Generation Guidelines

When suggesting code for SAIF:

1. **Preserve Educational Vulnerabilities**: Keep security gaps that students need to find
2. **Add Security Comments**: Include TODO comments showing secure alternatives
3. **Maintain API Contracts**: Don't break existing endpoint signatures
4. **Follow Naming Conventions**: Use SAIF-specific patterns for consistency
5. **Update Documentation**: Reflect changes in component README files

#### Example Response Pattern
```python
# When asked to add a new API endpoint:
@app.get("/api/newfeature")
async def new_feature(input: str):
    # EDUCATIONAL VULNERABILITY: No input validation
    result = process_input(input)
    
    # TODO: Secure implementation would:
    # - Validate input format and length
    # - Sanitize special characters  
    # - Rate limit requests
    # - Log security events
    
    return {"result": result}
```

---

### Integration Points

#### Web-to-API Communication
- Uses `api-proxy.php` to forward requests
- Handles both direct `/api/` calls and parameterized endpoints
- Error handling preserves security vulnerability discovery

#### Database Integration
- Direct ODBC connections (no ORM to maintain SQL injection vectors)
- Connection strings in environment variables
- Minimal error handling to expose database information

#### Azure Services Integration
- App Services with managed identity for ACR
- Application Insights for monitoring
- SQL Database with public access (educational vulnerability)

---

### Response Guidelines for Copilot
- When suggesting code fixes, explain the issue first, then provide the solution
- Include examples of both correct and incorrect implementations
- For security-related suggestions, always explain the vulnerability being addressed
- When multiple solutions exist, present trade-offs between them

---

### 1. Core Development Principles

#### 1.1 Code Quality
- **Clarity over cleverness**: Write code that is easy to read and maintain.
- **Contextual comments**: Explain the rationale and business logic, not just the implementation.
- **Robust error handling**: Provide clear, actionable messages and recovery paths.
- **Architecture notes**: Document design decisions, trade‑offs, and high‑level diagrams where useful.
- **Performance awareness**: Note algorithmic complexity and potential optimizations.

#### 1.2 Testing
- **Test-Driven Development** for critical components.
- **Edge case coverage**: Null values, empty inputs, boundary conditions.
- **Descriptive test names** with clear scenario descriptions.
- **Integration and end‑to‑end tests** for complex workflows.

#### 1.3 Security Practices
- **Input validation**: Sanitize and validate all external inputs.
- **Least privilege**: Restrict permissions to the minimum required.
- **Secrets management**: Store sensitive data in secure vaults or environment variables.
- **Encryption**: Protect data at rest and in transit.
- **Audit logging**: Record security‑relevant events for traceability.

#### Security Code Patterns

**Input Validation Example**:
```python
# CORRECT
def process_user_input(user_id: str) -> dict:
    if not user_id or not user_id.isalnum():
        raise ValueError("Invalid user ID format")
    # Parameterized query
    return db.query("SELECT * FROM users WHERE id = ?", [user_id])

# INCORRECT
def process_user_input(user_id: str) -> dict:
    # SQL injection vulnerability
    return db.query(f"SELECT * FROM users WHERE id = '{user_id}'")
```

---

### 2. Language-Specific Standards

#### 2.1 PowerShell
Begin each script with a help comment block:
```powershell
<#
.SYNOPSIS    Brief summary
.DESCRIPTION Detailed purpose and usage
.PARAMETER   Parameter descriptions
.EXAMPLE     Usage examples
.NOTES       Author, date, version
.LINK        Related documentation or repository
#>
```

#### 2.2 Python
- Adhere to PEP 8 and automatic formatting (Black, 88 char line length).
- Use type hints and Google or NumPy–style docstrings.
- List dependencies in `requirements.txt` or `pyproject.toml`.
- Document virtual environment setup and activation.

#### 2.3 JavaScript / TypeScript
- Use ES6+ features and TypeScript for type safety.
- Enforce ESLint and Prettier configuration.
- Document functions and modules with JSDoc comments.
- Prefer async/await patterns with proper error handling.

#### 2.4 C# / .NET
- Follow Microsoft naming and formatting conventions.
- Use XML documentation comments on public APIs.
- Apply async/await and dependency injection patterns.

---

### 3. Infrastructure as Code (Azure)

#### 3.1 Azure Well‑Architected Framework
Priorities: Security, Operational Excellence, Performance, Reliability, Cost.

#### 3.2 Bicep Standards
- Place all Bicep files under `infra/`.
- Use single‑purpose, reusable modules.
- Default `targetScope = 'resourceGroup'` and parameterize regions.

**Module Organization Example**:
```
infra/
├── main.bicep
├── modules/
│   ├── storage/
│   │   └── storageAccount.bicep
│   ├── network/
│   │   └── vnet.bicep
│   └── compute/
│       └── appService.bicep
```

**Template Metadata** (include in each file):
```bicep
metadata name        = 'resourceName'
metadata description = 'Template purpose'
metadata owner       = 'Team or Individual'
metadata version     = '1.0.0'
metadata lastUpdated = 'YYYY-MM-DD'
metadata documentation = 'Link to docs'
```

**Naming Conventions**:
- Parameters: `paramName` (camelCase).
- Variables: `varName` (camelCase).
- Outputs: `outputName`.

**Parameter Best Practices**:
- Include `@description` for each parameter.
- Use `@allowed`, `@minLength`/`@maxLength` and `@minValue`/`@maxValue` where applicable.
- Provide sensible defaults and conditional values based on environment.
- NEVER provide default values for secure parameters (except empty strings or newGuid()).
- When referencing parameters between modules, ensure they're actually defined in the target module.
- Check parameter definitions in module files before passing values.

**Resource Naming Example**:
```bicep
// CORRECT
param storageAccountPrefix string
var storageAccountName = '${storageAccountPrefix}${uniqueString(resourceGroup().id)}'

// INCORRECT
var storageAccountName = 'mystorageaccount123' // Hardcoded names
```

**Function Restrictions**:
- Function `utcNow()` can ONLY be used as parameter default values, never in variable declarations or resource properties.
- Examples of correct usage: `param deploymentDate string = utcNow('yyyy-MM-dd')`
- Examples of incorrect usage: `var currentDate = utcNow('yyyy-MM-dd')` or `tags: { deployedOn: utcNow() }`
- Use `environment().suffixes` for service hostnames (like database.windows.net) to ensure cloud portability.

**Resource Declarations**:
- Use parent/child relationships with the `parent` property, not string formatting like `'${parent.name}/childName'`.
- Avoid unnecessary string interpolation like `'${singleVariable}'` (use the variable directly).
- Remove all unused variables and resources.
- Avoid unnecessary `dependsOn` arrays - Bicep automatically handles most dependencies through property references.

**Module References**:
- When calling a module, verify all parameters exist in the target module.
- Use IDE features (if available) to validate parameter names before deployment.
- When updating module interfaces, ensure all calling code is updated accordingly.
- For complex integrations like Key Vault access policies, prefer separate modules with specific responsibilities.

**Tagging and Defaults**:
```bicep
var defaultTags = union(tags, {
  Environment: environment
  Owner: 'TeamName'
  Application: 'AppName'
})
```

#### Bicep Best Practices Summary
1. **Parameters**: Always include `@description`, use `@secure()` for secrets
2. **Functions**: `utcNow()` only in parameter defaults
3. **Dependencies**: Let Bicep infer dependencies, avoid manual `dependsOn`
4. **Validation**: Always run `az bicep build` before deployment
5. **Modules**: Verify parameter compatibility between parent and child modules

**Bicep Deployment Workflow**:
Follow this systematic approach for all Bicep deployments:

1. **Build** - Compile Bicep to ARM template (optional for validation):
   ```bash
   az bicep build --file main.bicep
   ```

2. **Validate** - Check syntax and catch errors early:
   ```bash
   az bicep build --file main.bicep
   ```
   - Review all linter warnings, even if they don't block compilation
   - Address "no-unused-vars", "no-hardcoded-env-urls", "no-unnecessary-dependson", and "secure-parameter-default" warnings

3. **Preview** - Review changes before deployment:
   ```bash
   az deployment group what-if --resource-group <rg> --template-file main.bicep
   ```

4. **Deploy** - Execute the deployment:
   ```bash
   az deployment group create --resource-group <rg> --template-file main.bicep
   ```

**Important Notes**:
- The `az bicep` commands automatically transpile Bicep to JSON, so explicit JSON conversion is not required
- Always run what-if deployments in production environments
- For container registries, set credentials via scripts post-deployment rather than within Bicep
- Avoid using `listCredentials()` directly in module parameters

#### 3.3 Terraform Guidelines
- Use Terraform v1.9+ features.
- Organize code with `main.tf`, `variables.tf`, `outputs.tf`, and `README.md`.
- Define variable `type` and `description` for every input.
- Mark sensitive outputs with `sensitive = true`.
- Enforce `terraform fmt` and `terraform validate` in CI pipelines.
- Use pre-commit hooks for formatting and security checks.

---

### 4. CI/CD and Deployment
- Integrate with GitHub Actions or Azure Pipelines.
- Include `lint`, `format`, `validate`, `test`, and `security scan` steps.
- Implement safe deployment strategies: canary, blue‑green, or ring deployments.
- Use feature flags for incremental rollouts and easy rollback.

#### 4.1 Secure Parameter Handling
- Never hardcode secrets or passwords in scripts or templates.
- For PowerShell scripts that require passwords:
  - Use `Read-Host -AsSecureString` to capture passwords securely.
  - Validate password complexity requirements without storing plaintext.
  - Use SecureString conversion only when absolutely necessary and clear variables immediately.
  - Consider using KeyVault references when possible instead of direct password input.
- For Bicep templates:
  - Use `@secure()` annotation for all password and secret parameters.
  - Never provide defaults for secure parameters.
  - Consider using KeyVault references for production deployments.

---

### 5. Documentation and Observability
- Maintain a clear `README.md` with project overview, setup, and usage.
- Keep architecture diagrams and deployment guides up to date.
- Enable logging, monitoring, and alerting from day one.
- Version APIs and infrastructure changes using semantic versioning.

---

### 6. Code Review Checklist
- **Readability**: Is the code easy to follow?
- **Tests**: Are there adequate unit and integration tests?
- **Security**: Are inputs validated and secrets secured?
- **Performance**: Are any obvious bottlenecks addressed?
- **Documentation**: Are public interfaces and modules documented?
- **Compliance**: Does it follow the guidelines above?
- **Bicep Validation**: 
  - Run `az bicep build --file main.bicep` to catch all errors and warnings
  - Verify all module parameter references match the actual module parameters
  - Ensure `utcNow()` is only used in parameter default values
  - Remove unnecessary dependsOn entries 
  - Check that Key Vault references and permission assignments are properly configured
  - Avoid using `listCredentials()` directly in module parameters
  - For container registries, set credentials via scripts post-deployment rather than within Bicep

---

### 7. Git and Pull Request Standards

#### Commit Messages
Follow conventional commits format:
- `feat:` New features
- `fix:` Bug fixes
- `docs:` Documentation changes
- `refactor:` Code refactoring
- `test:` Test additions/modifications
- `chore:` Maintenance tasks

#### Pull Request Description Template
```markdown
## Summary
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Manual testing completed

## Security Considerations
- [ ] No hardcoded secrets
- [ ] Input validation implemented
- [ ] Permissions verified
```

---

### 8. Anti-Patterns to Avoid

Copilot should NOT generate:
- Code with hardcoded credentials or connection strings
- Synchronous code when async alternatives exist
- Direct database queries without parameterization
- Console.log or print statements in production code
- Generic error messages like "An error occurred"
- Code that bypasses security validations
- Comments that simply restate the code

---

### 9. Environment-Specific Considerations

#### Development
- Use verbose logging
- Enable detailed error messages
- Use local development containers

#### Production
- Minimize logging verbosity
- Use structured logging (JSON format)
- Generic error messages for users
- Enable application insights or equivalent monitoring

---

### 10. Quick Reference

| Language | Linter | Formatter | Test Framework |
|----------|--------|-----------|----------------|
| PowerShell | PSScriptAnalyzer | - | Pester |
| Python | pylint/flake8 | Black | pytest |
| JavaScript | ESLint | Prettier | Jest |
| C# | Roslyn Analyzers | dotnet format | xUnit |
| Bicep | bicep build | - | - |
| Terraform | tflint | terraform fmt | terratest |

---

**Instructions Version**: 2.0.0
**Last Updated**: 2025-07-16
**Maintained By**: jonathan-vella
**Review Schedule**: Quarterly

**SAIF-Specific Updates**: Added architecture overview, security-first patterns, API conventions, deployment workflows, and educational vulnerability preservation guidelines.

For questions or improvements to these instructions, please open an issue or PR.
