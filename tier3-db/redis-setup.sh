# Redis Setup for Tier 3 Caching (Version 3)
# Run on your Cache server (or same as Tier 2 for practice)

# ── Install Redis on Amazon Linux ─────────────────────
sudo dnf install -y redis6
sudo systemctl start redis6
sudo systemctl enable redis6

# ── Verify Redis is running ───────────────────────────
redis6-cli ping
# Expected output: PONG

# ── Allow Tier 2 to connect (if Redis on separate server)
# Edit /etc/redis6/redis6.conf
# Change: bind 127.0.0.1
# To:     bind 0.0.0.0
sudo systemctl restart redis6

# ── Firewall: allow only Tier 2 IP ───────────────────
sudo firewall-cmd --permanent --add-rich-rule='
  rule family="ipv4"
  source address="TIER2_SERVER_IP/32"
  port port="6379" protocol="tcp" accept'
sudo firewall-cmd --reload

# ── Watch Redis in real time during demo ─────────────
# Run this while students click Reload in the browser
redis6-cli monitor
# You will see:  GET all_students  (cache hit)
# or nothing     (cache miss — went to PostgreSQL instead)

# ── Manually inspect cache ────────────────────────────
redis6-cli GET all_students        # see raw cached data
redis6-cli TTL all_students        # see seconds until expiry
redis6-cli DEL all_students        # manually clear cache
redis6-cli KEYS "*"                # list all cached keys
