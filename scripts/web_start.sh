#!/bin/bash
sudo rm -rf /var/www/html/*
sudo cp -r /home/ec2-user/deployment/tier1-frontend/* /var/www/html/
sudo systemctl restart httpd
