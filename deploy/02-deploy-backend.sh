#!/usr/bin/env bash
# =============================================================
# 02-deploy-backend.sh — Build and deploy the Spring Boot JAR to EC2
#
# Run after 01-infra.sh and after filling in config.env with
# EC2_PUBLIC_IP and DB_HOST values.
# =============================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
source "$SCRIPT_DIR/config.env"

# Validate required config
for var in EC2_PUBLIC_IP EC2_KEY_PATH DB_HOST DB_NAME DB_USER DB_PASSWORD CLOUDFRONT_DOMAIN JWT_SECRET; do
  if [ -z "${!var:-}" ]; then
    echo "ERROR: $var is not set in config.env"
    exit 1
  fi
done

SSH="ssh -i $EC2_KEY_PATH -o StrictHostKeyChecking=no ec2-user@$EC2_PUBLIC_IP"
SCP="scp -i $EC2_KEY_PATH -o StrictHostKeyChecking=no"

echo "==> [1/3] Building JAR..."
JAVA_HOME_LOCAL=~/java/jdk-17.0.10+7/Contents/Home
export PATH=$JAVA_HOME_LOCAL/bin:~/java/apache-maven-3.9.6/bin:$PATH
export JAVA_HOME=$JAVA_HOME_LOCAL
cd "$ROOT_DIR/backend"
mvn clean package -DskipTests -q
JAR=$(ls target/*.jar | head -1)
echo "  Built: $JAR"

echo "==> [2/3] Uploading JAR to EC2..."
$SCP "$JAR" "ec2-user@$EC2_PUBLIC_IP:/tmp/app.jar"

echo "==> [3/3] Deploying on EC2..."
$SSH << EOF
  # Write environment file read by the systemd service
  sudo tee /opt/notes/env > /dev/null << 'ENVEOF'
DB_HOST=${DB_HOST}
DB_NAME=${DB_NAME}
DB_USER=${DB_USER}
DB_PASSWORD=${DB_PASSWORD}
CORS_ALLOWED_ORIGINS=https://${CLOUDFRONT_DOMAIN}
JWT_SECRET=${JWT_SECRET}
ENVEOF
  sudo chmod 600 /opt/notes/env
  sudo chown notes:notes /opt/notes/env

  sudo mv /tmp/app.jar /opt/notes/app.jar
  sudo chown notes:notes /opt/notes/app.jar

  sudo systemctl restart notes
  echo "  Waiting for service to start..."
  sleep 8
  sudo systemctl status notes --no-pager
EOF

echo ""
echo "============================================================"
echo "  Backend deployed!"
echo "  API: http://$EC2_PUBLIC_IP:8080/api/notes"
echo "  Logs: ssh -i $EC2_KEY_PATH ec2-user@$EC2_PUBLIC_IP"
echo "          sudo journalctl -u notes -f"
echo "============================================================"
