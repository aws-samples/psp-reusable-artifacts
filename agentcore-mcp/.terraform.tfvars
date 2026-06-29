# =============================================================================
# PSP Reusable Artifacts — AgentCore MCP (ArgoCD MCP Server)
# Single-account deployment: 970479985461
# =============================================================================

region = "us-east-1"

# ArgoCD server URL — get from bootstrap outputs after apply:
#   cd ../bootstrap && terraform output -raw argocd_server_url
argocd_server_url = "https://adab8563998d9486839bb55a2a1aee4cd6cf77ab95ab5dab0.eks-capabilities.us-east-1.amazonaws.com"  # TODO: fill after bootstrap apply

# ArgoCD API token — generate from ArgoCD UI:
#   Settings → Projects → default → Roles → JWT Tokens → Generate
argocd_api_token = "..."  # TODO: fill after generating token

# Tags
tags = {
  ManagedBy   = "terraform"
  Project     = "argocd-mcp"
  Environment = "workshop"
}
