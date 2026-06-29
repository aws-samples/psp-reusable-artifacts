data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
}

################################################################################
# ECR Repository
################################################################################

resource "aws_ecr_repository" "argocd_mcp" {
  name                 = "argocd-mcp"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = var.tags
}

################################################################################
# Secrets Manager — ArgoCD API Token
################################################################################

resource "aws_secretsmanager_secret" "argocd_api_token" {
  name                    = "argocd-mcp/api-token"
  description             = "ArgoCD API token for the MCP server on AgentCore"
  recovery_window_in_days = 0
  tags                    = var.tags
}

resource "aws_secretsmanager_secret_version" "argocd_api_token" {
  secret_id     = aws_secretsmanager_secret.argocd_api_token.id
  secret_string = var.argocd_api_token
}

################################################################################
# CodeBuild — Build & Push ARM64 Docker image
################################################################################

resource "aws_iam_role" "codebuild" {
  name = "codebuild-argocd-mcp"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "codebuild.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "codebuild" {
  name = "codebuild-argocd-mcp-policy"
  role = aws_iam_role.codebuild.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.region}:${local.account_id}:*"
      },
      {
        Sid      = "ECRAuth"
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        Sid    = "ECRPush"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = [aws_ecr_repository.argocd_mcp.arn]
      }
    ]
  })
}

resource "aws_codebuild_project" "argocd_mcp_build" {
  name         = "argocd-mcp-build"
  description  = "Build ArgoCD MCP ARM64 Docker image and push to ECR"
  service_role = aws_iam_role.codebuild.arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-aarch64-standard:3.0"
    type                        = "ARM_CONTAINER"
    privileged_mode             = true
    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "ECR_URL"
      value = aws_ecr_repository.argocd_mcp.repository_url
    }
    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = var.region
    }
  }

  source {
    type      = "NO_SOURCE"
    buildspec = <<-BUILDSPEC
      version: 0.2
      phases:
        pre_build:
          commands:
            - aws ecr get-login-password --region $AWS_DEFAULT_REGION | docker login --username AWS --password-stdin $ECR_URL
        build:
          commands:
            - git clone --depth 1 https://github.com/argoproj-labs/mcp-for-argocd.git repo
            - echo "$DOCKERFILE_CONTENT" | base64 -d > repo/Dockerfile
            - echo "$ENTRYPOINT_CONTENT" | base64 -d > repo/entrypoint.sh
            - chmod +x repo/entrypoint.sh
            - docker build -t $ECR_URL:latest repo/
        post_build:
          commands:
            - docker push $ECR_URL:latest
    BUILDSPEC
  }

  tags = var.tags
}

resource "null_resource" "argocd_mcp_build_trigger" {
  depends_on = [
    aws_ecr_repository.argocd_mcp,
    aws_codebuild_project.argocd_mcp_build,
  ]

  triggers = {
    dockerfile_hash = filesha256("${path.module}/docker/argocd-mcp/Dockerfile")
    entrypoint_hash = filesha256("${path.module}/docker/argocd-mcp/entrypoint.sh")
    ecr_url         = aws_ecr_repository.argocd_mcp.repository_url
  }

  provisioner "local-exec" {
    environment = {
      AWS_PROFILE = var.aws_profile
    }
    interpreter = ["bash", "-c"]
    command     = <<-EOT
      set -e

      REGION="${var.region}"
      PROJECT_NAME="${aws_codebuild_project.argocd_mcp_build.name}"

      DOCKERFILE_B64=$(base64 < ${path.module}/docker/argocd-mcp/Dockerfile)
      ENTRYPOINT_B64=$(base64 < ${path.module}/docker/argocd-mcp/entrypoint.sh)

      echo "==> Starting CodeBuild project $PROJECT_NAME..."
      BUILD_ID=$(aws codebuild start-build \
        --project-name "$PROJECT_NAME" \
        --region "$REGION" \
        --environment-variables-override \
          "name=DOCKERFILE_CONTENT,value=$DOCKERFILE_B64,type=PLAINTEXT" \
          "name=ENTRYPOINT_CONTENT,value=$ENTRYPOINT_B64,type=PLAINTEXT" \
        --query 'build.id' --output text)

      echo "==> Build started: $BUILD_ID"
      echo "==> Waiting for build to complete..."

      while true; do
        STATUS=$(aws codebuild batch-get-builds \
          --ids "$BUILD_ID" \
          --region "$REGION" \
          --query 'builds[0].buildStatus' --output text)

        case "$STATUS" in
          SUCCEEDED)
            echo "==> Build succeeded!"
            break
            ;;
          FAILED|FAULT|STOPPED|TIMED_OUT)
            echo "==> Build failed with status: $STATUS"
            LOG_URL=$(aws codebuild batch-get-builds \
              --ids "$BUILD_ID" \
              --region "$REGION" \
              --query 'builds[0].logs.deepLink' --output text)
            echo "==> Build logs: $LOG_URL"
            exit 1
            ;;
          *)
            echo "    Status: $STATUS — waiting 15s..."
            sleep 15
            ;;
        esac
      done
    EOT
  }
}
