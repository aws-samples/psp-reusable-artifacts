variable "aws_profile" {
  description = "AWS CLI profile name for authentication"
  type        = string
  default     = ""
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "argocd_server_url" {
  description = "ArgoCD server URL from the hub account EKS capability"
  type        = string
}

variable "argocd_api_token" {
  description = "ArgoCD API token (project-scoped JWT recommended, up to 365 days)"
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    ManagedBy = "terraform"
    Project   = "argocd-mcp"
  }
}
