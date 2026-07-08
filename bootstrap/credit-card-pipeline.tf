################################################################################
# Credit Card CI/CD Pipeline
################################################################################
# Flow:
# 1. Dev pushes Java code to credit-card-java → CodeBuild builds + pushes
#    Docker image to ECR
# 2. ECR image push triggers credit-card-data-plane CodeBuild → packages
#    Helm chart with new image tag → pushes chart OCI to ECR
# 3. Chart push triggers a CodeBuild that updates control-plane-operations
#    repo (applications/ folder) with the new chart version so ArgoCD rolls
#    it out to the cluster
################################################################################

locals {
  java_repo_name       = "credit-card-java"
  data_plane_repo_name = "credit-card-data-plane"
  java_ecr_name        = "credit-card"
  # The Helm chart is named "credit-card" in Chart.yaml, so `helm push` stores
  # it at <registry>/<basepath>/credit-card. We push under the "charts/"
  # basepath to keep the chart in its own ECR repo, separate from the Java
  # image repo (also "credit-card"). Otherwise chart + image collide and the
  # pipeline's describe-images picks the wrong artifact.
  chart_ecr_name       = "charts/credit-card"
}

################################################################################
# ECR Replication — replicate images to spoke accounts
################################################################################
# EKS Auto Mode nodes can only pull from ECR in their own account.
# This replication rule copies Docker images to the spoke account ECR
# so the kubelet can pull natively without cross-account auth.
################################################################################

resource "aws_ecr_replication_configuration" "cross_account" {
  count = var.enable_ecr_replication ? 1 : 0

  replication_configuration {
    rule {
      destination {
        region      = var.spoke_region
        registry_id = var.spoke_account_id
      }

      repository_filter {
        filter      = local.java_ecr_name
        filter_type = "PREFIX_MATCH"
      }
    }
  }
}

################################################################################
# ECR Repositories
################################################################################

resource "aws_ecr_repository" "credit_card_java" {
  name                 = local.java_ecr_name
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = var.tags
}

# Dedicated ECR repository for the packaged Helm chart (OCI). ECR does not
# create repositories on push, so it must exist before `helm push`.
resource "aws_ecr_repository" "credit_card_chart" {
  name                 = local.chart_ecr_name
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  tags = var.tags
}

resource "aws_ecr_repository_policy" "credit_card_java_cross_account" {
  repository = aws_ecr_repository.credit_card_java.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowOrgAccountsPull"
        Effect    = "Allow"
        Principal = "*"
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability"
        ]
        Condition = {
          StringEquals = {
            "aws:PrincipalOrgID" = var.organization_id
          }
        }
      },
      {
        Sid    = "AllowControlPlaneAdminPull"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.control_plane_admin.arn
        }
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability"
        ]
      }
    ]
  })
}

################################################################################
# CodeCommit Repositories
################################################################################

resource "aws_codecommit_repository" "credit_card_java" {
  repository_name = local.java_repo_name
  description     = "Credit Card Java application source code"
  tags            = var.tags
}

resource "aws_codecommit_repository" "credit_card_data_plane" {
  repository_name = local.data_plane_repo_name
  description     = "Credit Card Helm chart for data-plane deployment"
  tags            = var.tags
}

################################################################################
# IAM Role for CodeBuild
################################################################################

resource "aws_iam_role" "codebuild_credit_card" {
  name = "codebuild-credit-card"

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

resource "aws_iam_role_policy" "codebuild_credit_card" {
  name = "codebuild-credit-card-policy"
  role = aws_iam_role.codebuild_credit_card.id

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
          "ecr:CompleteLayerUpload",
          "ecr:DescribeImages"
        ]
        Resource = [
          aws_ecr_repository.credit_card_java.arn,
          aws_ecr_repository.credit_card_chart.arn
        ]
      },
      {
        Sid    = "CodeCommitPull"
        Effect = "Allow"
        Action = [
          "codecommit:GitPull",
          "codecommit:GetRepository",
          "codecommit:GetBranch",
          "codecommit:GetCommit"
        ]
        Resource = [
          aws_codecommit_repository.credit_card_java.arn,
          aws_codecommit_repository.credit_card_data_plane.arn,
          aws_codecommit_repository.this.arn
        ]
      },
      {
        Sid    = "CodeCommitPushOps"
        Effect = "Allow"
        Action = [
          "codecommit:GitPush",
          "codecommit:CreateCommit",
          "codecommit:GetBranch",
          "codecommit:GetCommit",
          "codecommit:PutFile",
          "codecommit:MergeBranchesByFastForward"
        ]
        Resource = aws_codecommit_repository.this.arn
      },
      {
        Sid    = "S3Artifacts"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:GetBucketAcl",
          "s3:GetBucketLocation"
        ]
        Resource = [
          "${aws_s3_bucket.pipeline_artifacts.arn}",
          "${aws_s3_bucket.pipeline_artifacts.arn}/*"
        ]
      },
      {
        Sid    = "StartBuild"
        Effect = "Allow"
        Action = "codebuild:StartBuild"
        Resource = [
          aws_codebuild_project.credit_card_java.arn,
          aws_codebuild_project.credit_card_chart.arn,
          aws_codebuild_project.credit_card_update_ops.arn
        ]
      }
    ]
  })
}

################################################################################
# IAM Role for CodePipeline
################################################################################

resource "aws_iam_role" "codepipeline_credit_card" {
  name = "codepipeline-credit-card"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "codepipeline.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "codepipeline_credit_card" {
  name = "codepipeline-credit-card-policy"
  role = aws_iam_role.codepipeline_credit_card.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CodeCommitSource"
        Effect = "Allow"
        Action = [
          "codecommit:GetBranch",
          "codecommit:GetCommit",
          "codecommit:UploadArchive",
          "codecommit:GetUploadArchiveStatus",
          "codecommit:CancelUploadArchive"
        ]
        Resource = aws_codecommit_repository.credit_card_java.arn
      },
      {
        Sid    = "CodeBuildTrigger"
        Effect = "Allow"
        Action = [
          "codebuild:BatchGetBuilds",
          "codebuild:StartBuild"
        ]
        Resource = [
          aws_codebuild_project.credit_card_java.arn,
          aws_codebuild_project.credit_card_chart.arn,
          aws_codebuild_project.credit_card_update_ops.arn
        ]
      },
      {
        Sid    = "S3Artifacts"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:GetBucketAcl",
          "s3:GetBucketLocation",
          "s3:GetBucketVersioning"
        ]
        Resource = [
          "${aws_s3_bucket.pipeline_artifacts.arn}",
          "${aws_s3_bucket.pipeline_artifacts.arn}/*"
        ]
      }
    ]
  })
}

################################################################################
# S3 Bucket for Pipeline Artifacts
################################################################################

resource "aws_s3_bucket" "pipeline_artifacts" {
  bucket        = "credit-card-pipeline-${local.account_id}-${var.region}"
  force_destroy = true
  tags          = var.tags
}

resource "aws_s3_bucket_server_side_encryption_configuration" "pipeline_artifacts" {
  bucket = aws_s3_bucket.pipeline_artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "pipeline_artifacts" {
  bucket                  = aws_s3_bucket.pipeline_artifacts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


################################################################################
# CodeBuild — Build Java Docker Image
################################################################################

resource "aws_codebuild_project" "credit_card_java" {
  name         = "credit-card-java-build"
  description  = "Build credit-card Java app and push Docker image to ECR"
  service_role = aws_iam_role.codebuild_credit_card.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = true
    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = local.account_id
    }
    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = var.region
    }
    environment_variable {
      name  = "ECR_REPO"
      value = aws_ecr_repository.credit_card_java.repository_url
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec.yml"
  }

  tags = var.tags
}

################################################################################
# CodeBuild — Package Helm Chart and Push to ECR
################################################################################

resource "aws_codebuild_project" "credit_card_chart" {
  name         = "credit-card-chart-build"
  description  = "Package credit-card Helm chart and push OCI image to ECR"
  service_role = aws_iam_role.codebuild_credit_card.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = true
    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = local.account_id
    }
    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = var.region
    }
    environment_variable {
      name  = "CHART_ECR_REPO"
      value = "${local.account_id}.dkr.ecr.${var.region}.amazonaws.com"
    }
    environment_variable {
      name  = "CHART_ECR_NAME"
      value = local.chart_ecr_name
    }
    environment_variable {
      name  = "IMAGE_ECR_REPO"
      value = "${var.spoke_account_id}.dkr.ecr.${var.spoke_region}.amazonaws.com/${local.java_ecr_name}"
    }
    environment_variable {
      name  = "DATA_PLANE_REPO"
      value = local.data_plane_repo_name
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = <<-BUILDSPEC
      version: 0.2
      phases:
        install:
          commands:
            - curl -fsSL https://get.helm.sh/helm-v3.17.0-linux-amd64.tar.gz | tar xz
            - mv linux-amd64/helm /usr/local/bin/helm
            - pip3 install git-remote-codecommit
        pre_build:
          commands:
            - aws ecr get-login-password --region $AWS_DEFAULT_REGION | helm registry login --username AWS --password-stdin $CHART_ECR_REPO
            # Get the latest image tag from the Java ECR repo
            - IMAGE_TAG=$(aws ecr describe-images --repository-name ${local.java_ecr_name} --region $AWS_DEFAULT_REGION --query 'sort_by(imageDetails,&imagePushedAt)[-1].imageTags[0]' --output text)
            - echo "Using image tag $IMAGE_TAG"
            # Clone the data-plane repo using git-remote-codecommit (IAM auth, no git credentials needed)
            - git clone codecommit::$AWS_DEFAULT_REGION://$DATA_PLANE_REPO data-plane
        build:
          commands:
            # Update the chart values with the new image tag
            - |
              sed -i "s|tag:.*|tag: \"$IMAGE_TAG\"|" data-plane/credit-card/values.yaml
              sed -i "s|repository:.*|repository: $IMAGE_ECR_REPO|" data-plane/credit-card/values.yaml
            - helm package data-plane/credit-card
            - CHART_VERSION=$(grep '^version:' data-plane/credit-card/Chart.yaml | awk '{print $2}')
            - helm push credit-card-$CHART_VERSION.tgz oci://$CHART_ECR_REPO/charts
      artifacts:
        files:
          - '**/*'
        secondary-artifacts:
          chart_info:
            files:
              - chart_version.txt
    BUILDSPEC
  }

  tags = var.tags
}

################################################################################
# CodeBuild — Update control-plane-operations repo
################################################################################

resource "aws_codebuild_project" "credit_card_update_ops" {
  name         = "credit-card-update-ops"
  description  = "Update control-plane-operations with new credit-card chart version"
  service_role = aws_iam_role.codebuild_credit_card.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = local.account_id
    }
    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = var.region
    }
    environment_variable {
      name  = "OPS_REPO"
      value = var.git_repo_url
    }
    environment_variable {
      name  = "IMAGE_ECR_REPO"
      value = "${var.spoke_account_id}.dkr.ecr.${var.spoke_region}.amazonaws.com/${local.java_ecr_name}"
    }
    environment_variable {
      name  = "CHART_ECR_REPO"
      value = "${local.account_id}.dkr.ecr.${var.region}.amazonaws.com"
    }
    environment_variable {
      name  = "CHART_ECR_NAME"
      value = local.chart_ecr_name
    }
    environment_variable {
      name  = "JAVA_ECR_NAME"
      value = local.java_ecr_name
    }
    # The apps ApplicationSet reads clusterName + namespace from config.json,
    # so they must be preserved on every regeneration.
    environment_variable {
      name  = "CLUSTER_NAME"
      value = "credit-card-development"
    }
    environment_variable {
      name  = "APP_NAMESPACE"
      value = "credit-card"
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = <<-BUILDSPEC
      version: 0.2
      phases:
        pre_build:
          commands:
            - CHART_VERSION=$(aws ecr describe-images --repository-name $CHART_ECR_NAME --region $AWS_DEFAULT_REGION --query 'sort_by(imageDetails,&imagePushedAt)[-1].imageTags[0]' --output text)
            - IMAGE_TAG=$(aws ecr describe-images --repository-name $JAVA_ECR_NAME --region $AWS_DEFAULT_REGION --query 'sort_by(imageDetails,&imagePushedAt)[-1].imageTags[0]' --output text)
            - echo "Chart version - $CHART_VERSION"
            - echo "Image tag - $IMAGE_TAG"
        build:
          commands:
            - |
              PARENT_COMMIT=$(aws codecommit get-branch --repository-name $OPS_REPO --branch-name main --region $AWS_DEFAULT_REGION --query 'branch.commitId' --output text)

              CONFIG_JSON=$(echo '{}' | jq \
                --arg url "$CHART_ECR_REPO" \
                --arg name "$CHART_ECR_NAME" \
                --arg version "$CHART_VERSION" \
                --arg cluster "$CLUSTER_NAME" \
                --arg ns "$APP_NAMESPACE" \
                '{chartUrl: $url, chartName: $name, chartVersion: $version, clusterName: $cluster, namespace: $ns}')

              CONFIG_B64=$(echo "$CONFIG_JSON" | base64)

              # Build the values.yaml content with the new image tag.
              # Uses printf (not a column-0 heredoc) so the buildspec stays
              # uniformly indented and remains valid YAML after the Terraform
              # indented-heredoc (<<-) dedent.
              VALUES_CONTENT=$(printf 'replicaCount: 2\n\nimage:\n  repository: %s\n  tag: "%s"\n  pullPolicy: IfNotPresent\n\nservice:\n  type: ClusterIP\n  port: 8080\n\nresources:\n  requests:\n    cpu: 100m\n    memory: 256Mi\n  limits:\n    cpu: 500m\n    memory: 512Mi\n' "$IMAGE_ECR_REPO" "$IMAGE_TAG")
              VALUES_B64=$(echo "$VALUES_CONTENT" | base64)

              PUT_FILES=$(echo '[]' | jq \
                --arg path "applications/development/credit-card-development/credit-card/config.json" \
                --arg content "$CONFIG_B64" \
                '. + [{"filePath": $path, "fileContent": $content}]')

              # Update config.json in runtime/development/credit-card/apps/
              # so the apps ApplicationSet picks up the new chart version
              PUT_FILES=$(echo "$PUT_FILES" | jq \
                --arg path "runtime/development/credit-card/apps/config.json" \
                --arg content "$CONFIG_B64" \
                '. + [{"filePath": $path, "fileContent": $content}]')

              # Also update the values file in runtime/development/credit-card/apps/
              # so ArgoCD triggers a helm upgrade on the data-plane cluster
              PUT_FILES=$(echo "$PUT_FILES" | jq \
                --arg path "runtime/development/credit-card/apps/values.yaml" \
                --arg content "$VALUES_B64" \
                '. + [{"filePath": $path, "fileContent": $content}]')

              aws codecommit create-commit \
                --repository-name $OPS_REPO \
                --branch-name main \
                --parent-commit-id $PARENT_COMMIT \
                --commit-message "chore: update credit-card chart to $CHART_VERSION (image: $IMAGE_TAG)" \
                --put-files "$PUT_FILES" \
                --region $AWS_DEFAULT_REGION
    BUILDSPEC
  }

  tags = var.tags
}

################################################################################
# CodePipeline — Java → Docker → Chart → Ops Update
################################################################################

resource "aws_codepipeline" "credit_card" {
  name     = "credit-card-pipeline"
  role_arn = aws_iam_role.codepipeline_credit_card.arn

  artifact_store {
    location = aws_s3_bucket.pipeline_artifacts.bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "JavaSource"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeCommit"
      version          = "1"
      output_artifacts = ["java_source"]

      configuration = {
        RepositoryName = aws_codecommit_repository.credit_card_java.repository_name
        BranchName     = "main"
      }
    }
  }

  stage {
    name = "BuildImage"

    action {
      name             = "BuildDockerImage"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["java_source"]
      output_artifacts = ["build_output"]

      configuration = {
        ProjectName = aws_codebuild_project.credit_card_java.name
      }
    }
  }

  stage {
    name = "PackageChart"

    action {
      name             = "PackageHelmChart"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["build_output"]
      output_artifacts = ["chart_output"]

      configuration = {
        ProjectName = aws_codebuild_project.credit_card_chart.name
      }
    }
  }

  stage {
    name = "UpdateOps"

    action {
      name             = "UpdateControlPlaneOps"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["chart_output"]
      output_artifacts = []

      configuration = {
        ProjectName = aws_codebuild_project.credit_card_update_ops.name
      }
    }
  }

  tags = var.tags
}


################################################################################
# EventBridge Rule — trigger pipeline on CodeCommit push to main
################################################################################

resource "aws_iam_role" "eventbridge_pipeline" {
  name = "eventbridge-credit-card-pipeline"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "events.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "eventbridge_pipeline" {
  name = "start-pipeline"
  role = aws_iam_role.eventbridge_pipeline.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "codepipeline:StartPipelineExecution"
      Resource = aws_codepipeline.credit_card.arn
    }]
  })
}

resource "aws_cloudwatch_event_rule" "credit_card_java_push" {
  name        = "credit-card-java-push-to-main"
  description = "Trigger credit-card pipeline when code is pushed to main branch"

  event_pattern = jsonencode({
    source      = ["aws.codecommit"]
    detail-type = ["CodeCommit Repository State Change"]
    resources   = [aws_codecommit_repository.credit_card_java.arn]
    detail = {
      event         = ["referenceCreated", "referenceUpdated"]
      referenceType = ["branch"]
      referenceName = ["main"]
    }
  })

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "credit_card_pipeline" {
  rule     = aws_cloudwatch_event_rule.credit_card_java_push.name
  arn      = aws_codepipeline.credit_card.arn
  role_arn = aws_iam_role.eventbridge_pipeline.arn
}
