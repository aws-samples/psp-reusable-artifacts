output "configure_kubectl" {
  description = "Configure kubectl: make sure you're logged in with the correct AWS profile and run the following command to update your kubeconfig"
  value       = <<-EOT
    export KUBECONFIG="/tmp/${module.eks.cluster_name}"
    aws eks --region ${local.region} update-kubeconfig --name ${module.eks.cluster_name}
  EOT
}

output "access_argocd" {
  description = "ArgoCD Access"
  value       = <<-EOT
    export KUBECONFIG="/tmp/${module.eks.cluster_name}"
    aws eks --region ${local.region} update-kubeconfig --name ${module.eks.cluster_name}
    echo "ArgoCD URL: https://$(kubectl get svc -n argocd argo-cd-argocd-server -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
    echo "ArgoCD Username: admin"
    echo "ArgoCD Password: $(kubectl get secrets argocd-initial-admin-secret -n argocd --template="{{index .data.password | base64decode}}")"
    EOT
}

output "access_grafana" {
  description = "Grafana Access"
  value       = <<-EOT
    export KUBECONFIG="/tmp/${module.eks.cluster_name}"
    aws eks --region ${local.region} update-kubeconfig --name ${module.eks.cluster_name}
    echo "Grafana Username: admin"
    echo "Grafana Password: $(kubectl get secret kube-prometheus-stack-grafana -n kube-prometheus-stack --template='{{ index .data "admin-password" | base64decode }}')"
    echo "Grafana URL: https://$(kubectl get svc -n kube-prometheus-stack kube-prometheus-stack-grafana -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
    EOT
}

# output "argocd_iam_role_arn" {
#   description = "IAM Role for ArgoCD Cluster Hub, use to connect to spoke clusters"
#   value       = module.argocd_irsa.iam_role_arn
# }

output "cluster_name" {
  description = "Cluster controlplane name"
  value       = module.eks.cluster_name
}
output "cluster_endpoint" {
  description = "Cluster controlplane endpoint"
  value       = module.eks.cluster_endpoint
}
output "cluster_certificate_authority_data" {
  description = "Cluster controlplane certificate_authority_data"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}
output "cluster_region" {
  description = "Cluster controlplane region"
  value       = local.region
}
