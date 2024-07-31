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

  vpc_id                        = local.vpc_id
  subnet_ids                    = local.private_subnets_nodes
  create_cluster_security_group = true
  create_node_security_group    = true

  #manage_aws_auth_configmap = true

  eks_managed_node_groups = {
    # AL2023 node group utilizing new user data format which utilizes nodeadm
    # to join nodes to the cluster (instead of /etc/eks/bootstrap.sh)
    al2023_nodeadm = {
      ami_type = "AL2023_x86_64_STANDARD"

      use_latest_ami_release_version = true
      instance_types                 = ["c5a.large", "c6a.large", "c5.large", "c6i.large"]

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
      min_size     = 3
      max_size     = 5
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

  # EKS Addons
  cluster_addons = {
    coredns = {
      most_recent = true
      timeouts = {
        create = "25m"
        delete = "10m"
      }
    }
    kube-proxy = {
      most_recent = true
    }
    # Specify the VPC CNI addon outside of the module as shown below
    # to ensure the addon is configured before compute resources are created
    # See README for further details
  }

  tags = local.tags

  # # EKS Addons
  # cluster_addons = {
  #   vpc-cni = {
  #     # Specify the VPC CNI addon should be deployed before compute to ensure
  #     # the addon is configured before data plane compute resources are created
  #     # See README for further details
  #     before_compute = true
  #     most_recent    = true # To ensure access to the latest settings provided
  #     configuration_values = jsonencode({
  #       env = {
  #         # Reference docs https://docs.aws.amazon.com/eks/latest/userguide/cni-increase-ip-addresses.html
  #         ENABLE_PREFIX_DELEGATION = "true"
  #         WARM_PREFIX_TARGET       = "1"
  #       }
  #     })
  #   }
  #   aws-ebs-csi-driver = {
  #     most_recent              = true
  #     service_account_role_arn = module.ebs_csi_driver_irsa.iam_role_arn
  #   }
  #   coredns = {
  #     most_recent = true

  #     timeouts = {
  #       create = "25m"
  #       delete = "10m"
  #     }
  #   }
  #   kube-proxy = {}
  #   /* adot needs to be installed after cert-manager is installed with gitops, uncomment once cluster addons are deployed
  #   adot = {
  #     most_recent              = true
  #     service_account_role_arn = module.adot_irsa.iam_role_arn
  #   }
  #   */
  #   # aws-guardduty-agent = {}
  # }

  access_entries = {
    # One access entry with a policy associated
    cluster-admin = {
      kubernetes_groups = []
      principal_arn     = var.eks_role_admin

      policy_associations = {
        cluster-admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }
}
