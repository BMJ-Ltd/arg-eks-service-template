# Critical Actions - EKS Service Template

**Version:** 1.0.0 | **Last Updated:** 2026-02-11

---

## Purpose

This document defines actions that require **human approval and intervention** when working with EKS deployment repositories. These rules apply to both human developers and AI agents.

---

## **FORBIDDEN** - Never Automate

These actions must **NEVER** be performed without explicit human approval and manual execution:

### 1. Destructive Operations

**FORBIDDEN:**
- Deleting Kubernetes resources in production (live environment)
- Removing PersistentVolumeClaims with data
- Deleting namespaces
- Scaling down to zero replicas in production
- Removing ingress rules for public-facing services
- Force-deleting stuck resources

**Why**: Risk of data loss, service outage, security exposure

**Required Process**: 
1. Create Jira ticket describing the deletion
2. Get approval from service owner
3. Create backup if data involved
4. Schedule maintenance window
5. Execute manually with verification at each step

---

### 2. Production Deployments

**FORBIDDEN:**
- Direct deployment to live environment without testing
- Bypassing ArgoCD sync policies
- Manual `kubectl apply` in production
- Force-syncing ArgoCD applications
- Disabling automated sync for production apps

**Why**: Risk of unvalidated changes, service disruption

**Required Process**:
1. Deploy to dev → validate
2. Deploy to stg → validate
3. Create change request (if required)
4. Deploy to live via ArgoCD
5. Monitor deployment, ready to rollback

---

### 3. Secrets and Credentials

**FORBIDDEN:**
- Committing plain-text secrets to git
- Storing secrets in ConfigMaps
- Sharing secrets in Slack/Email/Notion
- Using kubeseal with wrong cluster certificate
- Decrypting sealed secrets unnecessarily

**Why**: Security breach, credential exposure, compliance violation

**Required Process**:
1. Use AWS Secrets Manager or Parameter Store for storage
2. Create plain secret locally (never commit)
3. Seal with kubeseal using correct cluster certificate
4. Commit sealed secret only
5. Verify sealed secret decryptable in cluster
6. Delete plain secret file

---

### 4. IAM and Permissions

**FORBIDDEN:**
- Creating or modifying IAM roles without OPSQ ticket
- Adding broad IAM permissions (e.g., `*` actions)
- Changing IRSA role ARNs without verification
- Disabling IRSA (removing service account annotations)
- Granting cross-account access without approval

**Why**: Security risk, compliance violation, privilege escalation

**Required Process**:
1. Document exact permissions needed
2. Create OPSQ ticket with justification
3. Platform Team creates/modifies IAM roles
4. Reference role ARN in service account
5. Test with least privilege

---

### 5. Network Configuration

**FORBIDDEN:**
- Opening security groups to 0.0.0.0/0 without approval
- Changing ingress from internal to public without review
- Modifying network policies
- Changing VPC or subnet configurations
- Adding cross-region routing without planning

**Why**: Security exposure, compliance breach, network disruption

**Required Process**:
1. Document network requirements
2. Review security implications
3. Create OPSQ ticket for Platform Team
4. Test in dev environment first
5. Schedule change window for production

---

### 6. Resource Scaling

**FORBIDDEN in Live:**
- Scaling down replicas below 2 without approval
- Removing PodDisruptionBudget
- Disabling HorizontalPodAutoscaler
- Changing resource limits dramatically (>50% change)
- Removing replica configuration

**Why**: Risk of insufficient capacity, service degradation

**Required Process**:
1. Analyze current resource usage
2. Test scaling changes in stg
3. Document expected impact
4. Schedule change during low-traffic period
5. Monitor closely after change

---

## **RESTRICTED** - Require Confirmation

These actions require explicit **human confirmation** before proceeding:

### 1. Cost-Impacting Changes

**Requires confirmation:**
- Adding new PersistentVolumes (cost per GB)
- Increasing PVC storage size
- Increasing replica count above configured HPA max
- Adding new services to live environment
- Enabling features with data transfer costs

**Confirmation Required:**
- [ ] Cost estimate reviewed
- [ ] Budget allocation confirmed
- [ ] Cost centre tag correct

---

### 2. Configuration Changes

**Requires confirmation:**
- Changing environment variables in production
- Modifying ConfigMaps used by running pods
- Updating sealed secrets
- Changing health check thresholds
- Modifying resource requests/limits

**Confirmation Required:**
- [ ] Testing completed in dev/stg
- [ ] Impact analysis documented
- [ ] Rollback plan prepared

---

### 3. Ingress and TLS

**Requires confirmation:**
- Changing ingress hostnames
- Updating certificate ARNs
- Modifying ingress annotations (ALB settings)
- Adding new ingress rules
- Changing from internal to external load balancer

**Confirmation Required:**
- [ ] DNS changes coordinated
- [ ] Certificate validated
- [ ] Security review completed

---

### 4. Dependencies

**Requires confirmation:**
- Updating container image tags (especially in prod)
- Changing database connection strings
- Modifying API endpoints
- Adding new external service dependencies
- Upgrading Kubernetes API versions in manifests

**Confirmation Required:**
- [ ] Compatibility verified
- [ ] Testing completed
- [ ] Rollback procedure ready

---

## Safety Guidelines for AI Agents

### Before Making Changes

AI agents must:

1. **Analyze the environment**: dev/stg/live?
2. **Check criticality**: Is this a forbidden or restricted action?
3. **Request confirmation**: Present plan and wait for approval
4. **Document reasoning**: Why is this change needed?
5. **Provide rollback**: How can this be undone?

### Recommended Workflow

```
1. Analyze user request
2. Identify environment (dev/stg/live)
3. Check if action is forbidden or restricted
4. If forbidden: inform user, do not proceed
5. If restricted: present plan, request explicit approval
6. If approved: validate in dev/stg first
7. Execute with verification at each step
8. Monitor results
```

---

## Approved Automations

These actions are **SAFE** to automate:

### Development Environment

✅ Creating new services  
✅ Updating ConfigMaps  
✅ Changing environment variables  
✅ Modifying resource limits (within reason)  
✅ Creating sealed secrets (using kubeseal)  
✅ Running kustomize builds  
✅ Updating documentation  
✅ Adding new overlays  
✅ Refactoring manifests  

### All Environments

✅ Reading/viewing resources  
✅ Validating manifests (`kustomize build`)  
✅ Dry-run applies (`kubectl apply --dry-run`)  
✅ Generating documentation  
✅ Creating OPSQ tickets  
✅ Updating README files  
✅ Running verification scripts  

---

## Red Flags - Stop and Ask

If you see these patterns, **STOP and ask for human review**:

🚩 Command includes `--force`  
🚩 Deleting anything in live environment  
🚩 Credentials visible in diff  
🚩 NetworkPolicy with empty `{}` selectors  
🚩 SecurityContext with `privileged: true`  
🚩 HostPath volumes  
🚩 IAM role with `*` permissions  
🚩 Resource without labels (team, product, costcentre)  
🚩 Image tagged `latest` in production  
🚩 Secrets in ConfigMaps  
🚩 HTTP endpoints (not HTTPS) for external services  
🚩 No resource limits defined  
🚩 Container running as root (uid 0)  

---

## Incident Response

If automation causes an issue:

### Immediate Actions

1. **Stop further changes**: Halt any in-progress operations
2. **Assess impact**: How many users/services affected?
3. **Notify team**: Alert service owner and Platform Team
4. **Rollback**: Use ArgoCD or kubectl to restore previous state
5. **Document**: What happened, what was changed, how it was fixed

### Follow-up

1. Create incident report (Jira)
2. Update this document with lessons learned
3. Add safeguards to prevent recurrence
4. Review and improve validation scripts

---

## Validation Before Commit

**ALWAYS run these checks** before committing:

```bash
# 1. Check for secrets
git diff | grep -i -E "(password|secret|key|token)" || echo "No secrets found"

# 2. Validate kustomize builds
kustomize build {{SERVICE_NAME}}/overlays/dev/
kustomize build {{SERVICE_NAME}}/overlays/stg/
kustomize build {{SERVICE_NAME}}/overlays/live/

# 3. Check for remaining placeholders
grep -r "{{" {{SERVICE_NAME}}/ || echo "No placeholders"

# 4. Run verification script
./verify-configuration.sh

# 5. YAML lint check
yamllint {{SERVICE_NAME}}/
```

- [ ] No plain secrets in diff
- [ ] All kustomize builds succeed
- [ ] No placeholders remain
- [ ] Verification script passes
- [ ] YAML is valid

---

## Compliance Requirements

### ISO27001 (Security)

**Required for all changes:**
- Non-root containers (securityContext)
- No privileged containers
- Secrets encrypted (sealed secrets)
- Network policies (for sensitive services)
- Audit logging enabled
- No hard-coded credentials

### ISO14001 (Sustainability)

**Required for production:**
- Resource limits defined
- Right-sizing based on actual usage
- Auto-scaling configured
- Cost centre tags accurate
- Unused resources cleaned up

---

## Questions to Ask Before Acting

When working with this repository, ask:

1. **Environment**: Is this dev, stg, or live?
2. **Impact**: How many users will this affect?
3. **Reversibility**: Can this be rolled back easily?
4. **Testing**: Has this been validated in lower environments?
5. **Approval**: Do I have explicit human approval?
6. **Documentation**: Is the change documented?
7. **Monitoring**: How will I know if this causes issues?
8. **Compliance**: Does this meet security/sustainability requirements?

---

## Emergency Contacts

### Service Issues

- **Jira**: Create incident in service's project
- **Platform Team**: [OPSQ Board](https://bmjtech.atlassian.net/jira/software/c/projects/OPSQ/boards/493)
- **On-call**: Check PagerDuty rotation

### Security Issues

- **Security Team**: Marie Ashworth (BISO)
- **Email**: biso@bmj.com
- **Process**: Follow ISO27001 incident response

---

## Summary

| Action Type | Human Approval | Environment | Notes |
|-------------|----------------|-------------|-------|
| Read/View | ❌ Not required | All | Safe |
| Create in dev | ❌ Not required | Dev | Automated OK |
| Modify in dev | ❌ Not required | Dev | Automated OK |
| Deploy to stg | ✅ Recommended | Stg | After dev validation |
| Deploy to live | ✅✅ Required | Live | Via ArgoCD only |
| Delete in dev | ⚠️ Confirm | Dev | Verify not needed |
| Delete in stg/live | 🛑 Forbidden | Stg/Live | Manual only |
| Secrets | 🛑 Forbidden | All | Sealed secrets only |
| IAM changes | 🛑 Forbidden | All | OPSQ ticket required |
| Network changes | 🛑 Forbidden | All | OPSQ ticket required |

---

**Remember**: When in doubt, ask. It's better to get confirmation than to cause an outage.

---

**Version**: 1.0.0  
**Last Updated**: 2026-02-11  
**Owner**: Architecture Review Group  
**Review Frequency**: Quarterly
