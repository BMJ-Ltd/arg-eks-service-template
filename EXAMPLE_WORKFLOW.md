# Practical Example: Creating a Multi-Service Product

## Scenario

You're creating the "Clinical Intelligence Knowledge Graph" product with 4 services:
- knowledge-graph-api (REST API)
- knowledge-graph-builder (Background worker)
- knowledge-graph-ui (Web UI)
- allegrograph-db (Database)

---

## Step-by-Step Workflow

### Step 1: Create Product Repository

```bash
# Create from template on GitHub UI
# Repository name: clin-intel-knowledge-graph_eks
# Description: Kubernetes deployments for Clinical Intelligence Knowledge Graph

# Clone it
git clone git@github.com:BMJ-Ltd/clin-intel-knowledge-graph_eks.git
cd clin-intel-knowledge-graph_eks
```

---

### Step 2: Create Service Directories

```bash
# Copy template for each service
cp -r example-service/ knowledge-graph-api/
cp -r example-service/ knowledge-graph-builder/
cp -r example-service/ knowledge-graph-ui/
cp -r example-service/ allegrograph-db/

# Remove template
rm -rf example-service/
```

**Result:**
```
clin-intel-knowledge-graph_eks/
├── knowledge-graph-api/
├── knowledge-graph-builder/
├── knowledge-graph-ui/
├── allegrograph-db/
├── README.md
├── AGENTS.MD
├── CONFIGURATION_CHECKLIST.md
├── CRITICAL_ACTIONS.md
└── verify-configuration.sh
```

---

### Step 3: Configure Each Service

**For knowledge-graph-api:**

```bash
cd knowledge-graph-api/

# Replace placeholders
find . -type f -exec sed -i 's/{{SERVICE_NAME}}/knowledge-graph-api/g' {} +
find . -type f -exec sed -i 's/{{PRODUCT_NAME}}/Clinical Intelligence/g' {} +
find . -type f -exec sed -i 's/{{TEAM_NAME}}/Platform/g' {} +
find . -type f -exec sed -i 's/{{REPOSITORY_NAME}}/clin-intel-knowledge-graph_eks/g' {} +
find . -type f -exec sed -i 's/{{SERVICE_PORT}}/8080/g' {} +
find . -type f -exec sed -i 's/{{MEMORY_REQUEST}}/512Mi/g' {} +
find . -type f -exec sed -i 's/{{MEMORY_LIMIT}}/1Gi/g' {} +
find . -type f -exec sed -i 's/{{CPU_REQUEST}}/250m/g' {} +
find . -type f -exec sed -i 's/{{CPU_LIMIT}}/1000m/g' {} +

# Update environment variables in overlays/dev/env.yaml
cat > overlays/dev/env.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: knowledge-graph-api
spec:
  template:
    spec:
      containers:
        - name: app
          env:
            - name: ENVIRONMENT
              value: "dev"
            - name: LOG_LEVEL
              value: "DEBUG"
            - name: AWS_REGION
              value: "eu-west-1"
            - name: OPENSEARCH_ENDPOINT
              value: "https://search.clin-intel-dev.opensearch.aws.bmjgroup.com"
            - name: DATABASE_HOST
              value: "clin-intel-kg-dev.cluster.rds.amazonaws.com"
EOF

cd ..
```

**For knowledge-graph-builder:**

```bash
cd knowledge-graph-builder/

# Replace placeholders (service-specific values differ)
find . -type f -exec sed -i 's/{{SERVICE_NAME}}/knowledge-graph-builder/g' {} +
find . -type f -exec sed -i 's/{{PRODUCT_NAME}}/Clinical Intelligence/g' {} +  # Same product
find . -type f -exec sed -i 's/{{TEAM_NAME}}/Platform/g' {} +                 # Same team
find . -type f -exec sed -i 's/{{SERVICE_PORT}}/3000/g' {} +                   # Different port
find . -type f -exec sed -i 's/{{MEMORY_REQUEST}}/1Gi/g' {} +                  # More memory
find . -type f -exec sed -i 's/{{MEMORY_LIMIT}}/2Gi/g' {} +

# Different environment variables
cat > overlays/dev/env.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: knowledge-graph-builder
spec:
  template:
    spec:
      containers:
        - name: app
          env:
            - name: ENVIRONMENT
              value: "dev"
            - name: LOG_LEVEL
              value: "DEBUG"
            - name: WORKER_CONCURRENCY
              value: "4"
            - name: ALLEGROGRAPH_ENDPOINT
              value: "http://allegrograph-db:10035"
EOF

# Remove ingress (worker doesn't need external access)
rm base/ingress.yaml
# Update base/kustomization.yaml to remove ingress from resources

cd ..
```

**For knowledge-graph-ui:**

```bash
cd knowledge-graph-ui/

# Replace placeholders
find . -type f -exec sed -i 's/{{SERVICE_NAME}}/knowledge-graph-ui/g' {} +
find . -type f -exec sed -i 's/{{PRODUCT_NAME}}/Clinical Intelligence/g' {} +
find . -type f -exec sed -i 's/{{TEAM_NAME}}/Platform/g' {} +
find . -type f -exec sed -i 's/{{SERVICE_PORT}}/3000/g' {} +

# Configure ingress for public access
cat > overlays/dev/ingress-patch.yaml <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: knowledge-graph-ui
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing  # Public!
spec:
  rules:
    - host: knowledge-graph.dev.bmjgroup.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: knowledge-graph-ui
                port:
                  number: 80
EOF

cd ..
```

**For allegrograph-db:**

```bash
cd allegrograph-db

# Replace placeholders
find . -type f -exec sed -i 's/{{SERVICE_NAME}}/allegrograph-db/g' {} +
find . -type f -exec sed -i 's/{{PRODUCT_NAME}}/Clinical Intelligence/g' {} +
find . -type f -exec sed -i 's/{{TEAM_NAME}}/Platform/g' {} +
find . -type f -exec sed -i 's/{{SERVICE_PORT}}/10035/g' {} +
find . -type f -exec sed -i 's/{{STORAGE_SIZE}}/100Gi/g' {} +  # Database needs more storage

# Enable persistence
# (PVC already in template, just verify it's in kustomization.yaml)

# Remove ingress (internal database only)
rm base/ingress.yaml

cd ..
```

---

### Step 4: Create Sealed Secrets (Per Service)

**For knowledge-graph-api:**

```bash
# Get cluster certificate
kubeseal --fetch-cert \
  --controller-name=sealed-secrets-controller \
  --controller-namespace=kube-system \
  > dev-cert.pem

# Create secrets
kubectl create secret generic knowledge-graph-api-secrets \
  --from-literal=DATABASE_URL="postgresql://user:pass@host/db" \
  --from-literal=OPENSEARCH_PASSWORD="secret123" \
  --from-literal=API_KEY="api-key-here" \
  --dry-run=client -o yaml > secret.yaml

# Seal it
kubeseal --format=yaml \
  --cert=dev-cert.pem \
  < secret.yaml > knowledge-graph-api/overlays/dev/sealed-secrets.yaml

# Clean up
rm secret.yaml dev-cert.pem
```

**Repeat for each service** (knowledge-graph-builder, knowledge-graph-ui, allegrograph-db)

---

### Step 5: Create IAM Roles via OPSQ

Create **separate IAM roles** for each service:

```
Ticket 1: IAM Role for knowledge-graph-api
- Role name: knowledge-graph-api-dev-role
- Permissions: RDS, OpenSearch, S3 read/write

Ticket 2: IAM Role for knowledge-graph-builder  
- Role name: knowledge-graph-builder-dev-role
- Permissions: AllegroGraph, S3, SQS

Ticket 3: IAM Role for knowledge-graph-ui
- Role name: knowledge-graph-ui-dev-role
- Permissions: None (just needs to call API)

Ticket 4: IAM Role for allegrograph-db
- Role name: allegrograph-db-dev-role
- Permissions: S3 for backups
```

---

### Step 6: Validate Each Service

```bash
# Validate all services
for service in knowledge-graph-api knowledge-graph-builder knowledge-graph-ui allegrograph-db; do
  echo "Validating $service..."
  kustomize build $service/overlays/dev/ > /dev/null && echo "✓ $service" || echo "✗ $service FAILED"
done

# Run verification script
./verify-configuration.sh
```

---

### Step 7: Update Product README

```bash
cat > README.md <<'EOF'
# Clinical Intelligence Knowledge Graph - EKS Deployments

Kubernetes deployment manifests for the Clinical Intelligence Knowledge Graph platform.

## Services

- **knowledge-graph-api** - REST API for knowledge graph queries
- **knowledge-graph-builder** - Background worker for graph construction
- **knowledge-graph-ui** - Web interface for graph visualization
- **allegrograph-db** - AllegroGraph triple store database

## Architecture

[Add diagram]

## Deployment

Services are deployed via ArgoCD:
- Dev: https://argo.dev.eks.bmjgroup.com
- Stg: https://argo.stg.eks.bmjgroup.com
- Live: https://argo.live.eks.bmjgroup.com

## Contact

- Team: Platform
- Slack: #clinical-intelligence
- Product Owner: John Smith
EOF
```

---

### Step 8: Commit and Deploy

```bash
# Initial commit
git add .
git commit -m "Initialize Clinical Intelligence Knowledge Graph deployments

Services:
- knowledge-graph-api (REST API)
- knowledge-graph-builder (Worker)
- knowledge-graph-ui (Web UI)
- allegrograph-db (Database)

Environments: dev, stg, live
OPSQ Tickets: OPSQ-1234, OPSQ-1235, OPSQ-1236"

# Push
git push origin main
```

---

### Step 9: Deploy via ArgoCD

**Option A: Individual Applications** (one per service):

```bash
# Deploy each service separately
kubectl apply -f knowledge-graph-api/base/argocd.yaml
kubectl apply -f knowledge-graph-builder/base/argocd.yaml
kubectl apply -f knowledge-graph-ui/base/argocd.yaml
kubectl apply -f allegrograph-db/base/argocd.yaml
```

**Option B: ApplicationSet** (all services, all environments):

Create `applicationset.yaml` in repo root:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: clinical-intelligence-kg
  namespace: argocd
spec:
  generators:
    - matrix:
        generators:
          - list:
              elements:
                - service: knowledge-graph-api
                - service: knowledge-graph-builder
                - service: knowledge-graph-ui
                - service: allegrograph-db
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
      name: '{{service}}-{{env}}'
      labels:
        product: clinical-intelligence
        service: '{{service}}'
        environment: '{{env}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/BMJ-Ltd/clin-intel-knowledge-graph_eks.git
        targetRevision: main
        path: '{{service}}/overlays/{{env}}'
      destination:
        name: '{{cluster}}'
        namespace: default
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
```

```bash
kubectl apply -f applicationset.yaml
```

This creates 12 ArgoCD applications (4 services × 3 environments).

---

## Final Structure

```
clin-intel-knowledge-graph_eks/
├── knowledge-graph-api/
│   ├── base/
│   │   ├── deployment.yaml       (port 8080, 512Mi/1Gi)
│   │   ├── service.yaml
│   │   ├── serviceaccount.yaml   (role: knowledge-graph-api-dev-role)
│   │   └── ingress.yaml          (internal)
│   └── overlays/
│       ├── dev/
│       │   ├── env.yaml          (OpenSearch, RDS configs)
│       │   └── sealed-secrets.yaml
│       ├── stg/
│       └── live/
├── knowledge-graph-builder/
│   ├── base/
│   │   ├── deployment.yaml       (port 3000, 1Gi/2Gi, no ingress)
│   │   ├── service.yaml
│   │   └── serviceaccount.yaml   (role: knowledge-graph-builder-dev-role)
│   └── overlays/
│       ├── dev/
│       │   ├── env.yaml          (Worker configs, AllegroGraph)
│       │   └── sealed-secrets.yaml
│       ├── stg/
│       └── live/
├── knowledge-graph-ui/
│   ├── base/
│   │   ├── deployment.yaml       (port 3000)
│   │   ├── service.yaml
│   │   ├── serviceaccount.yaml   (role: knowledge-graph-ui-dev-role)
│   │   └── ingress.yaml          (PUBLIC!)
│   └── overlays/
│       ├── dev/
│       │   └── ingress-patch.yaml (knowledge-graph.dev.bmjgroup.com)
│       ├── stg/
│       └── live/
├── allegrograph-db/
│   ├── base/
│   │   ├── deployment.yaml       (port 10035)
│   │   ├── service.yaml
│   │   ├── serviceaccount.yaml   (role: allegrograph-db-dev-role)
│   │   └── pvc.yaml              (100Gi)
│   └── overlays/
│       ├── dev/
│       ├── stg/
│       └── live/
├── applicationset.yaml           (Deploys all services to all envs)
├── README.md                     (Product overview)
└── AGENTS.MD                     (AI agent context)
```

---

## Key Takeaways

1. **One repository = One product** (clin-intel-knowledge-graph_eks)
2. **Multiple services** within product (4 in this case)
3. **Each service is independent**:
   - Own manifests
   - Own secrets
   - Own IAM roles
   - Own resource requirements
4. **Shared attributes**:
   - Product name: "Clinical Intelligence"
   - Team: "Platform"
   - Cost centre: "Clinical Intelligence"
5. **ApplicationSet deploys all services** across all environments from single manifest

This matches the pattern you see in production at BMJ.
