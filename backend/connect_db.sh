#!/bin/bash
# Connect to RDS PostgreSQL via bastion

echo "Looking up bastion instance..."
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=531-bastion" "Name=instance-state-name,Values=running,stopped" \
  --query 'Reservations[0].Instances[0].InstanceId' \
  --output text)

if [ "$INSTANCE_ID" == "None" ] || [ -z "$INSTANCE_ID" ]; then
  echo "Error: Bastion instance not found. Run setup_bastion.sh first."
  exit 1
fi

# Check if instance is running, start if stopped
INSTANCE_STATE=$(aws ec2 describe-instances \
  --instance-ids $INSTANCE_ID \
  --query 'Reservations[0].Instances[0].State.Name' \
  --output text)

if [ "$INSTANCE_STATE" == "stopped" ]; then
  echo "Bastion is stopped. Starting it..."
  aws ec2 start-instances --instance-ids $INSTANCE_ID > /dev/null
  echo "Waiting for instance to start..."
  aws ec2 wait instance-running --instance-ids $INSTANCE_ID
  echo "Waiting for SSM agent to come online..."
  sleep 30
fi

echo "Looking up RDS endpoint..."
RDS_ENDPOINT=$(aws rds describe-db-instances \
  --db-instance-identifier five-three-one-db \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text)

if [ "$RDS_ENDPOINT" == "None" ] || [ -z "$RDS_ENDPOINT" ]; then
  echo "Error: RDS instance not found."
  exit 1
fi

echo ""
echo "Starting port forwarding session..."
echo "Once connected, use your database client to connect to:"
echo "  Host: localhost"
echo "  Port: 5432"
echo "  Database: five_three_one"
echo "  User: postgres"
echo ""
echo "Press Ctrl+C to disconnect"
echo ""

aws ssm start-session \
  --target $INSTANCE_ID \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters "{\"host\":[\"$RDS_ENDPOINT\"],\"portNumber\":[\"5432\"],\"localPortNumber\":[\"5432\"]}"
