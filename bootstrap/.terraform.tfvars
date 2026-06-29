
# If single-account: disable ECR cross-account replication
enable_ecr_replication = true

# PSP Reusable Artifacts — Bootstrap (Control Plane)
# =============================================================================

region             = "us-east-1"
cluster_name       = "control-plane"

# AWS CLI Profile (used by provider and local-exec provisioners)
aws_profile = "caribei-Admin"

vpc_cidr           = "10.0.0.0/16"

# AWS Organizations
organization_id = "o-bhsak572lu"

# IAM Identity Center (SSO) — used by ArgoCD capability
idc_instance_arn = "arn:aws:sso:::instance/ssoins-7223a407a8930104"

# ArgoCD RBAC — IAM Identity Center group IDs
argocd_admin_group_id    = "a4f85448-2001-70ac-df2b-0d601a126940"
argocd_readonly_group_id = "d4781408-5071-7049-eb59-f21d85aa11c5"

# Spoke account — (same account for single-account deployment)
spoke_account_id         = "554615221220"
spoke_region             = "us-east-1"
spoke_vpc_id             = "vpc-0d8c8acab74ec2013"
spoke_subnet_ids         = ["subnet-008f50b9df5018759", "subnet-0aedb22de1fe9a53d", "subnet-056b6005570ff48e3"]
spoke_kubernetes_version = "1.33"

# Tags
tags = {
  ManagedBy   = "terraform"
  Project     = "control-plane"
  Environment = "workshop"
}
