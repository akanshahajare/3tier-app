#!/bin/bash
set -e

echo "Deploying frontend files..."

cp -r /opt/tier1-frontend/* /var/www/html/

systemctl restart httpd

echo "Frontend deployed successfully"
