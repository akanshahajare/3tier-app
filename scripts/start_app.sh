#!/bin/bash
set -e

echo "Restarting complete application..."

systemctl restart httpd

cd /opt/tier2-app

pm2 restart tier2 || pm2 start server.js --name tier2

echo "Application restarted successfully"
