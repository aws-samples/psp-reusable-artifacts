provider "aws" {
  region = local.region
  # alias  = "controlplane"

  assume_role {
    role_arn    = data.terraform_remote_state.platform-execution-role.outputs.role_arn
    external_id = "terraforSession-controlplane"
  }
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
      args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", local.region, "--role-arn", data.terraform_remote_state.platform-execution-role.outputs.role_arn]
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
    args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", local.region, "--role-arn", data.terraform_remote_state.platform-execution-role.outputs.role_arn]
  }
}

data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}
provider "kubectl" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  load_config_file       = false
  token                  = data.aws_eks_cluster_auth.this.token
}

/*
data "aws_route53_zone" "domain_name" {
  name         = "example.com"
  private_zone = false
}
*/

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
