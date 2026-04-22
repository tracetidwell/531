# AWS Hosting Guide for 5/3/1 Training App

## Architecture Overview

**Full deployment (web + mobile):**
```
[Route 53] → [CloudFront] → [S3] (Flutter web build)
                  ↓
           [ALB] → [ECS Fargate] (FastAPI backend)
                        ↓
                   [RDS PostgreSQL]
```

**Mobile-only (no domain needed):**
```
[Mobile App] → [App Runner] (FastAPI backend, auto-HTTPS)
                    ↓
              [RDS PostgreSQL]
```
For mobile-only, follow steps 1-4 (using App Runner instead of ECS/ALB), and skip steps 5-7.

---

## 1. Prerequisites

- AWS account with CLI configured (`aws configure`)
- A domain name (optional but recommended)
- Docker installed locally for building images

---

## 2. Database: RDS PostgreSQL

```bash
# Create a VPC security group for RDS
aws ec2 create-security-group \
  --group-name 531-db-sg \
  --description "5/3/1 app database"

# Create RDS instance
aws rds create-db-instance \
  --db-instance-identifier five-three-one-db \
  --db-instance-class db.t3.micro \
  --engine postgres \
  --engine-version 16.4 \
  --master-username postgres \
  --master-user-password <STRONG_PASSWORD> \
  --allocated-storage 20 \
  --db-name five_three_one \
  --vpc-security-group-ids <SG_ID> \
  --no-publicly-accessible \
  --storage-encrypted \
  --backup-retention-period 7
```

Note the endpoint after creation:
```bash
aws rds describe-db-instances --db-instance-identifier five-three-one-db \
  --query 'DBInstances[0].Endpoint.Address'
```

---

## 3. Secrets: AWS Secrets Manager

Store sensitive config rather than hardcoding in environment variables:

```bash
aws secretsmanager create-secret \
  --name 531-app/production \
  --secret-string '{
    "DATABASE_URL": "postgresql://postgres:<PASSWORD>@<RDS_ENDPOINT>:5432/five_three_one",
    "JWT_SECRET_KEY": "<GENERATE_STRONG_KEY>",
    "SMTP_HOST": "smtp.gmail.com",
    "SMTP_PORT": "587",
    "SMTP_USER": "your-email@gmail.com",
    "SMTP_PASSWORD": "your-app-password"
  }'
```

Generate a strong JWT secret:
```bash
openssl rand -hex 32
```

---

## 4. Backend: ECR + ECS Fargate

### 4a. Update Dockerfile for production

In `backend/Dockerfile`, change the CMD to remove `--reload`:

```dockerfile
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "2"]
```

### 4b. Update CORS in `backend/app/main.py`

**Mobile-only (no domain):** CORS is a browser-only mechanism. Native mobile apps (Flutter with Dio) are not subject to CORS, so you can skip this step entirely. The existing permissive CORS config is fine.

**Web deployment (with domain):** Replace the localhost regex with your actual frontend domain:

```python
allow_origin_regex=r"https://yourdomain\.com"
```

### 4c. Push image to ECR

```bash
# Create ECR repository
aws ecr create-repository --repository-name 531-backend

# Login to ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com

# Build and push
cd /home/trace/Documents/531/backend
docker build -t 531-backend .
docker tag 531-backend:latest <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/531-backend:latest
docker push <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/531-backend:latest
```

### 4d. Create ECS cluster and service

```bash
# Create cluster
aws ecs create-cluster --cluster-name 531-cluster

# Create task execution role (needs ECR pull + Secrets Manager access)
# Create task definition (JSON file):
```

**task-definition.json** (for mobile-only, you can remove the `CORS_ORIGINS` environment entry or set it to `["*"]`):
```json
{
  "family": "531-backend",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512",
  "executionRoleArn": "arn:aws:iam::<ACCOUNT_ID>:role/ecsTaskExecutionRole",
  "containerDefinitions": [{
    "name": "backend",
    "image": "<ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/531-backend:latest",
    "portMappings": [{"containerPort": 8000, "protocol": "tcp"}],
    "environment": [
      {"name": "CORS_ORIGINS", "value": "[\"https://yourdomain.com\"]"}
    ],
    "secrets": [
      {"name": "DATABASE_URL", "valueFrom": "arn:aws:secretsmanager:us-east-1:<ACCOUNT_ID>:secret:531-app/production:DATABASE_URL::"},
      {"name": "JWT_SECRET_KEY", "valueFrom": "arn:aws:secretsmanager:us-east-1:<ACCOUNT_ID>:secret:531-app/production:JWT_SECRET_KEY::"}
    ],
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "/ecs/531-backend",
        "awslogs-region": "us-east-1",
        "awslogs-stream-prefix": "ecs"
      }
    }
  }]
}
```

```bash
# Register task definition
aws ecs register-task-definition --cli-input-json file://task-definition.json

# Create ALB, target group, and ECS service
aws ecs create-service \
  --cluster 531-cluster \
  --service-name 531-backend \
  --task-definition 531-backend \
  --desired-count 1 \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[<SUBNET_IDS>],securityGroups=[<SG_ID>],assignPublicIp=ENABLED}" \
  --load-balancers "targetGroupArn=<TG_ARN>,containerName=backend,containerPort=8000"
```

### 4e. Run migrations

Run a one-off ECS task to apply migrations:

```bash
aws ecs run-task \
  --cluster 531-cluster \
  --task-definition 531-backend \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[<SUBNET_IDS>],securityGroups=[<SG_ID>],assignPublicIp=ENABLED}" \
  --overrides '{"containerOverrides":[{"name":"backend","command":["python","-m","alembic","upgrade","head"]}]}'
```

---

## 5. Frontend: Fix Hardcoded URL + S3/CloudFront

### 5a. Make the API URL configurable

The API URL is hardcoded at `frontend/lib/services/api_service.dart:16`. Change it to read from a compile-time variable:

```dart
static const String baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8000/api/v1',
);
```

**Mobile-only:** You still need this change. Build the APK with your App Runner URL:

```bash
cd /home/trace/Documents/531/frontend
flutter build apk --release \
  --dart-define=API_BASE_URL=https://<APP_RUNNER_URL>/api/v1
```

The App Runner URL looks like `https://xxxxx.us-east-1.awsapprunner.com`. Get it with:
```bash
aws apprunner list-services --query 'ServiceSummaryList[?ServiceName==`531-backend`].ServiceUrl' --output text
```

Skip steps 5b-5d, 6, and 7 if only deploying for mobile.

### 5b. Build the Flutter web app (web deployment only)

```bash
cd /home/trace/Documents/531/frontend
flutter build web --release \
  --dart-define=API_BASE_URL=https://api.yourdomain.com/api/v1
```

### 5c. Create S3 bucket and upload

```bash
# Create bucket
aws s3 mb s3://531-training-app-frontend

# Configure for static hosting
aws s3 website s3://531-training-app-frontend \
  --index-document index.html \
  --error-document index.html

# Upload build
aws s3 sync build/web/ s3://531-training-app-frontend/ --delete
```

### 5d. Create CloudFront distribution

```bash
aws cloudfront create-distribution \
  --origin-domain-name 531-training-app-frontend.s3.amazonaws.com \
  --default-root-object index.html
```

Configure CloudFront to:
- Redirect HTTP to HTTPS
- Set custom error response: 404 → `/index.html` (for SPA routing)
- Attach ACM certificate for your domain

---

## 6. SSL/TLS: ACM Certificates

```bash
# For CloudFront (must be in us-east-1)
aws acm request-certificate \
  --domain-name yourdomain.com \
  --subject-alternative-names "*.yourdomain.com" \
  --validation-method DNS \
  --region us-east-1

# For ALB (in your region)
aws acm request-certificate \
  --domain-name api.yourdomain.com \
  --validation-method DNS
```

Validate via DNS records in Route 53 or your DNS provider.

---

## 7. DNS: Route 53 (if using Route 53)

```bash
# Frontend: Point domain to CloudFront
aws route53 change-resource-record-sets --hosted-zone-id <ZONE_ID> \
  --change-batch '{
    "Changes": [{
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "yourdomain.com",
        "Type": "A",
        "AliasTarget": {
          "HostedZoneId": "Z2FDTNDATAQYW2",
          "DNSName": "<CLOUDFRONT_DOMAIN>.cloudfront.net",
          "EvaluateTargetHealth": false
        }
      }
    }]
  }'

# Backend: Point api subdomain to ALB
# Similar alias record pointing to ALB DNS name
```

---

## 8. Security Checklist

Before going live:

- [ ] RDS is **not** publicly accessible (only reachable from ECS security group)
- [ ] JWT_SECRET_KEY is a strong random value stored in Secrets Manager
- [ ] CORS in `main.py` is restricted to your frontend domain only
- [ ] Remove `--reload` from Dockerfile CMD
- [ ] Remove the `/network-test` route from the Flutter app
- [ ] Set `ACCESS_TOKEN_EXPIRE_MINUTES` appropriately
- [ ] Enable RDS encryption and automated backups
- [ ] CloudFront enforces HTTPS
- [ ] ALB listener redirects HTTP → HTTPS
- [ ] ECS task role has minimal permissions

---

## 9. Estimated Monthly Cost (minimal setup)

| Service | Spec | ~Cost |
|---------|------|-------|
| RDS PostgreSQL | db.t3.micro, 20GB | $15-20 |
| ECS Fargate | 0.25 vCPU, 512MB, 1 task | $10-15 |
| ALB | 1 load balancer | $16 |
| S3 | Static files, minimal traffic | $1 |
| CloudFront | Low traffic | $1-5 |
| Route 53 | 1 hosted zone | $0.50 |
| **Total** | | **~$45-60/mo** |

---

## 10. Deployment Updates

For subsequent deployments:

**Backend:**
```bash
cd backend
docker build -t 531-backend .
docker tag 531-backend:latest <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/531-backend:latest
docker push <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/531-backend:latest
aws ecs update-service --cluster 531-cluster --service 531-backend --force-new-deployment
```

**Frontend:**
```bash
cd frontend
flutter build web --release --dart-define=API_BASE_URL=https://api.yourdomain.com/api/v1
aws s3 sync build/web/ s3://531-training-app-frontend/ --delete
aws cloudfront create-invalidation --distribution-id <DIST_ID> --paths "/*"
```

---

## Simpler Alternative: AWS App Runner

If you want less infrastructure to manage, App Runner handles load balancing, scaling, and TLS automatically:

```bash
# Push image to ECR first (same as above), then:
aws apprunner create-service \
  --service-name 531-backend \
  --source-configuration '{
    "ImageRepository": {
      "ImageIdentifier": "<ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/531-backend:latest",
      "ImageRepositoryType": "ECR",
      "ImageConfiguration": {
        "Port": "8000",
        "RuntimeEnvironmentSecrets": {
          "DATABASE_URL": "arn:aws:secretsmanager:us-east-1:<ACCOUNT_ID>:secret:531-app/production:DATABASE_URL::",
          "JWT_SECRET_KEY": "arn:aws:secretsmanager:us-east-1:<ACCOUNT_ID>:secret:531-app/production:JWT_SECRET_KEY::"
        }
      }
    },
    "AutoDeploymentsEnabled": false,
    "AuthenticationConfiguration": {"AccessRoleArn": "<APPRUNNER_ECR_ROLE_ARN>"}
  }' \
  --instance-configuration '{"Cpu":"0.25 vCPU","Memory":"0.5 GB"}'
```

This gives you an HTTPS URL automatically (e.g., `https://xxxxx.us-east-1.awsapprunner.com`) without needing ALB, ACM, or Route 53 configuration. You'd still use RDS for the database and S3+CloudFront for the frontend.
