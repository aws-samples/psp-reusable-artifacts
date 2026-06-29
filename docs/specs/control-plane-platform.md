# Control Plane Operations Platform — Specification

## 1. Overview

A multi-account GitOps platform that provisions and manages EKS clusters and workloads declaratively across AWS accounts using EKS capabilities (ACK, KRO, ArgoCD), with a CI/CD pipeline for application delivery.

### Scope

This spec covers the `bootstrap/` Terraform module, `catalog/` KRO resource definitions, `runtime/` claims, `spoke-account-preparation/` IAM setup, and the CI/CD pipeline. The `agentcore-mcp/` module is documented separately in `docs/specs/agentcore-mcp.md`.

### Accounts

| Account | Role | ID |
|---|---|---|
| Hub (Control Plane) | Central EKS cluster with ACK/KRO/ArgoCD capabilities | Configurable |
| Spoke (Data Plane) | EKS clusters provisioned by the hub, running workloads | Configurable (multiple) |

---

## 2. Requirements

### 2.1 Functional Requirements

#### FR-1: EKS Control Plane Cluster
- Provision an EKS cluster in Auto Mode in the hub account
- Enable ACK, KRO, and ArgoCD as EKS managed capabilities
- All capabilities share a single IAM role (`control-plane-admin`)
- ArgoCD integrates with IAM Identity Center for SSO access

#### FR-2: Cross-Account Infrastructure Provisioning
- ACK provisions EKS clusters in spoke accounts via `sts:AssumeRole`
- Spoke accounts have a pre-provisioned `control-plane-execution` IAM role
- The hub's `control-plane-admin` role assumes the spoke execution role
- EKS clusters in spoke accounts use Auto Mode (no managed node groups)

#### FR-3: Declarative Platform APIs (KRO RGDs)
- `EKSCluster` — provisions an EKS Auto Mode cluster with IAM roles, addons, access entries, and ArgoCD cluster registration
- `HelmInstall` — creates an ArgoCD Application for deploying Helm charts to spoke clusters
- `SpokeAccountIAM` — maps a K8s namespace to a spoke account's execution role via IAMRoleSelector

#### FR-4: GitOps via ArgoCD
- ArgoCD watches a CodeCommit repository (`control-plane-operations`)
- A static `catalog` Application syncs RGDs to `kro-system` namespace
- Data-plane ApplicationSets (per environment) use Git Directory Generator to discover `runtime/{env}/*/data-plane/` directories and apply claims to the hub cluster
- Apps ApplicationSets (per environment) use Git File Generator to read `runtime/{env}/*/apps/config.json` and deploy OCI Helm charts to spoke clusters via multi-source Applications
- ArgoCD project (`control-plane`) scopes allowed resources and destinations

#### FR-5: CI/CD Pipeline
- EventBridge triggers CodePipeline on push to `credit-card-java` main branch
- Stage 1: Build Java app, create Docker image, push to ECR
- Stage 2: Clone Helm chart repo, update image tag, package chart, push OCI to ECR
- Stage 3: Update `control-plane-operations` repo with new chart version and image tag (config.json + values.yaml)
- ECR replication copies Docker images to spoke accounts for native kubelet pull

#### FR-6: Repository Seeding
- Terraform seeds the `control-plane-operations` CodeCommit repo with argocd/, catalog/, runtime/, and applications/ folders
- Terraform seeds the `credit-card-java` repo with a Spring Boot Hello World app
- Terraform seeds the `credit-card-data-plane` repo with a Helm chart
- Terraform seeds the initial app entry (config.json + values.yaml) for the apps ApplicationSet

### 2.2 Non-Functional Requirements

#### NFR-1: Security
- No hardcoded account IDs — use organization-level conditions for ECR cross-account access
- IAM roles follow least-privilege principle
- S3 pipeline artifacts bucket uses KMS encryption and blocks public access
- ECR repositories enable scan-on-push

#### NFR-2: Automation
- Single `terraform apply` provisions the entire control plane
- ArgoCD ApplicationSets auto-discover new runtimes from Git — no manual Application creation
- CI/CD pipeline is fully automated from code push to deployment

#### NFR-3: Multi-Environment
- Three environments: development, staging, production
- Each environment has its own pair of ApplicationSets (data-plane + apps)
- Runtime claims are isolated per environment directory

---

## 3. Design

### 3.1 Hub Account Infrastructure (bootstrap/)

#### 3.1.1 Networking
- VPC with 3 AZs, private + public subnets
- Single NAT gateway
- Subnet tags for ELB discovery

#### 3.1.2 EKS Cluster
- Auto Mode with `general-purpose` and `system` node pools
- Public endpoint access enabled
- Cluster creator gets admin permissions

#### 3.1.3 IAM
- `control-plane-admin` role trusted by `pods.eks.amazonaws.com` and `capabilities.eks.amazonaws.com`
- Cross-account assume role policy: `arn:aws:iam::*:role/control-plane-execution`
- Pod Identity Association maps `ack-system/ack-controller` to the admin role
- Additional policies: EKSClusterPolicy, CodeCommit read-only, ECR pull

#### 3.1.4 EKS Capabilities
- ACK: provisions AWS resources via K8s custom resources
- KRO: processes ResourceGraphDefinitions into K8s resources
- ArgoCD: GitOps with IAM Identity Center SSO, RBAC role mappings (ADMIN + VIEWER)
- All capabilities use `control-plane-admin` role
- 15-second IAM propagation wait before capability creation

#### 3.1.5 CodeCommit + Repo Seeding
- Repository created via `aws_codecommit_repository`
- Initial commit via `null_resource` using `aws codecommit create-commit` API (no git credentials needed)
- Rendered templates (from `.tftpl` files) are written to `rendered/` directory, then committed
- ArgoCD manifests applied via `kubectl apply` after capabilities are ready

### 3.2 KRO Resource Graph Definitions (catalog/)

#### 3.2.1 EKSCluster RGD
Resources created (in order):
1. IAM Role for EKS cluster (Auto Mode policies)
2. IAM Role for Auto Mode nodes
3. EKS Cluster with Auto Mode compute, storage, networking, logging
4. EKS Access Entry granting ArgoCD capability role cluster-admin
5. ArgoCD Cluster Secret registering the spoke cluster
6. EKS Addons (optional, forEach loop)
7. GuardDuty IAM Role + Pod Identity (conditional, only if addon requested)

#### 3.2.2 HelmInstall RGD
Creates an ArgoCD Application with:
- Helm source (repoURL, chart, targetRevision)
- Inline values or parameter overrides
- Automated sync policy with prune, self-heal, retry

#### 3.2.3 SpokeAccountIAM RGD
Creates an IAMRoleSelector mapping a K8s namespace to a spoke account's execution role ARN.

### 3.3 Runtime Claims (runtime/)

Each claim uses ArgoCD sync waves to ensure ordering:
- Wave 0: Namespace with ACK default region annotation
- Wave 1: SpokeAccountIAM (must exist before ACK can assume role)
- Wave 2: EKSCluster (depends on IAM mapping)
- Wave 3: HelmInstall (depends on cluster being ready)

### 3.4 ArgoCD ApplicationSets

#### 3.4.1 Data-Plane ApplicationSets
- Generator: Git Directory (`runtime/{env}/*/data-plane`)
- Template: Application deploying claim.yaml to hub cluster
- Destination: hub cluster, namespace derived from directory name
- One per environment (development, staging, production)

#### 3.4.2 Apps ApplicationSets
- Generator: Git File (`runtime/{env}/*/apps/config.json`)
- Template: Multi-source Application
  - Source 1: OCI Helm chart from ECR (coordinates from config.json)
  - Source 2: values.yaml from Git (platform repo, ref-based)
- Destination: spoke cluster (by name from config.json)
- One per environment (development, staging, production)

### 3.5 CI/CD Pipeline

#### 3.5.1 Pipeline Architecture
- CodePipeline with 4 stages: Source → BuildImage → PackageChart → UpdateOps
- EventBridge rule triggers on CodeCommit push to main
- S3 bucket for inter-stage artifacts (KMS encrypted)

#### 3.5.2 CodeBuild Projects
- `credit-card-java-build`: Builds Java app + Docker image, pushes to ECR
- `credit-card-chart-build`: Clones Helm repo, updates image tag, packages + pushes OCI chart
- `credit-card-update-ops`: Updates platform repo with new chart version + image tag via `codecommit create-commit`

#### 3.5.3 ECR Cross-Account
- Replication rule copies Docker images to spoke account ECR
- Organization-level ECR policy allows pull from any org account
- Explicit policy for `control-plane-admin` role

### 3.6 Spoke Account Preparation

Pre-provisioned in each spoke account (outside Terraform):
- `control-plane-execution` IAM role
- Trust policy: hub account's `control-plane-admin` role
- Permissions: EKS (Auto Mode), IAM (cluster + node roles), EC2 (networking), CloudWatch Logs

---

## 4. Terraform Resource Inventory

### bootstrap/ Module

| File | Resources |
|---|---|
| main.tf | VPC module, EKS module, CodeCommit repo, local_file (rendered templates), null_resource (seed repo, apply manifests) |
| iam.tf | control-plane-admin role, cross-account assume policy, Pod Identity Association |
| capabilities.tf | ACK/KRO/ArgoCD capabilities, EKS access entry + policy, IAM policies (EKS, CodeCommit, ECR), time_sleep |
| credit-card-pipeline.tf | ECR repos + replication, CodeCommit repos, CodeBuild projects (3), CodePipeline, S3 bucket, EventBridge rule, IAM roles (CodeBuild, CodePipeline, EventBridge) |
| credit-card-pipeline-seed.tf | null_resource (seed Java app, Helm chart, app entry) |

### Dependencies

| Resource | Depends On |
|---|---|
| EKS capabilities | EKS cluster, IAM role propagation (15s wait) |
| Repo seeding | CodeCommit repo, rendered template files |
| ArgoCD manifest apply | Repo seeding, ArgoCD + KRO capabilities, rendered secrets |
| CI/CD pipeline | CodeCommit repos, ECR repos, IAM roles |

---

## 5. Outputs

### bootstrap/ Outputs

| Output | Description | Used By |
|---|---|---|
| `argocd_server_url` | ArgoCD capability server URL | agentcore-mcp module (input variable) |
| `cluster_name` / `cluster_arn` | Hub EKS cluster identifiers | Operations, debugging |
| `control_plane_admin_role_arn` | IAM role ARN | Spoke claim templates |
| `codecommit_clone_url_http` | Platform repo URL | ArgoCD templates |
| `credit_card_*` | Pipeline repo/ECR URLs | CI/CD operations |

---

## 6. Adding a New Workload

To add a new workload (e.g. "payments"):

1. Create app code repo: add `aws_codecommit_repository` + `aws_ecr_repository` to `bootstrap/credit-card-pipeline.tf` (or a new file)
2. Create Helm chart repo: add `aws_codecommit_repository` for the chart
3. Create pipeline: add CodeBuild projects + CodePipeline stages
4. Create runtime claim: `runtime/{env}/payments/data-plane/claim.yaml` with SpokeAccountIAM + EKSCluster + HelmInstall
5. Create app config: `runtime/{env}/payments/apps/config.json` + `values.yaml`
6. Push to Git — ArgoCD auto-discovers via ApplicationSets

---

## 7. Adding a New Environment

To add a new environment (e.g. "qa"):

1. Create ApplicationSet templates: `applicationset-dataplane-qa.yaml.tftpl` + `applicationset-apps-qa.yaml.tftpl`
2. Add to `main.tf` locals and `local_file` resources
3. Add to `null_resource.seed_repo` and `null_resource.apply_argocd_manifests`
4. Create runtime directory: `runtime/qa/<workload>/data-plane/claim.yaml` + `apps/`
5. Apply Terraform and push to Git

---

## 8. Adding a New Spoke Account

1. Run spoke account preparation (create `control-plane-execution` role)
2. Add spoke variables to `bootstrap/variables.tf` if using templatefile for claims
3. Create runtime claims referencing the new spoke account ID
4. Push to Git — ArgoCD provisions the cluster via ACK
