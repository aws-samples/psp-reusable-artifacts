# GitOps Bridge - Reference Pattern

## Overview

The GitOps Bridge pattern bootstraps ArgoCD and platform addons via Terraform + Helm, using ArgoCD ApplicationSets to reconcile Kubernetes resources from a Git repository. This is the recommended approach for production PSP engagements where you need full control over the ArgoCD lifecycle.

## When to Use This Pattern

| Scenario | Use GitOps Bridge | Use EKS Capability ArgoCD |
|:---------|:-----------------|:--------------------------|
| Production PSP engagement | Yes | Depends on requirements |
| Full ArgoCD customization needed | Yes | No |
| Multi-cluster hub-spoke GitOps | Yes | Not yet supported |
| Workshop / quick start | No | Yes |
| Minimal operational overhead | No | Yes |
| AWS-managed upgrades and HA | No | Yes |

## How It Works

```
Terraform                    ArgoCD (self-managed)           Git Repository
┌─────────────────┐         ┌──────────────────────┐        ┌──────────────────┐
│ GitOps Bridge   │────────▶│ Bootstrap ArgoCD      │───────▶│ ApplicationSets  │
│ Helm Module     │         │ via Helm chart        │        │ for Addons       │
│                 │         │                       │        │ for Workloads    │
│ Git SSH Secrets │────────▶│ Repo credentials      │        │                  │
│ Addon Metadata  │────────▶│ Cluster annotations   │        │ Helm values per  │
│                 │         │                       │        │ environment      │
└─────────────────┘         └──────────────────────┘        └──────────────────┘
```

1. Terraform creates the EKS cluster and computes addon metadata (IAM roles, VPC IDs, etc.)
2. GitOps Bridge Helm module installs ArgoCD and creates a cluster Secret with all metadata as annotations
3. ArgoCD reads the ApplicationSet templates from the bootstrap folder
4. ApplicationSets use cluster annotations to resolve repo URLs, paths, and revisions
5. ArgoCD reconciles all addons and workloads from the Git repository

## Key Benefits

- Single source of truth for all platform configuration in Git
- Terraform only handles infrastructure, ArgoCD handles everything on top of Kubernetes
- Addon metadata (IAM roles, VPC IDs, account IDs) flows from Terraform to ArgoCD via cluster annotations
- Easy to add/remove addons by toggling flags in tfvars
- Supports custom Helm values per environment

## Files in This Pattern

| File | Purpose |
|:-----|:--------|
| `gitops.tf.bkp` | Terraform config for ArgoCD namespace, git secrets, GitOps Bridge bootstrap, Crossplane IRSA |
| `bootstrap/addons.yaml` | ApplicationSet template for cluster addons |
| `bootstrap/workloads.yaml` | ApplicationSet template for Crossplane templates |
| `gitops-bridge-argocd-control-plane-template/` | Full ArgoCD control plane template with addon charts and environment configs |

## Why the Workshop Uses EKS Capability ArgoCD Instead

The workshop uses EKS Capability ArgoCD (managed by AWS) for these reasons:

1. **No conflict** - The workshop teaches participants to enable ArgoCD as an EKS Capability in Module 2. If Terraform also installs ArgoCD via GitOps Bridge, you get two ArgoCD instances competing on the same cluster.

2. **Simpler Terraform** - Without GitOps Bridge, the Terraform only creates infrastructure (VPCs, clusters, IAM). No need for Helm, Kubernetes, or kubectl providers. Fewer moving parts, fewer failure modes.

3. **Aligned with learning flow** - Participants learn to enable capabilities step by step. Having ArgoCD pre-installed skips the learning moment.

4. **Zero operational overhead** - AWS manages ArgoCD upgrades, patches, and availability. For a workshop with time constraints, this is ideal.

## How to Adopt This Pattern

To use GitOps Bridge in a real PSP engagement:

1. Copy `gitops.tf.bkp` to your `terraform/` directory as `gitops.tf`
2. Copy the `bootstrap/` folder to `terraform/bootstrap/`
3. Copy `gitops-bridge-argocd-control-plane-template/` to your repo root
4. Add the Helm and kubectl providers to your `main.tf`
5. Add GitOps variables to your `variables.tf` (see the workshop terraform for reference)
6. Update `locals.tf` with the `addons_metadata` and `argocd_apps` blocks
7. Configure your SSH key and git repository URLs in tfvars

## References

- [GitOps Bridge Project](https://github.com/gitops-bridge-dev/gitops-bridge/)
- [EKS Blueprints for Terraform](https://github.com/aws-ia/terraform-aws-eks-blueprints)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/en/stable/)
- [EKS Capabilities - ArgoCD](https://docs.aws.amazon.com/eks/latest/userguide/argocd.html)
