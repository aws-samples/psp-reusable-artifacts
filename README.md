# AWS - PSP Platform Egineering

This repository contains reusable artifacts and templates to support the AWS Platform Strategy Program (PSP). The PSP is a no-cost program that provides guidance to customers on building internal developer platforms (IDP) on AWS.

The goal of this repository is to provide a set of verified, production-ready artifacts that customers can leverage when implementing an IDP as part of the PSP engagement. This includes:

- Terraform templates for provisioning the control plane infrastructure, including an EKS cluster, GitOps tooling, and supporting resources
- Crossplane compositions and claims for provisioning data plane EKS clusters in a self-service manner
- GitOps templates and configurations for deploying common platform addons and workloads
- Configuration files, scripts, and other utilities to streamline the PSP implementation process

By providing these reusable artifacts, the repository aims to accelerate the delivery of IDP solutions for PSP customers. The artifacts have been battle-tested through numerous customer engagements, ensuring they represent proven, scalable patterns.

You can leverage this repository as a starting point for building their own platform, customizing the templates and configurations to fit their specific requirements. This helps reduce the time and effort needed to set up the core IDP components, allowing the teams to focus on delivering value to their end users.

The repository is maintained by the AWS Solutions Architecture team and contributions are welcome from the broader AWS and customer community. It serves as a crucial part of the overall PSP offering, empowering customers to quickly realize the benefits of an AWS-powered internal developer platform.

## Table of Contents

- [AWS - PSP Platform Egineering](#aws---psp-platform-egineering)
  - [Prerequisites](#prerequisites)
  - [SSH Key](#ssh-key)
  - [S3 for TFState Persistance](#s3-for-tfstate-persistance)
  - [Roles and Permissions](#roles-and-permissions)
  - [Networking](#networking)
  - [GitOps Variables](#gitops-variables)
  - [Control Plane Creation](#control-plane-creation)
  - [Access to EKS Cluster](#access-to-eks-cluster)
  - [Access ArgoCD](#access-argocd)
  - [Create new data plane clusters using Crossplane](#create-new-data-plane-clusters-using-crossplane)
  - [Destroy EKS Cluster](#destroy-eks-cluster)
  - [Troubleshooting](#troubleshooting)
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

## SSH Key

You'll need to create or use an SSH key to give ArgoCD the necessary access to the `gitops_addons` and `gitops_workload` repositories. Run the following command to generate a new SSH key:

```bash
ssh-keygen -t ecdsa -f ~/.ssh/privatekey_name.pem
```

After generating the key, [register your public SSH key](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/adding-a-new-ssh-key-to-your-github-account) on your GitHub account.

## S3 for TFState Persistance

All your Terraform state files should be securely stored in an S3 bucket. To configure this, run the following commands to create your bucket, then update the versions.tf files in each Terraform folder that requires it.

Change the $BUCKETNAME and $AWSREGION variables to your desired values:

```bash
aws s3api create-bucket --bucket $BUCKETNAME --region $AWSREGION
```

In each versions.tf file, update the backend "s3" block with your bucket name and AWS region:

```json
backend "s3" {
       bucket = "BUCKETNAME"
       key    = "controlplane/tfstate/psp-controlplane.tfstate"
       region = "REGION"
   }
```

This ensures that your Terraform state files will be securely stored in an Amazon S3 bucket.

## Roles and Permissions

Create a PSP Control Plane Execution Role. This is your Platform Master Execution role. Follow the instructions in the [Roles and permissions readme](terraform/platform-execution-role/README.md)

## Networking

Create the PSP Control Plane Networking environment. Follow the instructions in the [Networking](terraform/networking/README.md)

## GitOps Variables

In platform engineering, we use GitOps to ensure that our Control Plane addons and applications are managed by a central Git repository.

We use [EKS Blueprints for Terraform](https://github.com/aws-ia/terraform-aws-eks-blueprints) for an EKS cluster for Control Plane, and through [GitOps Bridge project](https://github.com/gitops-bridge-dev/gitops-bridge/) we sent metadata and configurations to be used by [ArgoCD](https://argo-cd.readthedocs.io/en/stable/) to reconcile Kubernetes Helm charts for Addons/Plugins and Crossplane definitions/compositions.

- **gitops_addons_org**: Your Git Organization URL for your Platform Addons (eg.: `git@github.com:aws-samples`)
- **gitops_addons_repo**: Name of your Platform Addons repo (eg.: `psp-controlplane`)
- **gitops_addons_revision**: Git repository revision/branch/ref for your Platform Addons (eg.: `main`)
- **gitops_workload_org**: Your Git Organization URL for your Platform Workloads (eg.: `git@github.com:aws-samples`)
- **gitops_workload_repo**: Name of your Platform Workloads repo (eg.: `psp-controlplane`)
- **gitops_workload_revision**: Git repository revision/branch/ref for your Platform Workloads (eg.: `main`)

If you forked this repo, you can just change the org variables.

You can check and customize each plugin/addon at **ApplicationSet** files located at **gitops-bridge-argocd-control-plane-template/bootstrap/control-plane/addons** folder

You can also customize **helm chart values** at **gitops-bridge-argocd-control-plane-template/environments/default/addons** folder, or even create your own custom charts to be installed using **custom-charts** folder.

## Control Plane Creation

> Don't forget to setup terraform state backend on version.tf file first

```bash
cd terraform
terraform init
terraform apply -var-file=./env/variables.tfvars -auto-approve
```

## Access to EKS Cluster

By default the role used to create the cluster has complete access to EKS and Kubernetes APIs. That role is the Control Plane Execution Role created previously.
Also by adding the your operators role arn in the variable `eks_role_admin`, terraform added the role into access configuration using EKS Access policy `AmazonEKSClusterAdminPolicy`.

If you need to give access to another user or role use the following commands:

```bash
aws eks create-access-entry --cluster-name cluster-name --principal-arn arn:aws:iam::accountID:rle/iam-principal-arn  --kubernetes-groups masters
```

```bash
aws eks associate-access-policy --cluster-name cluster-name --principal-arn arn:aws:iam::accountID:role/iam-principal-arn --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy --access-scope type=cluster
```

## Access ArgoCD

The terraform output should give you the command list to get ArgoCD Url and credentials. For security reasons, we created an internal ALB (not exposed to Internet), so that if you don`t have access to VPC network, you can temporarlly expose the ArgoCD service with the following command:

```bash
echo "ArgoCD Password: $(kubectl get secrets argocd-initial-admin-secret -n argocd --template="{{index .data.password | base64decode}}")"
kubectl -n argocd port-forward service/argo-cd-argocd-server -n argocd 8080:443 &
```

## Create new data plane clusters using Crossplane

After ArgoCD successfully reconcile Crossplane components, check if the Crossplane composition and XRD are present in the cluster:

```bash
kubectl get crd xcluanys.eks.anycompany.com
kubectl get compositions xcluanys
```

> Replace the variables in crossplane-claim/eks/cluster-claim.yaml according to your environment (it can use the same Addons repo and SSH keys that we use for Control Plane creation).

After cluster-claim.yml file update and CRD and Composition are present, you can deploy a data plane cluster with:

```bash
kubectl apply -f crossplane-claim/eks/cluster-claim.yaml
```

Data Plane clusters take at least 10minutes to be ready. During this time the resources provisioned in Control Plane cluster by crossplane may be in Out-of-Sync or Failed status. We can check the provisioning status with:

```bash
kubectl describe xcluany DATAPLANE_CLUSTER_NAME
```

## Destroy EKS Cluster

The script will update kubeconfig values and will start to destroy the services using Enterprise Load Balancer after terraform resources.

```bash
cd terraform
bash destroy.sh
```

If you also want to destroy VPC and PSP Control Plane Execution role:

```bash
cd terraform/networking
terraform destroy -auto-approve -var-file=./env/controlplane.tfvars
cd ../..
```

```bash
cd terraform/platform-execution-role
terraform destroy -auto-approve -var-file=./env/controlplane.tfvars
```

## Troubleshooting

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

argocd repo add git@github.com:ORG-NAME/psp-controlplane.git --ssh-private-key-path id_ecdsa
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
