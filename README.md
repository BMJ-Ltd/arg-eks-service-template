# EKS Service Template

**Version:** 1.0.0 | **Owner:** Architecture Review Group | **Created:** 2026-02-11

---

## 📖 Documentation

- **[END_TO_END_WORKFLOW.md](END_TO_END_WORKFLOW.md)** - Complete workflow from developer request to production deployment (recommended starting point)
- **[EXAMPLE_WORKFLOW.md](EXAMPLE_WORKFLOW.md)** - Step-by-step technical example creating the Clinical Intelligence product with 4 services
- **[CONFIGURATION_CHECKLIST.md](CONFIGURATION_CHECKLIST.md)** - Setup verification checklist
- **[CRITICAL_ACTIONS.md](CRITICAL_ACTIONS.md)** - Security and safety guidelines
- **[AGENTS.MD](AGENTS.MD)** - AI agent context and skills

---

## Purpose

This template repository provides a standardized structure for creating new EKS deployment repositories at BMJ. 

**Repository Structure Pattern:**
- **Repository name** = Product (e.g., `clin-intel-knowledge-graph_eks`)
- **Multiple services** within repository (e.g., `knowledge-graph-api/`, `knowledge-graph-builder/`, `knowledge-graph-ui/`)

**Each service includes:**
- **Kubernetes manifests** with Kustomize base + overlays pattern
- **Multi-environment support** (dev, stg, live)
- **ArgoCD integration** for GitOps deployments
- **Security best practices** (IRSA, non-root containers, sealed secrets)
- **Documentation templates** for deployment plans and checklists

**Reference**: See [clin-intel-knowledge-graph_eks](https://github.com/BMJ-Ltd/clin-intel-knowledge-graph_eks) for real-world example

---

## Repository Structure: Product → Services

**Important**: Repository represents a **product** with multiple services, not a single service.

```
Example:
  clin-intel-knowledge-graph_eks  ← Product repository
  ├── knowledge-graph-api         ← Service 1
  ├── knowledge-graph-builder     ← Service 2  
  ├── knowledge-graph-ui         ← Service 3
  └── allegrograph-db            ← Service 4
```

Each service is independent with its own:
- Kubernetes manifests (deployment, service, etc.)
- Environment overlays (dev/stg/live)
- Secrets
- Resource requirements
- IAM roles

But all share the same:
- Product name (for cost tracking)
- Team ownership
- Repository

---

## ⚠️ Important: Template vs Instance

**This template repository will NOT build with Kustomize until customized.**

**Why?**
- Contains placeholders like `{{SERVICE_NAME}}`, `{{PRODUCT_NAME}}`, etc.
- Kustomize expects actual values, not placeholders
- Running `kustomize build` will fail with "invalid Kustomization" error

**This is expected and normal behavior for a template repository.**

**Before building:**
1. Replace **all placeholders** with actual values
2. Use `./verify-configuration.sh` to find unreplaced placeholders
3. See `gha-java-app_eks-v2` repository for working reference implementation

**What placeholders need replacing:**
- `{{SERVICE_NAME}}` - Your service name (e.g., `knowledge-graph-api`)
- `{{PRODUCT_NAME}}` - Your product name (e.g., `clinical-intelligence`)
- `{{TEAM_NAME}}` - Your team name (e.g., `platform`)
- `{{AWS_ACCOUNT_ID}}` - AWS account ID per environment
- `{{AWS_REGION}}` - AWS region (e.g., `eu-west-1`)
- `{{ENVIRONMENT}}` - Environment (dev/stg/live)
- And others - see CONFIGURATION_CHECKLIST.md

**Reference Implementation**: See `/home/bmohamoodally/workspace/gha-java/gha-java-app_eks-v2` for what this template looks like when properly customized with real values.

---

## Quick Start

### 1. Create New Repository

```bash
# Option A: Use GitHub template (recommended)
# Create new repo from this template via GitHub UI

# Option B: Manual clone
git clone https://github.com/BMJ-Ltd/arg-eks-service-template.git my-product_eks
cd my-product_eks
rm -rf .git
git init
```

### 2. Run Configuration Script

```bash
./verify-configuration.sh --configure
```

This will prompt you for:
- Service name
- Product name
- Team name
- AWS account IDs
- Regions
- ECR repository details

### 3. Add Your Services

**For single-service products:**
```bash
mv example-service/ your-service-name/
```

**For multi-service products** (like clin-intel-knowledge-graph_eks):
```bash
# Copy example-service for each service
cp -r example-service/ service-api/
cp -r example-service/ service-worker/
cp -r example-service/ service-ui/

# Remove the example
rm -rf example-service/
```

4. Update placeholders in all service directories
5. Configure environment-specific settings per service
6. Create sealed secrets for each service and environment
7. Update documentation

### 4. Validate

```bash
# Verify kustomize builds
kustomize build example-service/overlays/dev/
kustomize build example-service/overlays/stg/
kustomize build example-service/overlays/live/

# Run validation script
./verify-configuration.sh
```

---

## Repository Structure

**Pattern: Product repository with multiple services**

```
product-name_eks/                 # Repository = Product
├── README.md                     # Product overview
├── AGENTS.MD                     # AI agent configuration
├── CRITICAL_ACTIONS.md           # Safety guidelines
├── CONFIGURATION_CHECKLIST.md    # Setup checklist
├── verify-configuration.sh       # Validation script
├── service-api/                  # Service 1
│   ├── base/
│   │   ├── kustomization.yaml
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── serviceaccount.yaml
│   │   ├── ingress.yaml
│   │   ├── pvc.yaml              # Optional
│   │   ├── instrumentation.yaml  # Optional
│   │   └── argocd.yaml           # Optional
│   └── overlays/
│       ├── dev/
│       ├── stg/
│       └── live/
├── service-worker/               # Service 2
│   ├── base/
│   └── overlays/
│       ├── dev/
│       ├── stg/
│       └── live/
├── service-ui/                   # Service 3
│   ├── base/
│   └── overlays/
│       ├── dev/
│       ├── stg/
│       └── live/
└── .claude/
    └── skills/
        └── template-usage/
            └── SKILL.md
```

**Real-world example:**
```
clin-intel-knowledge-graph_eks/
├── knowledge-graph-api/
├── knowledge-graph-builder/
├── knowledge-graph-ui/
└── allegrograph-db/
```

---

## Standard Overlay Pattern

**✅ ONLY create these three permanent overlays:**

- **`dev/`** - Development environment (low resource limits, internal ingress)
- **`stg/`** - Staging/pre-production environment (production-like, testing)
- **`live/`** - Production environment (full resources, high availability)

**❌ DO NOT create additional permanent overlays:**

- ❌ `pr/` - Use PR preview ApplicationSet instead (see PR Preview section)
- ❌ `uat/`, `qa/`, `test/` - Use `stg/` for all pre-production testing
- ❌ `sandbox/`, `demo/` - Deploy as separate service if needed
- ❌ `prod/`, `production/` - Use `live/` (BMJ standard naming)

**Why only three?**
- Additional overlays create maintenance burden
- More overlays = more configuration drift
- Increases complexity and cognitive load
- Harder to ensure consistency across environments

**Environment progression:**
```
dev → stg → live
 ↓      ↓      ↓
Fast   Test   Stable
```

### PR Preview Environments (Ephemeral)

**For temporary PR preview environments, DO NOT create a permanent overlay.**

✅ **Correct approach:**
- Use `dev` overlay as base
- Apply dynamic overrides via ApplicationSet
- Ephemeral (created/destroyed with PRs)
- No permanent directory structure

❌ **Wrong approach:**
- Creating `overlays/pr/` directory
- Maintaining permanent PR configuration
- Treating PRs as permanent environment

**Example PR preview ApplicationSet:**
```yaml
# Uses dev overlay + dynamic overrides
path: {{service}}/overlays/dev
kustomize:
  namePrefix: pr-{{number}}-
  commonLabels:
    pr-number: "{{number}}"
  images:
    - registry/{{service}}:pr_{{branch}}_{{sha}}
```

See [applicationset-example.yaml](applicationset-example.yaml) for complete PR preview pattern.

---

## Naming Convention

- **Repository name**: `{product-name}_eks` (e.g., `clin-intel-knowledge-graph_eks`, `journals_eks`)
- **Service directories**: `{service-name}/` (e.g., `knowledge-graph-api/`, `payment-processor/`)
- **Labels**: `product` = product name, `app` = service name

## Template Placeholders

Replace these placeholders throughout each service directory:

| Placeholder | Description | Example |
|-------------|-------------|---------|
| `{{SERVICE_NAME}}` | Service name (lowercase-with-hyphens) | `knowledge-graph-api` |
| `{{PRODUCT_NAME}}` | Product name for cost tracking | `Clinical Intelligence` |
| `{{TEAM_NAME}}` | Owning team | `Platform` |
| `{{REPOSITORY_NAME}}` | GitHub repository name | `clin-intel_eks` |
| `{{AWS_ACCOUNT_ID}}` | AWS account ID by environment | `109227185188` (dev) |
| `{{AWS_REGION}}` | AWS region | `eu-west-1` |
| `{{ENVIRONMENT}}` | Environment name | `dev`, `stg`, `live` |
| `{{SERVICE_PORT}}` | Container port | `8080` |
| `{{MEMORY_REQUEST}}` | Memory request | `256Mi` |
| `{{MEMORY_LIMIT}}` | Memory limit | `512Mi` |
| `{{CPU_REQUEST}}` | CPU request | `100m` |
| `{{CPU_LIMIT}}` | CPU limit | `500m` |
| `{{STORAGE_SIZE}}` | PVC storage size | `10Gi` |
| `{{CERTIFICATE_ARN}}` | ACM certificate ARN | `arn:aws:acm:...` |

---

## AWS Account IDs by Environment

| Environment | Account ID | Region(s) |
|-------------|------------|-----------|
| dev | 109227185188 | eu-west-1 |
| stg | 138832992068 | eu-west-1, us-west-2 |
| live | 721468132385 | eu-west-1, us-west-2 |

---

## Environment Defaults

### Development (dev)
- **Replicas**: 1
- **Resources**: 256Mi/100m (request), 512Mi/500m (limit)
- **Log Level**: DEBUG
- **Region**: eu-west-1
- **Auto-scaling**: Disabled
- **Cycle State**: Auto-start/stop enabled

### Staging (stg)
- **Replicas**: 2
- **Resources**: 512Mi/250m (request), 1Gi/1000m (limit)
- **Log Level**: INFO
- **Regions**: eu-west-1, us-west-2
- **Auto-scaling**: Optional
- **Cycle State**: Auto-start/stop enabled

### Production (live)
- **Replicas**: 3+ (with HPA)
- **Resources**: Right-sized per service
- **Log Level**: WARN
- **Regions**: eu-west-1, us-west-2 (multi-region)
- **Auto-scaling**: Enabled (HPA)
- **Pod Disruption Budget**: Required
- **Cycle State**: Always-on

---

## Common Tasks

### Add a New Service to Product

**Each time you add a service to your product:**

1. Copy `example-service/` directory:
   ```bash
   cp -r example-service/ my-new-service/
   ```

2. Update placeholders for **THIS SERVICE** in all files:
   ```bash
   # Replace service name
   find my-new-service/ -type f -exec sed -i 's/{{SERVICE_NAME}}/my-new-service/g' {} +
   
   # Product name and team stay the same across all services
   # Only service-specific values change
   ```

3. Customize manifests for your service needs:
   - Resource limits (may differ per service)
   - Health check endpoints (service-specific)
   - Ingress rules (if this service needs external access)
   - Dependencies (service-specific AWS resources)

4. Validate:
   ```bash
   kustomize build my-new-service/overlays/dev/
   ```

**Example: Building clin-intel-knowledge-graph_eks pattern:**
```bash
# Start with cloned template
cd clin-intel-knowledge-graph_eks

# Create services
cp -r example-service/ knowledge-graph-api/
cp -r example-service/ knowledge-graph-builder/
cp -r example-service/ knowledge-graph-ui/
cp -r example-service/ allegrograph-db/

# Remove example
rm -rf example-service/

# Each service gets its own:
# - Service-specific resources
# - Service-specific secrets
# - Service-specific IAM roles
# But shares:
# - Product name
# - Team name
# - Cost centre
```

### Create Sealed Secrets

```bash
# 1. Get kubeseal certificate for target cluster
kubeseal --fetch-cert \
  --controller-name=sealed-secrets-controller \
  --controller-namespace=kube-system \
  > dev-cert.pem

# 2. Create plain secret
kubectl create secret generic my-service-secrets \
  --from-literal=DATABASE_URL="postgresql://..." \
  --from-literal=API_KEY="secret-key" \
  --dry-run=client -o yaml > secret.yaml

# 3. Seal it
kubeseal --format=yaml \
  --cert=dev-cert.pem \
  < secret.yaml > example-service/overlays/dev/sealed-secrets.yaml

# 4. Clean up plain secret
rm secret.yaml dev-cert.pem
```

### Deploy with ArgoCD

```bash
# Option 1: Via kubectl
kubectl apply -f example-service/base/argocd.yaml

# Option 2: Via ArgoCD CLI
argocd app create my-service-dev \
  --repo https://github.com/BMJ-Ltd/my-product_eks.git \
  --path example-service/overlays/dev \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace default \
  --sync-policy automated

# Option 3: Via ApplicationSet (multi-environment)
# See argocd-application-generator skill
```

---

## Prerequisites

Before using this template, ensure you have:

- [ ] AWS CLI configured with appropriate account access
- [ ] kubectl access to target EKS clusters
- [ ] kustomize CLI installed (`brew install kustomize`)
- [ ] kubeseal CLI installed (for sealed secrets)
- [ ] ArgoCD access to target clusters
- [ ] ECR repositories created for your services
- [ ] IAM roles created for IRSA (one per service per environment)
- [ ] ACM certificates for ingress domains
- [ ] GitHub repository created

### Required OPSQ Tickets

Create OPSQ tickets for Platform Team to provision:

1. **ECR Repositories**: One per service
2. **IAM Roles**: IRSA roles for each service/environment
3. **ACM Certificates**: Wildcard certificates per environment
4. **Namespaces**: If using custom namespaces
5. **ArgoCD Projects**: If using custom ArgoCD projects

---

## Related Resources

- **Organization Standards**: [arg-agentic-configuration](https://github.com/BMJ-Ltd/arg-agentic-configuration)
- **Reference Implementation**: [clin-intel-knowledge-graph_eks](https://github.com/BMJ-Ltd/clin-intel-knowledge-graph_eks)
- **Serverless Template**: [arg-serverless-python-app-template](https://github.com/BMJ-Ltd/arg-serverless-python-app-template)
- **Terraform Examples**: [arg-example_tf](https://github.com/BMJ-Ltd/arg-example_tf)

### Skills

Load these skills when working with this template:

- `eks-service-scaffolding` - Generate service structures
- `kustomize-overlay-builder` - Build environment overlays
- `argocd-application-generator` - Create ArgoCD configs
- `eks-repository-initializer` - Initialize from this template
- `jira-workflow` - Create OPSQ tickets
- `quality-gates` - Validate before committing

---

## Support

- **Platform Team**: Raise [OPSQ ticket](https://bmjtech.atlassian.net/jira/software/c/projects/OPSQ/boards/493)
- **ARG Review**: For architecture guidance
- **Documentation**: See [CONFIGURATION_CHECKLIST.md](CONFIGURATION_CHECKLIST.md)

---

**Last Updated**: 2026-02-11  
**Template Version**: 1.0.0  
**Maintained By**: Architecture Review Group
