#!/bin/bash
set -e

echo "Setting up bastion host for database access..."

# Variables from RDS
VPC_ID="vpc-95e58cf3"
SUBNET_ID="subnet-1c782331"
RDS_ENDPOINT="five-three-one-db.c2n0a6e6ozip.us-east-1.rds.amazonaws.com"
RDS_SG="sg-04aef6d181f23bc77"
REGION="us-east-1"

# Step 1: Create IAM role for SSM
echo "Creating IAM role for Session Manager..."
cat > /tmp/ec2-trust-policy.json << 'TRUST'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
TRUST

aws iam create-role \
  --role-name 531-bastion-role \
  --assume-role-policy-document file:///tmp/ec2-trust-policy.json \
  2>/dev/null || echo "Role already exists"

aws iam attach-role-policy \
  --role-name 531-bastion-role \
  --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore \
  2>/dev/null || echo "Policy already attached"

# Create instance profile
aws iam create-instance-profile \
  --instance-profile-name 531-bastion-profile \
  2>/dev/null || echo "Instance profile already exists"

aws iam add-role-to-instance-profile \
  --instance-profile-name 531-bastion-profile \
  --role-name 531-bastion-role \
  2>/dev/null || echo "Role already added to profile"

echo "Waiting for instance profile to propagate..."
sleep 10

# Step 2: Create security group for bastion
echo "Creating bastion security group..."
BASTION_SG=$(aws ec2 create-security-group \
  --group-name 531-bastion-sg \
  --description "Bastion host for database access" \
  --vpc-id $VPC_ID \
  --query 'GroupId' \
  --output text 2>/dev/null || \
  aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=531-bastion-sg" \
    --query 'SecurityGroups[0].GroupId' \
    --output text)

echo "Bastion SG: $BASTION_SG"

# Allow outbound to RDS (PostgreSQL)
aws ec2 authorize-security-group-egress \
  --group-id $BASTION_SG \
  --protocol tcp \
  --port 5432 \
  --source-group $RDS_SG \
  2>/dev/null || echo "Egress rule already exists"

# Step 3: Allow bastion to connect to RDS
echo "Updating RDS security group to allow bastion..."
aws ec2 authorize-security-group-ingress \
  --group-id $RDS_SG \
  --protocol tcp \
  --port 5432 \
  --source-group $BASTION_SG \
  2>/dev/null || echo "Ingress rule already exists"

# Step 4: Get latest Amazon Linux 2023 AMI
echo "Getting latest AMI..."
AMI_ID=$(aws ec2 describe-images \
  --owners amazon \
  --filters "Name=name,Values=al2023-ami-2023*-x86_64" "Name=state,Values=available" \
  --query 'sort_by(Images, &CreationDate)[-1].ImageId' \
  --output text)

echo "AMI: $AMI_ID"

# Step 5: Launch bastion instance
echo "Launching bastion instance..."
INSTANCE_ID=$(aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type t3.micro \
  --subnet-id $SUBNET_ID \
  --security-group-ids $BASTION_SG \
  --iam-instance-profile Name=531-bastion-profile \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=531-bastion}]' \
  --query 'Instances[0].InstanceId' \
  --output text)

echo "Instance ID: $INSTANCE_ID"

echo "Waiting for instance to be running..."
aws ec2 wait instance-running --instance-ids $INSTANCE_ID

echo "Waiting for SSM agent to register (this may take 1-2 minutes)..."
sleep 60

# Verify SSM connection
for i in {1..10}; do
  SSM_STATUS=$(aws ssm describe-instance-information \
    --filters "Key=InstanceIds,Values=$INSTANCE_ID" \
    --query 'InstanceInformationList[0].PingStatus' \
    --output text 2>/dev/null || echo "NotFound")
  
  if [ "$SSM_STATUS" = "Online" ]; then
    echo "SSM agent is online!"
    break
  fi
  echo "Waiting for SSM... ($i/10)"
  sleep 15
done

# Save connection script
cat > /home/trace/Documents/531/backend/connect_db.sh << CONNECT
#!/bin/bash
# Connect to RDS PostgreSQL via bastion

INSTANCE_ID="$INSTANCE_ID"
RDS_ENDPOINT="$RDS_ENDPOINT"

echo "Starting port forwarding session..."
echo "Once connected, use your database client to connect to:"
echo "  Host: localhost"
echo "  Port: 5432"
echo "  Database: five_three_one"
echo "  User: postgres"
echo ""
echo "Press Ctrl+C to disconnect"
echo ""

aws ssm start-session \\
  --target \$INSTANCE_ID \\
  --document-name AWS-StartPortForwardingSessionToRemoteHost \\
  --parameters '{"host":["\$RDS_ENDPOINT"],"portNumber":["5432"],"localPortNumber":["5432"]}'
CONNECT

chmod +x /home/trace/Documents/531/backend/connect_db.sh

echo ""
echo "========================================="
echo "Setup complete!"
echo "========================================="
echo ""
echo "Instance ID: $INSTANCE_ID"
echo "RDS Endpoint: $RDS_ENDPOINT"
echo ""
echo "To connect to the database:"
echo "  1. Run: ./connect_db.sh"
echo "  2. Open pgAdmin/DBeaver and connect to localhost:5432"
echo "  3. Database: five_three_one, User: postgres"
echo ""
echo "To stop the bastion (save money):"
echo "  aws ec2 stop-instances --instance-ids $INSTANCE_ID"
echo ""
echo "To start it again:"
echo "  aws ec2 start-instances --instance-ids $INSTANCE_ID"
echo ""
