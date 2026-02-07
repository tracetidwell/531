#!/bin/bash
set -e

# Configuration
S3_BUCKET="531-frontend"
DOMAIN_NAME="531.tracetidwell.com"
REGION="us-east-1"
OAC_NAME="531-frontend-oac"

echo "=== 531 Frontend AWS Setup ==="
echo ""

# Step 1: Create S3 bucket (keeps default Block Public Access - more secure)
echo "Step 1: Creating S3 bucket..."
if aws s3api head-bucket --bucket ${S3_BUCKET} 2>/dev/null; then
  echo "  Bucket ${S3_BUCKET} already exists. Skipping."
else
  aws s3 mb s3://${S3_BUCKET} --region ${REGION}
  echo "  Bucket ${S3_BUCKET} created."
fi

# Step 2: Request SSL certificate
echo ""
echo "Step 2: Checking/requesting SSL certificate..."
CERT_ARN=$(aws acm list-certificates --region ${REGION} \
  --query "CertificateSummaryList[?DomainName=='${DOMAIN_NAME}'].CertificateArn" \
  --output text)

if [ -n "$CERT_ARN" ] && [ "$CERT_ARN" != "None" ]; then
  echo "  Certificate already exists: ${CERT_ARN}"
else
  echo "  Requesting new certificate for ${DOMAIN_NAME}..."
  CERT_ARN=$(aws acm request-certificate \
    --domain-name ${DOMAIN_NAME} \
    --validation-method DNS \
    --region ${REGION} \
    --query 'CertificateArn' \
    --output text)
  echo "  Certificate requested: ${CERT_ARN}"
fi

# Get DNS validation record
echo ""
echo "Step 3: Getting DNS validation record..."
sleep 2  # Wait for certificate details to be available

VALIDATION_RECORD=$(aws acm describe-certificate \
  --certificate-arn ${CERT_ARN} \
  --region ${REGION} \
  --query 'Certificate.DomainValidationOptions[0].ResourceRecord' \
  --output json 2>/dev/null || echo "null")

if [ "$VALIDATION_RECORD" != "null" ] && [ -n "$VALIDATION_RECORD" ]; then
  CNAME_NAME=$(echo "$VALIDATION_RECORD" | jq -r '.Name // empty')
  CNAME_VALUE=$(echo "$VALIDATION_RECORD" | jq -r '.Value // empty')
  if [ -n "$CNAME_NAME" ] && [ -n "$CNAME_VALUE" ]; then
    echo ""
    echo "  ============================================"
    echo "  ADD THIS DNS RECORD IN GODADDY:"
    echo "  ============================================"
    echo "  Type:  CNAME"
    echo "  Name:  ${CNAME_NAME}"
    echo "  Value: ${CNAME_VALUE}"
    echo "  ============================================"
    echo ""
  fi
fi

# Check certificate status
CERT_STATUS=$(aws acm describe-certificate \
  --certificate-arn ${CERT_ARN} \
  --region ${REGION} \
  --query 'Certificate.Status' \
  --output text)

if [ "$CERT_STATUS" != "ISSUED" ]; then
  echo "  Certificate status: ${CERT_STATUS}"
  echo ""
  echo "  !! ACTION REQUIRED !!"
  echo "  Add the DNS validation record in GoDaddy, then wait for validation."
  echo "  Run this script again after the certificate is validated (status: ISSUED)."
  echo ""
  echo "  To check status:"
  echo "  aws acm describe-certificate --certificate-arn ${CERT_ARN} --region ${REGION} --query 'Certificate.Status'"
  exit 0
fi

echo "  Certificate is ISSUED. Proceeding with CloudFront setup..."

# Step 4: Create Origin Access Control
echo ""
echo "Step 4: Creating Origin Access Control..."

OAC_ID=$(aws cloudfront list-origin-access-controls \
  --query "OriginAccessControlList.Items[?Name=='${OAC_NAME}'].Id" \
  --output text 2>/dev/null || echo "")

if [ -n "$OAC_ID" ] && [ "$OAC_ID" != "None" ]; then
  echo "  OAC already exists: ${OAC_ID}"
else
  OAC_ID=$(aws cloudfront create-origin-access-control \
    --origin-access-control-config "{
      \"Name\": \"${OAC_NAME}\",
      \"SigningProtocol\": \"sigv4\",
      \"SigningBehavior\": \"always\",
      \"OriginAccessControlOriginType\": \"s3\"
    }" \
    --query 'OriginAccessControl.Id' \
    --output text)
  echo "  OAC created: ${OAC_ID}"
fi

# Step 5: Create CloudFront distribution
echo ""
echo "Step 5: Checking/creating CloudFront distribution..."

EXISTING_DIST_ID=$(aws cloudfront list-distributions \
  --query "DistributionList.Items[?Aliases.Items[?@ == '${DOMAIN_NAME}']].Id" \
  --output text 2>/dev/null || echo "")

if [ -n "$EXISTING_DIST_ID" ] && [ "$EXISTING_DIST_ID" != "None" ]; then
  echo "  CloudFront distribution already exists: ${EXISTING_DIST_ID}"
  DIST_DOMAIN=$(aws cloudfront get-distribution --id ${EXISTING_DIST_ID} \
    --query 'Distribution.DomainName' --output text)
else
  echo "  Creating CloudFront distribution..."

  # Create distribution config with OAC
  cat > /tmp/cloudfront-config.json << EOF
{
  "CallerReference": "531-frontend-$(date +%s)",
  "Aliases": {
    "Quantity": 1,
    "Items": ["${DOMAIN_NAME}"]
  },
  "DefaultRootObject": "index.html",
  "Origins": {
    "Quantity": 1,
    "Items": [
      {
        "Id": "S3-${S3_BUCKET}",
        "DomainName": "${S3_BUCKET}.s3.${REGION}.amazonaws.com",
        "OriginAccessControlId": "${OAC_ID}",
        "S3OriginConfig": {
          "OriginAccessIdentity": ""
        }
      }
    ]
  },
  "DefaultCacheBehavior": {
    "TargetOriginId": "S3-${S3_BUCKET}",
    "ViewerProtocolPolicy": "redirect-to-https",
    "AllowedMethods": {
      "Quantity": 2,
      "Items": ["GET", "HEAD"],
      "CachedMethods": {
        "Quantity": 2,
        "Items": ["GET", "HEAD"]
      }
    },
    "CachePolicyId": "658327ea-f89d-4fab-a63d-7e88639e58f6",
    "Compress": true
  },
  "CustomErrorResponses": {
    "Quantity": 1,
    "Items": [
      {
        "ErrorCode": 404,
        "ResponsePagePath": "/index.html",
        "ResponseCode": "200",
        "ErrorCachingMinTTL": 300
      }
    ]
  },
  "Comment": "531 Frontend Distribution",
  "Enabled": true,
  "ViewerCertificate": {
    "ACMCertificateArn": "${CERT_ARN}",
    "SSLSupportMethod": "sni-only",
    "MinimumProtocolVersion": "TLSv1.2_2021"
  },
  "PriceClass": "PriceClass_100"
}
EOF

  DIST_OUTPUT=$(aws cloudfront create-distribution \
    --distribution-config file:///tmp/cloudfront-config.json)

  EXISTING_DIST_ID=$(echo "$DIST_OUTPUT" | jq -r '.Distribution.Id')
  DIST_DOMAIN=$(echo "$DIST_OUTPUT" | jq -r '.Distribution.DomainName')

  echo "  Distribution created: ${EXISTING_DIST_ID}"
fi

# Step 6: Set bucket policy to allow CloudFront OAC access
echo ""
echo "Step 6: Setting bucket policy for CloudFront access..."

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

cat > /tmp/bucket-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowCloudFrontServicePrincipal",
      "Effect": "Allow",
      "Principal": {
        "Service": "cloudfront.amazonaws.com"
      },
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::${S3_BUCKET}/*",
      "Condition": {
        "StringEquals": {
          "AWS:SourceArn": "arn:aws:cloudfront::${ACCOUNT_ID}:distribution/${EXISTING_DIST_ID}"
        }
      }
    }
  ]
}
EOF

aws s3api put-bucket-policy --bucket ${S3_BUCKET} --policy file:///tmp/bucket-policy.json
echo "  Bucket policy set (CloudFront OAC only)."

# Cleanup temp files
rm -f /tmp/bucket-policy.json /tmp/cloudfront-config.json

echo ""
echo "=== Setup Complete ==="
echo ""
echo "CloudFront Distribution ID: ${EXISTING_DIST_ID}"
echo "CloudFront Domain: ${DIST_DOMAIN}"
echo ""
echo "============================================"
echo "ADD THIS DNS RECORD IN GODADDY:"
echo "============================================"
echo "Type:  CNAME"
echo "Name:  531"
echo "Value: ${DIST_DOMAIN}"
echo "============================================"
echo ""
echo "After adding the DNS record, you can deploy with:"
echo "  ./deploy_web.sh"
