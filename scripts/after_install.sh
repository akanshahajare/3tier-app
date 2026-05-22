#!/bin/bash
set -e

# Ensure Apache is installed and enabled (Tier 1)
dnf install -y httpd 2>/dev/null || true
systemctl enable httpd

# Install Node.js production dependencies (Tier 2)
if [ -d /opt/tier2-app ]; then
  cd /opt/tier2-app
  npm install --production
  echo "Node.js deps installed"
fi

# Dynamically patch index.html with actual Tier 2 private IP
# (replaces localhost:3000 with real private IP)
TIER2_IP=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=Tier2-App" "Name=instance-state-name,Values=running" \
  --query "Reservations[0].Instances[0].PrivateIpAddress" \
  --output text --region us-east-1 2>/dev/null || echo "")

if [ ! -z "$TIER2_IP" ] && [ "$TIER2_IP" != "None" ]; then
  sed -i "s|http://localhost:3000|http://${TIER2_IP}:3000|g" \
    /var/www/3tier-app/index.html
  echo "Patched Tier2 IP to: ${TIER2_IP}"
fi

echo "after_install.sh completed"
