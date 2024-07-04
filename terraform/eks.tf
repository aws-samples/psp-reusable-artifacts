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

  kms_key_aliases = [local.name] # Backwards compat

  vpc_id     = local.vpc_id
  subnet_ids = local.private_subnets_nodes

  # create_cluster_security_group = false
  # create_node_security_group    = false
  create_cluster_security_group = true
  create_node_security_group    = true
  eks_managed_node_groups = {
    # AL2023 node group utilizing new user data format which utilizes nodeadm
    # to join nodes to the cluster (instead of /etc/eks/bootstrap.sh)
    al2023_nodeadm = {
      ami_type = "AL2023_x86_64_STANDARD"

      use_latest_ami_release_version = true

      cloudinit_pre_nodeadm = [
        {
          content_type = "application/node.eks.aws"
          content      = <<-EOT
            ---
            apiVersion: node.eks.aws/v1alpha1
            kind: NodeConfig
            spec:
              kubelet:
                config:
                  shutdownGracePeriod: 30s
                  featureGates:
                    DisableKubeletCloudCredentialProviders: true
          EOT
        }
      ]
      min_size     = 2
      max_size     = 3
      desired_size = 3
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

  # eks_managed_node_groups = {
  #   managed = {
  #     iam_role_name              = "${local.name}-managed" # Backwards compat
  #     iam_role_use_name_prefix   = false                   # Backwards compat
  #     use_custom_launch_template = false                   # Backwards compat

  #     instance_types = ["c6a.large", "c5a.large", "c6i.large", "c5.large"]

  #     min_size     = 2
  #     max_size     = 3
  #     desired_size = 2
  #     selectors = [{
  #       namespace = "kube-system"
  #       labels = {
  #         Which = "managed"
  #       }
  #       },
  #       {
  #         namespace = "karpenter"
  #         labels = {
  #           Which = "managed"
  #         }
  #       }
  #     ]
  #   }
  # }
  # #   manage_aws_auth_configmap = true
  # #   aws_auth_roles = flatten(
  # #     [
  # #       module.operators_team.aws_auth_configmap_role,
  # #       module.developers_team.aws_auth_configmap_role,
  # #     ]
  # #   )
  # manage_aws_auth_configmap = true
  # aws_auth_roles = flatten([
  #   # {
  #   #   rolearn  = "arn:aws:iam::787843526639:role/AWSReservedSSO_AWSAdministratorAccess_ba0ccc6c0012ab35"
  #   #   username = "admin"
  #   #   groups   = ["system:masters"]
  #   # },
  #   # module.operators_team.aws_auth_configmap_role,
  #   # module.developers_team.aws_auth_configmap_role,
  #   {
  #     rolearn  = module.eks_blueprints_addons.karpenter.node_iam_role_arn
  #     username = "system:node:{{EC2PrivateDNSName}}"
  #     groups = [
  #       "system:bootstrappers",
  #       "system:nodes",
  #     ]
  #   }
  # ])

  # EKS Addons
  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    # Specify the VPC CNI addon outside of the module as shown below
    # to ensure the addon is configured before compute resources are created
    # See README for further details
  }

  tags = local.tags
}
