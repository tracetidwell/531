ACCOUNT_ID="454262414767"
REGION="us-east-1"
APPRUNNER_ECR_ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/AppRunnerECRAccessRole"
APPRUNNER_INSTANCE_ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/AppRunnerInstanceRole"

# Create trust policy for App Runner                                                                                                                                                    
aws iam create-role \
--role-name AppRunnerECRAccessRole \
--assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
    "Effect": "Allow",
    "Principal": {"Service": "build.apprunner.amazonaws.com"},
    "Action": "sts:AssumeRole"
    }]
}'                                                                                                                                                                                    
                                                                                                                                                                                        
# Attach the managed policy for ECR access                                                                                                                                              
aws iam attach-role-policy \
--role-name AppRunnerECRAccessRole \
--policy-arn arn:aws:iam::aws:policy/service-role/AWSAppRunnerServicePolicyForECRAccess

# Create instance role (allows running container to access Secrets Manager)
aws iam create-role \
  --role-name AppRunnerInstanceRole \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {"Service": "tasks.apprunner.amazonaws.com"},
      "Action": "sts:AssumeRole"
    }]
  }'

# Grant instance role access to Secrets Manager
aws iam put-role-policy \
  --role-name AppRunnerInstanceRole \
  --policy-name SecretsManagerAccess \
  --policy-document "{
    \"Version\": \"2012-10-17\",
    \"Statement\": [{
      \"Effect\": \"Allow\",
      \"Action\": [\"secretsmanager:GetSecretValue\"],
      \"Resource\": \"arn:aws:secretsmanager:${REGION}:${ACCOUNT_ID}:secret:531-app/production*\"
    }]
  }"

aws apprunner create-service \
  --service-name 531-backend \
  --source-configuration "{
    \"ImageRepository\": {
      \"ImageIdentifier\": \"${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/531-backend:latest\",
      \"ImageRepositoryType\": \"ECR\",
      \"ImageConfiguration\": {
        \"Port\": \"8000\",
        \"RuntimeEnvironmentSecrets\": {
          \"DATABASE_URL\": \"arn:aws:secretsmanager:${REGION}:${ACCOUNT_ID}:secret:531-app/production:DATABASE_URL::\",
          \"JWT_SECRET_KEY\": \"arn:aws:secretsmanager:${REGION}:${ACCOUNT_ID}:secret:531-app/production:JWT_SECRET_KEY::\",
          \"SMTP_HOST\": \"arn:aws:secretsmanager:${REGION}:${ACCOUNT_ID}:secret:531-app/production:SMTP_HOST::\",
          \"SMTP_PORT\": \"arn:aws:secretsmanager:${REGION}:${ACCOUNT_ID}:secret:531-app/production:SMTP_PORT::\",
          \"SMTP_USER\": \"arn:aws:secretsmanager:${REGION}:${ACCOUNT_ID}:secret:531-app/production:SMTP_USER::\",
          \"SMTP_PASSWORD\": \"arn:aws:secretsmanager:${REGION}:${ACCOUNT_ID}:secret:531-app/production:SMTP_PASSWORD::\"
        }
      }
    },
    \"AutoDeploymentsEnabled\": false,
    \"AuthenticationConfiguration\": {\"AccessRoleArn\": \"${APPRUNNER_ECR_ROLE_ARN}\"}
  }" \
  --instance-configuration "{\"Cpu\":\"0.25 vCPU\",\"Memory\":\"0.5 GB\",\"InstanceRoleArn\":\"${APPRUNNER_INSTANCE_ROLE_ARN}\"}"