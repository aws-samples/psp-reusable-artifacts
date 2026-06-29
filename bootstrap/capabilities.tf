################################################################################
# Policies on control-plane-admin for EKS Capabilities
################################################################################
# The control-plane-admin role (defined in iam.tf) is used by all capabilities.
# It already has sts:AssumeRole for spoke accounts.
# Here we add the additional policies needed by ArgoCD and capabilities.
################################################################################

resource "aws_iam_role_policy_attachment" "admin_eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.control_plane_admin.name
}

# ArgoCD needs to pull from CodeCommit in this account
resource "aws_iam_role_policy" "admin_codecommit" {
  name = "codecommit-readonly"
  role = aws_iam_role.control_plane_admin.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CodeCommitReadOnly"
        Effect = "Allow"
        Action = [
          "codecommit:GitPull",
          "codecommit:GetRepository",
          "codecommit:GetBranch",
          "codecommit:ListRepositories"
        ]
        Resource = "arn:aws:codecommit:${var.region}:${local.account_id}:*"
      }
    ]
  })
}

# ArgoCD needs ECR access to pull OCI Helm charts
resource "aws_iam_role_policy" "admin_ecr" {
  name = "ecr-pull-charts"
  role = aws_iam_role.control_plane_admin.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ECRAuth"
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        Sid    = "ECRPullCharts"
        Effect = "Allow"
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability"
        ]
        Resource = "arn:aws:ecr:${var.region}:${local.account_id}:repository/*"
      }
    ]
  })
}

# Wait for IAM role trust policy to propagate
resource "time_sleep" "wait_for_iam" {
  depends_on      = [aws_iam_role.control_plane_admin, aws_iam_role_policy_attachment.admin_eks_cluster_policy]
  create_duration = "15s"
}

################################################################################
# EKS Capabilities (ACK, KRO, ArgoCD)
################################################################################

resource "aws_eks_capability" "ack" {
  cluster_name              = module.eks.cluster_name
  capability_name           = "${var.cluster_name}-ack"
  type                      = "ACK"
  role_arn                  = aws_iam_role.control_plane_admin.arn
  delete_propagation_policy = "RETAIN"

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-ack"
  })

  depends_on = [module.eks, time_sleep.wait_for_iam]

  timeouts {
    create = "30m"
    update = "30m"
    delete = "30m"
  }
}

resource "aws_eks_capability" "kro" {
  cluster_name              = module.eks.cluster_name
  capability_name           = "${var.cluster_name}-kro"
  type                      = "KRO"
  role_arn                  = aws_iam_role.control_plane_admin.arn
  delete_propagation_policy = "RETAIN"

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-kro"
  })

  depends_on = [module.eks, time_sleep.wait_for_iam]

  timeouts {
    create = "30m"
    update = "30m"
    delete = "30m"
  }
}

resource "aws_eks_capability" "argocd" {
  cluster_name              = module.eks.cluster_name
  capability_name           = "${var.cluster_name}-argocd"
  type                      = "ARGOCD"
  role_arn                  = aws_iam_role.control_plane_admin.arn
  delete_propagation_policy = "RETAIN"

  configuration {
    argo_cd {
      aws_idc {
        idc_instance_arn = var.idc_instance_arn
      }
      namespace = "argocd"

      rbac_role_mapping {
        role = "ADMIN"
        identity {
          id   = var.argocd_admin_group_id
          type = "SSO_GROUP"
        }
      }

      rbac_role_mapping {
        role = "VIEWER"
        identity {
          id   = var.argocd_readonly_group_id
          type = "SSO_GROUP"
        }
      }
    }
  }

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-argocd"
  })

  depends_on = [module.eks, time_sleep.wait_for_iam]

  timeouts {
    create = "30m"
    update = "30m"
    delete = "30m"
  }
}

################################################################################
# Access Entry — control-plane-admin gets cluster-admin
################################################################################

resource "aws_eks_access_entry" "admin" {
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_iam_role.control_plane_admin.arn
  type          = "STANDARD"

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-admin-access"
  })
}

resource "aws_eks_access_policy_association" "admin_cluster_admin" {
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_iam_role.control_plane_admin.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.admin]
}
