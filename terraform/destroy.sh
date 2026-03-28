#!/bin/bash
set -x

TFVARS="./env/workshop.tfvars"

# Destroy addons IAM roles first, then clusters
terraform destroy -target="module.crossplane_irsa_aws" -auto-approve -var-file=$TFVARS
terraform destroy -target="module.eks_blueprints_addons_cluster1" -auto-approve -var-file=$TFVARS
terraform destroy -target="module.eks_cluster1" -auto-approve -var-file=$TFVARS
terraform destroy -target="module.eks_cluster2" -auto-approve -var-file=$TFVARS
terraform destroy -target="module.eks_cluster3" -auto-approve -var-file=$TFVARS
terraform destroy -auto-approve -var-file=$TFVARS

echo ""
echo "EKS clusters destroyed. To also destroy networking and IAM role:"
echo "  cd networking && terraform destroy -auto-approve"
echo "  cd ../platform-execution-role && terraform destroy -auto-approve -var-file=../env/workshop.tfvars"
