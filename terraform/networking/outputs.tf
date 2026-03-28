# Cluster 1 - Capabilities
output "vpc_id_cluster1" {
  description = "VPC ID for Cluster 1 (Capabilities)"
  value       = module.vpc_cluster1.vpc_id
}

output "private_subnets_nodes_cluster1" {
  description = "Private subnet IDs for nodes - Cluster 1"
  value       = slice(module.vpc_cluster1.private_subnets, 0, 3)
}

output "private_subnets_pods_cluster1" {
  description = "Private subnet IDs for pods (RFC6598) - Cluster 1"
  value       = slice(module.vpc_cluster1.private_subnets, 3, 6)
}

output "public_subnets_cluster1" {
  description = "Public subnet IDs - Cluster 1"
  value       = module.vpc_cluster1.public_subnets
}

# Cluster 2 - CNOE DIY
output "vpc_id_cluster2" {
  description = "VPC ID for Cluster 2 (CNOE DIY)"
  value       = module.vpc_cluster2.vpc_id
}

output "private_subnets_nodes_cluster2" {
  description = "Private subnet IDs for nodes - Cluster 2"
  value       = slice(module.vpc_cluster2.private_subnets, 0, 3)
}

output "private_subnets_pods_cluster2" {
  description = "Private subnet IDs for pods (RFC6598) - Cluster 2"
  value       = slice(module.vpc_cluster2.private_subnets, 3, 6)
}

output "public_subnets_cluster2" {
  description = "Public subnet IDs - Cluster 2"
  value       = module.vpc_cluster2.public_subnets
}

# Cluster 3 - Apps Platform
output "vpc_id_cluster3" {
  description = "VPC ID for Cluster 3 (Apps Platform)"
  value       = module.vpc_cluster3.vpc_id
}

output "private_subnets_nodes_cluster3" {
  description = "Private subnet IDs for nodes - Cluster 3"
  value       = slice(module.vpc_cluster3.private_subnets, 0, 3)
}

output "private_subnets_pods_cluster3" {
  description = "Private subnet IDs for pods (RFC6598) - Cluster 3"
  value       = slice(module.vpc_cluster3.private_subnets, 3, 6)
}

output "public_subnets_cluster3" {
  description = "Public subnet IDs - Cluster 3"
  value       = module.vpc_cluster3.public_subnets
}

# Peering connections
output "peering_c1_c2" {
  description = "VPC Peering Connection ID between Cluster 1 and Cluster 2"
  value       = aws_vpc_peering_connection.cluster1_to_cluster2.id
}

output "peering_c1_c3" {
  description = "VPC Peering Connection ID between Cluster 1 and Cluster 3"
  value       = aws_vpc_peering_connection.cluster1_to_cluster3.id
}

output "peering_c2_c3" {
  description = "VPC Peering Connection ID between Cluster 2 and Cluster 3"
  value       = aws_vpc_peering_connection.cluster2_to_cluster3.id
}
