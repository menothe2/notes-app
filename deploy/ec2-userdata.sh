#!/usr/bin/env bash
# EC2 user-data: runs once on first boot
# Installs Java 17, creates the app user and systemd service
set -euo pipefail

# Install Java 17
dnf install -y java-17-amazon-corretto-headless

# Create app user
useradd -r -s /sbin/nologin notes || true
mkdir -p /opt/notes
chown notes:notes /opt/notes

# Create systemd service (app JAR will be deployed by 02-deploy-backend.sh)
cat > /etc/systemd/system/notes.service << 'EOF'
[Unit]
Description=Notes App Spring Boot
After=network.target

[Service]
User=notes
WorkingDirectory=/opt/notes
EnvironmentFile=/opt/notes/env
ExecStart=/usr/bin/java -jar /opt/notes/app.jar --spring.profiles.active=prod
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=notes

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable notes
