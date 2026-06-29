variable "aws_profile" {
  description = "AWS CLI profile name for authentication"
  type        = string
  default     = ""
}

variable "enable_ecr_replication" {
  description = "Enable ECR cross-account replication (disable for single-account deployments)"
  type        = bool
  default     = true
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "control-plane"
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.35"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "organization_id" {
  description = "AWS Organizations ID (e.g. o-xxxxxxxxxx) for the trust policy condition"
  type        = string
}

variable "git_repo_url" {
  description = "Git repository URL for ArgoCD (Default to CodeCommit)"
  type        = string
  default     = "control-plane-operations"
}

variable "idc_instance_arn" {
  description = "ARN of the AWS IAM Identity Center instance for ArgoCD capability"
  type        = string
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    ManagedBy = "terraform"
    Project   = "control-plane"
  }
}

variable "argocd_admin_group_id" {
  description = "AWS IAM Identity Center group ID for ArgoCD ADMIN role"
  type        = string
}

variable "argocd_readonly_group_id" {
  description = "AWS IAM Identity Center group ID for ArgoCD VIEWER role"
  type        = string
}

################################################################################
# Spoke Account Variables (for claim.yaml templatefile rendering)
################################################################################

variable "spoke_account_id" {
  description = "AWS Account ID of the spoke account (e.g. development environment)"
  type        = string
}

variable "spoke_region" {
  description = "AWS region for the spoke account EKS cluster"
  type        = string
  default     = "us-east-1"
}

variable "spoke_vpc_id" {
  description = "VPC ID in the spoke account where the EKS cluster will be deployed"
  type        = string
}

variable "spoke_subnet_ids" {
  description = "List of subnet IDs in the spoke account for the EKS cluster"
  type        = list(string)
}

variable "spoke_kubernetes_version" {
  description = "Kubernetes version for the spoke EKS cluster"
  type        = string
  default     = "1.33"
}
