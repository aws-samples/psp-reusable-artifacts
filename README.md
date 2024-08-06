# AWS - PSP Platform Egineering - Pilot

## Table of Contents

- [AWS - PSP Platform Egineering - Pilot](#aws---psp-platform-egineering---pilot)
  - [Table of Contents](#table-of-contents)
  - [Prerequisites](#prerequisites)
    - [Roles and Permissions](#roles-and-permissions)
    - [S3 for TFState Persistance](#s3-for-tfstate-persistance)
    - [SSH Key](#ssh-key)
  - [Networking](#networking)
  - [Environment Variables](#environment-variables)
  - [Control Plane Creation](#control-plane-creation)
  - [Access to EKS Cluster](#access-to-eks-cluster)
  - [Destroy EKS Cluster](#destroy-eks-cluster)
  - [Troubleshooting session](#troubleshooting-session)
  - [Security](#security)
  - [License](#license)

## Prerequisites

Before you begin, make sure you have the following command line tools installed:

- git
- terraform 1.5.0 or above
- AWS CLI 2.3.1 or above
- jq 1.6 or above
- kubectl
- ssh-key with **read access** to repositories

Also, for a full provisioning experience, we should have at least:

- 2 AWS Accounts
  - Control Plane Account
  - Data Plane Account

### Roles and Permissions

Create PSP ControlPlane Execution Role. This role is your Platform Master Execution role. It will requires the following permissions to provision your control plane.
For more details:

1. [Roles and permissions readme](terraform/platform-execution-role/README.md)

Rename and modify [variables.tfvars](terraform/env/variables.tfvars.example) file adding ControlPlaneAccountID

Follow the instructions on readme to create role and policy.

<!-- Before continue, Assume the new PSP-ControlPlane-Execution role to provision your controlplane. To configure AWS CLI user with Role check AWS Documentation [here](https://docs.aws.amazon.com/cli/v1/userguide/cli-configure-role.html) .

Ensure that you are using the correct role with the following command
```
aws sts get-caller-identity
``` -->

By the end o this step, you should have a AWS CLI configured with a PSP-ControlPlane-Execution role.

### S3 for TFState Persistance

Change your bucket name (must be unique) and AWS region

```bash
aws s3api create-bucket --bucket $BUCKETNAME --region $AWSREGION
```

Change bucket name and region inside file: terraform/versions.tf

```json
backend "s3" {
       bucket = "BUCKETNAME"
       key    = "controlplane/tfstate/psp-controlplane.tfstate"
       region = "REGION"
   }
```

This ensure that your TFState files will be securely stored in Amazon S3 bucket.

### SSH Key

We'll need to create or use an ssh key to give ArgoCD the right to access the `gitops_addons` and `gitops_workload` repositories.

Example:

```bash
ssh-keygen -t ecdsa -f privatekey_name.pem
```

## Networking

You must have a VPC configured with:

- 3 Private for Nodes
  - Tag Subnets with kubernetes.io/role/internal-elb = 1
- 3 Private Subnets for Pods (RFC6598): to use Custom Networking achieving higher scalability
- 3 Public Subnets: to host Load Balancers
  - Tag Subnets with kubernetes.io/role/elb = 1

IF you don`t have Internet access (through Internet Gateway): VPC Endpoints

- S3 Gateway Endpoint
- ECR.api
- ECR.dkr
- EKS
- "ec2", "ec2messages", "elasticloadbalancing", "sts", "kms", "logs", "ssm", "ssmmessages"

You can use networking folder of this repo to help provisioning networking infrastructure (**please remember to change terraform/networking/versions.tf file to use your bucket as in previous step**).

## Environment Variables

Replace the **variables.tfvars** file with the following content:

- **controlplaneaccountid**: AWS Account ID where you want to deploy your PSP Control Plane cluster
- **vpcid**: VPC ID where you want to deploy your PSP Control Plane cluster
- **privatesubnetids**: Array of Subnet IDs where your EKS Nodes will have the primary interface (outside VPC communication). It is recommended to be on at least 3 different AZs.
- **publicsubnetids**: Array of Subnet IDs to be used by External Load Balancers. It is recommended to be on at least 3 different AZs.
- **gitops_addons_org**: Your Git Organization URL for your Platform Addons (eg.: `git@github.com:aws-samples`)
- **gitops_addons_repo**: Name of your Platform Addons repo (eg.: `psp-controlplane`)
- **gitops_addons_revision**: Git repository revision/branch/ref for your Platform Addons (eg.: `main`)
- **gitops_workload_org**: Your Git Organization URL for your Platform Workloads (eg.: `git@github.com:aws-samples`)
- **gitops_workload_repo**: Name of your Platform Workloads repo (eg.: `psp-controlplane`)
- **gitops_workload_revision**: Git repository revision/branch/ref for your Platform Workloads (eg.: `main`)

OPTIONAL (if using AWS Identity Center integration)

- **managementaccountid**: Your Managements Account ID

You can also export the variables manually using the following commands:

```bash
export TF_VAR_controlplaneaccountid=CONTROLPLANE_ACCOUNT_ID
export TF_VAR_vpcid=VPC_ID
export TF_VAR_privatesubnetids_nodes='["SUBNETID1","SUBNETID2","SUBNETID3"]'
export TF_VAR_privatesubnetids_pods='["SUBNETID1","SUBNETID2","SUBNETID3"]'
export TF_VAR_publicsubnetids='["SUBNETID1","SUBNETID2","SUBNETID3"]'
export TF_VAR_gitops_addons_org=https://GITURL/ORGNAME
export TF_VAR_gitops_addons_repo=ADDONSREPONAME
export TF_VAR_gitops_addons_revision=main
export TF_VAR_gitops_workloads_org=https://GITURL/ORGNAME
export TF_VAR_gitops_workloads_repo=WORKLOADREPONAME
export TF_VAR_gitops_workloads_revision=main
```

## Control Plane Creation

```bash
cd psp-controlplane/terraform
terraform init
terraform apply -var-file=variables.tfvars -auto-approve
```

## Access to EKS Cluster

By default the role used to create the cluster has complete access to EKS and Kubernetes APIs.

Also by adding the `role_arn` in the variable `eks_role_admin`, terraform will add the role into access configuration using EKS Access policy `AmazonEKSClusterAdminPolicy`

If you need to give access to another user or role use the following commands:

```bash
aws eks create-access-entry --cluster-name cluster-name --principal-arn arn:aws:iam::accountID:rle/iam-principal-arn  --kubernetes-groups masters
```

```bash
aws eks associate-access-policy --cluster-name cluster-name --principal-arn arn:aws:iam::accountID:role/iam-principal-arn --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy --access-scope type=cluster
```

## Destroy EKS Cluster

The script will update kubeconfig values and will start to destroy the services using Enterprise Load Balancer after terraform resources.

```bash
cd terraform
bash destroy.sh
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

## Troubleshooting session

- If after full creation of the environment via terraform the ArgoCD service is still as ClusterIP, please check:
  - Check the SSH key with right permissons to the repositories
  - Repository URLs
  - Repository branches
  - Directory path on variable file or tfvar file
- Check container logs
- Check if repository URI is in correct form `git@github.com:ORG-NAME`

```bash
stern -n argocd argo-cd-argocd-server-
```

- Connecting to ArgCD using kubectl port-forward

```bash
echo "ArgoCD Password: $(kubectl get secrets argocd-initial-admin-secret -n argocd --template="{{index .data.password | base64decode}}")"
kubectl -n argocd port-forward service/argo-cd-argocd-server -n argocd 8080:443
```

- Deleting Terminating namespace stalled

```bash
namespaceToDelete=argocd

kubectl get namespace "$namespaceToDelete" -o json \
  | jq 'del(.spec.finalizers)' \
  | kubectl replace --raw /api/v1/namespaces/$namespaceToDelete/finalize -f -
```

Try to manual add repository using argocd client

```bash
echo "ArgoCD Password: $(kubectl get secrets argocd-initial-admin-secret -n argocd --template="{{index .data.password | base64decode}}")"
argocd login localhost:8080 --insecure --username admin

argocd repo add git@github.com:JOAMELO-ORG/psp-controlplane.git --ssh-private-key-path id_ecdsa
```

Check on argocd server if they have conectivity and permissions to clone the repository

```bash
kubectl -n argocd exec --stdin --tty argo-cd-argocd-server-6c6b95b77f-2b65c -- /bin/bash
git clone git@github.com:ORG-NAME/repository-name
```

## Security

See [CONTRIBUTING](CONTRIBUTING.md#security-issue-notifications) for more information.

## License

This library is licensed under the MIT-0 License. See the [LICENSE](LICENSE) file.
