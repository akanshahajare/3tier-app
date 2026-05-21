# 3-Tier Student Records App — Version 3
# PostgreSQL + Redis Cache Edition
# ════════════════════════════════════════════════════════

## What Changed from v2
- Redis caching layer added between Tier 2 and PostgreSQL
- GET requests check Redis first — only hits PostgreSQL on cache miss
- POST and DELETE automatically invalidate the Redis cache
- UI dynamically shows whether data came from Redis or PostgreSQL
- Cache TTL set to 60 seconds (configurable)

## Architecture

```
[Browser]
    │  HTTP :80
    ▼
[TIER 1 — Apache]          index.html (HTML/JS)
    │  HTTP :3000
    ▼
[TIER 2 — Node.js]         server.js (Express API + Business Logic)
    │              │
    │  TCP :6379   │  TCP :5432
    ▼              ▼
[Redis Cache]   [TIER 3 — PostgreSQL]
 Cache HIT →     Cache MISS →
 return data      query DB → store in Redis → return data
```

## How Caching Works (Cache-Aside Pattern)

```
GET /api/students
    │
    ▼
Check Redis for key "all_students"
    │
    ├── HIT  → return data from Redis  (UI shows purple ⚡ Redis banner)
    │
    └── MISS → query PostgreSQL
                  → store result in Redis (TTL: 60s)
                  → return data          (UI shows green 🗄️ PostgreSQL banner)

POST / DELETE
    → always writes to PostgreSQL
    → deletes "all_students" key from Redis
    → next GET will be a cache MISS (fresh data from PostgreSQL)
```

## Project Files

```
3tier-v3/
├── tier1-frontend/
│   └── index.html           ← UI with Redis/PostgreSQL source indicator
├── tier2-app/
│   ├── server.js            ← Express + cache-aside logic
│   └── package.json         ← Dependencies (express, cors, pg, redis)
└── tier3-db/
    ├── setup.sql            ← PostgreSQL schema + sample data
    └── redis-setup.sh       ← Redis install + useful debug commands
```

---

## STEP 1 — Setup Tier 3 (PostgreSQL Server)

Same as v2. Run setup.sql on your PostgreSQL server:

```bash
sudo dnf install -y postgresql15-server
sudo postgresql-setup --initdb
sudo systemctl start postgresql
sudo systemctl enable postgresql

sudo -u postgres psql -f tier3-db/setup.sql
```

**Edit pg_hba.conf to allow Tier 2:**
```bash
sudo vi /var/lib/pgsql/data/pg_hba.conf
# Add: host  school_db  appuser  TIER2_SERVER_IP/32  md5

sudo systemctl restart postgresql
```

**Firewall:**
```bash
sudo firewall-cmd --permanent --add-rich-rule='
  rule family="ipv4"
  source address="TIER2_SERVER_IP/32"
  port port="5432" protocol="tcp" accept'
sudo firewall-cmd --reload
```

---

## STEP 2 — Setup Redis Cache Server

Redis can run on the same server as Tier 2 (for practice) or on a dedicated server.

```bash
# Install Redis
sudo dnf install -y redis6
sudo systemctl start redis6
sudo systemctl enable redis6

# Verify
redis6-cli ping
# Output: PONG
```

**If Redis is on a separate server — allow remote connections:**
```bash
sudo vi /etc/redis6/redis6.conf
# Change:  bind 127.0.0.1
# To:      bind 0.0.0.0

sudo systemctl restart redis6
```

**Firewall — open 6379 to Tier 2 only:**
```bash
sudo firewall-cmd --permanent --add-rich-rule='
  rule family="ipv4"
  source address="TIER2_SERVER_IP/32"
  port port="6379" protocol="tcp" accept'
sudo firewall-cmd --reload
```

---

## STEP 3 — Setup Tier 2 (Node.js App Server)

```bash
# Install Node.js
curl -fsSL https://rpm.nodesource.com/setup_18.x | sudo bash -
sudo dnf install -y nodejs

# Copy and install
sudo mkdir -p /opt/tier2-app
sudo cp tier2-app/* /opt/tier2-app/
cd /opt/tier2-app
npm install

# Test run with env vars
export DB_HOST="TIER3_SERVER_IP"
export DB_PORT="5432"
export DB_USER="appuser"
export DB_PASSWORD="apppassword"
export DB_NAME="school_db"
export REDIS_HOST="REDIS_SERVER_IP"   # or 127.0.0.1 if on same server
export REDIS_PORT="6379"

node server.js
```

**Run as systemd service:**
```bash
sudo tee /etc/systemd/system/tier2.service > /dev/null <<EOF
[Unit]
Description=Tier 2 App Server v3 (PostgreSQL + Redis)
After=network.target

[Service]
WorkingDirectory=/opt/tier2-app
ExecStart=/usr/bin/node server.js
Restart=always
Environment=DB_HOST=TIER3_SERVER_IP
Environment=DB_PORT=5432
Environment=DB_USER=appuser
Environment=DB_PASSWORD=apppassword
Environment=DB_NAME=school_db
Environment=REDIS_HOST=REDIS_SERVER_IP
Environment=REDIS_PORT=6379

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable tier2
sudo systemctl start tier2
sudo systemctl status tier2
```

---

## STEP 4 — Setup Tier 1 (Apache Web Server)

```bash
sudo dnf install -y httpd
sudo systemctl start httpd && sudo systemctl enable httpd

sudo mkdir -p /var/www/3tier-app
sudo cp tier1-frontend/index.html /var/www/3tier-app/

# Point to Tier 2 IP
sudo sed -i 's|http://localhost:3000|http://TIER2_SERVER_IP:3000|g' \
    /var/www/3tier-app/index.html

sudo tee /etc/httpd/conf.d/tier1.conf > /dev/null <<EOF
<VirtualHost *:80>
    DocumentRoot /var/www/3tier-app
    <Directory /var/www/3tier-app>
        Options -Indexes +FollowSymLinks
        AllowOverride None
        Require all granted
    </Directory>
    ErrorLog  /var/log/httpd/tier1_error.log
    CustomLog /var/log/httpd/tier1_access.log combined
</VirtualHost>
EOF

sudo apachectl configtest && sudo systemctl reload httpd
sudo firewall-cmd --permanent --add-service=http && sudo firewall-cmd --reload
```

---

## STEP 5 — Verify Full Stack

```bash
# Redis up?
redis6-cli ping

# Tier 2 health (shows DB + Cache status)?
curl http://TIER2_SERVER_IP:3000/health

# First load — should hit PostgreSQL (cache MISS)
curl http://TIER2_SERVER_IP:3000/api/students | python3 -m json.tool

# Second load — should hit Redis (cache HIT)
curl http://TIER2_SERVER_IP:3000/api/students | python3 -m json.tool
# Look for "source": "redis" in the response

# Open browser
# http://TIER1_SERVER_IP
# Click Reload twice — watch the banner change colour
```

---

## Classroom Demo Flow

```
1. Open browser → first load → green banner (PostgreSQL)
2. Click Reload  → second load → purple banner (Redis ⚡ Cache HIT)
3. Watch TTL countdown on screen
4. Add a new student → cache cleared → next reload is green again
5. Run on Tier 2:  sudo journalctl -u tier2 -f
   Students can see [CACHE HIT] and [CACHE MISS] logs in real time
6. Run on Redis:   redis6-cli monitor
   Students can see the GET/SET commands firing on cache hits/misses
```

---

## Port Reference

| Component  | Port | Server       | Open To             |
|------------|------|--------------|---------------------|
| Apache     | 80   | Tier 1       | Internet (everyone) |
| Node.js    | 3000 | Tier 2       | Tier 1 IP only      |
| Redis      | 6379 | Cache server | Tier 2 IP only      |
| PostgreSQL | 5432 | Tier 3       | Tier 2 IP only      |

## Troubleshooting

```bash
# Watch Tier 2 cache logs live
sudo journalctl -u tier2 -f
# Look for: [CACHE HIT], [CACHE MISS], [CACHE SET], [CACHE CLEAR]

# Watch Redis commands in real time
redis6-cli monitor

# Check if key exists and its TTL
redis6-cli GET all_students
redis6-cli TTL all_students

# Manually clear cache to force a DB hit
redis6-cli DEL all_students

# Check all ports
ss -tlnp | grep -E '80|3000|5432|6379'
```
