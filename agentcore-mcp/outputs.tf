output "argocd_mcp_runtime_arn" {
  description = "ARN of the ArgoCD MCP AgentCore Runtime"
  value       = aws_bedrockagentcore_agent_runtime.argocd_mcp.agent_runtime_arn
}

output "argocd_mcp_runtime_id" {
  description = "ID of the ArgoCD MCP AgentCore Runtime"
  value       = aws_bedrockagentcore_agent_runtime.argocd_mcp.agent_runtime_id
}

output "argocd_mcp_ecr_url" {
  description = "ECR repository URL for the ArgoCD MCP container image"
  value       = aws_ecr_repository.argocd_mcp.repository_url
}

output "argocd_mcp_token_secret_arn" {
  description = "Secrets Manager ARN — store the ArgoCD API token here"
  value       = aws_secretsmanager_secret.argocd_api_token.arn
}

################################################################################
# DevOps Agent Registration Values
################################################################################

output "devops_agent_client_id" {
  description = "ClientId — for DevOps Agent MCP registration"
  value       = aws_cognito_user_pool_client.argocd_mcp.id
}

output "devops_agent_client_secret" {
  description = "Secret — for DevOps Agent MCP registration"
  value       = aws_cognito_user_pool_client.argocd_mcp.client_secret
  sensitive   = true
}

output "devops_agent_exchange_url" {
  description = "Exchange URL — for DevOps Agent MCP registration"
  value       = "https://${aws_cognito_user_pool_domain.argocd_mcp.domain}.auth.${var.region}.amazoncognito.com/oauth2/token"
}

output "devops_agent_oauth_scopes" {
  description = "OAuth Scopes — for DevOps Agent MCP registration"
  value       = "argocd-mcp/invoke"
}

output "devops_agent_mcp_endpoint_url" {
  description = "MCP Endpoint URL — for DevOps Agent MCP registration"
  value       = "https://bedrock-agentcore.${var.region}.amazonaws.com/runtimes/${replace(replace(aws_bedrockagentcore_agent_runtime.argocd_mcp.agent_runtime_arn, ":", "%3A"), "/", "%2F")}/invocations?qualifier=DEFAULT"
}
