provider "aws" {
  region = local.region
}
data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      # This requires the awscli to be installed locally where Terraform is executed
      args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", local.region]
    }
  }
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", local.region]
  }
}



################################################################################
# GitOps Bridge: Bootstrap
################################################################################
module "gitops_bridge_bootstrap" {
  source = "gitops-bridge-dev/gitops-bridge/helm"

  cluster = {
    cluster_name = module.eks.cluster_name
    environment  = local.environment
    metadata     = local.addons_metadata
    addons       = local.addons
  }
  apps = local.argocd_apps
  depends_on = [module.eks_blueprints_addons, kubernetes_secret.git_secrets]
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
}

resource "aws_eks_access_entry" "karpenter_node_access_entry" {
  depends_on = [ module.eks, module.eks_blueprints_addons ]
  cluster_name      = module.eks.cluster_name
  principal_arn     = module.eks_blueprints_addons.karpenter.node_iam_role_arn
  type              = "EC2_LINUX"
}
/*
data "aws_route53_zone" "domain_name" {
  name         = "example.com"
  private_zone = false
}
*/


################################################################################
# EKS Cluster
################################################################################
#tfsec:ignore:aws-eks-enable-control-plane-logging
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.14"

  cluster_name                         = local.name
  cluster_version                      = local.cluster_version
  cluster_endpoint_public_access       = local.cluster_endpoint_public_access
  cluster_endpoint_public_access_cidrs = local.allowed_public_cidrs
  cluster_endpoint_private_access      = local.cluster_endpoint_private_access
  cluster_enabled_log_types            = ["api", "audit", "authenticator", "controllerManager", "scheduler"] # Backwards compat

  enable_cluster_creator_admin_permissions = true

  iam_role_name            = "${local.name}-cluster-role" # Backwards compat
  iam_role_use_name_prefix = false                        # Backwards compat

  vpc_id     = var.vpcid
  subnet_ids = var.privatesubnetids
  create_cluster_security_group = true
  create_node_security_group    = true

  #manage_aws_auth_configmap = true

  eks_managed_node_groups = {
    initial = {
      instance_types = ["m5.xlarge"]

      min_size     = 2
      max_size     = 10
      desired_size = 3
    }
  }

  self_managed_node_groups = {
    default = {
      instance_type = "m5.large"

      min_size     = 2
      max_size     = 10
      desired_size = 3
    }
  }
  # EKS Addons
  cluster_addons = {
    vpc-cni = {
      # Specify the VPC CNI addon should be deployed before compute to ensure
      # the addon is configured before data plane compute resources are created
      # See README for further details
      before_compute = true
      most_recent    = true # To ensure access to the latest settings provided
      configuration_values = jsonencode({
        env = {
          # Reference docs https://docs.aws.amazon.com/eks/latest/userguide/cni-increase-ip-addresses.html
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = "1"
        }
      })
    }
    aws-ebs-csi-driver = {
      most_recent              = true
      service_account_role_arn = module.ebs_csi_driver_irsa.iam_role_arn
    }
    coredns = {
      most_recent = true

      timeouts = {
        create = "25m"
        delete = "10m"
      }
    }
    kube-proxy = {}
    /* adot needs to be installed after cert-manager is installed with gitops, uncomment once cluster addons are deployed
    adot = {
      most_recent              = true
      service_account_role_arn = module.adot_irsa.iam_role_arn
    }
    */
    # aws-guardduty-agent = {}
  }
  tags = local.tags
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

# module "adot_irsa" {
#   source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
#   version = "~> 5.20"

#   role_name_prefix = "${local.name}-adot-"

#   role_policy_arns = {
#     prometheus = "arn:aws:iam::aws:policy/AmazonPrometheusRemoteWriteAccess"
#     xray       = "arn:aws:iam::aws:policy/AWSXrayWriteOnlyAccess"
#     cloudwatch = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
#   }
#   oidc_providers = {
#     main = {
#       provider_arn               = module.eks.oidc_provider_arn
#       namespace_service_accounts = ["opentelemetry-operator-system:opentelemetry-operator"]
#     }
#   }

#   tags = local.tags
# }


# resource "aws_security_group" "guardduty" {
#   name        = "guardduty_vpce_allow_tls"
#   description = "Allow TLS inbound traffic"
#   vpc_id      = module.vpc.vpc_id

#   ingress {
#     description = "TLS from VPC"
#     from_port   = 443
#     to_port     = 443
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   tags = local.tags
# }

# resource "aws_vpc_endpoint" "guardduty" {
#   vpc_id              = module.vpc.vpc_id
#   service_name        = "com.amazonaws.${local.region}.guardduty-data"
#   subnet_ids          = module.vpc.private_subnets
#   vpc_endpoint_type   = "Interface"
#   security_group_ids  = [aws_security_group.guardduty.id]
#   private_dns_enabled = true

#   tags = local.tags
# }

################################################################################
# GitOps Bridge: Private ssh keys for git
################################################################################
resource "kubernetes_namespace" "argocd" {
  depends_on = [module.eks_blueprints_addons, module.eks]
  metadata {
    name = "argocd"
  }
}
resource "kubernetes_secret" "git_secrets" {
  depends_on = [kubernetes_namespace.argocd]
  for_each = {
    git-addons = {
      type          = "git"
      url           = local.gitops_addons_org
      sshPrivateKey = file(pathexpand(local.git_private_ssh_key))
    }
    git-workloads = {
      type          = "git"
      url           = local.gitops_workload_org
      sshPrivateKey = file(pathexpand(local.git_private_ssh_key))
    }
  }
  metadata {
    name      = each.key
    namespace = kubernetes_namespace.argocd.metadata[0].name
    labels = {
      "argocd.argoproj.io/secret-type" = "repo-creds"
    }
  }
  data = each.value
}

################################################################################
# Crossplane
################################################################################
module "crossplane_irsa_aws" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.14"

  role_name_prefix = "${local.name}-crossplane-"

  role_policy_arns = {
    policy = "arn:aws:iam::aws:policy/AdministratorAccess"
  }

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["${local.crossplane_namespace}:${local.crossplane_sa}"]
    }
  }

  tags = local.tags
}