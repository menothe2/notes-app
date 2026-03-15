#!/usr/bin/env bash
# =============================================================
# 03-deploy-frontend.sh — Build React app and deploy to S3/CloudFront
#
# Run after 01-infra.sh and after filling in config.env with
# EC2_PUBLIC_IP and CLOUDFRONT_DOMAIN values.
# =============================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
source "$SCRIPT_DIR/config.env"

for var in EC2_PUBLIC_IP S3_BUCKET CLOUDFRONT_DOMAIN; do
  if [ -z "${!var:-}" ]; then
    echo "ERROR: $var is not set in config.env"
    exit 1
  fi
done

echo "==> [1/3] Building React app..."
cd "$ROOT_DIR/frontend"
VITE_API_URL="http://$EC2_PUBLIC_IP:8080" npm run build

echo "==> [2/3] Syncing to S3..."
aws s3 sync dist/ "s3://$S3_BUCKET" \
  --delete \
  --cache-control "public,max-age=31536000,immutable" \
  --exclude "index.html" \
  --region "$AWS_REGION"

# index.html must not be cached so deploys take effect immediately
aws s3 cp dist/index.html "s3://$S3_BUCKET/index.html" \
  --cache-control "no-cache,no-store,must-revalidate" \
  --region "$AWS_REGION"

echo "==> [3/3] Invalidating CloudFront cache..."
CF_ID=$(aws cloudfront list-distributions \
  --query "DistributionList.Items[?Comment=='${APP_NAME} frontend'].Id" \
  --output text)

if [ -n "$CF_ID" ]; then
  aws cloudfront create-invalidation \
    --distribution-id "$CF_ID" \
    --paths "/*"
  echo "  Invalidation created for distribution $CF_ID"
else
  echo "  WARNING: Could not find CloudFront distribution to invalidate."
  echo "  If needed, invalidate manually in the AWS console."
fi

echo ""
echo "============================================================"
echo "  Frontend deployed!"
echo "  URL: https://$CLOUDFRONT_DOMAIN"
echo "  (CloudFront may take a few minutes to propagate globally)"
echo "============================================================"
