variable "controlplaneaccountid" {
  type      = string
  sensitive = true
}

variable "name" {
  description = "Prefix name"
  type        = string
  default     = "psp-controlplane"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "psp-controlplane"
}

variable "vpcid" {
  type      = string
  sensitive = true
}


variable "privatesubnetids_nodes" {
  type = list(string)
}

variable "privatesubnetids_pods" {
  type = list(string)
}

variable "publicsubnetids" {
  type = list(string)
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}


# variable "addons_apps" {
#   description = "Folder bootstrap of addons"
#   type        = string
#   default     = file("${path.module}/bootstrap/addons.yaml")
# }

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.30"
}

variable "addons" {
  description = "Kubernetes addons"
  type        = any
  default = {
    enable_aws_load_balancer_controller    = true
    enable_metrics_server                  = true
    enable_argocd                          = true
    enable_karpenter                       = true
    enable_aws_crossplane_provider         = false # installs aws contrib provider
    enable_aws_crossplane_upbound_provider = true  # installs aws upbound provider
    enable_crossplane_kubernetes_provider  = true  # installs kubernetes provider
    enable_crossplane_helm_provider        = true  # installs helm provider
    enable_crossplane                      = true  # installs crossplane core
    enable_prometheus_adapter              = true
    enable_kube_prometheus_stack           = true
    enable_gatekeeper                      = true
  }
}
# Addons Git
variable "gitops_addons_org" {
  description = "Git repository org/user contains for addons"
  type        = string
  default     = "git@github.com:JOAMELO-ORG"
}
variable "gitops_addons_repo" {
  description = "Git repository contains for addons"
  type        = string
  default     = "psp-controlplane"
}
variable "gitops_addons_revision" {
  description = "Git repository revision/branch/ref for addons"
  type        = string
  default     = "psp-aws-ia"
}
variable "gitops_addons_basepath" {
  description = "Git repository base path for addons"
  type        = string
  default     = "blueprints-add-ons/"
}
variable "gitops_addons_path" {
  description = "Git repository path for addons"
  type        = string
  default     = "argocd/bootstrap/control-plane/addons"
}

# Workloads Git
variable "gitops_workload_org" {
  description = "Git repository org/user contains for workload"
  type        = string
  default     = "git@github.com:JOAMELO-ORG"
}
variable "gitops_workload_repo" {
  description = "Git repository contains for workload"
  type        = string
  default     = "psp-controlplane"
}
variable "gitops_workload_revision" {
  description = "Git repository revision/branch/ref for workload"
  type        = string
  default     = "psp-aws-ia"
}
variable "gitops_workload_basepath" {
  description = "Git repository base path for workload"
  type        = string
  default     = "crossplane-templates/"
}
variable "gitops_workload_path" {
  description = "Git repository path for workload"
  type        = string
  default     = "components"
}
variable "ssh_key_path" {
  description = "SSH key path for git access"
  type        = string
  default     = "~/.ssh/id_rsa"
}
