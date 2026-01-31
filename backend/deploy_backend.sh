#!/bin/bash
set -e

cd /home/trace/Documents/531/backend

echo "Building Docker image..."
docker build --no-cache -t 531-backend .

echo "Tagging image..."
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
docker tag 531-backend:latest ${ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/531-backend:latest

echo "Pushing to ECR..."
docker push ${ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/531-backend:latest

echo "Getting service ARN..."
SERVICE_ARN=$(aws apprunner list-services \
  --query 'ServiceSummaryList[?ServiceName==`531-backend`].ServiceArn' \
  --output text)

# Wait for service to be in RUNNING state before deploying
echo "Checking service status..."
MAX_RETRIES=30
RETRY_INTERVAL=10

for i in $(seq 1 $MAX_RETRIES); do
  STATUS=$(aws apprunner describe-service --service-arn "$SERVICE_ARN" --query 'Service.Status' --output text)

  if [ "$STATUS" == "RUNNING" ]; then
    echo "Service is RUNNING. Starting deployment..."
    aws apprunner start-deployment --service-arn "$SERVICE_ARN"
    echo "Deployment started successfully!"
    exit 0
  else
    echo "Service status: $STATUS (attempt $i/$MAX_RETRIES). Waiting ${RETRY_INTERVAL}s..."
    sleep $RETRY_INTERVAL
  fi
done

echo "Error: Service did not reach RUNNING state after $MAX_RETRIES attempts."
exit 1
