MASTER_USER_PASSWORD=$(grep MASTER_USER_PASSWORD /home/trace/Documents/531/backend/.env | cut -d'=' -f2 | tr -d ' ')
JWT_SECRET_KEY=$(grep JWT_SECRET_KEY /home/trace/Documents/531/backend/.env | cut -d'=' -f2 | tr -d ' ')
RDS_ENDPOINT=$(grep RDS_ENDPOINT /home/trace/Documents/531/backend/.env | cut -d'=' -f2 | tr -d ' ')
SMTP_PASSWORD=$(grep SMTP_PASSWORD /home/trace/Documents/531/backend/.env | cut -d'=' -f2 | tr -d ' ')
SMTP_USER=$(grep "^SMTP_USER=" /home/trace/Documents/531/backend/.env | cut -d'=' -f2 | tr -d ' ')

aws secretsmanager create-secret \
    --name 531-app/production \
    --secret-string "{
        \"DATABASE_URL\": \"postgresql://postgres:${MASTER_USER_PASSWORD}@${RDS_ENDPOINT}:5432/five_three_one\",
        \"JWT_SECRET_KEY\": \"${JWT_SECRET_KEY}\",
        \"SMTP_HOST\": \"smtp.gmail.com\",
        \"SMTP_PORT\": \"587\",
        \"SMTP_USER\": \"${SMTP_USER}\",
        \"SMTP_PASSWORD\": \"${SMTP_PASSWORD}\"
    }"