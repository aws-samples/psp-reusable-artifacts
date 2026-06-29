# Control Plane Operations Platform

Multi-account GitOps platform for managing EKS clusters and workloads declaratively using KRO + ACK + ArgoCD capabilities on EKS, with AI-assisted operations via ArgoCD MCP on AWS Bedrock AgentCore.

## Documentation

- [Architecture Overview](docs/architecture.md) — multi-account topology, account roles, IAM model
- [Repository Ecosystem & CI/CD Pipeline](docs/repositories-and-cicd.md) — CodeCommit repos, pipeline stages, end-to-end flow
- [ArgoCD ApplicationSets](docs/argocd-applicationsets.md) — ApplicationSet types, discovery patterns, platform claim processing
- [Modules](docs/modules.md) — bootstrap, agentcore-mcp, catalog, and runtime reference

## Repository Structure

```
control-plane-operations/
├── bootstrap/                              # Terraform — Control Plane Account
│   ├── main.tf                             # VPC, EKS (Auto Mode), CodeCommit, seed repo
│   ├── iam.tf                              # control-plane-admin role + Pod Identity
│   ├── capabilities.tf                     # ACK, KRO, ArgoCD EKS capabilities
│   ├── credit-card-pipeline.tf             # CI/CD: CodePipeline + CodeBuild
│   ├── credit-card-pipeline-seed.tf        # Seeds Java app + Helm chart repos
│   ├── templates/                          # ArgoCD manifest templates (.tftpl)
│   ├── variables.tf
│   ├── outputs.tf
│   └── versions.tf
│
├── agentcore-mcp/                          # Terraform — GenAI MCP Account
│   ├── main.tf                             # ECR, Secrets Manager, CodeBuild
│   ├── runtime.tf                          # IAM, AgentCore Runtime
│   ├── cognito.tf                          # Cognito User Pool, OAuth (M2M)
│   ├── docker/argocd-mcp/
│   │   ├── Dockerfile                      # ARM64 image with AWS CLI
│   │   └── entrypoint.sh                   # Fetches API token from Secrets Manager
│   ├── variables.tf
│   ├── outputs.tf
│   └── versions.tf
│
├── catalog/                                # KRO Resource Graph Definitions
│   ├── eks-cluster.yaml                    # RGD: EKS cluster (Auto Mode via ACK)
│   ├── helm-install.yaml                   # RGD: ArgoCD App for Helm charts
│   └── spoke-account-iam.yaml             # RGD: IAMRoleSelector per spoke
│
├── runtime/                                # Runtime claims (per environment)
│   ├── development/
│   │   └── credit-card/
│   │       ├── data-plane/claim.yaml       # EKS cluster + workloads claim
│   │       └── apps/                       # App configs for ApplicationSets
│   ├── staging/
│   │   └── credit-card/
│   └── production/
│       └── credit-card/
│
├── applications/                           # Helm chart overrides per environment
│   ├── development/
│   ├── staging/
│   └── production/
│
└── spoke-account-preparation/              # IAM role setup for spoke accounts
    ├── control-plane-execution-policy.json
    ├── control-plane-execution-trust.json
    └── README.md
```

## Deployment Order

### 0. Create Terraform Remote State Bucket

Before running any Terraform module, create the S3 bucket for remote state.

Open `create-tfstate-bucket.sh` and fill in the variables at the top:

```bash
PROFILE=""          # Your AWS CLI profile name, or leave empty for default credentials
REGION="us-east-1"  # AWS region where the bucket will be created
ACCOUNT_ID=""       # Your AWS account ID (e.g. 123456789012)
```

Then run:

```bash
./create-tfstate-bucket.sh
```

This creates a versioned, encrypted, private S3 bucket named `psp-tfstate-<ACCOUNT_ID>`.

> **Important:** Before running `terraform init` in any module, update the `backend "s3"` block in its `versions.tf` with your bucket name and (optionally) your AWS profile:
> ```hcl
> backend "s3" {
>   bucket  = "psp-tfstate-<YOUR_ACCOUNT_ID>"
>   key     = "psp-workshop/bootstrap/terraform.tfstate"
>   region  = "us-east-1"
>   profile = "<YOUR_PROFILE>"  # or remove this line for default credentials
> }
> ```

### 1. Spoke Account Preparation

Before creating the role, update the trust policy with your hub account ID:

```bash
# Replace REPLACE_WITH_HUB_ACCOUNT_ID with your actual hub account ID
sed -i '' 's/REPLACE_WITH_HUB_ACCOUNT_ID/123456789012/g' \
  spoke-account-preparation/control-plane-execution-trust.json
```

Then in each spoke account, create the execution role:

```bash
aws iam create-role --role-name control-plane-execution \
  --assume-role-policy-document file://spoke-account-preparation/control-plane-execution-trust.json
aws iam put-role-policy --role-name control-plane-execution \
  --policy-name control-plane-execution-policy \
  --policy-document file://spoke-account-preparation/control-plane-execution-policy.json
```

> **Workshop note:** If you cloned this repo for a workshop, the trust policy may already contain the hub account ID. Verify the value in `spoke-account-preparation/control-plane-execution-trust.json` before proceeding. For single-account deployments, the hub and spoke account IDs are the same.

#### Allow ECR Cross-Account Replication

If `enable_ecr_replication = true` (multi-account deployments), the spoke account's ECR registry must allow the hub account to replicate images into it. Without this, replication fails with `DESTINATION_REGISTRY_ACCESS_DENIED`.

```bash
aws ecr put-registry-policy \
  --policy-text '{
    "Version": "2012-10-17",
    "Statement": [{
      "Sid": "AllowReplicationFromHub",
      "Effect": "Allow",
      "Principal": {"AWS": "arn:aws:iam::<HUB_ACCOUNT_ID>:root"},
      "Action": ["ecr:ReplicateImage", "ecr:BatchImportUpstreamImage", "ecr:CreateRepository"],
      "Resource": "arn:aws:ecr:us-east-1:<SPOKE_ACCOUNT_ID>:repository/*"
    }]
  }' \
  --region us-east-1 \
  --profile <your-spoke-profile>
```

> Replace `<HUB_ACCOUNT_ID>` with the account ID where the CI/CD pipeline runs, and `<SPOKE_ACCOUNT_ID>` with the destination spoke account ID.

#### Tag Spoke Subnets for EKS Auto Mode

EKS Auto Mode uses subnet tags to discover where to launch nodes. Without these tags, the node provisioner (Karpenter) cannot find subnets and instances will never be created.

Tag the spoke subnets that will be used by the EKS cluster:

```bash
# For public subnets (MapPublicIpOnLaunch=true)
aws ec2 create-tags \
  --resources subnet-0aaa111bbb222ccc3 subnet-0ddd444eee555fff6 subnet-0ggg777hhh888iii9 \
  --tags Key=kubernetes.io/role/elb,Value=1 \
  --region us-east-1 \
  --profile <your-spoke-profile>

# For private subnets (recommended for production)
aws ec2 create-tags \
  --resources subnet-0aaa111bbb222ccc3 subnet-0ddd444eee555fff6 subnet-0ggg777hhh888iii9 \
  --tags Key=kubernetes.io/role/internal-elb,Value=1 \
  --region us-east-1 \
  --profile <your-spoke-profile>
```

> **Important:** Use the same subnet IDs you will set in `spoke_subnet_ids` in your `.terraform.tfvars`. Without this step, the EKS cluster will be created but nodes will remain in a pending state indefinitely.

#### Enable GuardDuty EKS Runtime Monitoring

If your claim includes the `aws-guardduty-agent` addon, you must enable both `RUNTIME_MONITORING` and `EKS_RUNTIME_MONITORING` on the GuardDuty detector in the spoke account. Without this, the agent will crash with `AccessDeniedException` even if the IAM role and Pod Identity are correctly configured.

```bash
# Get the detector ID
DETECTOR_ID=$(aws guardduty list-detectors --region us-east-1 --profile <your-spoke-profile> --query 'DetectorIds[0]' --output text)

# Enable EKS Runtime Monitoring (set EKS_ADDON_MANAGEMENT=DISABLED since the addon is managed by the platform)
aws guardduty update-detector \
  --detector-id $DETECTOR_ID \
  --features '[{"Name":"EKS_RUNTIME_MONITORING","Status":"ENABLED","AdditionalConfiguration":[{"Name":"EKS_ADDON_MANAGEMENT","Status":"DISABLED"}]},{"Name":"RUNTIME_MONITORING","Status":"ENABLED","AdditionalConfiguration":[{"Name":"EKS_ADDON_MANAGEMENT","Status":"DISABLED"},{"Name":"ECS_FARGATE_AGENT_MANAGEMENT","Status":"DISABLED"},{"Name":"EC2_AGENT_MANAGEMENT","Status":"DISABLED"}]}]' \
  --region us-east-1 \
  --profile <your-spoke-profile>
```

> **Note:** `EKS_ADDON_MANAGEMENT` is set to `DISABLED` because the platform manages the addon via the EKS cluster catalog RGD. Enabling it would cause GuardDuty to conflict with the platform-managed addon.

### 2. Control Plane (Hub Account)

#### Configure Variables

> **Tip:** Run `./gather-infra.sh` to discover your VPC IDs, subnet IDs, Organization ID, IAM Identity Center instance ARN, and group IDs. Before running, open the file and fill in the variables at the top (`PROFILE`, `REGION`, `ACCOUNT_ID`). Use the output to fill in your `.terraform.tfvars`.

Create `bootstrap/.terraform.tfvars` with your environment values:

```hcl
# AWS Region
region = "us-east-1"

# AWS CLI Profile (leave empty or remove for default credentials)
aws_profile = ""

# Set to false for single-account deployments
enable_ecr_replication = false

# EKS Cluster
cluster_name       = "control-plane"
kubernetes_version = "1.35"

# VPC
vpc_cidr = "10.0.0.0/16"

# AWS Organizations
organization_id = "o-abc123def4"

# CodeCommit repository name (ArgoCD GitOps source)
git_repo_url = "control-plane-operations"

# IAM Identity Center (SSO) — used by ArgoCD capability
idc_instance_arn = "arn:aws:sso:::instance/ssoins-1234567890abcdef"

# ArgoCD RBAC — IAM Identity Center group IDs
argocd_admin_group_id    = "a1b2c3d4-5678-90ab-cdef-111111111111"
argocd_readonly_group_id = "a1b2c3d4-5678-90ab-cdef-222222222222"

# Spoke account (development environment)
spoke_account_id         = "123456789012"
spoke_region             = "us-east-1"
spoke_vpc_id             = "vpc-0abc123def456789a"
spoke_subnet_ids         = ["subnet-0aaa111bbb222ccc3", "subnet-0ddd444eee555fff6"]
spoke_kubernetes_version = "1.33"

# Tags
tags = {
  ManagedBy   = "terraform"
  Project     = "control-plane"
  Environment = "hub"
}
```

| Variable | Required | Description |
|---|---|---|
| `region` | No (default: us-east-1) | AWS region for the control plane |
| `aws_profile` | No (default: "") | AWS CLI profile name for authentication. Required when using named profiles instead of default credentials |
| `enable_ecr_replication` | No (default: true) | Enable ECR cross-account replication. Set to `false` for single-account deployments |
| `cluster_name` | No (default: control-plane) | Name of the hub EKS cluster |
| `kubernetes_version` | No (default: 1.35) | Kubernetes version for the hub cluster |
| `vpc_cidr` | No (default: 10.0.0.0/16) | CIDR block for the hub VPC |
| `organization_id` | Yes | AWS Organizations ID (e.g. `o-abc123def4`) — used in cross-account trust policies |
| `git_repo_url` | No (default: control-plane-operations) | CodeCommit repository name |
| `idc_instance_arn` | Yes | ARN of the IAM Identity Center instance — enables SSO login to ArgoCD UI |
| `argocd_admin_group_id` | Yes | IAM Identity Center group ID for ArgoCD ADMIN role |
| `argocd_readonly_group_id` | Yes | IAM Identity Center group ID for ArgoCD VIEWER role |
| `spoke_account_id` | Yes | AWS account ID of the spoke (data-plane) account |
| `spoke_region` | No (default: us-east-1) | Region for the spoke EKS cluster |
| `spoke_vpc_id` | Yes | VPC ID in the spoke account |
| `spoke_subnet_ids` | Yes | Subnet IDs in the spoke account for the EKS cluster |
| `spoke_kubernetes_version` | No (default: 1.33) | Kubernetes version for spoke clusters |
| `tags` | No | Common tags applied to all resources |

#### Apply

```bash
cd bootstrap
terraform init
terraform apply -var-file=.terraform.tfvars
```

## Adding a New Runtime

1. Create `runtime/<environment>/<name>/data-plane/claim.yaml`
2. Include `SpokeAccountIAM`, `EKSCluster`, and `HelmInstall` instances
3. Set namespace to `<name>-<environment>`
4. Push to Git — ArgoCD picks it up automatically via the ApplicationSet

## Deploying an Application

Bootstrap seeds two CodeCommit repositories and a pipeline (`credit-card-pipeline`) as a ready-to-use example. The same pattern applies to any new application.

### Repositories created by bootstrap

| Repository | Purpose |
|---|---|
| `credit-card-java` | Java application source — Dockerfile, buildspec |
| `credit-card-data-plane` | Helm chart — `Chart.yaml`, `values.yaml`, `templates/` |

### Trigger a deployment

Push to the `main` branch of the app repo to start the pipeline:

```bash
# Clone the seeded app repo
git clone codecommit::us-east-1://credit-card-java
cd credit-card-java

# Make changes, then push
git add .
git commit -m "update application"
git push origin main
```

The pipeline runs three stages automatically:
1. **Build** — compiles the Java app, builds and pushes the Docker image to ECR
2. **Package** — packages and pushes the Helm chart as an OCI artifact to ECR
3. **Update** — commits updated `config.json` and `values.yaml` to this platform repo

ArgoCD detects the platform repo change and syncs the new image to the spoke cluster.

### Monitor the pipeline

```bash
# List pipeline executions
aws codepipeline list-pipeline-executions --pipeline-name credit-card-pipeline

# Watch ArgoCD sync status
kubectl get applications -n argocd
```

### Update Helm values

To change resource limits, replicas, or any other Helm value without a code change, edit the relevant file and push:

```
runtime/development/credit-card/apps/values.yaml
```

ArgoCD picks up the change and re-syncs without running the pipeline.

## Optional: AI-Assisted Operations (ArgoCD MCP + Bedrock AgentCore)

Deploys an ArgoCD MCP server on Bedrock AgentCore so AI agents can query and operate ArgoCD via natural language.

### Deploy ArgoCD MCP (GenAI Account)

> **Tip:** If running in a single-account setup, the ArgoCD server URL comes from your bootstrap outputs: `cd ../bootstrap && terraform output -raw argocd_server_url`

Create `agentcore-mcp/.terraform.tfvars`:

```hcl
region            = "us-east-1"
argocd_server_url = "https://abc123def456.eks-capabilities.us-east-1.amazonaws.com"
argocd_api_token  = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."

tags = {
  ManagedBy = "terraform"
  Project   = "argocd-mcp"
}
```

| Variable | Required | Description |
|---|---|---|
| `region` | No (default: us-east-1) | AWS region for the AgentCore deployment |
| `argocd_server_url` | Yes | ArgoCD server URL — `terraform output -raw argocd_server_url` from the bootstrap folder |
| `argocd_api_token` | Yes (sensitive) | Project-scoped JWT from ArgoCD UI: Settings → Projects → default → Roles → JWT Tokens → Generate |
| `tags` | No | Common tags applied to all resources |

> The `argocd_api_token` is sensitive — pass via CLI to avoid storing it in the tfvars file:
> ```bash
> terraform apply -var='argocd_api_token=eyJhbGci...'
> ```

```bash
cd agentcore-mcp
terraform init
terraform apply -var-file=.terraform.tfvars
```

### Register MCP in DevOps Agent

```bash
cd agentcore-mcp
terraform output devops_agent_client_id
terraform output -raw devops_agent_client_secret
terraform output devops_agent_exchange_url
terraform output devops_agent_oauth_scopes
terraform output devops_agent_mcp_endpoint_url
```

### Validate the MCP Endpoint

Open `test-mcp.sh` and set the region at the top if needed:

```bash
REGION="us-east-1"  # AWS region where AgentCore is deployed
```

Then run:

```bash
./test-mcp.sh
```

Verifies the full OAuth → MCP → ArgoCD chain: obtains a Cognito token, performs the MCP handshake, lists tools, and calls `list_applications`.

### Token Management

To rotate the ArgoCD API token:
```bash
cd agentcore-mcp
terraform apply -var='argocd_api_token=<new-token>'
```

### Rebuilding the Docker Image

If you modify the Dockerfile or entrypoint:
```bash
cd agentcore-mcp
terraform taint null_resource.argocd_mcp_build_trigger
terraform apply
```

> **Note:** The Dockerfile uses ECR Public mirrors (`public.ecr.aws/docker/library/`) instead of Docker Hub to avoid rate limits. If building in environments without ECR Public access, swap back to `node:20-slim` in the Dockerfile.
