provider "aws" {
  region = local.region
  # alias  = "controlplaneaccount"
}
# Find the user currently in use by AWS
data "aws_caller_identity" "current" {}
# Availability zones to use in our solution
data "aws_availability_zones" "available" {
  state = "available"
}

# provider "aws" {
#   region = data.aws_region.current.name
#   assume_role {
#     role_arn     = "arn:aws:iam::${var.MANAGEMENTACCOUNTID}:role/GithubActionsRole-CreatePermissionSets"
#   }
#   alias = "mgmt-account"
# }

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

provider "kubectl" {
  apply_retry_count      = 10
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  load_config_file       = false
  token                  = data.aws_eks_cluster_auth.this.token
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", local.region]
  }
}
data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}

# resource "aws_s3_bucket" "s3Bucket" {
#     bucket = "mybucket1234332412348676"
#     tags = {
#         Owner = "Dev"
#   }
# }

# resource "aws_s3_bucket_policy" "allow_access_from_another_account" {
#   bucket = aws_s3_bucket.s3Bucket.id
#   policy = data.aws_iam_policy_document.allow_access_from_another_account.json
# }

# data "aws_iam_policy_document" "allow_access_from_another_account" {
#   statement {
#     principals {
#       type        = "AWS"
#       identifiers = ["671273807786"]
#     }

#     actions = [
#       "s3:GetObject",
#       "s3:ListBucket",
#     ]

#     resources = [
#       aws_s3_bucket.s3Bucket.arn,
#       "${aws_s3_bucket.s3Bucket.arn}/*",
#     ]
#   }
# }
