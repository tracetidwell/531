#!/bin/bash
set -e

echo "Fetching resource IDs..."

CF_DIST_ID="EFMIS8N0F3I1I"
S3_BUCKET="531-frontend"
ALB_NAME="531-backend-alb"
ECS_CLUSTER="531-cluster"
ECS_SERVICE="531-backend"
BASTION_ID="i-0ea7eb61aa2f1aeb4"

ALB_ARN=$(aws elbv2 describe-load-balancers --names $ALB_NAME \
  --query 'LoadBalancers[0].LoadBalancerArn' --output text)

# Disable CloudFront distribution (required before deletion)
echo "Disabling CloudFront distribution..."
aws cloudfront get-distribution-config --id $CF_DIST_ID \
  --query 'DistributionConfig' > /tmp/cf-config.json
CF_ETAG=$(aws cloudfront get-distribution-config --id $CF_DIST_ID --query 'ETag' --output text)
sed -i 's/"Enabled": true/"Enabled": false/' /tmp/cf-config.json
aws cloudfront update-distribution --id $CF_DIST_ID \
  --distribution-config file:///tmp/cf-config.json \
  --if-match $CF_ETAG
echo "Waiting for CloudFront distribution to finish disabling (this may take a few minutes)..."
aws cloudfront wait distribution-deployed --id $CF_DIST_ID
echo "CloudFront is disabled and Deployed."

# Delete CloudFront distribution
echo "Deleting CloudFront distribution..."
CF_ETAG=$(aws cloudfront get-distribution --id $CF_DIST_ID --query 'ETag' --output text)
aws cloudfront delete-distribution --id $CF_DIST_ID --if-match $CF_ETAG
echo "CloudFront distribution deleted."

# Empty and delete S3 bucket
echo "Deleting S3 bucket $S3_BUCKET..."
aws s3 rm s3://$S3_BUCKET --recursive
aws s3 rb s3://$S3_BUCKET
echo "S3 bucket deleted."

# Delete ALB
echo "Deleting ALB $ALB_NAME..."
aws elbv2 delete-load-balancer --load-balancer-arn $ALB_ARN
echo "ALB deleted."

# Delete ECS service and cluster
echo "Scaling down ECS service..."
aws ecs update-service --cluster $ECS_CLUSTER --service $ECS_SERVICE --desired-count 0
echo "Deleting ECS service..."
aws ecs delete-service --cluster $ECS_CLUSTER --service $ECS_SERVICE --force
echo "Deleting ECS cluster..."
aws ecs delete-cluster --cluster $ECS_CLUSTER
echo "ECS resources deleted."

# Stop bastion
echo "Stopping bastion host..."
aws ec2 stop-instances --instance-ids $BASTION_ID
echo "Bastion stopped."

echo "Done. Check your AWS Cost Explorer in a day or two to confirm savings."
