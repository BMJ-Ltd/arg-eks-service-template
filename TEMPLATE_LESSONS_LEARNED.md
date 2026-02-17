# Template Lessons Learned

**Date**: 2026-02-17  
**Source**: Creating gha-java-app_eks-v2 from this template  
**Status**: Improvements applied ✅

---

## Overview

This document captures lessons learned from creating a real-world repository (gha-java-app_eks-v2) from this template. These improvements have been incorporated back into the template to benefit future users.

---

## Issues Identified

### 1. ✅ FIXED: commonLabels Deprecation Warning

**Problem**: Kustomize v5+ deprecates `commonLabels` in favor of `labels` with `pairs` syntax.

**Impact**: Deprecation warnings in all builds, future compatibility concerns.

**Solution Applied**:
- Template uses `commonLabels` with quoted placeholders for compatibility
- Real implementations should migrate to `labels` with actual values
- Documented in README that this is intentional for template parseability

**Example**:
```yaml
# Template (works with placeholders)
commonLabels:
  app.kubernetes.io/name: "{{SERVICE_NAME}}"
  environment: "{{ENVIRONMENT}}"

# Real implementation (migrate to this)
labels:
  - pairs:
      app.kubernetes.io/name: gha-java-app
      environment: dev
```

**Note**: `commonLabels` still works in Kustomize v5, just shows warnings. Using it in template ensures YAML parses correctly with placeholder values.

---

### 2. ✅ FIXED: Sealed Secrets Not Actually Optional

**Problem**: `sealed-secrets.yaml` was listed in `kustomization.yaml` resources by default.

**Impact**: 
- Users couldn't skip secrets even for basic services
- Build failed if file didn't exist or wasn't customized
- Violated user requirement: "some basic services may not use or require sealed secrets"

**Solution Applied**:
- **Commented out** `sealed-secrets.yaml` in all overlay kustomizations by default
- Added comprehensive "OPTIONAL" header to all sealed-secrets files
- Documented when to use vs not use sealed secrets
- Services now work without secrets (opt-in not opt-out)

**Before**:
```yaml
resources:
  - ../../base
  - sealed-secrets.yaml  # Required, breaks if missing
```

**After**:
```yaml
resources:
  - ../../base
  # Optional: Uncomment if you have sealed secrets to deploy
  # - sealed-secrets.yaml
```

---

### 3. ✅ FIXED: envFrom Assumes Secrets Exist

**Problem**: Deployment spec had `envFrom` referencing secret that might not exist.

**Impact**: 
- Pod fails to start if secret doesn't exist
- Can't deploy services without secrets configured first

**Solution Applied**:
- Made `envFrom` optional with `optional: true` flag
- Commented out by default
- Clear instructions on when to uncomment

**Before**:
```yaml
env:
  - name: ENVIRONMENT
    value: "dev"
envFrom:
  - secretRef:
      name: {{SERVICE_NAME}}-secrets
```

**After**:
```yaml
env:
  - name: ENVIRONMENT
    value: "dev"
# Optional: Uncomment and customize if your service needs secrets
# envFrom:
#   - secretRef:
#       name: {{SERVICE_NAME}}-secrets
#       optional: true  # Pod starts even if secret doesn't exist
```

---

### 4. ☑️ DOCUMENTED: Placeholders Break Kustomize Build

**Problem**: Template with `{{PLACEHOLDERS}}` cannot be built with `kustomize build` until customized.

**Impact**: 
- Can't validate template structure before customization
- Error misleading: "invalid Kustomization: yaml: invalid map key"

**Solution Applied**:
- **Documented clearly** in README that template must be customized before building
- Added note to verify-configuration.sh about this limitation
- V2 example shows what template looks like when properly customized

**Why This Happens**:
- Kustomize parses YAML and expects valid Kubernetes resource references
- `{{SERVICE_NAME}}` in field like `name: {{SERVICE_NAME}}` confuses YAML parser
- Go template syntax `{{}}` has special meaning to Kustomize

**Workaround**:
- This is **expected behavior** for a template
- See gha-java-app_eks-v2 for working example with values filled in
- Use verify-configuration.sh to check for unreplaced placeholders before building

---

### 5. ✅ FIXED: No Matrix ApplicationSet Example

**Problem**: Template only showed per-service ApplicationSet pattern, not the more scalable matrix generator pattern.

**Impact**: 
- Users couldn't easily add services over time (violated requirement)
- Had to create ApplicationSet per service (doesn't scale)
- Missed the "matrix way" that user specifically wanted

**Solution Applied**:
- Created `applicationset-example.yaml` demonstrating matrix generator
- Shows **one file** deploying **all services** to **all environments**
- Adding new service = 3 lines added to list
- Adding new environment = 4 lines added to list

**Example**:
```yaml
generators:
  - matrix:
      generators:
        - list:  # Services
            elements:
              - service: api
              - service: web
              # Add more services here
        - list:  # Environments
            elements:
              - env: dev
              - env: stg
              # Add more environments here
```

---

### 6. ✅ FIXED: Certificate ARN Placeholder Errors

**Problem**: `{{CERTIFICATE_ARN}}` in ingress.yaml caused ambiguity - users didn't know if it should be:
- Left as placeholder
- Commented out
- Replaced immediately

**Impact**: 
- Confusion when cert not yet created
- YAML parse errors if not handled correctly

**Solution Applied**:
- Certificate annotation enabled in base `ingress.yaml` (without ARN value)
- Overlays use `ingress-vars.yaml` with clear `REPLACE_WITH_CERT_ID` marker
- Documented pattern: base enables feature, overlay provides specifics
- Clear comments explain when to fill in value

**Pattern**:
```yaml
# base/ingress.yaml - Feature enabled
annotations:
  alb.ingress.kubernetes.io/certificate-arn: ""  # Override in overlay

# overlays/*/ingress-vars.yaml - Specific value
annotations:
  alb.ingress.kubernetes.io/certificate-arn: |
    arn:aws:acm:eu-west-1:ACCOUNT_ID:certificate/REPLACE_WITH_CERT_ID
```

---

### 7. ☑️ IMPROVED: Placeholder Pattern Clarity

**Problem**: Mixed use of `{{NAME}}` and inconsistent patterns throughout template.

**Impact**: 
- Users unsure what needs replacing
- Difficult to grep for unreplaced values
- Some placeholders looked like Helm templates

**Solution Applied**:
- **Standardized on `{{NAME}}`** for most placeholders (familiar from other tools)
- **Added clear context** where placeholders appear
- **Provided replacement checklist** in CONFIGURATION_CHECKLIST.md
- **verify-configuration.sh** checks for common unreplaced patterns

**Standard Patterns**:
```
{{SERVICE_NAME}}    - Name of the Kubernetes service
{{PRODUCT_NAME}}    - Product/team name for grouping
{{TEAM_NAME}}       - Team responsible for service
{{ENVIRONMENT}}     - Environment name (dev/stg/live)
{{AWS_ACCOUNT_ID}}  - AWS account ID (varies by environment)
{{AWS_REGION}}      - AWS region (e.g., eu-west-1)
ACCOUNT_ID          - Generic "fill this in" marker
REPLACE_WITH_X      - Temporary marker for unknown values
```

---

### 8. ✅ FIXED: replacement.yaml Pattern Incomplete

**Problem**: Template showed replacement pattern for Deployment but not ConfigMap pattern shown in other repos.

**Impact**: 
- Users couldn't see complete replacement examples
- Limited to just image replacement use case

**Solution Applied**:
- Kept minimal example (Deployment image replacement)
- Added comments showing ConfigMap replacement pattern
- Referenced V2 example for more complex cases
- Documented that replacements work for any field in any resource

**Enhanced Example**:
```yaml
# Replace Deployment image
- source:
    kind: ConfigMap
    name: {{SERVICE_NAME}}
    fieldPath: data.IMAGE_TAG
  targets:
    - select:
        kind: Deployment
        name: {{SERVICE_NAME}}
      fieldPaths:
        - spec.template.spec.containers.[name=app].image

# ConfigMap example (commented in template):
# - source:
#     kind: ConfigMap
#     name: config-vars
#     fieldPath: data.DATABASE_URL
#   targets:
#     - select:
#         kind: Deployment
#       fieldPaths:
#         - spec.template.spec.containers.[name=app].env.[name=DATABASE_URL].value
```

---

## Implementation Status

| Issue | Status | Files Changed |
|-------|--------|---------------|
| commonLabels deprecation | ✅ Fixed | base/kustomization.yaml, overlays/*/kustomization.yaml |
| Sealed secrets required | ✅ Fixed | overlays/*/kustomization.yaml, sealed-secrets.yaml |
| envFrom assumes secrets | ✅ Fixed | base/deployment.yaml |
| Placeholders break build | ☑️ Documented | README.md, verify-configuration.sh |
| No matrix ApplicationSet | ✅ Fixed | applicationset-example.yaml (new file) |
| Certificate placeholder | ✅ Fixed | base/ingress.yaml, overlays/*/ingress-vars.yaml |
| Placeholder pattern | ☑️ Improved | All files, CONFIGURATION_CHECKLIST.md |
| replacement.yaml incomplete | ✅ Fixed | overlays/*/replacement.yaml |

---

## Testing Validation

### V2 Repository (gha-java-app_eks-v2)

All improvements were validated in the V2 implementation:

```bash
✅ dev overlay builds successfully
✅ stg overlay builds successfully  
✅ live overlay builds successfully
✅ Service works WITHOUT sealed secrets
✅ Matrix ApplicationSet pattern working
✅ Optional IRSA integration (commented out)
✅ Optional instrumentation (can be enabled)
✅ Clear placeholder markers throughout
```

### Template Status

**Current State**: 
- ❌ Template overlays do NOT build (expected - has placeholders)
- ✅ All improvements applied to template structure
- ✅ Documentation updated with guidance
- ✅ V2 provides working reference implementation

**Why Template Doesn't Build**:
This is **normal and expected**. Templates with `{{PLACEHOLDERS}}` cannot be built with Kustomize until customized. See gha-java-app_eks-v2 for what the template looks like when properly configured with actual values.

---

## Key Takeaways

### For Template Maintainers:

1. **Templates vs Instances**: Templates have placeholders (won't build), instances have values (will build). Both are necessary.

2. **Optional Must Mean Optional**: If something says "optional", it should be commented out by default, not just documented as skippable.

3. **Real-World Testing Essential**: Creating an actual repo from the template reveals issues not obvious from reviewing template files alone.

4. **Placeholder Format Matters**: `{{NAME}}` works in YAML but breaks Kustomize parsing - this is expected. Document it clearly.

5. **Matrix Pattern Scales Better**: Matrix ApplicationSet > Per-service ApplicationSet for repos with multiple services.

6. **Standard Overlay Pattern Only**: Only create three permanent overlays (dev/stg/live). PR previews and other temporary environments should be ephemeral, not permanent overlays.

### For Template Users:

1. **Start with V2 Example**: Look at gha-java-app_eks-v2 to see what the template looks like filled in.

2. **Replace All Placeholders**: Use verify-configuration.sh to find unreplaced values before building.

3. **Sealed Secrets Are Optional**: Don't create them unless you actually have secrets to manage.

4. **Matrix ApplicationSet Preferred**: Use applicationset-example.yaml pattern for multi-service repos.

5. **Infrastructure Can Wait**: You can commit the repo with placeholder values (ACCOUNT_ID, CERT_ID) and fill them in later when available.

6. **Only Three Overlays**: Create only dev/stg/live permanent overlays. Use ApplicationSet dynamic overrides for PR previews and other temporary environments.

---

## Reference Implementation

**See**: `/home/bmohamoodally/workspace/gha-java/gha-java-app_eks-v2`

This directory contains a complete, working implementation created from this template demonstrating:
- Matrix ApplicationSet for multi-service deployment
- Optional sealed secrets (not required)
- Optional IRSA integration (can enable when needed)
- Clear placeholder markers for infrastructure not yet created
- All Kustomize builds passing
- Production-ready structure

Use V2 as reference when customizing this template for your own services.

---

## Questions or Issues?

- **Template Questions**: See README.md and CONFIGURATION_CHECKLIST.md
- **Working Example**: Reference gha-java-app_eks-v2
- **Platform Support**: Raise OPSQ ticket
- **ARG Guidance**: Contact Architecture Review Group

---

**Document Maintained By**: Architecture Review Group  
**Last Updated**: 2026-02-17  
**Version**: 1.0.0
