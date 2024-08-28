# PSP Platform Egineering - Role and Permissions

Create PSP ControlPlane Execution Role. This role is your Platform Master Execution role. It will requires the following permissions to provision your control plane:

- VPCFullAccess
- EC2FUllAccess
- ECRFullAccess
- S3FullAccess
- EKSFullAccess (customer managed inline policy)
- AmazonEC2ContainerRegistryFullAccess
- AmazonEventBridgeFullAccess
- AmazonSQSFullAccess
- CloudWatchLogsFullAccess
- IAMFullAccess
- KMSTagResource (customer managed inline policy)
- STSandECRAccess (customer managed inline policy)

## Required Variables

Rename and modify [variables.tfvars](../env/variables.tfvars.example) file adding ControlPlaneAccountID

- controlplaneaccountid: This account will be your central account for your Control Plane cluster
- eks_role_admin: This is an existing role that operators should use to access EKS cluster (it`s not the role created for Platform Execution, that will be the owner of the Control Plane cluster).

> Don't forget to setup terraform state backend on version.tf file inside the platform-execution-role folder

## How to run

```bash
cd ./terraform/platform-execution-role
terraform init
terraform apply -auto-approve -compact-warnings -var-file=../env/terraform-file.tfvars
```

> After role creation, update the terraform/remote_state.tf file with your bucket name and AWS Region.