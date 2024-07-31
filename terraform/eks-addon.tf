resource "time_sleep" "wait_for_eks" {
  create_duration = "30s"

  depends_on = [module.eks]
}
################################################################################
# Create ENIConfig for custom networking
################################################################################
resource "kubectl_manifest" "eni_config" {
  for_each = zipmap(local.azs, local.private_subnets_pods)

  yaml_body = yamlencode({
    apiVersion = "crd.k8s.amazonaws.com/v1alpha1"
    kind       = "ENIConfig"
    metadata = {
      name = each.key
    }
    spec = {
      securityGroups = [
        module.eks.node_security_group_id,
      ]
      subnet = each.value
    }
  })

  depends_on = [module.eks, time_sleep.wait_for_eks]
}

################################################################################
# VPC-CNI Custom CNI and IPv4 Prefix Delegation
################################################################################
data "aws_eks_addon_version" "latest" {
  for_each = toset(["vpc-cni", "aws-ebs-csi-driver"])

  addon_name         = each.value
  kubernetes_version = local.cluster_version
  most_recent        = true
}
resource "aws_eks_addon" "vpc_cni" {
  cluster_name  = module.eks.cluster_name
  addon_name    = "vpc-cni"
  addon_version = data.aws_eks_addon_version.latest["vpc-cni"].version

  configuration_values = jsonencode({
    env = {
      # Reference https://aws.github.io/aws-eks-best-practices/reliability/docs/networkmanagement/#cni-custom-networking
      AWS_VPC_K8S_CNI_CUSTOM_NETWORK_CFG = "true"
      ENI_CONFIG_LABEL_DEF               = "failure-domain.beta.kubernetes.io/zone"

      # Reference docs https://docs.aws.amazon.com/eks/latest/userguide/cni-increase-ip-addresses.html
      ENABLE_PREFIX_DELEGATION = "true"
      WARM_PREFIX_TARGET       = "1"
    }
  })

  tags = local.tags

  depends_on = [kubectl_manifest.eni_config, time_sleep.wait_for_eks]
}
resource "aws_eks_addon" "aws-ebs-csi-driver" {
  cluster_name  = module.eks.cluster_name
  addon_name    = "aws-ebs-csi-driver"
  addon_version = data.aws_eks_addon_version.latest["aws-ebs-csi-driver"].version

  service_account_role_arn = module.ebs_csi_driver_irsa.iam_role_arn

  tags = local.tags

  depends_on = [kubectl_manifest.eni_config, time_sleep.wait_for_eks]
}

################################################################################
# EKS Blueprints Addons
################################################################################
module "eks_blueprints_addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "~> 1.16"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  # Using GitOps Bridge
  create_kubernetes_resources = false

  # EKS Blueprints Addons
  enable_cert_manager                 = local.aws_addons.enable_cert_manager
  enable_aws_efs_csi_driver           = local.aws_addons.enable_aws_efs_csi_driver
  enable_aws_fsx_csi_driver           = local.aws_addons.enable_aws_fsx_csi_driver
  enable_aws_cloudwatch_metrics       = local.aws_addons.enable_aws_cloudwatch_metrics
  enable_aws_privateca_issuer         = local.aws_addons.enable_aws_privateca_issuer
  enable_cluster_autoscaler           = local.aws_addons.enable_cluster_autoscaler
  enable_external_dns                 = local.aws_addons.enable_external_dns
  enable_external_secrets             = local.aws_addons.enable_external_secrets
  enable_aws_load_balancer_controller = local.aws_addons.enable_aws_load_balancer_controller
  enable_fargate_fluentbit            = local.aws_addons.enable_fargate_fluentbit
  enable_aws_for_fluentbit            = local.aws_addons.enable_aws_for_fluentbit
  enable_aws_node_termination_handler = local.aws_addons.enable_aws_node_termination_handler
  enable_karpenter                    = local.aws_addons.enable_karpenter
  enable_velero                       = local.aws_addons.enable_velero
  enable_aws_gateway_api_controller   = local.aws_addons.enable_aws_gateway_api_controller

  #external_dns_route53_zone_arns = ["arn:aws:route53:::hostedzone/Z123456789"] # fake value for testing
  #external_dns_route53_zone_arns = [data.aws_route53_zone.domain_name.arn]
  # aws_for_fluentbit = {
  #   s3_bucket_arns = [
  #     module.velero_backup_s3_bucket.s3_bucket_arn,
  #     "${module.velero_backup_s3_bucket.s3_bucket_arn}/logs/*"
  #   ]
  # }

  tags = local.tags

  depends_on = [aws_eks_addon.aws-ebs-csi-driver, aws_eks_addon.vpc_cni]
}

module "ebs_csi_driver_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.14"

  role_name_prefix = "${local.name}-ebs-csi-driver-"

  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }

  tags = local.tags
}

resource "aws_eks_access_entry" "karpenter_node_access_entry" {
  cluster_name  = module.eks.cluster_name
  principal_arn = module.eks_blueprints_addons.karpenter.node_iam_role_arn
  type          = "EC2_LINUX"

  depends_on = [module.eks, module.eks_blueprints_addons]
}
