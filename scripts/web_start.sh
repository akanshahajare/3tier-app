#!/bin/bash
set -e

cp -r /opt/tier1-frontend/* /var/www/html/

systemctl restart httpd
systemctl enable httpd
