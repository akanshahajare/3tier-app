#!/bin/bash
set -e
sudo rm -rf /var/www/3tier-app/*
sudo cp -r /home/ec2-user/deployment/tier1-frontend/* /var/www/3tier-app/
sudo chmod -R 755 /var/www/3tier-app/
sudo chown -R apache:apache /var/www/3tier-app/
sudo systemctl restart httpd
echo "Deploy complete - $(date)" >> /var/log/web_deploy.log
