#!/bin/bash
set -e

cd /opt/tier2-app

# Install dependencies
npm install

# Install PM2 globally if missing
npm install -g pm2

# Restart app
pm2 delete tier2 || true
pm2 start server.js --name tier2
pm2 save
