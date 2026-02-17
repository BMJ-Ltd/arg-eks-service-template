---
name: template-usage
description: >
  Guide for using the arg-eks-service-template to create new EKS deployment repositories.
  Use this skill when: (1) creating a new _eks repository from template, (2) instantiating
  the template with actual values, (3) understanding template structure.
  Triggers on questions about: template usage, using template, template instantiation,
  create from template, eks template.
---

# EKS Service Template Usage

This skill guides you through using the `arg-eks-service-template` to create new EKS deployment repositories.

**Template Repository**: https://github.com/BMJ-Ltd/arg-eks-service-template

---

## Quick Reference

### Template Creation Workflow

```
1. Create repo from template (GitHub UI or CLI)
2. Clone locally
3. Gather service information
4. Replace placeholders
5. Customize manifests
6. Create sealed secrets
7. Validate with kustomize
8. Commit and push
9. Create OPSQ tickets for infrastructure
10. Deploy via ArgoCD
```

---

## Step-by-Step Guide

### Step 1: Gather Information

Before starting, collect:

| Information | Example | Where Used |
|-------------|---------|------------|
| Service name | `knowledge-graph-api` | All manifests |
| Product name | `Clinical Intelligence` | Labels, cost tracking |
| Team name | `Platform` | Labels |
| Repository name | `clin-intel_eks` | ArgoCD, README |
| Environments | dev, stg, live | Overlays |
| Regions | eu-west-1, us-west-2 | Account IDs, ECR |
| Service port | 8080 | Deployment, service |
| Resource needs | Memory, CPU | Deployment |
| Dependencies | RDS, S3, OpenSearch | OPSQ tickets |
| Ingress type | Internal/public | Ingress config |

### Step 2: Create Repository

**Option A: GitHub UI (Recommended)**
1. Go to https://github.com/BMJ-Ltd/arg-eks-service-template
2. Click "Use this template" → "Create a new repository"
3. Name: `{{PRODUCT}}_eks` (e.g., `clin-intel_eks`)
4. Description: Brief description
5. Private repository
6. Click "Create repository"
7. Clone: `git clone git@github.com:BMJ-Ltd/{{PRODUCT}}_eks.git`

**Option B: Command Line**
```bash
git clone https://github.com/BMJ-Ltd/arg-eks-service-template.git my-product_eks
cd my-product_eks
rm -rf .git
git init
git remote add origin git@github.com:BMJ-Ltd/my-product_eks.git
```

### Step 3: Rename Service Directory

```bash
cd my-product_eks
mv example-service/ {{SERVICE_NAME}}/

# Example:
mv example-service/ knowledge-graph-api/
```

### Step 4: Replace Placeholders

**Automated replacement** (recommended):

```bash
# Service name
SERVICE_NAME="knowledge-graph-api"
find . -type f -not -path "./.git/*" -exec sed -i "s/{{SERVICE_NAME}}/$SERVICE_NAME/g" {} +

# Product name
PRODUCT_NAME="Clinical Intelligence"
find . -type f -not -path "./.git/*" -exec sed -i "s/{{PRODUCT_NAME}}/$PRODUCT_NAME/g" {} +

# Team name
TEAM_NAME="Platform"
find . -type f -not -path "./.git/*" -exec sed -i "s/{{TEAM_NAME}}/$TEAM_NAME/g" {} +

# Repository name
REPO_NAME="clin-intel_eks"
find . -type f -not -path "./.git/*" -exec sed -i "s/{{REPOSITORY_NAME}}/$REPO_NAME/g" {} +

# Service port
SERVICE_PORT="8080"
find . -type f -not -path "./.git/*" -exec sed -i "s/{{SERVICE_PORT}}/$SERVICE_PORT/g" {} +
```

**Manual replacement**:
- Use editor's find/replace across all files
- Be careful with special characters

### Step 5: Environment-Specific Configuration

**For EACH environment**, update:

#### Dev (overlays/dev/)

```yaml
# env.yaml
env:
  - name: ENVIRONMENT
    value: "dev"
  - name: LOG_LEVEL
    value: "DEBUG"
  - name: AWS_REGION
    value: "eu-west-1"
  # Add service-specific vars
```

```yaml
# serviceaccount-patch.yaml
annotations:
  eks.amazonaws.com/role-arn: arn:aws:iam::109227185188:role/{{SERVICE_NAME}}-dev-role
```

#### Stg (overlays/stg/)

```yaml
# serviceaccount-patch.yaml
annotations:
  eks.amazonaws.com/role-arn: arn:aws:iam::138832992068:role/{{SERVICE_NAME}}-stg-role
```

#### Live (overlays/live/)

```yaml
# serviceaccount-patch.yaml
annotations:
  eks.amazonaws.com/role-arn: arn:aws:iam::721468132385:role/{{SERVICE_NAME}}-live-role
```

### Step 6: Create Sealed Secrets

**For each environment**:

```bash
# 1. Get kubeseal certificate
kubeseal --fetch-cert \
  --controller-name=sealed-secrets-controller \
  --controller-namespace=kube-system \
  > dev-cert.pem

# 2. Create plain secret
kubectl create secret generic {{SERVICE_NAME}}-secrets \
  --from-literal=DATABASE_URL="postgresql://..." \
  --from-literal=API_KEY="secret-key" \
  --dry-run=client -o yaml > secret.yaml

# 3. Seal it
kubeseal --format=yaml \
  --cert=dev-cert.pem \
  < secret.yaml > {{SERVICE_NAME}}/overlays/dev/sealed-secrets.yaml

# 4. CRITICAL: Delete plain secret
rm secret.yaml dev-cert.pem

# 5. Verify sealed secret
cat {{SERVICE_NAME}}/overlays/dev/sealed-secrets.yaml | grep "encryptedData:"
```

**Repeat for stg and live using their respective certificates.**

### Step 7: Customize Resources

#### Update Resource Limits

Edit `{{SERVICE_NAME}}/base/deployment.yaml`:

```yaml
resources:
  requests:
    memory: "256Mi"  # Adjust based on service
    cpu: "100m"      # Adjust based on service
  limits:
    memory: "512Mi"  # Adjust based on service
    cpu: "500m"      # Adjust based on service
```

#### Configure Health Checks

If your service has health endpoints:

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 60
  periodSeconds: 30

readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 10
```

#### Remove Unused Resources

If NOT needed, remove from `base/kustomization.yaml` resources:
- `pvc.yaml` - if no persistent storage
- `instrumentation.yaml` - if not using OpenTelemetry
- `ingress.yaml` - if internal service only

### Step 8: Validate

```bash
# Build each overlay and check for errors
kustomize build {{SERVICE_NAME}}/overlays/dev/
kustomize build {{SERVICE_NAME}}/overlays/stg/
kustomize build {{SERVICE_NAME}}/overlays/live/

# Run verification script
./verify-configuration.sh

# Check for remaining placeholders
grep -r "{{" {{SERVICE_NAME}}/ || echo "All placeholders replaced"
```

### Step 9: Create OPSQ Tickets

Create Platform Team tickets for:

**1. ECR Repository**
```
Summary: Create ECR repository for {{SERVICE_NAME}}
Project: OPSQ
Issue Type: Task

Description:
Please create ECR repositories for new service:
- Service: {{SERVICE_NAME}}
- Regions: eu-west-1 [, us-west-2]
- Repository naming: {{SERVICE_NAME}}
- Scan on push: Enabled
- Tag immutability: Enabled

Justification: New service deployment for {{PRODUCT_NAME}}
```

**2. IAM Roles (IRSA)**
```
Summary: Create IRSA roles for {{SERVICE_NAME}}
Project: OPSQ
Issue Type: Task

Description:
Please create IRSA roles for service accounts:
- Service: {{SERVICE_NAME}}
- Environments: dev, stg, live
- Role naming: {{SERVICE_NAME}}-{env}-role
- Cluster OIDC providers: [list clusters]

Required permissions:
- S3: Read/Write to bucket {{BUCKET_NAME}}
- RDS: Connect to {{DB_NAME}}
- [Other AWS services]

Justification: Service requires AWS resource access
```

**3. ACM Certificates** (if new product/domain)
```
Summary: Wildcard ACM certificates for {{PRODUCT_NAME}}
Project: OPSQ
Issue Type: Task

Description:
Request wildcard certificates for:
- Domains: *.{{PRODUCT}}.dev.eks.bmjgroup.com
           *.{{PRODUCT}}.stg.eks.bmjgroup.com
           *.{{PRODUCT}}.live.eks.bmjgroup.com
- Regions: eu-west-1 [, us-west-2]
- DNS validation via Route53

Justification: New product deployment
```

### Step 10: Initial Commit

```bash
# Stage all changes
git add .

# Commit
git commit -m "Initialize {{PRODUCT_NAME}} EKS deployment repository

- Configured {{SERVICE_NAME}}
- Set up dev/stg/live overlays
- Created sealed secrets for all environments
- Configured ArgoCD integration
- OPSQ tickets: OPSQ-XXX, OPSQ-YYY"

# Create main branch and push
git branch -M main
git push -u origin main
```

---

## Common Scenarios

### Single Service, All Environments

Use template as-is, just replace placeholders.

### Multiple Services

```bash
# Copy example-service for each service
cp -r example-service/ service-api/
cp -r example-service/ service-worker/
cp -r example-service/ service-ui/

# Replace placeholders in each
```

### Subset of Environments

If only deploying to dev and stg:

```bash
rm -rf {{SERVICE_NAME}}/overlays/live/
# Update documentation to reflect this
```

### Multi-Region

For services in multiple regions:

**Option 1**: Region-specific overlays
```
overlays/
  dev-euw1/
  dev-usw2/
  stg-euw1/
  stg-usw2/
  live-euw1/
  live-usw2/
```

**Option 2**: Use ApplicationSet with matrix generator

---

## Validation Checklist

Before committing, verify:

- [ ] All `{{PLACEHOLDERS}}` replaced
- [ ] Service name consistent everywhere
- [ ] AWS account IDs correct per environment
- [ ] Sealed secrets created and encrypted
- [ ] Plain secret files deleted
- [ ] `kustomize build` succeeds for all overlays
- [ ] `./verify-configuration.sh` passes
- [ ] No hard-coded credentials
- [ ] Security context configured (non-root)
- [ ] Resource limits defined
- [ ] Labels include team/costcentre/product
- [ ] .gitignore includes secret.yaml and *.pem
- [ ] README updated with product details
- [ ] OPSQ tickets created

---

## Troubleshooting

### Issue: kustomize build fails with "resource not found"

**Cause**: Resource listed in kustomization.yaml but file doesn't exist

**Fix**: Either create the file or remove from resources list

### Issue: Sealed secret won't decrypt

**Cause**: Used wrong cluster certificate

**Fix**: Get correct certificate for target cluster:
```bash
kubeseal --fetch-cert \
  --controller-name=sealed-secrets-controller \
  --controller-namespace=kube-system \
  > correct-cert.pem
```

### Issue: Placeholders remain after replacement

**Cause**: Special characters or incomplete find/replace

**Fix**: Manual search and replace, or use verification script to find them:
```bash
./verify-configuration.sh
```

### Issue: ArgoCD sync fails with permission error

**Cause**: IRSA role not created or incorrect ARN

**Fix**: 
1. Verify OPSQ ticket completed
2. Check role ARN in serviceaccount-patch.yaml
3. Verify role trust policy includes cluster OIDC provider

---

## Related Skills

- [`eks-service-scaffolding`](../../arg-agentic-configuration/.claude/skills/eks-service-scaffolding/SKILL.md) - Service structure patterns
- [`kustomize-overlay-builder`](../../arg-agentic-configuration/.claude/skills/kustomize-overlay-builder/SKILL.md) - Overlay customization
- [`argocd-application-generator`](../../arg-agentic-configuration/.claude/skills/argocd-application-generator/SKILL.md) - GitOps setup
- [`jira-workflow`](../../arg-agentic-configuration/.claude/skills/jira-workflow/SKILL.md) - OPSQ tickets

---

**Last Updated**: 2026-02-11  
**Owner**: Architecture Review Group
