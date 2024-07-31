# AWS - PSP Platform Egineering - Network Configuration

This example will create a minimum VPC exampple to setup EKS using custom networking.

## Required Variables

Add this variables `../env/terraform-file.tfvars`

- vpc_cidr
- vpc_secondary_cidr
- region
- name
- environment

> Don't forget to setup terraform state backend on version.tf file first

### How to run

```bash
terraform init
terraform apply -auto-approve -var-file=../env/terraform-file.tfvars
```
