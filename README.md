# Platform Strategy Program (PSP) - Reusable Artifacts

Terraform templates and reference patterns for building Internal Developer Platforms (IDPs) on AWS using Amazon EKS.

This repository supports the [Platform Engineering Foundations on AWS](https://catalog.workshops.aws/) workshop and real-world PSP customer engagements.

## What's Inside

```
psp-reusable-artifacts/
├── terraform/                          # Infrastructure as Code
│   ├── platform-execution-role/        # IAM execution role (Stage 1)
│   ├── networking/                     # 3 VPCs + full mesh peering (Stage 2)
│   ├── eks.tf                          # 3 EKS Auto Mode clusters (Stage 3)
│   ├── eks-addon.tf                    # IAM roles for addons (LB Controller, Crossplane)
│   └── env/                            # Example tfvars
├── crossplane-claim/                   # Crossplane claims for data plane clusters
├── crossplane-templates/               # Compositions, XRDs, and functions
└── psp-reference-patterns/             # Advanced patterns for production use
    └── gitops-bridge/                  # ArgoCD bootstrap via Terraform + GitOps Bridge
```

## Architecture

Three EKS Auto Mode clusters with isolated VPCs and full mesh VPC peering:

```
┌─────────────────────────────────────────────────────────────┐
│                     Your AWS Account                        │
│                                                             │
│  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐   │
│  │  VPC 10.0/16  │  │  VPC 10.1/16  │  │  VPC 10.2/16  │   │
│  │               │  │               │  │               │   │
│  │  Cluster 1    │  │  Cluster 2    │  │  Cluster 3    │   │
│  │  Capabilities │  │  CNOE DIY     │  │  Apps Platform│   │
│  │               │  │               │  │               │   │
│  │  EKS Auto Mode│  │  EKS Auto Mode│  │  EKS Auto Mode│   │
│  └───────┬───────┘  └───────┬───────┘  └───────┬───────┘   │
│          │    VPC Peering    │    VPC Peering    │           │
│          └──────────────────┴──────────────────┘           │
│                    Full Mesh Peering                        │
└─────────────────────────────────────────────────────────────┘
```

| Cluster | Purpose | Key Components |
|:--------|:--------|:---------------|
| **Cluster 1** - Capabilities | EKS native features | [EKS Capabilities](https://docs.aws.amazon.com/eks/latest/userguide/eks-add-ons.html) (Argo CD, kro, ACK) |
| **Cluster 2** - CNOE DIY | Full IDP stack | [CNOE](https://cnoe.io/) reference implementation |
| **Cluster 3** - Apps Platform | Application workloads | Target for deployments |

### Key Technologies

| Technology | Role | Documentation |
|:-----------|:-----|:--------------|
| [EKS Auto Mode](https://docs.aws.amazon.com/eks/latest/userguide/automode.html) | Simplified cluster operations, automatic node provisioning | Replaces managed node groups |
| [EKS Capabilities](https://docs.aws.amazon.com/eks/latest/userguide/eks-add-ons.html) | Managed platform services (Argo CD, kro, ACK) | One-click enable, AWS-managed |
| [Crossplane](https://www.crossplane.io/) | Multi-cloud infrastructure control plane | Compositions and custom APIs |
| [Backstage](https://backstage.io/) | Developer portal and service catalog | Self-service templates |

## Prerequisites

- [Terraform >= 1.5](https://developer.hashicorp.com/terraform/install)
- [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- AWS account with admin access

## Quick Start

### Stage 1: Create IAM Execution Role

```bash
cd terraform/platform-execution-role

# Edit tfvars with your account ID
cp ../env/workshop.tfvars.example ../env/workshop.tfvars
# Update controlplaneaccountid and eks_role_admin

terraform init
terraform apply -auto-approve -var-file=../env/workshop.tfvars
```

### Stage 2: Deploy Networking

Creates 3 VPCs with pod subnets (RFC6598) and full mesh VPC peering.

```bash
cd ../networking
terraform init
terraform apply -auto-approve
```

### Stage 3: Deploy EKS Clusters

Creates 3 EKS Auto Mode clusters with IAM roles for platform addons.

```bash
cd ..
terraform init
terraform apply -var-file=./env/workshop.tfvars -auto-approve
```

### Configure kubectl

```bash
aws eks update-kubeconfig --name psp-cluster-1-capabilities --region us-east-1 --alias cluster1
aws eks update-kubeconfig --name psp-cluster-2-cnoe-diy --region us-east-1 --alias cluster2
aws eks update-kubeconfig --name psp-cluster-3-apps-platform --region us-east-1 --alias cluster3
```

## Cleanup

```bash
cd terraform
bash destroy.sh

cd networking
terraform destroy -auto-approve

cd ../platform-execution-role
terraform destroy -auto-approve -var-file=../env/workshop.tfvars
```

## Terraform State

All state files are stored in S3. Before running, update the `backend "s3"` block in each `versions.tf`:

```hcl
backend "s3" {
  bucket = "YOUR_BUCKET_NAME"
  key    = "controlplane/tfstate/KEEP_EXISTING_KEY"
  region = "us-east-1"
}
```

## Reference Patterns

The `psp-reference-patterns/` folder contains advanced patterns for production PSP engagements:

| Pattern | Description | When to Use |
|:--------|:------------|:------------|
| [GitOps Bridge](psp-reference-patterns/gitops-bridge/) | Bootstrap ArgoCD + addons via Terraform and GitOps Bridge | Production engagements needing full ArgoCD lifecycle control |

## Crossplane Templates

The `crossplane-templates/` folder contains reusable Crossplane artifacts:

- **Compositions** - Infrastructure patterns (e.g., Serverless Multi-Tier Architecture)
- **CompositeResourceDefinitions (XRDs)** - Custom API definitions
- **Functions** - Crossplane composition functions

The `crossplane-claim/` folder contains example claims for provisioning data plane clusters.

## Related Resources

- [Platform Engineering Foundations Workshop](https://catalog.workshops.aws/)
- [EKS Auto Mode Documentation](https://docs.aws.amazon.com/eks/latest/userguide/automode.html)
- [EKS Capabilities](https://docs.aws.amazon.com/eks/latest/userguide/eks-add-ons.html)
- [CNOE Project](https://cnoe.io/)
- [GitOps Bridge Project](https://github.com/gitops-bridge-dev/gitops-bridge/)
- [EKS Blueprints for Terraform](https://github.com/aws-ia/terraform-aws-eks-blueprints)

## Security

See [CONTRIBUTING](CONTRIBUTING.md#security-issue-notifications) for more information.

## License

This library is licensed under the MIT-0 License. See the [LICENSE](LICENSE) file.
