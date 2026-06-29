################################################################################
# Cognito — OAuth for AgentCore MCP endpoint
################################################################################
# Uses client_credentials grant (M2M) for the AWS DevOps Agent.
# No users needed — the agent authenticates with client ID + secret.
################################################################################

resource "aws_cognito_user_pool" "argocd_mcp" {
  name = "argocd-mcp-auth"

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = false
    require_uppercase = true
  }

  admin_create_user_config {
    allow_admin_create_user_only = true
  }

  tags = var.tags
}

resource "aws_cognito_user_pool_domain" "argocd_mcp" {
  domain       = "argocd-mcp-${local.account_id}"
  user_pool_id = aws_cognito_user_pool.argocd_mcp.id
}

resource "aws_cognito_resource_server" "argocd_mcp" {
  identifier   = "argocd-mcp"
  name         = "ArgoCD MCP Server"
  user_pool_id = aws_cognito_user_pool.argocd_mcp.id

  scope {
    scope_name        = "invoke"
    scope_description = "Invoke the ArgoCD MCP server"
  }
}

resource "aws_cognito_user_pool_client" "argocd_mcp" {
  name         = "argocd-mcp-client"
  user_pool_id = aws_cognito_user_pool.argocd_mcp.id

  generate_secret = true

  allowed_oauth_flows                  = ["client_credentials"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_scopes                 = ["argocd-mcp/invoke"]

  supported_identity_providers = ["COGNITO"]

  depends_on = [aws_cognito_resource_server.argocd_mcp]
}
