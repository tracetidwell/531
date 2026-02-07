#!/bin/bash
# Authenticate with AWS ECR
# Run this when you get "authorization token has expired" errors

set -e

REGION="${AWS_REGION:-us-east-1}"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "Authenticating with ECR in $REGION..."
aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com"

echo "Authentication successful!"
