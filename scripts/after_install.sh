#!/bin/bash
set -e

# Update packages
dnf update -y

# Install Apache
dnf install -y httpd

# Install Node.js
curl -fsSL https://rpm.nodesource.com/setup_18.x | bash -
dnf install -y nodejs

# Install PM2 globally
npm install -g pm2

# Enable Apache
systemctl enable httpd
systemctl start httpd

# Install Tier2 dependencies
if [ -d /opt/tier2-app ]; then
  cd /opt/tier2-app
  npm install --production
fi

echo "after_install.sh completed"
