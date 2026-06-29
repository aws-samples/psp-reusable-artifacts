output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_arn" {
  description = "EKS cluster ARN"
  value       = module.eks.cluster_arn
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "control_plane_admin_role_arn" {
  description = "ARN of the control-plane-admin role (used by ACK pods)"
  value       = aws_iam_role.control_plane_admin.arn
}

output "capability_role_arn" {
  description = "ARN of the role used by all capabilities (control-plane-admin)"
  value       = aws_iam_role.control_plane_admin.arn
}

output "capability_ack_arn" {
  description = "ARN of the ACK capability"
  value       = aws_eks_capability.ack.arn
}

output "capability_kro_arn" {
  description = "ARN of the KRO capability"
  value       = aws_eks_capability.kro.arn
}

output "capability_argocd_arn" {
  description = "ARN of the ArgoCD capability"
  value       = aws_eks_capability.argocd.arn
}

output "codecommit_repository_name" {
  description = "CodeCommit repository name"
  value       = aws_codecommit_repository.this.repository_name
}

output "codecommit_clone_url_http" {
  description = "CodeCommit HTTPS clone URL"
  value       = aws_codecommit_repository.this.clone_url_http
}

output "codecommit_clone_url_ssh" {
  description = "CodeCommit SSH clone URL"
  value       = aws_codecommit_repository.this.clone_url_ssh
}

output "codecommit_arn" {
  description = "CodeCommit repository ARN"
  value       = aws_codecommit_repository.this.arn
}

################################################################################
# Credit Card Pipeline Outputs
################################################################################

output "credit_card_java_repo_name" {
  description = "CodeCommit repository name for credit-card-java"
  value       = aws_codecommit_repository.credit_card_java.repository_name
}

output "credit_card_java_repo_clone_url" {
  description = "CodeCommit HTTPS clone URL for credit-card-java"
  value       = aws_codecommit_repository.credit_card_java.clone_url_http
}

output "credit_card_data_plane_repo_name" {
  description = "CodeCommit repository name for credit-card-data-plane"
  value       = aws_codecommit_repository.credit_card_data_plane.repository_name
}

output "credit_card_data_plane_repo_clone_url" {
  description = "CodeCommit HTTPS clone URL for credit-card-data-plane"
  value       = aws_codecommit_repository.credit_card_data_plane.clone_url_http
}

output "credit_card_ecr_url" {
  description = "ECR repository URL for credit-card Docker image"
  value       = aws_ecr_repository.credit_card_java.repository_url
}

output "credit_card_chart_ecr_url" {
  description = "ECR repository URL for credit-card Helm chart"
  value       = aws_ecr_repository.credit_card_java.repository_url
}

output "credit_card_pipeline_name" {
  description = "CodePipeline name for credit-card CI/CD"
  value       = aws_codepipeline.credit_card.name
}

################################################################################
# ArgoCD Server URL (needed for agentcore-mcp module)
################################################################################

output "argocd_server_url" {
  description = "ArgoCD server URL from the EKS capability (use this to access the ArgoCD UI and generate API tokens)"
  value       = aws_eks_capability.argocd.configuration[0].argo_cd[0].server_url
}
