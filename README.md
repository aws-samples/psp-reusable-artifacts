# AWS - PSP Platform Egineering - Pilot

## Table of Contents

1. [How to deploy Infrastructure and Besu cluster](#how-to-deploy)
1. [Ingress Services](#ingress-services)
1. [Configuring Index Pattern in Kibana](#configuring-index-pattern-in-kibana)
1. [Testing Cluster Besu](#testing-cluster-besu)
1. [Stop and Start Besu Services](#stop-and-start-besu)
1. [Installing Sirato - Optional](#installing-sirato---optional)
1. [Troubleshooting](#troubleshooting)
1. [How to destroy infrastructure](#how-to-destroy)

## Pre-reqs
- 2 AWS Accounts
    - Control Plane Account
        - S3 bucket for Terraform backend
    - Data Plane Account
- terraform 1.5.0
- AWS CLI >= 2.3.1
- jq 1.6

## Roles and Permissions
Create PSP ControlPlane Execution Role. This role is your Platform Master Execution role. It will requires the following permissions to provision your control plane:

- VPCFullAccess
- EC2FUllAccess
- ECRFullAccess
- S3FullAccess
- EKSFullAccess (customer managed inline policy)

You can use the following AWS CLI commands:

```bash
aws iam create-role --role-name PSP-ControlPlane-Execution --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"AWS":"arn:aws:iam::$CONTROLPLANE_ACCOUNT_ID:root"},"Action":"sts:AssumeRole"}]}'
```

```bash
aws iam attach-role-policy --role-name PSP-ControlPlane-Execution --policy-arn arn:aws:iam::aws:policy/AmazonVPCFullAccess
```

```bash
aws iam attach-role-policy --role-name PSP-ControlPlane-Execution --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess
```

```bash
aws iam attach-role-policy --role-name PSP-ControlPlane-Execution --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess
```

```bash
aws iam attach-role-policy --role-name PSP-ControlPlane-Execution --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess
```

```bash
aws iam put-role-policy --role-name PSP-ControlPlane-Execution --policy-name AmazonEKSFullAccess --policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":["eks:*"],"Resource":["*"]}]}'
```

After role creation, before continue Assume the PSP-ControlPlane-Execution role to provision your controlplane. To configure AWS CLI user with Role check AWS Documentation [here](https://docs.aws.amazon.com/cli/v1/userguide/cli-configure-role.html) .

Ensure that you are using the correct role with the following command
```
aws sts get-caller-identity
```

By the end o this step, you should have a AWS CLI configured with a PSP-ControlPlane-Execution role. Please take note of this ARN.


## S3 for TFState Persistance
Change your bucket name (must be unique) and AWS region
```
aws s3api create-bucket --bucket $BUCKETNAME --region $AWSREGION
```


## Networking
You must have a VPC configured with:
- 3 Private for Nodes
    - Tag Subnets with kubernetes.io/role/internal-elb = 1
- 3 Private Subnets for Pods (RFC RFC6598): to use Custom Networking achieving higher scalability
- 3 Public Subnets: to host Load Balancers
    - Tag Subnets with kubernetes.io/role/elb = 1

IF you don`t have Internet access (through Internet Gateway): VPC Endpoints
- S3 Gateway Endpoint
- ECR.api
- ECR.dkr
- EKS
- "ec2", "ec2messages", "elasticloadbalancing", "sts", "kms", "logs", "ssm", "ssmmessages"

You can use networking folder of this repo to help provisioning networking infrastructure.


## Environment Variables
Export the following terraform variables (you can also set a tfvars file):

- TF_VAR_controlplaneaccountid: AWS Account ID where you want to deploy your PSP Control Plane cluster
- TF_VAR_vpcid: VPC ID where you want to deploy your PSP Control Plane cluster
- TF_VAR_privatesubnetids_nodes: Array of Subnet IDs where your EKS Nodes will have the primary interface (outside VPC communication). It is recommended to be on at least 3 different AZs.
- TF_VAR_privatesubnetids_pods: Array of Subnet IDs where VPC-CNI will allocate IPs for Pods. It is recommended to use CGNAT IPs of RFC6598 (100.64.0.0/10). It is recommended to be on at least 3 different AZs.
- TF_VAR_publicsubnetids: Array of Subnet IDs to be used by External Load Balancers. It is recommended to be on at least 3 different AZs.
- TF_VAR_gitops_addons_org: Your Git Organization URL for your Platform Addons (eg.: https://github.com/aws-samples)
- TF_VAR_gitops_addons_repo: Name of your Platform Addons repo (eg.: eks-blueprints-add-ons)
- TF_VAR_gitops_addons_revision: Git repository revision/branch/ref for your Platform Addons (eg.: main)
- TF_VAR_gitops_workload_org: Your Git Organization URL for your Platform Workloads (eg.: https://github.com/aws-samples)
- TF_VAR_gitops_workload_repo: Name of your Platform Workloads repo (eg.: eks-blueprints-add-ons)
- TF_VAR_gitops_workload_revision: Git repository revision/branch/ref for your Platform Workloads (eg.: main)

OPTIONAL (if using AWS Identity Center integration)
- TF_VAR_MANAGEMENTACCOUNTID: Your Managements Account ID

```bash
export TF_VAR_controlplaneaccountid=CONTROLPLANE_ACCOUNT_ID
export TF_VAR_vpcid=VPC_ID
export TF_VAR_privatesubnetids_nodes={SUBNETID1, SUBNETID2, SUBNETID3}
export TF_VAR_privatesubnetids_pods={SUBNETID1, SUBNETID2, SUBNETID3}
export TF_VAR_publicsubnetids={SUBNETID1, SUBNETID2, SUBNETID3}
export TF_VAR_gitops_addons_org=https://GITURL/ORGNAME
export TF_VAR_gitops_addons_repo=ADDONSREPONAME
export TF_VAR_gitops_addons_revision=main
export TF_VAR_gitops_workloads_org=https://GITURL/ORGNAME
export TF_VAR_gitops_workloads_repo=WORKLOADREPONAME
export TF_VAR_gitops_workloads_revision=main
```


<!-- 3. Create Cluster Admin Role and Cluster Operator Role
    If you miss this configurations, start by Roles folder
    OPTIONAL: You can also use AWS Identity Center to create permission sets for Admin Role and Cluster Operator Role. Check SSO folder for examples. -->
<!-- ### Create Control Plane Role in the Control Plane Account with the following permission
GitHubAction-AssumeRoleWithAction
-EKS FullAdmin
-S3 Put,List
-ECR FullAdmin
-EC2 FullAdmin
-VPC FullAdmin


### Create Control Plane Role in the Control Plane Account with the following permission
GitHubAction-AssumeRoleWithAction
-EKS FullAdmin
-S3 Put,List
-ECR FullAdmin
-EC2 FullAdmin
-VPC FullAdmin -->


