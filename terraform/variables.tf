variable "name" {
  description = "Prefix name for all resources"
  type        = string
  default     = "psp"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "workshop"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.35"
}

variable "allowed_public_cidrs" {
  description = "EKS allowed public CIDRs for API endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "eks_role_admin" {
  description = "IAM Role ARN to add as EKS Cluster Admin"
  type        = string
}

variable "crossplane_namespace" {
  description = "Kubernetes namespace for Crossplane"
  type        = string
  default     = "crossplane-system"
}

variable "crossplane_sa" {
  description = "Crossplane service account name"
  type        = string
  default     = "provider-aws"
}
