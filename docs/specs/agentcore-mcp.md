# Spec: Deploy ArgoCD MCP Server on AWS Bedrock AgentCore

## Context & Architecture

The `argocd-mcp` npm package (from `argoproj-labs/mcp-for-argocd`) is a Node.js TypeScript server that supports `stdio`, `sse`, and `http` (streamable-HTTP) transports. The `http` transport already listens on `/mcp` — which is exactly what AgentCore MCP protocol expects. However, it defaults to port `3000`, while AgentCore MCP requires port `8000`.

The ArgoCD EKS Capability exposes a server URL (obtainable via `aws eks describe-capability`) and supports API token authentication (generated from the ArgoCD UI). These two values (`ARGOCD_BASE_URL` and `ARGOCD_API_TOKEN`) are the env vars the MCP server needs.

### Target Account

- **SYSOPS account**: Where AgentCore Runtime will be deployed
- **Hub account**: Where the EKS control-plane cluster and ArgoCD capability run

### ArgoCD MCP Source Code Analysis

- Repository: https://github.com/argoproj-labs/mcp-for-argocd
- Transport file: `src/server/transport.ts` — `connectHttpTransport()` uses `StreamableHTTPServerTransport` from `@modelcontextprotocol/sdk`, serves on `/mcp` path
- CLI: `src/cmd/cmd.ts` — `http` command accepts `--port` flag (default 3000)
- Existing Dockerfile: Uses `node:20-slim` (x86_64), exposes port 3000, runs `node dist/index.js http`
- Dependencies: `@modelcontextprotocol/sdk ^1.10.1`, `express ^5.1.0`, `yargs`, `zod`, `pino`, `dotenv`

### AgentCore MCP Protocol Requirements

- **Transport**: Stateless streamable-HTTP only
- **Host**: Container must listen on `0.0.0.0`
- **Port**: `8000`
- **Path**: `/mcp` (POST endpoint for MCP RPC messages)
- **Architecture**: ARM64 (`linux/arm64`)
- **Protocol messages**: `tools/list`, `tools/call`
- **Session**: Platform automatically adds `Mcp-Session-Id` header

---

## Phase 1: Obtain ArgoCD API Credentials

### 1.1 Get the ArgoCD Server URL

```bash
aws eks describe-capability \
  --cluster-name control-plane \
  --capability-name control-plane-argocd \
  --query 'capability.configuration.argoCd.serverUrl' \
  --output text \
  --region us-east-1
```

### 1.2 Generate an API Token

1. Navigate to the ArgoCD UI URL (from the EKS console → Capabilities tab)
2. Go to **Settings → Accounts → admin → Generate New Token**
3. Save the token securely — it will be stored as an environment variable in AgentCore

> **Note**: The EKS managed ArgoCD capability does not support `argocd login` or local users. Authentication is via AWS Identity Center. The API token must be generated from the UI.

---

## Phase 2: Build ARM64 Docker Container

The existing Dockerfile needs modifications for AgentCore compatibility:

| Requirement | Original | Modified |
|-------------|----------|----------|
| Architecture | x86_64 (node:20-slim) | ARM64 (--platform=linux/arm64) |
| Port | 3000 | 8000 |
| Path | /mcp | /mcp (no change) |
| Transport | http (streamable-HTTP) | http (no change) |

### 2.1 Custom Dockerfile

```dockerfile
FROM --platform=linux/arm64 node:20-slim AS base
ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
RUN corepack enable
COPY . /app
WORKDIR /app

FROM base AS prod-deps
RUN --mount=type=cache,id=pnpm,target=/pnpm/store pnpm install --prod --frozen-lockfile

FROM base AS build
RUN --mount=type=cache,id=pnpm,target=/pnpm/store pnpm install --frozen-lockfile
RUN pnpm run build

FROM --platform=linux/arm64 node:20-slim
ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
WORKDIR /app
COPY --from=prod-deps /app/node_modules /app/node_modules
COPY --from=build /app/dist /app/dist
COPY --from=build /app/package.json /app/package.json
EXPOSE 8000
CMD ["node", "dist/index.js", "http", "--port", "8000"]
```

### 2.2 Build & Push Commands

```bash
# Clone the argocd-mcp repo
git clone https://github.com/argoproj-labs/mcp-for-argocd.git
cd mcp-for-argocd

# Replace Dockerfile with the custom one above

# Setup docker buildx for cross-platform builds
docker buildx create --use

# Login to ECR in SYSOPS account
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin <SYSOPS_ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com

# Build ARM64 image and push to ECR
docker buildx build --platform linux/arm64 \
  -t <SYSOPS_ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/argocd-mcp:latest \
  --push .
```

---

## Phase 3: ECR Repository (SYSOPS Account)

### 3.1 Terraform Resource

```hcl
resource "aws_ecr_repository" "argocd_mcp" {
  name                 = "argocd-mcp"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = var.tags
}
```

---

## Phase 4: IAM Execution Role for AgentCore Runtime

AgentCore assumes this role to pull the ECR image and write logs.

### 4.1 Trust Policy

```hcl
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
      values   = [local.sysops_account_id]
    }
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:bedrock-agentcore:${var.region}:${local.sysops_account_id}:*"]
    }
  }
}
```

### 4.2 Permissions Policy

```hcl
data "aws_iam_policy_document" "agentcore_permissions" {
  # ECR auth token
  statement {
    sid       = "ECRAuth"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  # ECR image pull
  statement {
    sid     = "ECRPull"
    effect  = "Allow"
    actions = [
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer"
    ]
    resources = [aws_ecr_repository.argocd_mcp.arn]
  }

  # CloudWatch Logs
  statement {
    sid     = "LogsCreateGroup"
    effect  = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:DescribeLogStreams"
    ]
    resources = [
      "arn:aws:logs:${var.region}:${local.sysops_account_id}:log-group:/aws/bedrock-agentcore/runtimes/*"
    ]
  }

  statement {
    sid     = "LogsDescribeGroups"
    effect  = "Allow"
    actions = ["logs:DescribeLogGroups"]
    resources = [
      "arn:aws:logs:${var.region}:${local.sysops_account_id}:log-group:*"
    ]
  }

  statement {
    sid     = "LogsWrite"
    effect  = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "arn:aws:logs:${var.region}:${local.sysops_account_id}:log-group:/aws/bedrock-agentcore/runtimes/*:log-stream:*"
    ]
  }

  # X-Ray (observability)
  statement {
    sid     = "XRay"
    effect  = "Allow"
    actions = [
      "xray:PutTraceSegments",
      "xray:PutTelemetryRecords",
      "xray:GetSamplingRules",
      "xray:GetSamplingTargets"
    ]
    resources = ["*"]
  }

  # CloudWatch Metrics
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
```

### 4.3 Role Resource

```hcl
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
```

---

## Phase 5: Deploy AgentCore Runtime (Terraform)

Uses `aws_bedrockagentcore_agent_runtime` resource (AWS provider >= 6.37.0).

### 5.1 Variables

```hcl
variable "argocd_base_url" {
  description = "ArgoCD server URL from EKS capability (e.g. https://argocd.eks.us-east-1.amazonaws.com/...)"
  type        = string
  sensitive   = true
}

variable "argocd_api_token" {
  description = "ArgoCD API token generated from the ArgoCD UI"
  type        = string
  sensitive   = true
}
```

### 5.2 AgentCore Runtime Resource

```hcl
resource "aws_bedrockagentcore_agent_runtime" "argocd_mcp" {
  agent_runtime_name = "argocd_mcp_server"
  description        = "ArgoCD MCP Server — AI-assisted GitOps management via MCP protocol"
  role_arn           = aws_iam_role.agentcore_argocd_mcp.arn

  agent_runtime_artifact {
    container_configuration {
      container_uri = "${aws_ecr_repository.argocd_mcp.repository_url}:latest"
    }
  }

  environment_variables = {
    ARGOCD_BASE_URL  = var.argocd_base_url
    ARGOCD_API_TOKEN = var.argocd_api_token
    MCP_READ_ONLY    = "true"  # Safety: disable write operations initially
  }

  network_configuration {
    network_mode = "PUBLIC"
  }

  protocol_configuration {
    server_protocol = "MCP"
  }

  lifecycle_configuration {
    idle_runtime_session_timeout = 300   # 5 min idle timeout
    max_lifetime                 = 3600  # 1 hour max session
  }

  tags = var.tags
}
```

### 5.3 Outputs

```hcl
output "argocd_mcp_runtime_arn" {
  description = "ARN of the ArgoCD MCP AgentCore Runtime"
  value       = aws_bedrockagentcore_agent_runtime.argocd_mcp.agent_runtime_arn
}

output "argocd_mcp_runtime_id" {
  description = "ID of the ArgoCD MCP AgentCore Runtime"
  value       = aws_bedrockagentcore_agent_runtime.argocd_mcp.agent_runtime_id
}
```

---

## Phase 6: Authentication (Optional — Cognito OAuth)

By default, AgentCore uses SigV4 authentication. If you want OAuth-based access:

### 6.1 Cognito Resources

```hcl
resource "aws_cognito_user_pool" "argocd_mcp" {
  name = "argocd-mcp-pool"
  password_policy {
    minimum_length = 8
  }
}

resource "aws_cognito_user_pool_client" "argocd_mcp" {
  user_pool_id        = aws_cognito_user_pool.argocd_mcp.id
  name                = "argocd-mcp-client"
  explicit_auth_flows = ["ALLOW_USER_PASSWORD_AUTH", "ALLOW_REFRESH_TOKEN_AUTH"]
  generate_secret     = false
}
```

### 6.2 Add Authorizer to Runtime

```hcl
authorizer_configuration {
  custom_jwt_authorizer {
    discovery_url = "https://cognito-idp.${var.region}.amazonaws.com/${aws_cognito_user_pool.argocd_mcp.id}/.well-known/openid-configuration"
  }
}
```

> **Decision needed**: SigV4-only (simpler, default) vs Cognito OAuth (needed if non-AWS clients will invoke the MCP server).

---

## Phase 7: Testing & Invocation

### 7.1 Test with MCP Inspector

```bash
# Get the runtime ARN
AGENT_ARN=$(terraform output -raw argocd_mcp_runtime_arn)

# URL-encode the ARN
ENCODED_ARN=$(echo -n "$AGENT_ARN" | python3 -c "import sys,urllib.parse; print(urllib.parse.quote(sys.stdin.read(), safe=''))")

# Start MCP Inspector
npx @modelcontextprotocol/inspector

# In the Inspector UI:
# - Transport: Streamable HTTP
# - URL: https://bedrock-agentcore.us-east-1.amazonaws.com/runtimes/${ENCODED_ARN}/invocations?qualifier=DEFAULT
# - Auth header: Bearer <token>
```

### 7.2 Test with AWS CLI

```bash
aws bedrock-agentcore-runtime invoke-agent-runtime \
  --agent-runtime-id $(terraform output -raw argocd_mcp_runtime_id) \
  --qualifier DEFAULT \
  --payload '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' \
  --region us-east-1
```

### 7.3 Expected tools/list Response

The ArgoCD MCP server exposes these tools:
- `list_applications` — List and filter all applications
- `get_application` — Get detailed info about a specific application
- `create_application` — Create a new application (disabled if MCP_READ_ONLY=true)
- `update_application` — Update an existing application (disabled if MCP_READ_ONLY=true)
- `delete_application` — Delete an application (disabled if MCP_READ_ONLY=true)
- `sync_application` — Trigger sync (disabled if MCP_READ_ONLY=true)
- `get_application_resource_tree` — Get resource tree
- `get_application_managed_resources` — Get managed resources
- `get_application_workload_logs` — Get workload logs
- `get_resource_events` — Get resource events
- `get_resource_actions` — Get available resource actions
- `run_resource_action` — Run resource action (disabled if MCP_READ_ONLY=true)

---

## Resource Summary

| Resource | Account | Purpose |
|----------|---------|---------|
| ECR Repository (`argocd-mcp`) | SYSOPS | Store ARM64 container image |
| IAM Role (`agentcore-argocd-mcp-execution`) | SYSOPS | AgentCore execution role |
| IAM Role Policy | SYSOPS | ECR pull, CloudWatch, X-Ray permissions |
| AgentCore Runtime (`argocd_mcp_server`) | SYSOPS | MCP server deployment |
| Cognito User Pool (optional) | SYSOPS | OAuth authentication |

## Key Considerations

1. **No VPC peering needed**: The ArgoCD EKS Capability exposes a public HTTPS URL. AgentCore with `PUBLIC` network mode can reach it directly.
2. **Port mapping**: The `argocd-mcp` `http` transport serves on `/mcp` with streamable-HTTP — exactly what AgentCore MCP protocol expects. We only need to change the port from 3000 to 8000.
3. **API token security**: The `ARGOCD_API_TOKEN` is passed as an environment variable. For production, consider using AWS Secrets Manager with a custom entrypoint that fetches the secret at startup.
4. **Read-only mode**: `MCP_READ_ONLY=true` disables write operations (create, update, delete, sync). Remove this once you're confident in the setup.
5. **AWS provider version**: Must be `>= 6.37.0` for `aws_bedrockagentcore_agent_runtime`.
6. **ARM64 build**: The Docker image must be built for `linux/arm64`. Use `docker buildx` for cross-platform builds.

## Prerequisites Before Execution

1. **SYSOPS account ID** — needed for IAM ARNs
2. **ArgoCD server URL** — from `aws eks describe-capability` (Phase 1.1)
3. **ArgoCD API token** — generated from ArgoCD UI (Phase 1.2)
4. **Auth decision** — SigV4-only or Cognito OAuth (Phase 6)
