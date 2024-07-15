variable "name" {
  description = "Prefix name"
  type        = string
  default     = "psp-controlplane"
}
# variable "vpc_cidr" {
#   description = "VPC CIDR"
#   type        = string
#   default     = "10.0.0.0/16"
# }
variable "vpcid" {
  type      = string
  sensitive = true
}
variable "privatesubnetids" {
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
variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.28"
}

variable "addons" {
  description = "Kubernetes addons"
  type        = any
  default = {
    enable_cert_manager                          = false
    enable_aws_efs_csi_driver                    = false
    enable_aws_fsx_csi_driver                    = false
    enable_aws_cloudwatch_metrics                = false
    enable_aws_privateca_issuer                  = false
    enable_cluster_autoscaler                    = false
    enable_external_dns                          = false
    enable_external_secrets                      = true
    enable_aws_load_balancer_controller          = true
    enable_aws_for_fluentbit                     = false
    enable_aws_node_termination_handler          = false
    enable_karpenter                             = true
    enable_velero                                = false
    enable_aws_gateway_api_controller            = false
    enable_aws_ebs_csi_resources                 = true # generate gp2 and gp3 storage classes for ebs-csi
    enable_aws_secrets_store_csi_driver_provider = true
    enable_argo_rollouts                         = false
    enable_argo_workflows                        = false
    enable_gpu_operator                          = false
    enable_kube_prometheus_stack                 = true
    enable_metrics_server                        = true
    enable_prometheus_adapter                    = false
    enable_secrets_store_csi_driver              = true
    enable_vpa                                   = false
    enable_aws_crossplane_upbound_provider       = true //esse deveria estar true
    enable_crossplane                            = true
    enable_aws_crossplane_provider               = false
    enable_crossplane_kubernetes_provider        = true  # installs kubernetes provider
    enable_crossplane_helm_provider              = true  # installs helm provider
    enable_foo                                   = false # you can add any addon here, make sure to update the gitops repo with the corresponding application set
  }
}
# Addons Git
variable "gitops_addons_org" {
  description = "Git repository org/user contains for addons"
  type        = string
  default     = "git@github.com:ORGNAME"
}
variable "gitops_addons_repo" {
  description = "Git repository contains for addons"
  type        = string
  default     = "psp-controlplane"
}
variable "gitops_addons_revision" {
  description = "Git repository revision/branch/ref for addons"
  type        = string
  default     = "main"
}
variable "gitops_addons_basepath" {
  description = "Git repository base path for addons"
  type        = string
  default     = "gitops-bridge-argocd-control-plane-template/"
}
variable "gitops_addons_path" {
  description = "Git repository path for addons"
  type        = string
  default     = "bootstrap/control-plane/addons"
}
variable "gitops_workload_org" {
  description = "Git repository org/user contains for workloads"
  type        = string
  default     = "git@github.com:ORGNAME"
}
variable "gitops_workload_repo" {
  description = "Git repository contains for workload"
  type        = string
  default     = "psp-controlplane"
}
variable "gitops_workload_revision" {
  description = "Git repository revision/branch/ref for addons"
  type        = string
  default     = "main"
}
variable "gitops_workload_basepath" {
  description = "Git repository base path for addons"
  type        = string
  default     = "/"
}
variable "gitops_workload_path" {
  description = "Git repository path for addons"
  type        = string
  default     = "crossplane-templates"
}
variable "ssh_key_path" {
  description = "SSH key path for git access"
  type        = string
  default     = "~/.ssh/id_rsa"
}
