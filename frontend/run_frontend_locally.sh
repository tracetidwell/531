#!/bin/bash
set -e

# Usage: ./run_frontend_locally.sh [local|cloud]
# Default: local

BACKEND="${1:-local}"

if [ "$BACKEND" = "cloud" ]; then
  APP_RUNNER_URL=$(aws apprunner list-services \
    --query 'ServiceSummaryList[?ServiceName==`531-backend`].ServiceUrl' \
    --output text)
  API_BASE_URL="https://${APP_RUNNER_URL}/api/v1"
else
  API_BASE_URL="http://localhost:8000/api/v1"
fi

echo "Running frontend with API_BASE_URL: ${API_BASE_URL}"

cd /home/trace/Documents/531/frontend
flutter run -d chrome \
  --dart-define=API_BASE_URL=${API_BASE_URL}