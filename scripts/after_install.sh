#!/bin/bash
set -e

echo "Updating system packages..."

dnf update -y

echo "Installing Apache..."

dnf install -y httpd

systemctl enable httpd
systemctl start httpd

echo "Installing Node.js..."

curl -fsSL https://rpm.nodesource.com/setup_18.x | bash -

dnf install -y nodejs

echo "Installing PM2..."

npm install -g pm2

echo "Installing Tier2 dependencies..."

cd /opt/tier2-app

npm install

echo "after_install.sh completed"
