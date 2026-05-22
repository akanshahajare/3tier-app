#!/bin/bash
set -e

echo "Cleaning old deployment..."

mkdir -p /opt/tier1-frontend
mkdir -p /opt/tier2-app

rm -rf /opt/tier1-frontend/*
rm -rf /opt/tier2-app/*
rm -rf /var/www/html/*

echo "before_install.sh completed"
