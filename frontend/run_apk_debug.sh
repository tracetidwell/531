#!/bin/bash
set -e

APP_RUNNER_URL=$(aws apprunner list-services \
  --query 'ServiceSummaryList[?ServiceName==`531-backend`].ServiceUrl' \
  --output text)

echo "Building APK with API_BASE_URL: https://${APP_RUNNER_URL}/api/v1"

flutter run --dart-define=API_BASE_URL=https://${APP_RUNNER_URL}/api/v1 --debug