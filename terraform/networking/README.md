# PSP Platform Egineering - Networking

Create PSP ControlPlane Networkingn environment for your Control plane EKS cluster. Your VPC must have:

- 3 Private for Nodes
  - Tag Subnets with kubernetes.io/role/internal-elb = 1
- 3 Private Subnets for Pods (RFC6598): to use Custom Networking achieving higher scalability
- 3 Public Subnets: to host Load Balancers
  - Tag Subnets with kubernetes.io/role/elb = 1

If you don`t have Internet access (through Internet Gateway), you should also have VPC endpoints for:

- S3 Gateway Endpoint
- ECR.api
- ECR.dkr
- EKS
- "ec2", "ec2messages", "elasticloadbalancing", "sts", "kms", "logs", "ssm", "ssmmessages"

## Required Variables

Rename and modify [variables.tfvars](../env/variables.tfvars.example) file adding the following variables:

- controlplaneaccountid: This account will be your central account for your Control Plane cluster

> Don't forget to setup terraform state backend on version.tf file inside the platform-execution-role folder

Add this variables `../env/terraform-file.tfvars`

- **vpc_cidr**: VPC CIDR for Platform Control Plane Nodes IP
- **vpc_secondary_cidr**: VPC CIDR for Platform Control Plane Pods IP
- **region**: AWS region to be used for your Platform Control Plane
- **name**: Prefix name for VPC 
- **environment**: Environment tag for you VPC

> Don't forget to setup terraform state backend on version.tf file first

### How to run

```bash
cd ./terraform/networking
terraform init
terraform apply -auto-approve -var-file=../env/terraform-file.tfvars
```

### Configure TFVars with Networking parameters

Please use the Terraform final output to overwrite the following variables in the `../env/terraform-file.tfvars`:

- **vpcid**: VPC ID where you want to deploy your PSP Control Plane cluster
- **privatesubnetids_nodes**: Array of Subnet IDs where your EKS Nodes will have the primary interface (outside VPC communication). It is recommended to be on at least 3 different AZs.
- **privatesubnetids_pods**: Array of Subnet IDs to be used by EKS Pods. It is recommended to be on at least 3 different AZs.
- **publicsubnetids**: Array of Subnet IDs to be used by External Load Balancers. It is recommended to be on at least 3 different AZs.