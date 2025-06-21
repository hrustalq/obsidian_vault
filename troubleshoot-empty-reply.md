# "Empty Reply from Server" Troubleshooting Guide

An "Empty reply from server" error means the container is running but CouchDB process is not responding. This guide will help you diagnose and fix this issue.

## Quick Diagnostics

Run these commands to understand what's happening:

```bash
# Check if container is running
docker compose ps

# Check if CouchDB process is running inside container
docker compose exec couchdb-obsidian-livesync ps aux

# Check if port 5984 is listening
docker compose exec couchdb-obsidian-livesync netstat -ln | grep 5984

# Check CouchDB logs
docker compose logs couchdb-obsidian-livesync --tail=50
```

## Common Causes & Solutions

### 1. CouchDB Process Not Started

**Check if CouchDB is running inside the container:**
```bash
# Check processes inside container
docker compose exec couchdb-obsidian-livesync ps aux | grep couchdb

# Check if beam.smp (Erlang/CouchDB) is running
docker compose exec couchdb-obsidian-livesync ps aux | grep beam
```

**If no CouchDB process is found:**
```bash
# Check container logs for startup errors
docker compose logs couchdb-obsidian-livesync

# Look for specific error patterns
docker compose logs couchdb-obsidian-livesync 2>&1 | grep -i error
docker compose logs couchdb-obsidian-livesync 2>&1 | grep -i fail
```

### 2. CouchDB Crashed During Startup

**Check for crash logs:**
```bash
# Look for crash dumps or error messages
docker compose logs couchdb-obsidian-livesync | grep -i "crash\|dump\|abort\|fatal"

# Check system logs
docker compose exec couchdb-obsidian-livesync dmesg | tail -20
```

**Common crash causes:**
- Invalid configuration in local.ini
- Permission issues with data directory
- Memory/resource constraints
- Corrupted data files

### 3. Port Binding Issues

**Check if CouchDB is listening on the correct port:**
```bash
# Check what ports are listening inside container
docker compose exec couchdb-obsidian-livesync netstat -tuln

# Check if 5984 is bound to 0.0.0.0 (not just 127.0.0.1)
docker compose exec couchdb-obsidian-livesync netstat -tuln | grep 5984

# Test connection from inside container
docker compose exec couchdb-obsidian-livesync curl localhost:5984
```

### 4. Configuration File Issues

**Check CouchDB configuration:**
```bash
# Verify local.ini syntax
docker compose exec couchdb-obsidian-livesync cat /opt/couchdb/etc/local.ini

# Check for configuration errors
docker compose exec couchdb-obsidian-livesync /opt/couchdb/bin/couchdb -s
```

**Common configuration problems:**
- Syntax errors in local.ini
- Invalid bind_address setting
- Conflicting port configurations

### 5. Permission Issues

**Check file permissions:**
```bash
# Check data directory permissions
docker compose exec couchdb-obsidian-livesync ls -la /opt/couchdb/data/

# Check config file permissions
docker compose exec couchdb-obsidian-livesync ls -la /opt/couchdb/etc/

# Check if CouchDB can write to data directory
docker compose exec couchdb-obsidian-livesync touch /opt/couchdb/data/test_write
```

## Step-by-Step Debugging

### Step 1: Container Status Check
```bash
echo "=== Container Status ==="
docker compose ps couchdb-obsidian-livesync

echo -e "\n=== Container Resource Usage ==="
docker stats couchdb-obsidian-livesync --no-stream
```

### Step 2: Process Analysis
```bash
echo "=== Processes Inside Container ==="
docker compose exec couchdb-obsidian-livesync ps aux

echo -e "\n=== CouchDB Specific Processes ==="
docker compose exec couchdb-obsidian-livesync ps aux | grep -E "(couchdb|beam|epmd)"
```

### Step 3: Network Analysis
```bash
echo "=== Port Listening Check ==="
docker compose exec couchdb-obsidian-livesync netstat -tuln

echo -e "\n=== CouchDB Port Status ==="
docker compose exec couchdb-obsidian-livesync netstat -tuln | grep 5984 || echo "Port 5984 not listening"
```

### Step 4: Internal Connectivity Test
```bash
echo "=== Internal Connection Test ==="
docker compose exec couchdb-obsidian-livesync curl -v localhost:5984 2>&1 | head -10

echo -e "\n=== Internal Health Check ==="
docker compose exec couchdb-obsidian-livesync curl -s localhost:5984/_up 2>/dev/null || echo "Health endpoint not responding"
```

### Step 5: Configuration Validation
```bash
echo "=== Configuration Check ==="
docker compose exec couchdb-obsidian-livesync cat /opt/couchdb/etc/local.ini | head -20

echo -e "\n=== Configuration Syntax Test ==="
docker compose exec couchdb-obsidian-livesync /opt/couchdb/bin/couchdb -s 2>&1 | head -10
```

## Quick Fixes

### Fix 1: Restart CouchDB Process
```bash
# Restart just the CouchDB container
docker compose restart couchdb-obsidian-livesync

# Wait for startup
sleep 30

# Test
curl localhost:5984
```

### Fix 2: Fresh Container Start
```bash
# Stop and remove container
docker compose down

# Start fresh
docker compose up -d

# Monitor startup logs
docker compose logs -f couchdb-obsidian-livesync
```

### Fix 3: Reset Configuration
```bash
# Stop containers
docker compose down

# Backup current config
cp /mnt/user/appdata/couchdb-obsidian-livesync/etc/local.ini /tmp/local.ini.backup

# Recreate configuration
./setup-directories.sh

# Start containers
docker compose up -d
```

### Fix 4: Minimal Configuration Test
```bash
# Stop everything
docker compose down -v

# Create minimal config for testing
mkdir -p /mnt/user/appdata/couchdb-obsidian-livesync/etc
cat > /mnt/user/appdata/couchdb-obsidian-livesync/etc/local.ini << 'EOF'
[couchdb]
single_node=true

[httpd]
bind_address = 0.0.0.0
port = 5984

[chttpd]
bind_address = 0.0.0.0
port = 5984
require_valid_user = false
EOF

# Start with minimal config
docker compose up -d

# Test
sleep 30
curl localhost:5984
```

## Advanced Debugging

### Enable Debug Logging
```bash
# Add debug logging to local.ini
docker compose exec couchdb-obsidian-livesync sed -i '/\[log\]/a level = debug' /opt/couchdb/etc/local.ini

# Restart to apply
docker compose restart couchdb-obsidian-livesync

# Watch debug logs
docker compose logs -f couchdb-obsidian-livesync
```

### Check CouchDB Startup Command
```bash
# See how CouchDB is being started
docker compose exec couchdb-obsidian-livesync ps aux | grep couchdb

# Check environment variables
docker compose exec couchdb-obsidian-livesync env | grep COUCHDB
```

### Memory and Resource Check
```bash
# Check container resource limits
docker inspect couchdb-obsidian-livesync | grep -A 10 "Memory"

# Check host system resources
free -h
df -h
```

### Manual CouchDB Start (for debugging)
```bash
# Stop the container
docker compose stop couchdb-obsidian-livesync

# Start container without CouchDB process
docker compose run --rm couchdb-obsidian-livesync bash

# Inside container, manually start CouchDB
/opt/couchdb/bin/couchdb

# In another terminal, test connection
curl localhost:5984
```

## Expected Working State

When CouchDB is working correctly:

```bash
# Container should be running
docker compose ps couchdb-obsidian-livesync
# State: Up

# CouchDB process should be running
docker compose exec couchdb-obsidian-livesync ps aux | grep beam
# Should show beam.smp process

# Port should be listening
docker compose exec couchdb-obsidian-livesync netstat -tuln | grep 5984
# Should show: 0.0.0.0:5984

# Should respond to requests
curl localhost:5984
# Should return: {"couchdb":"Welcome",...}
```

## Collect Debug Information

If the issue persists, gather this information:

```bash
#!/bin/bash
echo "=== CouchDB Empty Reply Debug Report ==="
echo "Date: $(date)"
echo ""

echo "=== System Information ==="
uname -a
docker --version
docker compose version
echo ""

echo "=== Container Status ==="
docker compose ps
echo ""

echo "=== Container Processes ==="
docker compose exec couchdb-obsidian-livesync ps aux 2>/dev/null || echo "Cannot access container"
echo ""

echo "=== Port Status ==="
docker compose exec couchdb-obsidian-livesync netstat -tuln 2>/dev/null || echo "Cannot check ports"
echo ""

echo "=== CouchDB Logs ==="
docker compose logs couchdb-obsidian-livesync --tail=50
echo ""

echo "=== Container Environment ==="
docker compose exec couchdb-obsidian-livesync env | grep COUCHDB 2>/dev/null || echo "Cannot access environment"
echo ""

echo "=== Configuration ==="
docker compose exec couchdb-obsidian-livesync cat /opt/couchdb/etc/local.ini 2>/dev/null || echo "Cannot read config"
echo ""

echo "=== Internal Connection Test ==="
docker compose exec couchdb-obsidian-livesync curl -v localhost:5984 2>&1 | head -20 || echo "Cannot test internal connection"
```

Save this output for further assistance.

## Common Patterns

### Pattern 1: Process Not Running
```
Symptom: ps aux shows no couchdb/beam process
Cause: Configuration error preventing startup
Fix: Check logs, fix config, restart
```

### Pattern 2: Wrong Bind Address
```
Symptom: netstat shows 127.0.0.1:5984 instead of 0.0.0.0:5984
Cause: bind_address misconfiguration
Fix: Set bind_address = 0.0.0.0 in local.ini
```

### Pattern 3: Permission Issues
```
Symptom: Cannot write to data directory
Cause: Wrong file permissions or ownership
Fix: Check permissions, run setup script
``` 