################################################################################
# EKS Cluster 1 - Capabilities (Argo CD, kro, ACK)
################################################################################
module "eks_cluster1" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.31"

  cluster_name                         = local.cluster1_name
  cluster_version                      = local.cluster_version
  cluster_endpoint_public_access       = true
  cluster_endpoint_private_access      = true
  cluster_endpoint_public_access_cidrs = var.allowed_public_cidrs

  enable_cluster_creator_admin_permissions = true

  iam_role_name            = "${local.cluster1_name}-cluster-role"
  iam_role_use_name_prefix = false

  vpc_id     = local.vpc_id_cluster1
  subnet_ids = local.private_subnets_nodes_cluster1

  # EKS Auto Mode
  cluster_compute_config = {
    enabled    = true
    node_pools = ["general-purpose", "system"]
    node_role_arn = aws_iam_role.auto_mode_node_role_cluster1.arn
  }

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
    vpc-cni = {
      most_recent = true
      before_compute = true
      configuration_values = jsonencode({
        env = {
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = "1"
        }
      })
    }
    eks-pod-identity-agent = {
      most_recent = true
    }
  }

  access_entries = {
    cluster-admin = {
      kubernetes_groups = []
      principal_arn     = var.eks_role_admin
      policy_associations = {
        cluster-admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = { type = "cluster" }
        }
      }
    }
  }

  tags = local.tags
}

################################################################################
# EKS Cluster 2 - CNOE DIY
################################################################################
module "eks_cluster2" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.31"

  cluster_name                         = local.cluster2_name
  cluster_version                      = local.cluster_version
  cluster_endpoint_public_access       = true
  cluster_endpoint_private_access      = true
  cluster_endpoint_public_access_cidrs = var.allowed_public_cidrs

  enable_cluster_creator_admin_permissions = true

  iam_role_name            = "${local.cluster2_name}-cluster-role"
  iam_role_use_name_prefix = false

  vpc_id     = local.vpc_id_cluster2
  subnet_ids = local.private_subnets_nodes_cluster2

  # EKS Auto Mode
  cluster_compute_config = {
    enabled    = true
    node_pools = ["general-purpose", "system"]
    node_role_arn = aws_iam_role.auto_mode_node_role_cluster2.arn
  }

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
    vpc-cni = {
      most_recent = true
      before_compute = true
      configuration_values = jsonencode({
        env = {
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = "1"
        }
      })
    }
    eks-pod-identity-agent = {
      most_recent = true
    }
  }

  access_entries = {
    cluster-admin = {
      kubernetes_groups = []
      principal_arn     = var.eks_role_admin
      policy_associations = {
        cluster-admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = { type = "cluster" }
        }
      }
    }
  }

  tags = local.tags
}

################################################################################
# EKS Cluster 3 - Apps Platform
################################################################################
module "eks_cluster3" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.31"

  cluster_name                         = local.cluster3_name
  cluster_version                      = local.cluster_version
  cluster_endpoint_public_access       = true
  cluster_endpoint_private_access      = true
  cluster_endpoint_public_access_cidrs = var.allowed_public_cidrs

  enable_cluster_creator_admin_permissions = true

  iam_role_name            = "${local.cluster3_name}-cluster-role"
  iam_role_use_name_prefix = false

  vpc_id     = local.vpc_id_cluster3
  subnet_ids = local.private_subnets_nodes_cluster3

  # EKS Auto Mode
  cluster_compute_config = {
    enabled    = true
    node_pools = ["general-purpose", "system"]
    node_role_arn = aws_iam_role.auto_mode_node_role_cluster3.arn
  }

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
    vpc-cni = {
      most_recent = true
      before_compute = true
      configuration_values = jsonencode({
        env = {
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = "1"
        }
      })
    }
    eks-pod-identity-agent = {
      most_recent = true
    }
  }

  access_entries = {
    cluster-admin = {
      kubernetes_groups = []
      principal_arn     = var.eks_role_admin
      policy_associations = {
        cluster-admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = { type = "cluster" }
        }
      }
    }
  }

  tags = local.tags
}

################################################################################
# EKS Auto Mode Node IAM Roles
# Auto Mode requires a node role with specific managed policies
################################################################################
resource "aws_iam_role" "auto_mode_node_role_cluster1" {
  name = "${local.cluster1_name}-auto-mode-node"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = local.tags
}

resource "aws_iam_role" "auto_mode_node_role_cluster2" {
  name = "${local.cluster2_name}-auto-mode-node"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = local.tags
}

resource "aws_iam_role" "auto_mode_node_role_cluster3" {
  name = "${local.cluster3_name}-auto-mode-node"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = local.tags
}

# Attach required managed policies to all node roles
locals {
  auto_mode_node_policies = [
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodeMinimalPolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
  ]

  node_roles = {
    cluster1 = aws_iam_role.auto_mode_node_role_cluster1.name
    cluster2 = aws_iam_role.auto_mode_node_role_cluster2.name
    cluster3 = aws_iam_role.auto_mode_node_role_cluster3.name
  }

  # Flatten for for_each
  node_role_policy_attachments = flatten([
    for cluster, role_name in local.node_roles : [
      for policy in local.auto_mode_node_policies : {
        key       = "${cluster}-${basename(policy)}"
        role_name = role_name
        policy    = policy
      }
    ]
  ])
}

resource "aws_iam_role_policy_attachment" "auto_mode_node_policies" {
  for_each   = { for item in local.node_role_policy_attachments : item.key => item }
  role       = each.value.role_name
  policy_arn = each.value.policy
}
