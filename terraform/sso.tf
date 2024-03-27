# Pre requisite
# Enable AWS IAM Identity Manager (https://console.aws.amazon.com/singlesignon/home/)

# provider "kubernetes" {
#   host                   = module.eks.cluster_endpoint
#   cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

#   exec {
#     api_version = "client.authentication.k8s.io/v1beta1"
#     command     = "aws"
#     # This requires the awscli to be installed locally where Terraform is executed
#     args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
#   }
# }

# data "aws_caller_identity" "current" {}

data "aws_ssoadmin_instances" "this" {}

resource "aws_ssoadmin_permission_set" "admin" {
  name             = "EKSClusterAdmin"
  description      = "Amazon EKS Cluster Admins."
  instance_arn     = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  relay_state      = "https://s3.console.aws.amazon.com/s3/home?region=us-west-2#"
  session_duration = "PT1H"
  provider = aws.mgmt-account
}

resource "aws_ssoadmin_permission_set" "user" {
  name             = "EKSClusterUser"
  description      = "Amazon EKS Cluster Users."
  instance_arn     = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  relay_state      = "https://s3.console.aws.amazon.com/s3/home?region=us-west-2#"
  session_duration = "PT1H"
  provider = aws.mgmt-account
}

data "aws_iam_policy_document" "admin" {
  statement {
    sid = "EKSAdmin"
    actions = [
      "eks:*"
    ]
    resources = [
      module.eks.cluster_arn
    ]
  }
  statement {
    sid = "AssumeRole"
    actions = [
      "sts:AssumeRole"
    ]
    resources = [
      "*"
    ]
  }
}

data "aws_iam_policy_document" "user" {
  statement {
    sid = "EKSRead"
    actions = [
      "eks:List*",
      "eks:Describe*",
      "eks:AccessKubernetesApi"
    ]
    resources = [
      module.eks.cluster_arn
    ]
  }

  statement {
    sid = "AssumeRole"
    actions = [
      "sts:AssumeRole"
    ]
    resources = [
      "*"
    ]
  }
}

resource "aws_ssoadmin_permission_set_inline_policy" "admin" {
  inline_policy      = data.aws_iam_policy_document.admin.json
  instance_arn       = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  permission_set_arn = aws_ssoadmin_permission_set.admin.arn
  provider = aws.mgmt-account 
}

resource "aws_ssoadmin_permission_set_inline_policy" "user" {
  inline_policy      = data.aws_iam_policy_document.user.json
  instance_arn       = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  permission_set_arn = aws_ssoadmin_permission_set.user.arn
  provider = aws.mgmt-account
}

resource "aws_ssoadmin_managed_policy_attachment" "admin" {
  instance_arn       = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  managed_policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
  permission_set_arn = aws_ssoadmin_permission_set.admin.arn
  provider = aws.mgmt-account
}

resource "aws_ssoadmin_managed_policy_attachment" "user" {
  instance_arn       = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  managed_policy_arn = "arn:aws:iam::aws:policy/job-function/ViewOnlyAccess"
  permission_set_arn = aws_ssoadmin_permission_set.user.arn
  provider = aws.mgmt-account
}

resource "aws_identitystore_group" "operators" {
  identity_store_id = tolist(data.aws_ssoadmin_instances.this.identity_store_ids)[0]
  display_name      = "eks-operators"
  description       = "EKS Operators Cluster Group"
  provider = aws.mgmt-account
}

resource "aws_identitystore_group" "developers" {
  identity_store_id = tolist(data.aws_ssoadmin_instances.this.identity_store_ids)[0]
  display_name      = "eks-developers"
  description       = "EKS Developers Cluster Group"
  provider = aws.mgmt-account
}

resource "aws_ssoadmin_account_assignment" "operators" {
  instance_arn       = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  permission_set_arn = aws_ssoadmin_permission_set.admin.arn

  principal_id   = aws_identitystore_group.operators.group_id
  principal_type = "GROUP"

  target_id   = data.aws_caller_identity.current.account_id
  target_type = "AWS_ACCOUNT"
  provider = aws.mgmt-account
}

resource "aws_ssoadmin_account_assignment" "developer" {
  instance_arn       = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  permission_set_arn = aws_ssoadmin_permission_set.user.arn

  principal_id   = aws_identitystore_group.developers.group_id
  principal_type = "GROUP"

  target_id   = data.aws_caller_identity.current.account_id
  target_type = "AWS_ACCOUNT"
  provider = aws.mgmt-account
}