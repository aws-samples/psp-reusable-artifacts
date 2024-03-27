################################################################################
# Karpenter
################################################################################

resource "kubectl_manifest" "karpenter_provisioner" {
  yaml_body  = <<-YAML
    apiVersion: karpenter.sh/v1beta1
    kind: NodePool
    metadata:
      name: default
    spec:
      disruption:
        # consolidationPolicy: WhenUnderutilized
        consolidationPolicy: WhenEmpty
        consolidateAfter: 30s
        expireAfter: 168h0m0s
      limits:
        cpu: "100"
      template:
        metadata: {}
        spec:
          kubelet:
            maxPods: 110
          nodeClassRef:
            name: default
          requirements:
          - key: karpenter.k8s.aws/instance-category
            operator: In
            values: ["t", "c", "m", "r"]
          - key: karpenter.k8s.aws/instance-cpu
            operator: In
            values: ["2", "4", "8", "16", "32"]
          - key: karpenter.k8s.aws/instance-hypervisor
            operator: In
            values: ["nitro"]
          - key: topology.kubernetes.io/zone
            operator: In
            values: ${jsonencode(local.azs)}
          - key: kubernetes.io/arch
            operator: In
            values: ["amd64"]
          - key: karpenter.sh/capacity-type
            operator: In
            values: ["on-demand"]
          - key: kubernetes.io/os
            operator: In
            values: ["linux"]
  YAML
  depends_on = [module.eks_blueprints_addons, aws_ec2_tag.karpenter_tag_cluster_primary_security_group, kubectl_manifest.karpenter_node_template]
}

resource "kubectl_manifest" "karpenter_node_template" {
  yaml_body  = <<-YAML
    apiVersion: karpenter.k8s.aws/v1beta1
    kind: EC2NodeClass
    metadata:
      name: default
    spec:
      amiFamily: AL2
      role: ${module.eks_blueprints_addons.karpenter.node_iam_role_name}
      securityGroupSelectorTerms:
      - tags:
          karpenter.sh/discovery: ${module.eks.cluster_name}
      subnetSelectorTerms:
      - tags:
          karpenter.sh/discovery: ${module.eks.cluster_name}
      tags:
        managed-by: karpenter
  YAML
  depends_on = [module.eks_blueprints_addons]
}
