provider "aws" {
  region = local.region
}

data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {}

locals {
  name        = var.name
  environment = var.environment
  region      = var.region
  azs         = slice(data.aws_availability_zones.available.names, 0, 3)

  # Three VPC CIDRs for the workshop clusters
  vpcs = {
    cluster1 = {
      name           = "${local.name}-cluster-1-capabilities"
      cidr           = "10.0.0.0/16"
      secondary_cidr = ["100.64.0.0/16"]
    }
    cluster2 = {
      name           = "${local.name}-cluster-2-cnoe-diy"
      cidr           = "10.1.0.0/16"
      secondary_cidr = ["100.65.0.0/16"]
    }
    cluster3 = {
      name           = "${local.name}-cluster-3-apps-platform"
      cidr           = "10.2.0.0/16"
      secondary_cidr = ["100.66.0.0/16"]
    }
  }

  tags = {
    Blueprint  = local.name
    GithubRepo = "github.com/aws-samples/psp-reusable-artifacts"
  }
}

################################################################################
# VPC 1 - Capabilities
################################################################################
module "vpc_cluster1" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = local.vpcs.cluster1.name
  cidr = local.vpcs.cluster1.cidr

  secondary_cidr_blocks = local.vpcs.cluster1.secondary_cidr

  azs = local.azs
  private_subnets = concat(
    [for k, v in local.azs : cidrsubnet(local.vpcs.cluster1.cidr, 4, k)],
    [for k, v in local.azs : cidrsubnet(element(local.vpcs.cluster1.secondary_cidr, 0), 4, k)],
  )
  public_subnets = [for k, v in local.azs : cidrsubnet(local.vpcs.cluster1.cidr, 8, k + 48)]

  enable_nat_gateway = true
  single_nat_gateway = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = local.tags
}

################################################################################
# VPC 2 - CNOE DIY
################################################################################
module "vpc_cluster2" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = local.vpcs.cluster2.name
  cidr = local.vpcs.cluster2.cidr

  secondary_cidr_blocks = local.vpcs.cluster2.secondary_cidr

  azs = local.azs
  private_subnets = concat(
    [for k, v in local.azs : cidrsubnet(local.vpcs.cluster2.cidr, 4, k)],
    [for k, v in local.azs : cidrsubnet(element(local.vpcs.cluster2.secondary_cidr, 0), 4, k)],
  )
  public_subnets = [for k, v in local.azs : cidrsubnet(local.vpcs.cluster2.cidr, 8, k + 48)]

  enable_nat_gateway = true
  single_nat_gateway = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = local.tags
}

################################################################################
# VPC 3 - Apps Platform
################################################################################
module "vpc_cluster3" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = local.vpcs.cluster3.name
  cidr = local.vpcs.cluster3.cidr

  secondary_cidr_blocks = local.vpcs.cluster3.secondary_cidr

  azs = local.azs
  private_subnets = concat(
    [for k, v in local.azs : cidrsubnet(local.vpcs.cluster3.cidr, 4, k)],
    [for k, v in local.azs : cidrsubnet(element(local.vpcs.cluster3.secondary_cidr, 0), 4, k)],
  )
  public_subnets = [for k, v in local.azs : cidrsubnet(local.vpcs.cluster3.cidr, 8, k + 48)]

  enable_nat_gateway = true
  single_nat_gateway = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = local.tags
}

################################################################################
# VPC Peering - Full Mesh (1<->2, 1<->3, 2<->3)
################################################################################
resource "aws_vpc_peering_connection" "cluster1_to_cluster2" {
  vpc_id      = module.vpc_cluster1.vpc_id
  peer_vpc_id = module.vpc_cluster2.vpc_id
  auto_accept = true

  accepter {
    allow_remote_vpc_dns_resolution = true
  }

  requester {
    allow_remote_vpc_dns_resolution = true
  }

  tags = merge(local.tags, { Name = "${local.name}-peering-c1-c2" })
}

resource "aws_vpc_peering_connection" "cluster1_to_cluster3" {
  vpc_id      = module.vpc_cluster1.vpc_id
  peer_vpc_id = module.vpc_cluster3.vpc_id
  auto_accept = true

  accepter {
    allow_remote_vpc_dns_resolution = true
  }

  requester {
    allow_remote_vpc_dns_resolution = true
  }

  tags = merge(local.tags, { Name = "${local.name}-peering-c1-c3" })
}

resource "aws_vpc_peering_connection" "cluster2_to_cluster3" {
  vpc_id      = module.vpc_cluster2.vpc_id
  peer_vpc_id = module.vpc_cluster3.vpc_id
  auto_accept = true

  accepter {
    allow_remote_vpc_dns_resolution = true
  }

  requester {
    allow_remote_vpc_dns_resolution = true
  }

  tags = merge(local.tags, { Name = "${local.name}-peering-c2-c3" })
}

################################################################################
# VPC Peering Routes - Full Mesh
################################################################################

# Cluster1 -> Cluster2 routes (all private route tables)
resource "aws_route" "cluster1_to_cluster2" {
  count                     = length(module.vpc_cluster1.private_route_table_ids)
  route_table_id            = module.vpc_cluster1.private_route_table_ids[count.index]
  destination_cidr_block    = local.vpcs.cluster2.cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.cluster1_to_cluster2.id
}

resource "aws_route" "cluster2_to_cluster1" {
  count                     = length(module.vpc_cluster2.private_route_table_ids)
  route_table_id            = module.vpc_cluster2.private_route_table_ids[count.index]
  destination_cidr_block    = local.vpcs.cluster1.cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.cluster1_to_cluster2.id
}

# Cluster1 -> Cluster3 routes
resource "aws_route" "cluster1_to_cluster3" {
  count                     = length(module.vpc_cluster1.private_route_table_ids)
  route_table_id            = module.vpc_cluster1.private_route_table_ids[count.index]
  destination_cidr_block    = local.vpcs.cluster3.cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.cluster1_to_cluster3.id
}

resource "aws_route" "cluster3_to_cluster1" {
  count                     = length(module.vpc_cluster3.private_route_table_ids)
  route_table_id            = module.vpc_cluster3.private_route_table_ids[count.index]
  destination_cidr_block    = local.vpcs.cluster1.cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.cluster1_to_cluster3.id
}

# Cluster2 -> Cluster3 routes
resource "aws_route" "cluster2_to_cluster3" {
  count                     = length(module.vpc_cluster2.private_route_table_ids)
  route_table_id            = module.vpc_cluster2.private_route_table_ids[count.index]
  destination_cidr_block    = local.vpcs.cluster3.cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.cluster2_to_cluster3.id
}

resource "aws_route" "cluster3_to_cluster2" {
  count                     = length(module.vpc_cluster3.private_route_table_ids)
  route_table_id            = module.vpc_cluster3.private_route_table_ids[count.index]
  destination_cidr_block    = local.vpcs.cluster2.cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.cluster2_to_cluster3.id
}
