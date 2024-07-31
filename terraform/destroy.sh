#!/bin/bash

set -x

# Delete the Ingress/SVC before removing the addons
TMPFILE=$(mktemp)
terraform output -raw configure_kubectl > "$TMPFILE"
source "$TMPFILE"

kubectl delete svc -n argocd argo-cd-argocd-server
kubectl delete svc -n kube-prometheus-stack kube-prometheus-stack-grafana
kubectl delete svc -n kube-prometheus-stack kube-prometheus-stack-prometheus

terraform destroy -target="module.gitops_bridge_bootstrap" -auto-approve -var-file=./env/controlplane.tfvars
terraform destroy -target="module.eks_blueprints_addons" -auto-approve -var-file=./env/controlplane.tfvars
terraform destroy -target="module.eks" -auto-approve -var-file=./env/controlplane.tfvars
terraform destroy -auto-approve -var-file=./env/controlplane.tfvars
