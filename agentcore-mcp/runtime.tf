################################################################################
# IAM — AgentCore execution role
################################################################################

data "aws_iam_policy_document" "agentcore_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["bedrock-agentcore.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:bedrock-agentcore:${var.region}:${local.account_id}:*"]
    }
  }
}

data "aws_iam_policy_document" "agentcore_permissions" {
  statement {
    sid       = "ECRAuth"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid    = "ECRPull"
    effect = "Allow"
    actions = [
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer"
    ]
    resources = [aws_ecr_repository.argocd_mcp.arn]
  }

  statement {
    sid    = "SecretsManagerRead"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue"
    ]
    resources = [aws_secretsmanager_secret.argocd_api_token.arn]
  }

  statement {
    sid    = "LogsCreateGroup"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:DescribeLogStreams"
    ]
    resources = [
      "arn:aws:logs:${var.region}:${local.account_id}:log-group:/aws/bedrock-agentcore/runtimes/*"
    ]
  }

  statement {
    sid     = "LogsDescribeGroups"
    effect  = "Allow"
    actions = ["logs:DescribeLogGroups"]
    resources = [
      "arn:aws:logs:${var.region}:${local.account_id}:log-group:*"
    ]
  }

  statement {
    sid    = "LogsWrite"
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "arn:aws:logs:${var.region}:${local.account_id}:log-group:/aws/bedrock-agentcore/runtimes/*:log-stream:*"
    ]
  }

  statement {
    sid    = "XRay"
    effect = "Allow"
    actions = [
      "xray:PutTraceSegments",
      "xray:PutTelemetryRecords",
      "xray:GetSamplingRules",
      "xray:GetSamplingTargets"
    ]
    resources = ["*"]
  }

  statement {
    sid       = "CloudWatchMetrics"
    effect    = "Allow"
    actions   = ["cloudwatch:PutMetricData"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "cloudwatch:namespace"
      values   = ["bedrock-agentcore"]
    }
  }
}

resource "aws_iam_role" "agentcore_argocd_mcp" {
  name               = "agentcore-argocd-mcp-execution"
  assume_role_policy = data.aws_iam_policy_document.agentcore_assume_role.json
  tags               = var.tags
}

resource "aws_iam_role_policy" "agentcore_argocd_mcp" {
  name   = "agentcore-argocd-mcp-permissions"
  role   = aws_iam_role.agentcore_argocd_mcp.id
  policy = data.aws_iam_policy_document.agentcore_permissions.json
}

################################################################################
# AgentCore Runtime — ArgoCD MCP Server
################################################################################

resource "aws_bedrockagentcore_agent_runtime" "argocd_mcp" {
  agent_runtime_name = "argocd_mcp_server"
  description        = "ArgoCD MCP Server - AI-assisted GitOps management via MCP protocol"
  role_arn           = aws_iam_role.agentcore_argocd_mcp.arn

  agent_runtime_artifact {
    container_configuration {
      container_uri = "${aws_ecr_repository.argocd_mcp.repository_url}:latest"
    }
  }

  environment_variables = {
    ARGOCD_BASE_URL             = var.argocd_server_url
    ARGOCD_API_TOKEN_SECRET_ARN = aws_secretsmanager_secret.argocd_api_token.arn
    AWS_REGION                  = var.region
    MCP_READ_ONLY               = "true"
  }

  authorizer_configuration {
    custom_jwt_authorizer {
      discovery_url   = "https://cognito-idp.${var.region}.amazonaws.com/${aws_cognito_user_pool.argocd_mcp.id}/.well-known/openid-configuration"
      allowed_clients = [aws_cognito_user_pool_client.argocd_mcp.id]
    }
  }

  network_configuration {
    network_mode = "PUBLIC"
  }

  protocol_configuration {
    server_protocol = "MCP"
  }

  tags = var.tags

  depends_on = [
    null_resource.argocd_mcp_build_trigger,
  ]
}
