# Agent Configuration - EKS Service Template

**Repository Type**: Template / Reference  
**Owner**: Architecture Review Group  
**Last Updated**: 2026-02-11

---

## Organization-Wide Standards

This repository follows BMJ organisation-wide agent standards.

**See**: https://github.com/BMJ-Ltd/arg-agentic-configuration/blob/main/AGENTS.MD

---

## Repository Context

### Purpose

This is a **template repository** for creating new EKS deployment repositories. It provides:

- Pre-configured Kubernetes manifests with Kustomize
- Multi-environment overlay structure (dev/stg/live)
- ArgoCD integration patterns
- Security best practices (IRSA, sealed secrets, non-root containers)
- Documentation templates

### Repository Structure Pattern

**Key concept**: Repository = **Product**, not service

**Pattern**:
- One repository per product (e.g., `clin-intel-knowledge-graph_eks`)
- Multiple service directories within (e.g., `knowledge-graph-api/`, `knowledge-graph-builder/`)
- Each service has independent base + overlays structure

**Example** (clin-intel-knowledge-graph_eks):
```
clin-intel-knowledge-graph_eks/
├── knowledge-graph-api/       # Service 1
│   ├── base/
│   └── overlays/{dev,stg,live}/
├── knowledge-graph-builder/   # Service 2
│   ├── base/
│   └── overlays/{dev,stg,live}/
├── knowledge-graph-ui/        # Service 3
│   ├── base/
│   └── overlays/{dev,stg,live}/
└── allegrograph-db/           # Service 4
    ├── base/
    └── overlays/{dev,stg,live}/
```

### Template Usage

**DO NOT modify this repository directly for production deployments.**

Instead:
1. Create a new repository from this template
2. Name it `{product-name}_eks`
3. Copy `example-service/` for each service you need
4. Rename each copy to actual service names
5. Replace all `{{PLACEHOLDERS}}` with actual values per service
6. Customize for your specific requirements

---

## Key Files

| File | Purpose |
|------|---------|
| [README.md](README.md) | Template usage guide |
| [CONFIGURATION_CHECKLIST.md](CONFIGURATION_CHECKLIST.md) | Setup steps |
| [CRITICAL_ACTIONS.md](CRITICAL_ACTIONS.md) | Safety guidelines |
| [verify-configuration.sh](verify-configuration.sh) | Validation script |
| `example-service/` | Template service structure |

---

## Working with This Template

### AI Agent Guidelines

When helping users work with this template:

1. **Always ask clarifying questions first**:
   - Service name?
   - Product/team name?
   - Environments needed? (dev/stg/live)
   - Regions? (eu-west-1, us-west-2)
   - Infrastructure dependencies? (RDS, OpenSearch, S3, etc.)
   - Ingress needed? (yes/no)
   - Persistent storage? (yes/no)

2. **Load relevant skills**:
   - `eks-repository-initializer` - For template instantiation
   - `eks-service-scaffolding` - For adding new services
   - `kustomize-overlay-builder` - For overlay customization
   - `argocd-application-generator` - For GitOps setup
   - `jira-workflow` - For OPSQ ticket creation

3. **Follow the configuration checklist**:
   - See [CONFIGURATION_CHECKLIST.md](CONFIGURATION_CHECKLIST.md)
   - Don't skip prerequisite steps

4. **Validate everything**:
   - Run `kustomize build` for each overlay
   - Use `verify-configuration.sh` script
   - Check for remaining `{{PLACEHOLDERS}}`

5. **Respect critical actions**:
   - See [CRITICAL_ACTIONS.md](CRITICAL_ACTIONS.md)
   - Never commit plain secrets
   - Always use sealed secrets for sensitive data

---

## Template Placeholders

All files contain placeholders that must be replaced:

```
{{SERVICE_NAME}}       - Service name (e.g., knowledge-graph-api)
{{PRODUCT_NAME}}       - Product name (e.g., Clinical Intelligence)
{{TEAM_NAME}}          - Team name (e.g., Platform)
{{REPOSITORY_NAME}}    - GitHub repo name (e.g., clin-intel_eks)
{{AWS_ACCOUNT_ID}}     - AWS account by environment
{{AWS_REGION}}         - AWS region (e.g., eu-west-1)
{{ENVIRONMENT}}        - Environment (dev/stg/live)
{{SERVICE_PORT}}       - Container port (e.g., 8080)
{{MEMORY_REQUEST}}     - Memory request (e.g., 256Mi)
{{MEMORY_LIMIT}}       - Memory limit (e.g., 512Mi)
{{CPU_REQUEST}}        - CPU request (e.g., 100m)
{{CPU_LIMIT}}          - CPU limit (e.g., 500m)
{{STORAGE_SIZE}}       - PVC size (e.g., 10Gi)
{{CERTIFICATE_ARN}}    - ACM certificate ARN
```

---

## Safety Guidelines

### Forbidden Actions (Even for AI Agents)

- **DO NOT** commit plain-text secrets
- **DO NOT** hard-code sensitive credentials
- **DO NOT** use this template repo for actual deployments
- **DO NOT** push to production without validation
- **DO NOT** skip sealed secrets encryption

### Required Actions

- **ALWAYS** use sealed secrets for sensitive data
- **ALWAYS** validate with `kustomize build` before committing
- **ALWAYS** run `verify-configuration.sh` before PR
- **ALWAYS** replace ALL placeholders
- **ALWAYS** create OPSQ tickets for infrastructure prerequisites

---

## Common Workflows

### 1. Initialize New Repository from Template

```bash
# Agent should guide through:
1. Clone template
2. Run verify-configuration.sh --configure
3. Rename example-service/
4. Replace placeholders
5. Customize manifests
6. Create sealed secrets
7. Validate with kustomize
8. Initialize git and push
```

### 2. Add New Service to Existing Repository

```bash
# Agent should:
1. Copy example-service/ structure
2. Update service-specific values
3. Customize base manifests
4. Create environment overlays
5. Generate sealed secrets
6. Create ArgoCD application
7. Validate builds
```

### 3. Add New Environment

```bash
# Agent should:
1. Copy existing overlay (e.g., stg → uat)
2. Update environment-specific values
3. Update AWS account IDs
4. Create new sealed secrets
5. Update ArgoCD ApplicationSet
6. Validate build
```

---

## Infrastructure Prerequisites

Before deploying services, ensure Platform Team has provisioned:

### AWS Resources (via OPSQ)

- [ ] EKS cluster in target region(s)
- [ ] ECR repositories for container images
- [ ] IAM roles for IRSA (service accounts)
- [ ] ACM certificates for ingress domains
- [ ] VPC and networking (subnets, security groups)
- [ ] ArgoCD installed and configured

### Kubernetes Resources

- [ ] Namespaces (if not using `default`)
- [ ] Sealed Secrets controller installed
- [ ] OpenTelemetry collector (if using instrumentation)
- [ ] Ingress controller (AWS Load Balancer Controller)
- [ ] StorageClasses (gp3 for PVCs)

### Access Requirements

- [ ] AWS CLI access to target accounts
- [ ] kubectl access to target clusters
- [ ] ArgoCD access
- [ ] GitHub write access

---

## Validation Checklist

Before merging PRs, verify:

- [ ] All `{{PLACEHOLDERS}}` replaced
- [ ] Service names consistent across all files
- [ ] AWS account IDs correct per environment
- [ ] Sealed secrets created and encrypted
- [ ] `kustomize build` succeeds for all overlays
- [ ] `verify-configuration.sh` passes
- [ ] No hard-coded secrets or credentials
- [ ] Security context set (non-root user)
- [ ] Resource limits defined
- [ ] Health checks configured (if applicable)
- [ ] IRSA roles referenced correctly
- [ ] Labels include team/costcentre/product
- [ ] Documentation updated
- [ ] OPSQ tickets created for prerequisites

---

## Reference Implementation

**See**: [clin-intel-knowledge-graph_eks](https://github.com/BMJ-Ltd/clin-intel-knowledge-graph_eks)

This production repository demonstrates:
- Real-world service configurations
- Multi-service deployments
- Environment-specific customizations
- Sealed secrets patterns
- ArgoCD ApplicationSet usage
- Multi-region deployments

Use it as reference when customizing this template.

---

## Skills to Load

When working with this template, load these skills from `arg-agentic-configuration`:

| Task | Load Skill |
|------|-----------|
| Initialize from template | `eks-repository-initializer` |
| Add new service | `eks-service-scaffolding` |
| Customize overlays | `kustomize-overlay-builder` |
| Setup GitOps | `argocd-application-generator` |
| Create OPSQ tickets | `jira-workflow` |
| Validate changes | `quality-gates` |
| Seal secrets | Load template-usage skill from this repo |

---

## Questions?

- **Platform Team**: [Raise OPSQ ticket](https://bmjtech.atlassian.net/jira/software/c/projects/OPSQ/boards/493)
- **ARG Guidance**: Contact Alex Hooper (ARG Chair)
- **Template Issues**: Create GitHub issue in this repository

---

**Maintained By**: Architecture Review Group  
**Version**: 1.0.0  
**Last Review**: 2026-02-11
