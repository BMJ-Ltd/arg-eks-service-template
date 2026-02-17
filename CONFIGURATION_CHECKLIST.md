# Configuration Checklist

**Purpose**: Step-by-step guide to configure a new EKS deployment repository from this template.

**Target Audience**: Developers creating new service repositories

---

## Pre-Configuration

### Information Gathering

Collect the following information before starting:

- [ ] **Service Name**: Lowercase-with-hyphens (e.g., `knowledge-graph-api`)
- [ ] **Product Name**: For cost tracking (e.g., `Clinical Intelligence`)
- [ ] **Team Name**: Owning team (e.g., `Platform`, `Journals`)
- [ ] **Repository Name**: GitHub repo name (e.g., `clin-intel_eks`)
- [ ] **Environments**: Which environments? (dev/stg/live or subset)
- [ ] **Regions**: Which AWS regions? (eu-west-1, us-west-2)
- [ ] **Service Type**: API, UI, Worker, Database, etc.
- [ ] **Container Port**: Port your app listens on (e.g., 8080)
- [ ] **Resource Requirements**: Memory/CPU per environment
- [ ] **Persistence Needed**: Yes/No (for PVC)
- [ ] **Ingress Needed**: Public, internal, or none
- [ ] **Dependencies**: List external services (databases, APIs, etc.)

---

## Step 1: Repository Creation

### 1.1 Create from Template

**Option A: GitHub UI**
1. Navigate to [arg-eks-service-template](https://github.com/BMJ-Ltd/arg-eks-service-template)
2. Click "Use this template" → "Create a new repository"
3. Name: `{{PRODUCT_NAME}}_eks` (use product, not service name)
4. Description: Brief description of deployment
5. Private repository
6. Create repository

**Option B: Command Line**
```bash
# Clone template
git clone https://github.com/BMJ-Ltd/arg-eks-service-template.git my-product_eks
cd my-product_eks

# Remove template git history
rm -rf .git

# Initialize new repository
git init
git remote add origin git@github.com:BMJ-Ltd/my-product_eks.git
```

- [ ] Repository created
- [ ] Cloned locally

### 1.2 Initial Cleanup

```bash
# Remove template-specific files (if any)
# Update README.md title to reflect your product
```

- [ ] Template references removed
- [ ] README updated with product name

---

## Step 2: Service Structure

### 2.1 Rename Example Service

```bash
# Rename directory
mv example-service/ {{SERVICE_NAME}}/

# Example:
mv example-service/ knowledge-graph-api/
```

- [ ] Service directory renamed

### 2.2 Replace Placeholders

Run find/replace across all files:

```bash
# Service name
find {{SERVICE_NAME}}/ -type f -exec sed -i 's/{{SERVICE_NAME}}/your-service-name/g' {} +

# Product name
find {{SERVICE_NAME}}/ -type f -exec sed -i 's/{{PRODUCT_NAME}}/Your Product Name/g' {} +

# Team name
find {{SERVICE_NAME}}/ -type f -exec sed -i 's/{{TEAM_NAME}}/Your Team/g' {} +

# Repository name
find {{SERVICE_NAME}}/ -type f -exec sed -i 's/{{REPOSITORY_NAME}}/your-product_eks/g' {} +

# Service port
find {{SERVICE_NAME}}/ -type f -exec sed -i 's/{{SERVICE_PORT}}/8080/g' {} +
```

**Or use the automated script**:
```bash
./verify-configuration.sh --configure
```

- [ ] All service placeholders replaced
- [ ] Verified with grep: `grep -r "{{" {{SERVICE_NAME}}/`

---

## Step 3: Environment Configuration

### 3.1 Development (dev)

Update `{{SERVICE_NAME}}/overlays/dev/`:

**env.yaml**:
```yaml
- name: ENVIRONMENT
  value: "dev"
- name: LOG_LEVEL
  value: "DEBUG"
# Add service-specific env vars
```

**serviceaccount-patch.yaml**:
```yaml
annotations:
  eks.amazonaws.com/role-arn: arn:aws:iam::109227185188:role/{{SERVICE_NAME}}-dev-role
```

**ingress-patch.yaml**:
```yaml
host: {{SERVICE_NAME}}.dev.eks.bmjgroup.com
```

- [ ] Dev environment variables set
- [ ] Dev IAM role ARN configured
- [ ] Dev ingress hostname set
- [ ] Dev resource limits appropriate

### 3.2 Staging (stg)

Update `{{SERVICE_NAME}}/overlays/stg/`:

**env.yaml**:
```yaml
- name: ENVIRONMENT
  value: "stg"
- name: LOG_LEVEL
  value: "INFO"
```

**serviceaccount-patch.yaml**:
```yaml
annotations:
  eks.amazonaws.com/role-arn: arn:aws:iam::138832992068:role/{{SERVICE_NAME}}-stg-role
```

- [ ] Stg environment variables set
- [ ] Stg IAM role ARN configured
- [ ] Stg ingress hostname set
- [ ] Stg replica count increased to 2

### 3.3 Production (live)

Update `{{SERVICE_NAME}}/overlays/live/`:

**env.yaml**:
```yaml
- name: ENVIRONMENT
  value: "live"
- name: LOG_LEVEL
  value: "WARN"
```

**serviceaccount-patch.yaml**:
```yaml
annotations:
  eks.amazonaws.com/role-arn: arn:aws:iam::721468132385:role/{{SERVICE_NAME}}-live-role
```

- [ ] Live environment variables set
- [ ] Live IAM role ARN configured
- [ ] Live ingress hostname set
- [ ] Live replica count set to 3+
- [ ] PodDisruptionBudget configured

---

## Step 4: Secrets Management

### 4.1 Get Kubeseal Certificates

```bash
# Dev cluster
kubeseal --fetch-cert \
  --controller-name=sealed-secrets-controller \
  --controller-namespace=kube-system \
  > dev-cert.pem

# Repeat for stg and live
```

- [ ] Kubeseal certificates obtained for all environments

### 4.2 Create Sealed Secrets

**For each environment**:

```bash
# 1. Create plain secret
kubectl create secret generic {{SERVICE_NAME}}-secrets \
  --from-literal=DATABASE_URL="postgresql://..." \
  --from-literal=API_KEY="your-api-key" \
  --dry-run=client -o yaml > secret.yaml

# 2. Seal it
kubeseal --format=yaml \
  --cert=dev-cert.pem \
  < secret.yaml > {{SERVICE_NAME}}/overlays/dev/sealed-secrets.yaml

# 3. Clean up plain secret
rm secret.yaml
```

- [ ] Dev sealed secrets created
- [ ] Stg sealed secrets created
- [ ] Live sealed secrets created
- [ ] Plain secret files deleted (verify with: `find . -name "secret*.yaml"`)

---

## Step 5: Resource Customization

### 5.1 Base Deployment

Update `{{SERVICE_NAME}}/base/deployment.yaml`:

**Health checks** (if applicable):
```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 8080
readinessProbe:
  httpGet:
    path: /ready
    port: 8080
```

**Resource limits** (adjust per environment):
```yaml
resources:
  requests:
    memory: "256Mi"  # Adjust
    cpu: "100m"      # Adjust
  limits:
    memory: "512Mi"  # Adjust
    cpu: "500m"      # Adjust
```

- [ ] Health checks configured (or removed if not applicable)
- [ ] Resource requests/limits set appropriately
- [ ] Image URL updated with correct ECR path
- [ ] Container port matches application

### 5.2 Optional Resources

**If NOT needed, remove from base/kustomization.yaml**:

- [ ] PVC: Remove if no persistent storage needed
- [ ] Instrumentation: Remove if not using OpenTelemetry
- [ ] Ingress: Remove if service is internal-only

---

## Step 6: Certificate Configuration

### 6.1 Get ACM Certificate ARNs

```bash
# Dev
aws acm list-certificates --region eu-west-1 | grep "*.dev.eks.bmjgroup.com"

# Stg
aws acm list-certificates --region eu-west-1 | grep "*.stg.eks.bmjgroup.com"

# Live
aws acm list-certificates --region eu-west-1 | grep "*.live.eks.bmjgroup.com"
```

### 6.2 Update Certificate References

**Option A: Direct annotation** (in ingress-vars.yaml):
```yaml
annotations:
  alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:...
```

**Option B: ConfigMap replacement** (preferred):
Create cluster ConfigMap with certificate ARN and use replacement.yaml

- [ ] Certificate ARNs obtained for all environments
- [ ] Ingress certificate references configured

---

## Step 7: ArgoCD Integration

### 7.1 Create ArgoCD Application

**Option 1: Single environment** (for testing):
```bash
kubectl apply -f {{SERVICE_NAME}}/base/argocd.yaml
```

**Option 2: ApplicationSet** (recommended for multi-env):

Create `applicationset.yaml` in repo root:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: {{SERVICE_NAME}}
  namespace: argocd
spec:
  generators:
    - list:
        elements:
          - env: dev
            cluster: eks-cluster-dev-euw1
          - env: stg
            cluster: eks-cluster-stg-euw1
          - env: live
            cluster: eks-cluster-live-euw1
  template:
    metadata:
      name: '{{SERVICE_NAME}}-{{env}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/BMJ-Ltd/{{REPOSITORY_NAME}}.git
        targetRevision: main
        path: '{{SERVICE_NAME}}/overlays/{{env}}'
      destination:
        name: '{{cluster}}'
        namespace: default
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
```

- [ ] ArgoCD Application/ApplicationSet created
- [ ] Repository URL correct
- [ ] Cluster names match actual EKS clusters
- [ ] Sync policy reviewed and approved

---

## Step 8: Validation

### 8.1 Kustomize Builds

```bash
# Validate each overlay builds without errors
kustomize build {{SERVICE_NAME}}/overlays/dev/
kustomize build {{SERVICE_NAME}}/overlays/stg/
kustomize build {{SERVICE_NAME}}/overlays/live/

# Check for any remaining placeholders
kustomize build {{SERVICE_NAME}}/overlays/dev/ | grep "{{" || echo "No placeholders found"
```

- [ ] Dev overlay builds successfully
- [ ] Stg overlay builds successfully
- [ ] Live overlay builds successfully
- [ ] No `{{PLACEHOLDERS}}` remain in built manifests

### 8.2 Dry-run Apply

```bash
# Requires kubectl access to target clusters
kustomize build {{SERVICE_NAME}}/overlays/dev/ | kubectl apply --dry-run=client -f -
```

- [ ] Dev dry-run succeeds
- [ ] Stg dry-run succeeds
- [ ] Live dry-run succeeds

### 8.3 Run Verification Script

```bash
./verify-configuration.sh
```

Review output and fix any issues.

- [ ] Verification script passes
- [ ] All checks green

---

## Step 9: Documentation

### 9.1 Update Repository README

Update main `README.md` with:
- Product overview
- Services included
- Deployment architecture diagram (optional)
- Prerequisites
- Getting started guide

- [ ] README updated with product-specific info
- [ ] Architecture documented
- [ ] Contact information added

### 9.2 Create Deployment Plans (Optional but Recommended)

Create `DEPLOYMENT_ACTION_PLAN.md` with:
- Step-by-step deployment instructions
- Environment-specific configurations
- Rollback procedures
- Troubleshooting guide

- [ ] Deployment documentation created
- [ ] Rollback procedures documented

---

## Step 10: Prerequisites via OPSQ

### 10.1 Infrastructure Requirements

Create OPSQ tickets for Platform Team:

**Ticket 1: ECR Repositories**
```
Summary: Create ECR repositories for {{PRODUCT_NAME}}
Description:
- Service: {{SERVICE_NAME}}
- Regions: eu-west-1, us-west-2 (as needed)
- Naming: {{SERVICE_NAME}}
```

**Ticket 2: IAM Roles (IRSA)**
```
Summary: Create IRSA roles for {{SERVICE_NAME}}
Description:
- Service: {{SERVICE_NAME}}
- Environments: dev, stg, live
- Permissions needed: [List S3, RDS, etc. access]
- Role naming pattern: {{SERVICE_NAME}}-{env}-role
```

**Ticket 3: ACM Certificates** (if not already exist)
```
Summary: Wildcard ACM certificates for {{PRODUCT_NAME}}
Description:
- Domains: *.dev.eks.bmjgroup.com, *.stg.eks.bmjgroup.com, *.live.eks.bmjgroup.com
- Regions: eu-west-1, us-west-2
```

- [ ] OPSQ tickets created
- [ ] Platform Team acknowledged
- [ ] Infrastructure provisioned

---

## Step 11: Initial Commit

### 11.1 Git Setup

```bash
# Stage all files
git add .

# Commit
git commit -m "Initial repository setup from template

- Configured {{SERVICE_NAME}}
- Set up dev/stg/live overlays
- Created sealed secrets
- Configured ArgoCD integration"

# Push
git push -u origin main
```

- [ ] Initial commit pushed
- [ ] Main branch protected (if applicable)

### 11.2 Create Pull Request (Optional)

If doing initial setup in a branch:

- [ ] PR created
- [ ] Verification checks pass  
- [ ] Reviewed and approved
- [ ] Merged to main

---

## Step 12: Deployment

### 12.1 Deploy to Dev

```bash
# If using ArgoCD CLI
argocd app sync {{SERVICE_NAME}}-dev

# Or via UI
# Navigate to ArgoCD → Applications → {{SERVICE_NAME}}-dev → Sync
```

- [ ] Dev deployment initiated
- [ ] Pods running: `kubectl get pods -l app.kubernetes.io/name={{SERVICE_NAME}}`
- [ ] Service accessible
- [ ] Health checks passing

### 12.2 Validate Dev Deployment

```bash
# Check pod status
kubectl get pods -l app.kubernetes.io/name={{SERVICE_NAME}}

# Check logs
kubectl logs -l app.kubernetes.io/name={{SERVICE_NAME}} --tail=50

# Test endpoint (if ingress configured)
curl https://{{SERVICE_NAME}}.dev.eks.bmjgroup.com/health
```

- [ ] Pods running and healthy
- [ ] No error logs
- [ ] Endpoint responds correctly

### 12.3 Deploy to Stg and Live

Once dev is validated:

- [ ] Stg deployment completed and validated
- [ ] Live deployment completed and validated
- [ ] Multi-region deployment (if applicable)

---

## Post-Configuration

### Ongoing Maintenance

- [ ] Set up monitoring alerts
- [ ] Configure log aggregation
- [ ] Document runbooks
- [ ] Schedule regular review of resource usage
- [ ] Update cost centre tags

---

## Troubleshooting

### Common Issues

**Issue**: `kustomize build` fails with "resource not found"
- **Fix**: Check base/kustomization.yaml resources list

**Issue**: Sealed secret decryption fails
- **Fix**: Verify using correct cluster certificate

**Issue**: ArgoCD sync fails with permission error
- **Fix**: Check IRSA role has been created and ARN is correct

**Issue**: Ingress not routing traffic
- **Fix**: Verify certificate ARN, verify ALB created, check security groups

---

## Checklist Summary

### Must Complete

- [ ] All {{PLACEHOLDERS}} replaced
- [ ] Sealed secrets created for all environments
- [ ] Kustomize builds succeed
- [ ] verify-configuration.sh passes
- [ ] OPSQ tickets created and resolved
- [ ] IAM roles configured correctly
- [ ] Initial commit pushed

### Recommended

- [ ] Deployment documentation created
- [ ] Health checks configured
- [ ] Resource limits tuned
- [ ] ArgoCD ApplicationSet created
- [ ] Dev deployment validated

### Optional

- [ ] Multi-region configuration
- [ ] Custom namespaces
- [ ] HPA configuration
- [ ] Network policies
- [ ] Service mesh integration

---

**Template Version**: 1.0.0  
**Last Updated**: 2026-02-11  
**Owner**: Architecture Review Group
