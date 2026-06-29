#!/bin/bash
# Gather infrastructure data for psp-reusable-artifacts terraform.tfvars
# Usage: ./gather-infra.sh

PROFILE=""          # Your AWS CLI profile name, or leave empty for default credentials
REGION="us-east-1"  # AWS region to query
ACCOUNT_ID=""       # Your AWS account ID (e.g. 123456789012)

echo "============================================"
echo "  PSP Reusable Artifacts - Infra Discovery"
echo "  Account: $ACCOUNT_ID | Region: $REGION"
echo "============================================"

echo ""
echo "=== 1. CALLER IDENTITY ==="
aws sts get-caller-identity --profile "$PROFILE" --region "$REGION"

echo ""
echo "=== 2. VPCs ==="
aws ec2 describe-vpcs --profile "$PROFILE" --region "$REGION" \
  --query 'Vpcs[*].{VpcId:VpcId,CidrBlock:CidrBlock,Name:Tags[?Key==`Name`]|[0].Value,IsDefault:IsDefault}' \
  --output table

echo ""
echo "=== 3. SUBNETS (private - for EKS) ==="
aws ec2 describe-subnets --profile "$PROFILE" --region "$REGION" \
  --query 'Subnets[*].{SubnetId:SubnetId,VpcId:VpcId,CidrBlock:CidrBlock,AZ:AvailabilityZone,Name:Tags[?Key==`Name`]|[0].Value,MapPublicIp:MapPublicIpOnLaunch}' \
  --output table

echo ""
echo "=== 4. IAM IDENTITY CENTER INSTANCE ==="
aws sso-admin list-instances --profile "$PROFILE" --region "$REGION" \
  --query 'Instances[*].{InstanceArn:InstanceArn,IdentityStoreId:IdentityStoreId}' \
  --output table 2>/dev/null || echo "(SSO not configured or no permission)"

echo ""
echo "=== 5. ORGANIZATIONS ID ==="
aws organizations describe-organization --profile "$PROFILE" --region "$REGION" \
  --query 'Organization.Id' --output text 2>/dev/null || echo "(Not in an Organization or no permission)"

echo ""
echo "=== 6. IDENTITY CENTER GROUPS (for ArgoCD RBAC) ==="
# Get Identity Store ID first
IDC_STORE=$(aws sso-admin list-instances --profile "$PROFILE" --region "$REGION" \
  --query 'Instances[0].IdentityStoreId' --output text 2>/dev/null)
if [ "$IDC_STORE" != "None" ] && [ -n "$IDC_STORE" ]; then
  aws identitystore list-groups --identity-store-id "$IDC_STORE" --profile "$PROFILE" --region "$REGION" \
    --query 'Groups[*].{GroupId:GroupId,DisplayName:DisplayName}' --output table 2>/dev/null
else
  echo "(Could not retrieve Identity Store ID)"
fi

echo ""
echo "============================================"
echo "  Done! Paste this output back to Quick."
echo "============================================"
