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

Add variables `../env/terraform-file.tfvars`

- controlplaneaccountid

> Don't forget to setup terraform state backend on version.tf file first

### How to run

```bash
terraform init
terraform apply -auto-approve -compact-warnings -var-file=../env/terraform-file.tfvars
```
