################################################################################
# Cluster 1 - Capabilities
################################################################################
output "configure_kubectl_cluster1" {
  description = "Configure kubectl for Cluster 1 (Capabilities)"
  value       = <<-EOT
    aws eks --region ${local.region} update-kubeconfig --name ${module.eks_cluster1.cluster_name} --alias cluster1
  EOT
}

output "cluster1_name" {
  description = "Cluster 1 name"
  value       = module.eks_cluster1.cluster_name
}

output "cluster1_endpoint" {
  description = "Cluster 1 endpoint"
  value       = module.eks_cluster1.cluster_endpoint
}

################################################################################
# Cluster 2 - CNOE DIY
################################################################################
output "configure_kubectl_cluster2" {
  description = "Configure kubectl for Cluster 2 (CNOE DIY)"
  value       = <<-EOT
    aws eks --region ${local.region} update-kubeconfig --name ${module.eks_cluster2.cluster_name} --alias cluster2
  EOT
}

output "cluster2_name" {
  description = "Cluster 2 name"
  value       = module.eks_cluster2.cluster_name
}

output "cluster2_endpoint" {
  description = "Cluster 2 endpoint"
  value       = module.eks_cluster2.cluster_endpoint
}

################################################################################
# Cluster 3 - Apps Platform
################################################################################
output "configure_kubectl_cluster3" {
  description = "Configure kubectl for Cluster 3 (Apps Platform)"
  value       = <<-EOT
    aws eks --region ${local.region} update-kubeconfig --name ${module.eks_cluster3.cluster_name} --alias cluster3
  EOT
}

output "cluster3_name" {
  description = "Cluster 3 name"
  value       = module.eks_cluster3.cluster_name
}

output "cluster3_endpoint" {
  description = "Cluster 3 endpoint"
  value       = module.eks_cluster3.cluster_endpoint
}

################################################################################
# ArgoCD Access (Cluster 1)
################################################################################
output "access_argocd" {
  description = "ArgoCD Access on Cluster 1"
  value       = <<-EOT
    aws eks --region ${local.region} update-kubeconfig --name ${module.eks_cluster1.cluster_name} --alias cluster1
    echo "ArgoCD URL: https://$(kubectl get svc -n argocd argo-cd-argocd-server --context cluster1 -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
    echo "ArgoCD Username: admin"
    echo "ArgoCD Password: $(kubectl get secrets argocd-initial-admin-secret -n argocd --context cluster1 --template="{{index .data.password | base64decode}}")"
  EOT
}

################################################################################
# Summary
################################################################################
output "workshop_clusters" {
  description = "All workshop cluster names"
  value = {
    capabilities  = module.eks_cluster1.cluster_name
    cnoe_diy      = module.eks_cluster2.cluster_name
    apps_platform = module.eks_cluster3.cluster_name
  }
}
