#!/bin/bash
set -e

# Configuration
S3_BUCKET="531-frontend"
DOMAIN_NAME="531.tracetidwell.com"

cd /home/trace/Documents/531/frontend

# Get CloudFront distribution ID by alias (domain name)
echo "Looking up CloudFront distribution for ${DOMAIN_NAME}..."
CLOUDFRONT_DISTRIBUTION_ID=$(aws cloudfront list-distributions \
  --query "DistributionList.Items[?Aliases.Items[?@ == '${DOMAIN_NAME}']].Id" \
  --output text 2>/dev/null || echo "")

if [ -z "$CLOUDFRONT_DISTRIBUTION_ID" ] || [ "$CLOUDFRONT_DISTRIBUTION_ID" = "None" ]; then
  echo "Warning: No CloudFront distribution found for ${DOMAIN_NAME}"
  echo "Run ./setup_web.sh first to create the infrastructure."
  CLOUDFRONT_DISTRIBUTION_ID=""
else
  echo "Found distribution: ${CLOUDFRONT_DISTRIBUTION_ID}"
fi

# Get backend API URL from App Runner
APP_RUNNER_URL=$(aws apprunner list-services \
  --query 'ServiceSummaryList[?ServiceName==`531-backend`].ServiceUrl' \
  --output text)

if [ -z "$APP_RUNNER_URL" ]; then
  echo "Error: Could not find 531-backend App Runner service"
  exit 1
fi

API_BASE_URL="https://${APP_RUNNER_URL}/api/v1"
echo "Building web app with API_BASE_URL: ${API_BASE_URL}"

# Build Flutter web
flutter build web --release \
  --dart-define=API_BASE_URL=${API_BASE_URL}

echo "Build complete. Uploading to S3..."

# Sync build output to S3
aws s3 sync build/web s3://${S3_BUCKET} \
  --delete \
  --cache-control "max-age=31536000" \
  --exclude "index.html" \
  --exclude "flutter_service_worker.js"

# Upload index.html and service worker with no-cache (these should always be fresh)
aws s3 cp build/web/index.html s3://${S3_BUCKET}/index.html \
  --cache-control "no-cache, no-store, must-revalidate"

aws s3 cp build/web/flutter_service_worker.js s3://${S3_BUCKET}/flutter_service_worker.js \
  --cache-control "no-cache, no-store, must-revalidate"

echo "Upload complete."

# Invalidate CloudFront cache if distribution ID is set
if [ -n "$CLOUDFRONT_DISTRIBUTION_ID" ]; then
  echo "Invalidating CloudFront cache..."
  aws cloudfront create-invalidation \
    --distribution-id ${CLOUDFRONT_DISTRIBUTION_ID} \
    --paths "/*"
  echo "CloudFront invalidation started."
else
  echo "Skipping CloudFront cache invalidation (no distribution found)."
fi

echo "Deployment complete!"
