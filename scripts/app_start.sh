#!/bin/bash

cd /home/ec2-user/deployment/tier2-app

npm install

pm2 delete tier2 || true

pm2 start server.js --name tier2

pm2 save
