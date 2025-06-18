## GitHub Copilot Repository Instructions

**Scope**: Applies to all files (`**/*`).

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
- Adhere to PEP 8 and automatic formatting (Black, 88 char line length).
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

**Tagging and Defaults**:
```bicep
var defaultTags = union(tags, {
  Environment: environment
  Owner: 'TeamName'
  DeploymentTime: utcNow('yyyy-MM-dd')
})
```

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

