# EKS Repository Comparison Analysis

**Date**: 2026-02-17  
**Repositories Analyzed**:
- `gha-java_eks` (gha-java-app_eks)
- `clin-intel-knowledge-graph_eks`
- `learning_eks`

**Template Reference**: `arg-eks-service-template`

---

## Executive Summary

All three repositories follow the **Kustomize base/overlays** pattern with ArgoCD integration, but there are **significant inconsistencies** that should be addressed in a standardized template. The most mature implementation appears to be `direct-analysis_eks` (which uses the template), followed by `clin-intel-knowledge-graph_eks`.

---

## Key Similarities ✅

### 1. **Repository Structure Pattern**
All repos follow the service-based structure:
```
<product>_eks/
├── <service-name>/
│   ├── base/
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── serviceaccount.yaml
│   │   ├── ingress.yaml
│   │   ├── instrumentation.yaml
│   │   └── kustomization.yaml
│   └── overlays/
│       ├── dev/
│       ├── stg/  (or pr/)
│       └── live/
```

### 2. **Base Manifests**
All repos include similar base resources:
- ✅ Deployment
- ✅ Service
- ✅ ServiceAccount  
- ✅ Ingress
- ✅ Instrumentation (OpenTelemetry)
- ✅ Kustomization

### 3. **Overlay Pattern**
All use Kustomize patches for environment-specific customization:
- `args.yaml` - Container args patches
- `env.yaml` - Environment variable patches
- `ingress-patch.yaml` - Ingress annotations/hosts
- `ingress-vars.yaml` - Ingress variable replacements
- `service-patch.yaml` - Service type/annotations
- `replacement.yaml` - Kustomize replacements
- `kustomization.yaml` - Main overlay configuration

### 4. **ArgoCD Integration**
- All use ApplicationSet for PR previews
- Pull Request generator pattern
- Dynamic namespace creation per PR
- Automated sync policies

---

## Major Differences ⚠️

### 1. **Environment Naming**

| Repository | Environments |
|------------|-------------|
| `gha-java_eks` | **dev**, **pr**, **live** |
| `clin-intel-knowledge-graph_eks` | **dev**, **stg**, **live** |
| `learning_eks` | **dev**, **stg**, **live** |
| `direct-analysis_eks` (template) | **dev**, **stg**, **live** |

**Issue**: `gha-java_eks` uses `pr` instead of `stg`, breaking consistency.

**Recommendation**: Standardize on **dev**, **stg**, **live** with separate PR preview ApplicationSets.

---

### 2. **ApplicationSet Location**

| Repository | ApplicationSet Location | Notes |
|------------|------------------------|-------|
| `gha-java_eks` | **Root-level** `application-set.yaml` | ❌ Only PR previews |
| `clin-intel-knowledge-graph_eks` | **Per-overlay** `application-set.yaml` | ❌ Duplicated across services |
| `learning_eks` | **Per-overlay** `application-set.yaml` | ❌ Duplicated across services |
| `direct-analysis_eks` | **Root-level** `applicationset.yaml` | ✅ Single ApplicationSet for all services/envs |

**Best Practice**: `direct-analysis_eks` uses a **matrix generator** to deploy all services across all environments from a single ApplicationSet:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: direct-analysis
spec:
  generators:
    - matrix:
        generators:
          - list:
              elements:
                - service: direct-analysis-api
                - service: direct-analysis-web
          - list:
              elements:
                - env: dev
                  cluster: eks-cluster-dev-euw1
                  account: "109227185188"
                - env: stg
                  cluster: eks-cluster-stg-euw1
                  account: "138832992068"
```

**Recommendation**: Template should provide **both**:
1. Root-level ApplicationSet (matrix generator) for multi-service products
2. Per-service ApplicationSet pattern for single-service repos

---

### 3. **Sealed Secrets Usage**

| Repository | Sealed Secrets Pattern |
|------------|----------------------|
| `gha-java_eks` | ❌ **Not used** |
| `clin-intel-knowledge-graph_eks` | ✅ Used in all overlays |
| `learning_eks` | ⚠️ **Inconsistent** (some services have them) |
| `direct-analysis_eks` | ✅ Used in all overlays |

**Finding**: `gha-java_eks` has **NO sealed secrets**, meaning secrets are likely:
- Hard-coded in deployments (security risk)
- Manually created in cluster (drift risk)
- Not version-controlled (auditability issue)

**Recommendation**: Template **MUST** include sealed secrets as a required component with clear documentation.

---

### 4. **Persistent Volume Claims (PVC)**

| Repository | Services with PVCs | Pattern |
|------------|-------------------|---------|
| `gha-java_eks` | `gha-java-app` (has `pvc.yaml`) | ✅ Base resource |
| `clin-intel-knowledge-graph_eks` | `knowledge-graph-api` | ✅ Base resource + volume mounts |
| `learning_eks` | ❌ **None visible** | N/A |

**Finding**: Not all services need storage, but the pattern should be standardized when they do.

**Recommendation**: Template should include **optional** PVC with clear guidance on when to use.

---

### 5. **Security Context Configuration**

| Repository | Security Context |
|------------|-----------------|
| `gha-java_eks` | ✅ `runAsUser: 1001`, `runAsGroup: 1001` |
| `clin-intel-knowledge-graph_eks` | ✅ `runAsUser: 1001`, `runAsGroup: 1001`, `runAsNonRoot: true`, `fsGroup: 1001` |
| `learning_eks` | ❌ **Not set** |

**Finding**: `learning_eks` deployments run as **root** by default (security risk).

**Recommendation**: Template **MUST** enforce non-root security context as default:
```yaml
securityContext:
  runAsUser: 1001
  runAsGroup: 1001
  runAsNonRoot: true
  fsGroup: 1001  # Only if PVC needed
```

---

### 6. **Health Check Configuration**

| Repository | Liveness/Readiness Probes |
|------------|--------------------------|
| `gha-java_eks` | ✅ Both configured (`/actuator/health`) |
| `clin-intel-knowledge-graph_eks` | ✅ Both configured (custom paths) |
| `learning_eks` | ⚠️ **Inconsistent** (some use `/`, others custom) |

**Recommendation**: Template should include **both** probes with placeholders for paths:
```yaml
livenessProbe:
  httpGet:
    path: {{LIVENESS_PATH}}
    port: {{SERVICE_PORT}}
  initialDelaySeconds: 60
readinessProbe:
  httpGet:
    path: {{READINESS_PATH}}
    port: {{SERVICE_PORT}}
  initialDelaySeconds: 30
```

---

### 7. **Resource Limits**

| Repository | Resource Configuration |
|------------|----------------------|
| `gha-java_eks` | ✅ Requests + Limits defined |
| `clin-intel-knowledge-graph_eks` | ✅ Requests + Limits defined (high for data processing) |
| `learning_eks` | ⚠️ **Varies by service** |

**Recommendation**: Template should include **sensible defaults** with environment-specific overrides:
```yaml
resources:
  requests:
    memory: {{MEMORY_REQUEST}}  # e.g., 256Mi
    cpu: {{CPU_REQUEST}}         # e.g., 100m
  limits:
    memory: {{MEMORY_LIMIT}}     # e.g., 512Mi
    cpu: {{CPU_LIMIT}}           # e.g., 500m
```

---

### 8. **IRSA (IAM Roles for Service Accounts)**

| Repository | IRSA Usage |
|------------|-----------|
| `gha-java_eks` | ❌ **Not visible** |
| `clin-intel-knowledge-graph_eks` | ✅ Used (`serviceaccount-patch.yaml`) |
| `learning_eks` | ✅ Used (`serviceaccount-patch.yaml`) |

**Recommendation**: Template should include `serviceaccount-patch.yaml` pattern:
```yaml
- op: add
  path: /metadata/annotations/eks.amazonaws.com~1role-arn
  value: arn:aws:iam::{{AWS_ACCOUNT_ID}}:role/{{SERVICE_NAME}}-role
```

---

### 9. **OpenTelemetry Instrumentation**

| Repository | OTel Annotation |
|------------|----------------|
| `gha-java_eks` | ✅ `instrumentation.opentelemetry.io/inject-java: "true"` |
| `clin-intel-knowledge-graph_eks` | ⚠️ **Commented out** in some services |
| `learning_eks` | ⚠️ **Commented out** in most services |

**Recommendation**: Template should include instrumentation as **optional** via overlay patches:
```yaml
# overlays/dev/enable-otel.yaml
- op: add
  path: /spec/template/metadata/annotations/instrumentation.opentelemetry.io~1inject-java
  value: "true"
```

---

### 10. **Documentation Quality**

| Repository | Documentation |
|------------|--------------|
| `gha-java_eks` | ❌ **Minimal** (single line README) |
| `clin-intel-knowledge-graph_eks` | ⚠️ **Basic** (deployment plans in separate files) |
| `learning_eks` | ⚠️ **Minimal** (notes about configuration needs) |
| `direct-analysis_eks` | ✅ **Comprehensive** (uses template structure) |

**Finding**: Only repos using the template have proper documentation.

**Recommendation**: Template documentation is excellent - ensure it's maintained.

---

## Glaring Issues Found 🚨

### 1. **No Standardized Secret Management** (Critical)
- `gha-java_eks` has **no sealed secrets**
- Risk of plain-text secrets in deployments
- No audit trail for sensitive configuration

### 2. **Inconsistent Environment Names**
- `gha-java_eks` uses `pr` instead of `stg`
- Makes cross-repo tooling difficult
- Confuses developers

### 3. **Missing Security Contexts**
- `learning_eks` services run as **root**
- Violates least privilege principle
- Security compliance issue

### 4. **Duplicated ApplicationSets**
- Each service/overlay has its own ApplicationSet
- Creates maintenance burden
- Harder to understand deployment topology

### 5. **No Validation Scripts**
- Only template repos have `verify-configuration.sh`
- Increases risk of misconfiguration
- No automated checks before deployment

### 6. **Inconsistent Labeling**
- Some use `app.kubernetes.io/name`, others use `app`
- Mix of `commonLabels` and `labels` in kustomization
- Makes querying resources harder

### 7. **Missing Critical Documentation**
- No `CRITICAL_ACTIONS.md` in production repos
- No `CONFIGURATION_CHECKLIST.md`
- Tribal knowledge risk

---

## Template Recommendations 📋

### Must-Have Features

1. **Dual ApplicationSet Pattern**
   - Root-level matrix generator for multi-service products
   - Per-service fallback for single-service repos
   - Clear documentation on when to use each

2. **Mandatory Sealed Secrets**
   - Include sealed-secrets.yaml in all overlays
   - Provide sealing script/documentation
   - Never allow plain-text secrets

3. **Security by Default**
   - Non-root security context (runAsUser: 1001)
   - runAsNonRoot: true enforced
   - fsGroup for PVC users

4. **Standardized Environment Names**
   - dev, stg, live (no exceptions)
   - Separate PR preview ApplicationSets
   - Clear region/account mapping

5. **Complete Base Resources**
   - deployment.yaml (security context, health checks, resources)
   - service.yaml
   - serviceaccount.yaml (with IRSA placeholder)
   - ingress.yaml (with ALB annotations)
   - instrumentation.yaml (OTel support)
   - pvc.yaml (optional, clearly marked)
   - kustomization.yaml

6. **Comprehensive Overlay Patches**
   - args.yaml
   - env.yaml
   - ingress-patch.yaml
   - ingress-vars.yaml
   - service-patch.yaml
   - serviceaccount-patch.yaml (IRSA)
   - sealed-secrets.yaml
   - replacement.yaml
   - enable-otel.yaml (optional)
   - kustomization.yaml

7. **Validation Tooling**
   - verify-configuration.sh script
   - Check for remaining placeholders
   - Validate kustomize builds
   - Check sealed secrets exist

8. **Documentation Suite**
   - README.md (product overview)
   - AGENTS.MD (AI agent guidance)
   - CONFIGURATION_CHECKLIST.md
   - CRITICAL_ACTIONS.md
   - DEPLOYMENT_SUMMARY.md (post-setup)

### Nice-to-Have Features

- ServiceMonitor for Prometheus
- HorizontalPodAutoscaler templates
- PodDisruptionBudget for production
- NetworkPolicy templates
- ConfigMap/Secret templates for non-sensitive config

---

## Migration Path for Existing Repos

### Option A: Full Migration (Recommended)
1. Create new repo from template
2. Copy service configurations
3. Replace all placeholders
4. Validate with verify-configuration.sh
5. Create sealed secrets
6. Test in dev
7. Switch ArgoCD to new repo

### Option B: Incremental Updates
1. Add missing security contexts
2. Standardize environment names
3. Add sealed secrets
4. Consolidate ApplicationSets
5. Add documentation
6. Add validation scripts

---

## Comparison Matrix

| Feature | gha-java | clin-intel | learning | template |
|---------|----------|------------|----------|----------|
| **Base/Overlays Pattern** | ✅ | ✅ | ✅ | ✅ |
| **Security Context** | ✅ | ✅ | ❌ | ✅ |
| **Sealed Secrets** | ❌ | ✅ | ⚠️ | ✅ |
| **IRSA Support** | ❌ | ✅ | ✅ | ✅ |
| **Health Checks** | ✅ | ✅ | ⚠️ | ✅ |
| **Resource Limits** | ✅ | ✅ | ⚠️ | ✅ |
| **OTel Instrumentation** | ✅ | ⚠️ | ⚠️ | ✅ |
| **Matrix ApplicationSet** | ❌ | ❌ | ❌ | ✅ |
| **Documentation** | ❌ | ⚠️ | ❌ | ✅ |
| **Validation Scripts** | ❌ | ❌ | ❌ | ✅ |
| **Standard Environments** | ❌ | ✅ | ✅ | ✅ |

---

## Conclusion

The **arg-eks-service-template** and **direct-analysis_eks** represent the **gold standard** for EKS deployment repos. The main improvements needed for existing repos are:

### Critical (Fix Immediately)
1. Add sealed secrets to `gha-java_eks`
2. Add security contexts to `learning_eks`
3. Standardize environment names

### High Priority
4. Consolidate to matrix ApplicationSets
5. Add validation scripts
6. Add comprehensive documentation

### Medium Priority
7. Standardize labeling patterns
8. Add ServiceMonitor support
9. Improve health check consistency

The template is **production-ready** and should be the baseline for all new EKS repos. Existing repos should be migrated incrementally or fully depending on team capacity.

---

**Next Steps**:
1. Review this comparison with Platform Team
2. Prioritize migration of critical gaps
3. Update template with any learnings from production repos
4. Create migration runbooks for each existing repo
5. Schedule migration windows

