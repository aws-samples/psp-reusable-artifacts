# ################################################################################
# # ArgoCD Configuration Test
# ################################################################################


# resource "null_resource" "argocd_service_template" {
#     provisioner "local-exec" {
#         command = "kubectl patch svc argocd-server -n argocd -p '{\"spec\": {\"type\": \"LoadBalancer\"}}'"
#     }
#   depends_on = [module.eks_blueprints_addons]
# }
