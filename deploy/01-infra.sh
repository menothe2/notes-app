#!/usr/bin/env bash
# =============================================================
# 01-infra.sh — Provision all AWS infrastructure
#   - VPC / Security Groups
#   - RDS PostgreSQL (db.t3.micro)
#   - EC2 (t3.micro) with Java 17 pre-installed
#   - S3 bucket (static frontend)
#   - CloudFront distribution (CDN over S3)
#
# Prerequisites:
#   aws cli v2 installed and configured (`aws configure`)
#   Fill in deploy/config.env before running
# =============================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.env"

echo "==> [1/7] Creating VPC and networking..."
VPC_ID=$(aws ec2 create-vpc \
  --cidr-block 10.0.0.0/16 \
  --region "$AWS_REGION" \
  --query 'Vpc.VpcId' --output text)
aws ec2 modify-vpc-attribute --vpc-id "$VPC_ID" --enable-dns-hostnames "{\"Value\":true}" --region "$AWS_REGION"
aws ec2 create-tags --resources "$VPC_ID" --tags "Key=Name,Value=${APP_NAME}-vpc" --region "$AWS_REGION"

IGW_ID=$(aws ec2 create-internet-gateway --region "$AWS_REGION" --query 'InternetGateway.InternetGatewayId' --output text)
aws ec2 attach-internet-gateway --vpc-id "$VPC_ID" --internet-gateway-id "$IGW_ID" --region "$AWS_REGION"

SUBNET_A=$(aws ec2 create-subnet \
  --vpc-id "$VPC_ID" --cidr-block 10.0.1.0/24 \
  --availability-zone "${AWS_REGION}a" \
  --region "$AWS_REGION" \
  --query 'Subnet.SubnetId' --output text)
SUBNET_B=$(aws ec2 create-subnet \
  --vpc-id "$VPC_ID" --cidr-block 10.0.2.0/24 \
  --availability-zone "${AWS_REGION}b" \
  --region "$AWS_REGION" \
  --query 'Subnet.SubnetId' --output text)

RT_ID=$(aws ec2 create-route-table --vpc-id "$VPC_ID" --region "$AWS_REGION" --query 'RouteTable.RouteTableId' --output text)
aws ec2 create-route --route-table-id "$RT_ID" --destination-cidr-block 0.0.0.0/0 --gateway-id "$IGW_ID" --region "$AWS_REGION"
aws ec2 associate-route-table --route-table-id "$RT_ID" --subnet-id "$SUBNET_A" --region "$AWS_REGION"
aws ec2 associate-route-table --route-table-id "$RT_ID" --subnet-id "$SUBNET_B" --region "$AWS_REGION"
aws ec2 modify-subnet-attribute --subnet-id "$SUBNET_A" --map-public-ip-on-launch --region "$AWS_REGION"

echo "==> [2/7] Creating security groups..."
# EC2: allow SSH (22) and app port (8080) from anywhere, all outbound
SG_EC2=$(aws ec2 create-security-group \
  --group-name "${APP_NAME}-ec2-sg" \
  --description "EC2 security group for ${APP_NAME}" \
  --vpc-id "$VPC_ID" --region "$AWS_REGION" \
  --query 'GroupId' --output text)
aws ec2 authorize-security-group-ingress --group-id "$SG_EC2" --protocol tcp --port 22   --cidr 0.0.0.0/0 --region "$AWS_REGION"
aws ec2 authorize-security-group-ingress --group-id "$SG_EC2" --protocol tcp --port 8080 --cidr 0.0.0.0/0 --region "$AWS_REGION"

# RDS: allow PostgreSQL (5432) only from EC2 SG
SG_RDS=$(aws ec2 create-security-group \
  --group-name "${APP_NAME}-rds-sg" \
  --description "RDS security group for ${APP_NAME}" \
  --vpc-id "$VPC_ID" --region "$AWS_REGION" \
  --query 'GroupId' --output text)
aws ec2 authorize-security-group-ingress --group-id "$SG_RDS" \
  --protocol tcp --port 5432 --source-group "$SG_EC2" --region "$AWS_REGION"

echo "==> [3/7] Creating RDS subnet group and PostgreSQL instance..."
aws rds create-db-subnet-group \
  --db-subnet-group-name "${APP_NAME}-subnet-group" \
  --db-subnet-group-description "${APP_NAME} subnet group" \
  --subnet-ids "$SUBNET_A" "$SUBNET_B" \
  --region "$AWS_REGION"

aws rds create-db-instance \
  --db-instance-identifier "$DB_INSTANCE_ID" \
  --db-instance-class db.t3.micro \
  --engine postgres \
  --engine-version 15 \
  --master-username "$DB_USER" \
  --master-user-password "$DB_PASSWORD" \
  --db-name "$DB_NAME" \
  --allocated-storage 20 \
  --no-publicly-accessible \
  --vpc-security-group-ids "$SG_RDS" \
  --db-subnet-group-name "${APP_NAME}-subnet-group" \
  --backup-retention-period 7 \
  --region "$AWS_REGION"

echo "  RDS is provisioning (takes ~5 min). Continuing with EC2..."

echo "==> [4/7] Launching EC2 instance..."
# Latest Amazon Linux 2023 AMI
AMI_ID=$(aws ec2 describe-images \
  --owners amazon \
  --filters "Name=name,Values=al2023-ami-*-x86_64" "Name=state,Values=available" \
  --query 'sort_by(Images, &CreationDate)[-1].ImageId' \
  --region "$AWS_REGION" --output text)

EC2_ID=$(aws ec2 run-instances \
  --image-id "$AMI_ID" \
  --instance-type "$EC2_INSTANCE_TYPE" \
  --key-name "$EC2_KEY_NAME" \
  --security-group-ids "$SG_EC2" \
  --subnet-id "$SUBNET_A" \
  --user-data file://"$SCRIPT_DIR/ec2-userdata.sh" \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${APP_NAME}-server}]" \
  --region "$AWS_REGION" \
  --query 'Instances[0].InstanceId' --output text)

echo "  EC2 instance ID: $EC2_ID"
echo "  Waiting for EC2 to be running..."
aws ec2 wait instance-running --instance-ids "$EC2_ID" --region "$AWS_REGION"
EC2_PUBLIC_IP=$(aws ec2 describe-instances \
  --instance-ids "$EC2_ID" \
  --region "$AWS_REGION" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)

echo "==> [5/7] Creating S3 bucket for frontend..."
if [ "$AWS_REGION" = "us-east-1" ]; then
  aws s3api create-bucket --bucket "$S3_BUCKET" --region "$AWS_REGION"
else
  aws s3api create-bucket --bucket "$S3_BUCKET" --region "$AWS_REGION" \
    --create-bucket-configuration LocationConstraint="$AWS_REGION"
fi
aws s3api put-public-access-block --bucket "$S3_BUCKET" \
  --public-access-block-configuration "BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false"
aws s3api put-bucket-policy --bucket "$S3_BUCKET" --policy "{
  \"Version\": \"2012-10-17\",
  \"Statement\": [{
    \"Effect\": \"Allow\",
    \"Principal\": \"*\",
    \"Action\": \"s3:GetObject\",
    \"Resource\": \"arn:aws:s3:::${S3_BUCKET}/*\"
  }]
}"
aws s3 website "s3://$S3_BUCKET" --index-document index.html --error-document index.html

echo "==> [6/7] Creating CloudFront distribution..."
CF_RESULT=$(aws cloudfront create-distribution --distribution-config "{
  \"CallerReference\": \"${APP_NAME}-$(date +%s)\",
  \"DefaultRootObject\": \"index.html\",
  \"Origins\": {
    \"Quantity\": 1,
    \"Items\": [{
      \"Id\": \"s3-${S3_BUCKET}\",
      \"DomainName\": \"${S3_BUCKET}.s3-website-${AWS_REGION}.amazonaws.com\",
      \"CustomOriginConfig\": {
        \"HTTPPort\": 80,
        \"HTTPSPort\": 443,
        \"OriginProtocolPolicy\": \"http-only\"
      }
    }]
  },
  \"DefaultCacheBehavior\": {
    \"TargetOriginId\": \"s3-${S3_BUCKET}\",
    \"ViewerProtocolPolicy\": \"redirect-to-https\",
    \"AllowedMethods\": {\"Quantity\": 2, \"Items\": [\"GET\", \"HEAD\"]},
    \"CachePolicyId\": \"658327ea-f89d-4fab-a63d-7e88639e58f6\",
    \"Compress\": true
  },
  \"CustomErrorResponses\": {
    \"Quantity\": 1,
    \"Items\": [{
      \"ErrorCode\": 404,
      \"ResponsePagePath\": \"/index.html\",
      \"ResponseCode\": \"200\",
      \"ErrorCachingMinTTL\": 0
    }]
  },
  \"Comment\": \"${APP_NAME} frontend\",
  \"Enabled\": true,
  \"PriceClass\": \"PriceClass_100\"
}" --region us-east-1)

CF_DOMAIN=$(echo "$CF_RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin)['Distribution']['DomainName'])")
CF_ID=$(echo "$CF_RESULT"     | python3 -c "import sys,json; print(json.load(sys.stdin)['Distribution']['Id'])")

echo "==> [7/7] Waiting for RDS to become available..."
aws rds wait db-instance-available --db-instance-identifier "$DB_INSTANCE_ID" --region "$AWS_REGION"
DB_HOST=$(aws rds describe-db-instances \
  --db-instance-identifier "$DB_INSTANCE_ID" \
  --region "$AWS_REGION" \
  --query 'DBInstances[0].Endpoint.Address' --output text)

echo ""
echo "============================================================"
echo "  Infrastructure ready!"
echo "============================================================"
echo "  EC2 public IP : $EC2_PUBLIC_IP"
echo "  RDS host      : $DB_HOST"
echo "  S3 bucket     : $S3_BUCKET"
echo "  CloudFront    : https://$CF_DOMAIN  (ID: $CF_ID)"
echo ""
echo "  ACTION REQUIRED — update deploy/config.env:"
echo "    EC2_PUBLIC_IP=$EC2_PUBLIC_IP"
echo "    CLOUDFRONT_DOMAIN=$CF_DOMAIN"
echo ""
echo "  Then run:"
echo "    02-deploy-backend.sh   (first deploy of the Spring Boot JAR)"
echo "    03-deploy-frontend.sh  (first deploy of the React build)"
echo "============================================================"
