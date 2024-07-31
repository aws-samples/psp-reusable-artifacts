locals {
  name        = var.name
  environment = var.environment
  region      = var.region

  cluster_version       = var.kubernetes_version
  vpc_id                = var.vpcid
  private_subnets_nodes = var.privatesubnetids_nodes
  private_subnets_pods  = var.privatesubnetids_pods
  public_subnets        = var.publicsubnetids
  azs                   = slice(data.aws_availability_zones.available.names, 0, 3)
  git_private_ssh_key   = var.ssh_key_path

  cluster_endpoint_public_access  = var.cluster_endpoint_public_access
  allowed_public_cidrs            = var.allowed_public_cidrs
  cluster_endpoint_private_access = var.cluster_endpoint_private_access

  gitops_addons_url        = "${var.gitops_addons_org}/${var.gitops_addons_repo}"
  gitops_addons_basepath   = var.gitops_addons_basepath
  gitops_addons_path       = var.gitops_addons_path
  gitops_addons_revision   = var.gitops_addons_revision
  gitops_addons_org        = var.gitops_addons_org
  gitops_workload_org      = var.gitops_workload_org
  gitops_workload_repo     = var.gitops_workload_repo
  gitops_workload_revision = var.gitops_workload_revision
  gitops_workload_basepath = var.gitops_workload_basepath
  gitops_workload_path     = var.gitops_workload_path
  gitops_workload_url      = "${local.gitops_workload_org}/${local.gitops_workload_repo}"
  crossplane_namespace     = var.crossplane_namespace
  crossplane_sa            = var.crossplane_sa

  aws_addons = {
    enable_cert_manager                          = try(var.addons.enable_cert_manager, false)
    enable_aws_efs_csi_driver                    = try(var.addons.enable_aws_efs_csi_driver, false)
    enable_aws_fsx_csi_driver                    = try(var.addons.enable_aws_fsx_csi_driver, false)
    enable_aws_cloudwatch_metrics                = try(var.addons.enable_aws_cloudwatch_metrics, false)
    enable_aws_privateca_issuer                  = try(var.addons.enable_aws_privateca_issuer, false)
    enable_cluster_autoscaler                    = try(var.addons.enable_cluster_autoscaler, false)
    enable_external_dns                          = try(var.addons.enable_external_dns, false)
    enable_external_secrets                      = try(var.addons.enable_external_secrets, false)
    enable_aws_load_balancer_controller          = try(var.addons.enable_aws_load_balancer_controller, false)
    enable_fargate_fluentbit                     = try(var.addons.enable_fargate_fluentbit, false)
    enable_aws_for_fluentbit                     = try(var.addons.enable_aws_for_fluentbit, false)
    enable_aws_node_termination_handler          = try(var.addons.enable_aws_node_termination_handler, false)
    enable_karpenter                             = try(var.addons.enable_karpenter, false)
    enable_velero                                = try(var.addons.enable_velero, false)
    enable_aws_gateway_api_controller            = try(var.addons.enable_aws_gateway_api_controller, false)
    enable_aws_ebs_csi_resources                 = try(var.addons.enable_aws_ebs_csi_resources, false)
    enable_aws_secrets_store_csi_driver_provider = try(var.addons.enable_aws_secrets_store_csi_driver_provider, false)
    enable_ack_apigatewayv2                      = try(var.addons.enable_ack_apigatewayv2, false)
    enable_ack_dynamodb                          = try(var.addons.enable_ack_dynamodb, false)
    enable_ack_s3                                = try(var.addons.enable_ack_s3, false)
    enable_ack_rds                               = try(var.addons.enable_ack_rds, false)
    enable_ack_prometheusservice                 = try(var.addons.enable_ack_prometheusservice, false)
    enable_ack_emrcontainers                     = try(var.addons.enable_ack_emrcontainers, false)
    enable_ack_sfn                               = try(var.addons.enable_ack_sfn, false)
    enable_ack_eventbridge                       = try(var.addons.enable_ack_eventbridge, false)
    enable_aws_argocd_ingress                    = try(var.addons.enable_aws_argocd_ingress, false)
    enable_aws_crossplane_provider               = try(var.addons.enable_aws_crossplane_provider, false)
    enable_aws_crossplane_upbound_provider       = try(var.addons.enable_aws_crossplane_upbound_provider, false)
  }
  oss_addons = {
    enable_argocd                          = try(var.addons.enable_argocd, true)
    enable_argo_rollouts                   = try(var.addons.enable_argo_rollouts, false)
    enable_argo_events                     = try(var.addons.enable_argo_events, false)
    enable_argo_workflows                  = try(var.addons.enable_argo_workflows, false)
    enable_cluster_proportional_autoscaler = try(var.addons.enable_cluster_proportional_autoscaler, false)
    enable_gatekeeper                      = try(var.addons.enable_gatekeeper, false)
    enable_gpu_operator                    = try(var.addons.enable_gpu_operator, false)
    enable_ingress_nginx                   = try(var.addons.enable_ingress_nginx, false)
    enable_keda                            = try(var.addons.enable_keda, false)
    enable_kyverno                         = try(var.addons.enable_kyverno, false)
    enable_kube_prometheus_stack           = try(var.addons.enable_kube_prometheus_stack, false)
    enable_metrics_server                  = try(var.addons.enable_metrics_server, false)
    enable_prometheus_adapter              = try(var.addons.enable_prometheus_adapter, false)
    enable_secrets_store_csi_driver        = try(var.addons.enable_secrets_store_csi_driver, false)
    enable_vpa                             = try(var.addons.enable_vpa, false)
    enable_crossplane                      = try(var.addons.enable_crossplane, false)
    enable_crossplane_kubernetes_provider  = try(var.addons.enable_crossplane_kubernetes_provider, false)
    enable_crossplane_helm_provider        = try(var.addons.enable_crossplane_helm_provider, false)
  }
  addons = merge(
    local.aws_addons,
    local.oss_addons,
    { kubernetes_version = local.cluster_version },
    { aws_cluster_name = module.eks.cluster_name }
  )

  addons_metadata = merge(
    module.eks_blueprints_addons.gitops_metadata,
    {
      aws_cluster_name = module.eks.cluster_name
      aws_region       = local.region
      aws_account_id   = data.aws_caller_identity.current.account_id
      aws_vpc_id       = var.vpcid
    },
    {
      # Required for external dns addon
      external_dns_domain_filters = "example.com"
    },
    {
      addons_repo_url      = local.gitops_addons_url
      addons_repo_basepath = local.gitops_addons_basepath
      addons_repo_path     = local.gitops_addons_path
      addons_repo_revision = local.gitops_addons_revision
    },
    {
      workload_repo_url      = local.gitops_workload_url
      workload_repo_basepath = local.gitops_workload_basepath
      workload_repo_path     = local.gitops_workload_path
      workload_repo_revision = local.gitops_workload_revision
    },
    {
      karpenter_security_group_id  = module.eks.node_security_group_id
      karpenter_private_subnet_id1 = local.private_subnets_nodes[0]
      karpenter_private_subnet_id2 = local.private_subnets_nodes[1]
      karpenter_private_subnet_id3 = local.private_subnets_nodes[2]
    },
    {
      aws_crossplane_iam_role_arn         = module.crossplane_irsa_aws.iam_role_arn
      aws_upbound_crossplane_iam_role_arn = module.crossplane_irsa_aws.iam_role_arn
    }
  )

  argocd_apps = {
    addons    = file("${path.module}/bootstrap/addons.yaml")
    workloads = file("${path.module}/bootstrap/workloads.yaml")
  }

  tags = {
    Blueprint = local.name
  }
}
