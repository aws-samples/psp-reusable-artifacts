#!/bin/sh
set -e

# Fetch ArgoCD API token from Secrets Manager if the secret ARN is provided
if [ -n "$ARGOCD_API_TOKEN_SECRET_ARN" ]; then
  echo "Fetching ARGOCD_API_TOKEN from Secrets Manager..."
  export ARGOCD_API_TOKEN=$(aws secretsmanager get-secret-value \
    --secret-id "$ARGOCD_API_TOKEN_SECRET_ARN" \
    --query 'SecretString' \
    --output text \
    --region "${AWS_REGION:-us-east-1}")
fi

exec node dist/index.js http --port 8000
