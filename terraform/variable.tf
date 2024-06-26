variable "managementaccountid" {
  type      = string
  sensitive = true
}

variable "controlplaneaccountid" {
  type      = string
  sensitive = true
}

variable "vpcid" {
  type      = string
  sensitive = true
}

variable "privatesubnetids_nodes" {
  type      = list(string)
  sensitive = true
}

variable "privatesubnetids_pods" {
  type      = list(string)
  sensitive = true
}

variable "publicsubnetids" {
  type      = list(string)
  sensitive = true
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.28"
}

variable "addons" {
  description = "Kubernetes addons"
  type        = any
  default = {
    enable_aws_load_balancer_controller = true
    enable_metrics_server               = true
    enable_argocd                       = true
    enable_karpenter                    = true
    enable_aws_crossplane_provider         = false # installs aws contrib provider
    enable_aws_crossplane_upbound_provider = true # installs aws upbound provider
    enable_crossplane_kubernetes_provider  = true # installs kubernetes provider
    enable_crossplane_helm_provider        = true # installs helm provider
    enable_crossplane                      = true # installs crossplane core
  }
}
# Addons Git
variable "gitops_addons_org" {
  description = "Git repository org/user contains for addons"
  type        = string
  default     = "https://github.com/aws-samples"
}
variable "gitops_addons_repo" {
  description = "Git repository contains for addons"
  type        = string
  default     = "eks-blueprints-add-ons"
}
variable "gitops_addons_revision" {
  description = "Git repository revision/branch/ref for addons"
  type        = string
  default     = "main"
}
variable "gitops_addons_basepath" {
  description = "Git repository base path for addons"
  type        = string
  default     = "argocd/"
}
variable "gitops_addons_path" {
  description = "Git repository path for addons"
  type        = string
  default     = "bootstrap/control-plane/addons"
}

# Workloads Git
variable "gitops_workload_org" {
  description = "Git repository org/user contains for workload"
  type        = string
  default     = "https://github.com/aws-ia"
}
variable "gitops_workload_repo" {
  description = "Git repository contains for workload"
  type        = string
  default     = "terraform-aws-eks-blueprints"
}
variable "gitops_workload_revision" {
  description = "Git repository revision/branch/ref for workload"
  type        = string
  default     = "main"
}
variable "gitops_workload_basepath" {
  description = "Git repository base path for workload"
  type        = string
  default     = "patterns/gitops/"
}
variable "gitops_workload_path" {
  description = "Git repository path for workload"
  type        = string
  default     = "getting-started-argocd/k8s"
}

variable "s3buckettfstate" {
  type      = string
  sensitive = true
}