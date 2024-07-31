
# Here why these local variables and datasources are needed:
# https://docs.aws.amazon.com/singlesignon/latest/userguide/referencingpermissionsets.html
# https://repost.aws/knowledge-center/eks-configure-sso-user
# locals {
#   sso_role_prefix = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role"
# }

# data "aws_iam_roles" "admin" {
#   name_regex  = "AWSReservedSSO_EKSClusterAdmin_.*"
#   path_prefix = "/aws-reserved/sso.amazonaws.com/"

#   depends_on = [
#     aws_ssoadmin_account_assignment.operators,
#   ]
# }

# data "aws_iam_roles" "user" {
#   name_regex  = "AWSReservedSSO_EKSClusterUser_.*"
#   path_prefix = "/aws-reserved/sso.amazonaws.com/"

#   depends_on = [
#     aws_ssoadmin_account_assignment.developer
#   ]
# }

module "operators_team" {
  source  = "aws-ia/eks-blueprints-teams/aws"
  version = "1.1.0"


  name = "eks-operators"

  enable_admin = true
  cluster_arn  = module.eks.cluster_arn

  create_iam_role = false
  iam_role_arn    = "${local.sso_role_prefix}/${tolist(data.aws_iam_roles.admin.names)[0]}"
  principal_arns  = data.aws_iam_roles.admin.arns

  tags = {
    Environment = "dev"
  }

  depends_on = [
    data.aws_iam_roles.admin,
    data.aws_iam_roles.user
  ]

}

module "developers_team" {
  source  = "aws-ia/eks-blueprints-teams/aws"
  version = "1.1.0"

  name = "eks-developers"

  cluster_arn       = module.eks.cluster_arn
  oidc_provider_arn = module.eks.oidc_provider_arn

  create_iam_role = false
  iam_role_arn    = "${local.sso_role_prefix}/${tolist(data.aws_iam_roles.user.names)[0]}"
  principal_arns  = data.aws_iam_roles.user.arns

  tags = {
    Environment = "dev"
  }

  depends_on = [
    data.aws_iam_roles.admin,
    data.aws_iam_roles.user
  ]

}
