locals {
  name        = var.name
  environment = var.environment
  region      = var.region

  cluster_version = var.kubernetes_version

  # Cluster names aligned with workshop contentspec
  cluster1_name = "${local.name}-cluster-1-capabilities"
  cluster2_name = "${local.name}-cluster-2-cnoe-diy"
  cluster3_name = "${local.name}-cluster-3-apps-platform"

  # Networking from remote state
  vpc_id_cluster1                = data.terraform_remote_state.networking.outputs.vpc_id_cluster1
  vpc_id_cluster2                = data.terraform_remote_state.networking.outputs.vpc_id_cluster2
  vpc_id_cluster3                = data.terraform_remote_state.networking.outputs.vpc_id_cluster3
  private_subnets_nodes_cluster1 = data.terraform_remote_state.networking.outputs.private_subnets_nodes_cluster1
  private_subnets_nodes_cluster2 = data.terraform_remote_state.networking.outputs.private_subnets_nodes_cluster2
  private_subnets_nodes_cluster3 = data.terraform_remote_state.networking.outputs.private_subnets_nodes_cluster3
  private_subnets_pods_cluster1  = data.terraform_remote_state.networking.outputs.private_subnets_pods_cluster1
  private_subnets_pods_cluster2  = data.terraform_remote_state.networking.outputs.private_subnets_pods_cluster2
  private_subnets_pods_cluster3  = data.terraform_remote_state.networking.outputs.private_subnets_pods_cluster3

  azs = slice(data.aws_availability_zones.available.names, 0, 3)

  tags = {
    Blueprint = local.name
  }
}
