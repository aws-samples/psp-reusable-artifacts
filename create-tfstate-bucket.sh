#!/bin/bash
# Create S3 bucket for Terraform remote state
# Usage: ./create-tfstate-bucket.sh

PROFILE=""          # Your AWS CLI profile name, or leave empty for default credentials
REGION="us-east-1"  # AWS region where the bucket will be created
ACCOUNT_ID=""       # Your AWS account ID (e.g. 123456789012)
BUCKET_NAME="psp-tfstate-${ACCOUNT_ID}"

echo "Creating S3 bucket: ${BUCKET_NAME} in ${REGION}..."

aws s3api create-bucket \
  --bucket "${BUCKET_NAME}" \
  --region "${REGION}" \
  --profile "${PROFILE}"

echo "Enabling versioning..."
aws s3api put-bucket-versioning \
  --bucket "${BUCKET_NAME}" \
  --versioning-configuration Status=Enabled \
  --profile "${PROFILE}"

echo "Enabling encryption..."
aws s3api put-bucket-encryption \
  --bucket "${BUCKET_NAME}" \
  --server-side-encryption-configuration '{
    "Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]
  }' \
  --profile "${PROFILE}"

echo "Blocking public access..."
aws s3api put-public-access-block \
  --bucket "${BUCKET_NAME}" \
  --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true \
  --profile "${PROFILE}"

echo ""
echo "✅ Bucket created: ${BUCKET_NAME}"
echo ""
echo "Now run terraform init in bootstrap/ and agentcore-mcp/"
