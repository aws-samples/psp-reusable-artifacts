module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.13"

  cluster_name                         = local.name
  cluster_version                      = local.cluster_version
  cluster_endpoint_public_access       = local.cluster_endpoint_public_access
  cluster_endpoint_public_access_cidrs = local.allowed_public_cidrs
  cluster_endpoint_private_access      = local.cluster_endpoint_private_access
  cluster_enabled_log_types            = ["api", "audit", "authenticator", "controllerManager", "scheduler"] # Backwards compat

  iam_role_name            = "${local.name}-cluster-role" # Backwards compat
  iam_role_use_name_prefix = false                        # Backwards compat

  kms_key_aliases = [local.name] # Backwards compat

  vpc_id     = local.vpc_id
  subnet_ids = local.private_subnets_nodes

  create_cluster_security_group = false
  create_node_security_group    = false

  eks_managed_node_groups = {
    managed = {
      iam_role_name              = "${local.name}-managed" # Backwards compat
      iam_role_use_name_prefix   = false                   # Backwards compat
      use_custom_launch_template = false                   # Backwards compat

      instance_types = ["c6a.large", "c5a.large", "c6i.large", "c5.large"]

      min_size     = 2
      max_size     = 3
      desired_size = 2
      selectors = [{
        namespace = "kube-system"
        labels = {
          Which = "managed"
        }
        },
        {
          namespace = "karpenter"
          labels = {
            Which = "managed"
          }
        }
      ]
    }
  }
#   manage_aws_auth_configmap = true
#   aws_auth_roles = flatten(
#     [
#       module.operators_team.aws_auth_configmap_role,
#       module.developers_team.aws_auth_configmap_role,
#     ]
#   )
  manage_aws_auth_configmap = true
  aws_auth_roles = flatten([
    # {
    #   rolearn  = "arn:aws:iam::787843526639:role/AWSReservedSSO_AWSAdministratorAccess_ba0ccc6c0012ab35"
    #   username = "admin"
    #   groups   = ["system:masters"]
    # },
    # module.operators_team.aws_auth_configmap_role,
    # module.developers_team.aws_auth_configmap_role,
    {
      rolearn  = module.eks_blueprints_addons.karpenter.node_iam_role_arn
      username = "system:node:{{EC2PrivateDNSName}}"
      groups = [
        "system:bootstrappers",
        "system:nodes",
      ]
    }
 ])

  tags = local.tags
}