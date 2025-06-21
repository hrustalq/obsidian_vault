# 502 Bad Gateway Troubleshooting Guide

A 502 Bad Gateway error means Nginx can't connect to the CouchDB backend. Follow these steps to diagnose and fix the issue.

## Quick Diagnostics

Run these commands to check the current state:

```bash
# Check if containers are running
docker compose ps

# Check container logs
docker compose logs couchdb-obsidian-livesync
docker compose logs nginx-proxy

# Check container health
docker compose exec couchdb-obsidian-livesync curl -f http://localhost:5984 || echo "CouchDB not responding"

# Check network connectivity
docker compose exec nginx-proxy ping couchdb-obsidian-livesync || echo "Network issue"
```

## Common Causes & Fixes

### 1. CouchDB Container Not Running

**Check:**
```bash
docker compose ps couchdb-obsidian-livesync
```

**If stopped, check logs:**
```bash
docker compose logs couchdb-obsidian-livesync --tail=50
```

**Common fixes:**
- Missing environment variables (especially `COUCHDB_PASSWORD`)
- Volume mount permissions issues
- Configuration file errors

### 2. CouchDB Starting Slowly

CouchDB can take 30-60 seconds to fully start.

**Wait and check:**
```bash
# Wait for CouchDB to be ready
timeout=60
counter=0
while [ $counter -lt $timeout ]; do
  if docker compose exec couchdb-obsidian-livesync curl -f http://localhost:5984 >/dev/null 2>&1; then
    echo "✅ CouchDB is ready!"
    break
  fi
  echo "Waiting... ($counter/$timeout)"
  sleep 2
  counter=$((counter + 2))
done
```

### 3. Network Connectivity Issues

**Test container-to-container communication:**
```bash
# From nginx container, test CouchDB connection
docker compose exec nginx-proxy ping couchdb-obsidian-livesync

# Test specific port
docker compose exec nginx-proxy nc -zv couchdb-obsidian-livesync 5984
```

**Fix network issues:**
```bash
# Recreate containers with fresh network
docker compose down
docker compose up -d
```

### 4. Port Configuration Problems

**Check if CouchDB is listening on the right port:**
```bash
# Inside CouchDB container
docker compose exec couchdb-obsidian-livesync netstat -ln | grep 5984

# Check if port is accessible from nginx
docker compose exec nginx-proxy curl -v http://couchdb-obsidian-livesync:5984
```

### 5. Configuration File Issues

**Check nginx configuration:**
```bash
# Test nginx config syntax
docker compose exec nginx-proxy nginx -t

# Reload nginx if needed
docker compose exec nginx-proxy nginx -s reload
```

**Check CouchDB configuration:**
```bash
# Verify CouchDB config
docker compose exec couchdb-obsidian-livesync cat /opt/couchdb/etc/local.ini
```

## Step-by-Step Troubleshooting

### Step 1: Verify Container Status
```bash
echo "=== Container Status ==="
docker compose ps

echo -e "\n=== Container Health ==="
docker compose exec couchdb-obsidian-livesync curl -f http://localhost:5984 2>/dev/null && echo "✅ CouchDB responding" || echo "❌ CouchDB not responding"
```

### Step 2: Check Logs
```bash
echo "=== CouchDB Logs ==="
docker compose logs couchdb-obsidian-livesync --tail=20

echo -e "\n=== Nginx Logs ==="
docker compose logs nginx-proxy --tail=20
```

### Step 3: Test Network Connectivity
```bash
echo "=== Network Test ==="
docker compose exec nginx-proxy ping -c 3 couchdb-obsidian-livesync

echo -e "\n=== Port Test ==="
docker compose exec nginx-proxy nc -zv couchdb-obsidian-livesync 5984
```

### Step 4: Test Direct CouchDB Access
```bash
echo "=== Direct CouchDB Test ==="
# Test from host (should work if port is exposed)
curl -v http://localhost:5984

# Test from inside network
docker compose exec nginx-proxy curl -v http://couchdb-obsidian-livesync:5984
```

## Quick Fixes

### Fix 1: Restart Everything
```bash
docker compose down
docker compose up -d
# Wait 60 seconds for services to start
sleep 60
curl http://localhost
```

### Fix 2: Recreate with Fresh Network
```bash
docker compose down -v
docker network prune -f
docker compose up -d
```

### Fix 3: Check Environment Variables
```bash
# Ensure required variables are set
docker compose config
```

### Fix 4: Reset to Working State
```bash
# Stop everything
docker compose down -v

# Remove containers and networks
docker system prune -f

# Recreate directory structure
./setup-directories.sh

# Start fresh
docker compose up -d
```

## Advanced Debugging

### Enable Nginx Debug Logging
Add to nginx.conf:
```nginx
error_log /var/log/nginx/error.log debug;
```

### Enable CouchDB Debug Logging
Set in local.ini:
```ini
[log]
level = debug
```

### Monitor Real-time Logs
```bash
# Watch all logs in real-time
docker compose logs -f

# Watch specific service
docker compose logs -f nginx-proxy
docker compose logs -f couchdb-obsidian-livesync
```

## Expected Working State

When everything is working correctly:

```bash
# Container status should show both running
docker compose ps
# NAME                    IMAGE         STATUS
# obsidian-livesync       couchdb:3.3.3 Up
# couchdb-nginx-proxy     nginx:alpine  Up

# CouchDB should respond
curl http://localhost:5984
# {"couchdb":"Welcome","version":"3.3.3",...}

# Nginx should proxy correctly
curl http://localhost
# Should return CouchDB response

# HTTPS should work (if certificates are configured)
curl -k https://localhost
# Should return CouchDB response
```

## Get Help

If the issue persists, collect this information:

```bash
# System info
echo "=== System Info ==="
uname -a
docker --version
docker compose version

echo -e "\n=== Container Info ==="
docker compose ps
docker compose logs --tail=50

echo -e "\n=== Network Info ==="
docker network ls
docker compose exec nginx-proxy ip route

echo -e "\n=== Configuration ==="
docker compose config
```

Save this output and share it for further assistance. 