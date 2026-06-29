provider "aws" {
  region = var.region
  profile = var.aws_profile != "" ? var.aws_profile : null
}

data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
  account_id = data.aws_caller_identity.current.account_id
  azs        = slice(data.aws_availability_zones.available.names, 0, 3)

  # Render ArgoCD manifests with the actual CodeCommit clone URL
  template_vars = {
    git_repo_url = aws_codecommit_repository.this.clone_url_http
    cluster_arn  = module.eks.cluster_arn
  }

  applicationset_dataplane_production  = templatefile("${path.module}/templates/applicationset-dataplane-production.yaml.tftpl", local.template_vars)
  applicationset_dataplane_staging     = templatefile("${path.module}/templates/applicationset-dataplane-staging.yaml.tftpl", local.template_vars)
  applicationset_dataplane_development = templatefile("${path.module}/templates/applicationset-dataplane-development.yaml.tftpl", local.template_vars)
  catalog_app                          = templatefile("${path.module}/templates/catalog-app.yaml.tftpl", local.template_vars)
  project                              = file("${path.module}/templates/project.yaml.tftpl")

  # ApplicationSets for deploying Helm apps to spoke clusters
  applicationset_apps_production  = templatefile("${path.module}/templates/applicationset-apps-production.yaml.tftpl", local.template_vars)
  applicationset_apps_staging     = templatefile("${path.module}/templates/applicationset-apps-staging.yaml.tftpl", local.template_vars)
  applicationset_apps_development = templatefile("${path.module}/templates/applicationset-apps-development.yaml.tftpl", local.template_vars)

  # ArgoCD repo and cluster registration secrets
  argocd_repo_secret = templatefile("${path.module}/templates/argocd-repo-secret.yaml.tftpl", {
    git_repo_url = aws_codecommit_repository.this.clone_url_http
  })
  argocd_cluster_secret = templatefile("${path.module}/templates/argocd-cluster-secret.yaml.tftpl", {
    cluster_arn = module.eks.cluster_arn
  })

  # Rendered claim for development data-plane (from templatefile)
  claim_development = templatefile("${path.module}/templates/claim-development.yaml.tftpl", {
    spoke_account_id         = var.spoke_account_id
    spoke_region             = var.spoke_region
    spoke_vpc_id             = var.spoke_vpc_id
    spoke_subnet_ids         = var.spoke_subnet_ids
    spoke_kubernetes_version = var.spoke_kubernetes_version
    capability_role_arn      = aws_iam_role.control_plane_admin.arn
  })
}

################################################################################
# VPC
################################################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name = var.cluster_name
  cidr = var.vpc_cidr

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 4, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 8, k + 48)]

  enable_nat_gateway = true
  single_nat_gateway = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = var.tags
}

################################################################################
# CodeCommit Repository
################################################################################
# Creates the Git repository that ArgoCD watches for runtime claims,
# catalog RGDs, and ApplicationSet definitions.
# A null_resource seeds the repo with the initial folder structure.
################################################################################

resource "aws_codecommit_repository" "this" {
  repository_name = var.git_repo_url
  description     = "Control-plane operations repository for ArgoCD"

  tags = var.tags
}

################################################################################
# Initial Commit — seed argocd/, catalog/, and runtime/ folders
################################################################################

resource "local_file" "applicationset_dataplane_production" {
  content  = local.applicationset_dataplane_production
  filename = "${path.module}/rendered/applicationset-dataplane-production.yaml"
}

resource "local_file" "applicationset_dataplane_staging" {
  content  = local.applicationset_dataplane_staging
  filename = "${path.module}/rendered/applicationset-dataplane-staging.yaml"
}

resource "local_file" "applicationset_dataplane_development" {
  content  = local.applicationset_dataplane_development
  filename = "${path.module}/rendered/applicationset-dataplane-development.yaml"
}

resource "local_file" "catalog_app" {
  content  = local.catalog_app
  filename = "${path.module}/rendered/catalog-app.yaml"
}

resource "local_file" "project" {
  content  = local.project
  filename = "${path.module}/rendered/project.yaml"
}

resource "local_file" "argocd_repo_secret" {
  content  = local.argocd_repo_secret
  filename = "${path.module}/rendered/argocd-repo-secret.yaml"
}

resource "local_file" "argocd_cluster_secret" {
  content  = local.argocd_cluster_secret
  filename = "${path.module}/rendered/argocd-cluster-secret.yaml"
}

resource "local_file" "applicationset_apps_production" {
  content  = local.applicationset_apps_production
  filename = "${path.module}/rendered/applicationset-apps-production.yaml"
}

resource "local_file" "applicationset_apps_staging" {
  content  = local.applicationset_apps_staging
  filename = "${path.module}/rendered/applicationset-apps-staging.yaml"
}

resource "local_file" "applicationset_apps_development" {
  content  = local.applicationset_apps_development
  filename = "${path.module}/rendered/applicationset-apps-development.yaml"
}

resource "local_file" "claim_development" {
  content  = local.claim_development
  filename = "${path.module}/rendered/claim-development.yaml"
}

resource "null_resource" "seed_repo" {
  depends_on = [
    aws_codecommit_repository.this,
    local_file.applicationset_dataplane_production,
    local_file.applicationset_dataplane_staging,
    local_file.applicationset_dataplane_development,
    local_file.catalog_app,
    local_file.project,
    local_file.applicationset_apps_production,
    local_file.applicationset_apps_staging,
    local_file.applicationset_apps_development,
    local_file.claim_development,
  ]

  triggers = {
    repo_name = aws_codecommit_repository.this.repository_name
  }

  provisioner "local-exec" {
    environment = {
      AWS_PROFILE = var.aws_profile
    }
    interpreter = ["bash", "-c"]
    command     = <<-EOT
      set -e

      REPO_NAME="${aws_codecommit_repository.this.repository_name}"
      REGION="${var.region}"

      # Build put-files JSON array from argocd/, catalog/, runtime/ folders
      # Use rendered templates for argocd, raw files for catalog and runtime
      PUT_FILES="[]"

      # Add rendered argocd templates (exclude repo/cluster secrets)
      for f in ${path.module}/rendered/applicationset-*.yaml \
               ${path.module}/rendered/catalog-app.yaml \
               ${path.module}/rendered/project.yaml; do
        BASENAME=$(basename "$f")
        CONTENT=$(base64 < "$f")
        PUT_FILES=$(echo "$PUT_FILES" | jq --arg path "argocd/$BASENAME" --arg content "$CONTENT" '. + [{"filePath": $path, "fileContent": $content}]')
      done

      # Add catalog files
      for f in ${path.module}/../catalog/*.yaml; do
        BASENAME=$(basename "$f")
        CONTENT=$(base64 < "$f")
        PUT_FILES=$(echo "$PUT_FILES" | jq --arg path "catalog/$BASENAME" --arg content "$CONTENT" '. + [{"filePath": $path, "fileContent": $content}]')
      done

      # Add runtime files (preserve directory structure)
      # Exclude the development data-plane claim — it will be added from the rendered templatefile
      while IFS= read -r f; do
        REL_PATH=$(echo "$f" | sed "s|${path.module}/../||")
        CONTENT=$(base64 < "$f")
        PUT_FILES=$(echo "$PUT_FILES" | jq --arg path "$REL_PATH" --arg content "$CONTENT" '. + [{"filePath": $path, "fileContent": $content}]')
      done < <(find ${path.module}/../runtime -type f -not -name '.gitkeep' -not -path '*/development/credit-card/data-plane/claim.yaml')

      # Add the development data-plane claim from the rendered templatefile
      CLAIM_CONTENT=$(base64 < ${path.module}/rendered/claim-development.yaml)
      PUT_FILES=$(echo "$PUT_FILES" | jq --arg path "runtime/development/credit-card/data-plane/claim.yaml" --arg content "$CLAIM_CONTENT" '. + [{"filePath": $path, "fileContent": $content}]')

      # Add applications files (preserve directory structure)
      if [ -d "${path.module}/../applications" ]; then
        while IFS= read -r f; do
          REL_PATH=$(echo "$f" | sed "s|${path.module}/../||")
          CONTENT=$(base64 < "$f")
          PUT_FILES=$(echo "$PUT_FILES" | jq --arg path "$REL_PATH" --arg content "$CONTENT" '. + [{"filePath": $path, "fileContent": $content}]')
        done < <(find ${path.module}/../applications -type f)
      fi

      # Create initial commit via AWS CLI (no git credentials needed)
      # Fetch parent commit ID if branch already exists
      PARENT_COMMIT_ID=$(aws codecommit get-branch \
        --repository-name "$REPO_NAME" \
        --branch-name main \
        --region "$REGION" \
        --query 'branch.commitId' \
        --output text 2>/dev/null || echo "")

      PARENT_ARG=""
      if [ -n "$PARENT_COMMIT_ID" ] && [ "$PARENT_COMMIT_ID" != "None" ]; then
        PARENT_ARG="--parent-commit-id $PARENT_COMMIT_ID"
      fi

      aws codecommit create-commit \
        --repository-name "$REPO_NAME" \
        --branch-name main \
        --commit-message "Initial commit: seed argocd, catalog, and runtime folders" \
        --put-files "$PUT_FILES" \
        --region "$REGION" \
        $PARENT_ARG
    EOT
  }
}

################################################################################
# Apply ArgoCD manifests — project, applicationset-production & catalog-app
################################################################################

resource "null_resource" "apply_argocd_manifests" {
  depends_on = [
    null_resource.seed_repo,
    aws_eks_capability.argocd,
    aws_eks_capability.kro,
    local_file.argocd_repo_secret,
    local_file.argocd_cluster_secret,
    local_file.applicationset_apps_production,
    local_file.applicationset_apps_staging,
    local_file.applicationset_apps_development,
  ]

  triggers = {
    repo_name      = aws_codecommit_repository.this.repository_name
    cluster_name   = module.eks.cluster_name
    capability_arn = aws_eks_capability.argocd.arn
  }

  provisioner "local-exec" {
    environment = {
      AWS_PROFILE = var.aws_profile
    }
    interpreter = ["bash", "-c"]
    command     = <<-EOT
      set -e

      CLUSTER="${module.eks.cluster_name}"
      REGION="${var.region}"

      aws eks update-kubeconfig --name "$CLUSTER" --region "$REGION"

      # Register CodeCommit repository and local cluster with ArgoCD
      kubectl apply -f ${path.module}/rendered/argocd-repo-secret.yaml
      kubectl apply -f ${path.module}/rendered/argocd-cluster-secret.yaml

      # Apply ArgoCD project and applications
      kubectl apply -f ${path.module}/rendered/project.yaml
      kubectl apply -f ${path.module}/rendered/applicationset-dataplane-production.yaml
      kubectl apply -f ${path.module}/rendered/applicationset-dataplane-staging.yaml
      kubectl apply -f ${path.module}/rendered/applicationset-dataplane-development.yaml
      kubectl apply -f ${path.module}/rendered/applicationset-apps-production.yaml
      kubectl apply -f ${path.module}/rendered/applicationset-apps-staging.yaml
      kubectl apply -f ${path.module}/rendered/applicationset-apps-development.yaml
      kubectl apply -f ${path.module}/rendered/catalog-app.yaml
    EOT
  }
}
################################################################################
# EKS Cluster — Auto Mode
################################################################################

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.15"

  name                   = var.cluster_name
  kubernetes_version     = var.kubernetes_version
  endpoint_public_access = true

  enable_cluster_creator_admin_permissions = true

  # Auto Mode
  compute_config = {
    enabled    = true
    node_pools = ["general-purpose", "system"]
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  tags = var.tags
}
