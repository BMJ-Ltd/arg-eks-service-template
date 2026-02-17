# End-to-End Workflow: From Request to Deployment

This document shows the complete journey from "I need a new EKS deployment" to "Services running in production."

---

## The Players

| Component | Role | Location |
|-----------|------|----------|
| **Developer** | Needs to deploy services to EKS | Human |
| **AI Agent** | Orchestrates the process | GitHub Copilot + Claude |
| **Skills Repository** | Provides domain knowledge | [arg-agentic-configuration](https://github.com/BMJ-Ltd/arg-agentic-configuration) |
| **Template Repository** | Provides structure/boilerplate | [arg-eks-service-template](https://github.com/BMJ-Ltd/arg-eks-service-template) (this repo) |
| **Product Repository** | Final deployable manifests | e.g., `new-product_eks` (created) |
| **Platform Team** | Provisions infrastructure | OPSQ tickets |
| **ArgoCD** | Deploys to Kubernetes | GitOps automation |

---

## Phase 1: Developer Initiates Request

### Scenario
Developer working on "Medical Records Modernization" project needs to deploy 3 services to EKS:
- `records-api` - REST API for medical records
- `records-indexer` - Background indexer
- `records-search` - Elasticsearch proxy

### Developer Action
In their IDE (VS Code with GitHub Copilot):

```
Developer: "I need to create EKS deployments for our Medical Records Modernization 
project. We have 3 services: records-api, records-indexer, and records-search. 
They need to run in dev, staging, and production environments."
```

---

## Phase 2: AI Agent Discovery

### Agent Reads AGENTS.MD Files

**Step 1: Agent discovers org-wide standards**

<function_calls>
<invoke name="read_file">
<parameter name="filePath">arg-agentic-configuration/AGENTS.MD