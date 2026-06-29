################################################################################
# control-plane-admin IAM Role
################################################################################
# This role is assumed by ACK pods via Pod Identity Association.
# It can ONLY sts:AssumeRole into spoke accounts within the Organization.
################################################################################

resource "aws_iam_role" "control_plane_admin" {
  name = "control-plane-admin"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowPodIdentity"
        Effect = "Allow"
        Principal = {
          Service = "pods.eks.amazonaws.com"
        }
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
      },
      {
        Sid    = "AllowEKSCapabilities"
        Effect = "Allow"
        Principal = {
          Service = "capabilities.eks.amazonaws.com"
        }
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "control_plane_admin_assume" {
  name = "cross-account-assume-role"
  role = aws_iam_role.control_plane_admin.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AssumeRoleInOrgAccounts"
        Effect = "Allow"
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
        Resource = "arn:aws:iam::*:role/control-plane-execution"
      }
    ]
  })
}

################################################################################
# Pod Identity Association — ACK uses control-plane-admin
################################################################################

resource "aws_eks_pod_identity_association" "ack" {
  cluster_name    = module.eks.cluster_name
  namespace       = "ack-system"
  service_account = "ack-controller"
  role_arn        = aws_iam_role.control_plane_admin.arn

  tags = var.tags
}
