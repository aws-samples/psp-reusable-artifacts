################################################################################
# EKS Blueprints Addons - Cluster 1 (Capabilities)
# Prepares IAM roles for addons that will be enabled as EKS Capabilities
# or installed during workshop exercises
################################################################################
module "eks_blueprints_addons_cluster1" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "~> 1.16"

  cluster_name      = module.eks_cluster1.cluster_name
  cluster_endpoint  = module.eks_cluster1.cluster_endpoint
  cluster_version   = module.eks_cluster1.cluster_version
  oidc_provider_arn = module.eks_cluster1.oidc_provider_arn

  # Don't create K8s resources - addons are enabled as EKS Capabilities during the workshop
  create_kubernetes_resources = false

  # IAM roles for addons (participants enable the capabilities in Module 2)
  enable_aws_load_balancer_controller = true
  enable_external_secrets             = true

  tags = local.tags
}

################################################################################
# Crossplane IRSA - Cluster 1 (used in Module 3: OSS Platform Tools)
################################################################################
module "crossplane_irsa_aws" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.14"

  role_name_prefix = "${local.cluster1_name}-crossplane-"

  role_policy_arns = {
    policy = "arn:aws:iam::aws:policy/AdministratorAccess"
  }

  oidc_providers = {
    main = {
      provider_arn               = module.eks_cluster1.oidc_provider_arn
      namespace_service_accounts = ["${var.crossplane_namespace}:${var.crossplane_sa}"]
    }
  }

  tags = local.tags
}
