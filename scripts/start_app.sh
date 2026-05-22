#!/bin/bash
set -e

# Restart Apache web server (Tier 1)
systemctl restart httpd
echo "Apache restarted"

# Restart Node.js app service (Tier 2)
# Uses || true so it does not fail if tier2 is not on this server
systemctl restart tier2 2>/dev/null || true
echo "Application start script completed"
