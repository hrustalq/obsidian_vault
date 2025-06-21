# 401 Unauthorized Error Troubleshooting Guide

A 401 error means CouchDB is running but requires authentication. This guide will help you fix authentication issues.

## Quick Fix - Test with Authentication

Try accessing CouchDB with your credentials:

```bash
# Test with environment variables
COUCHDB_USER="${COUCHDB_USER:-obsidian_user}"
COUCHDB_PASSWORD="${COUCHDB_PASSWORD:-your_password_here}"

# Test authenticated access
curl -u "$COUCHDB_USER:$COUCHDB_PASSWORD" http://localhost:5984

# Or test directly with credentials
curl -u "obsidian_user:your_password" http://localhost:5984
```

## Common Causes & Solutions

### 1. Missing Admin User Setup

**Problem:** CouchDB requires authentication but no admin user exists.

**Check current admin users:**
```bash
# Check if admin user exists
docker compose exec couchdb-obsidian-livesync curl http://localhost:5984/_users/_all_docs

# Check CouchDB configuration
docker compose exec couchdb-obsidian-livesync curl http://localhost:5984/_node/_local/_config/admins
```

**Fix: Create admin user manually**
```bash
# Method 1: Using CouchDB API
curl -X PUT http://localhost:5984/_node/_local/_config/admins/obsidian_user \
     -d '"your_password_here"'

# Method 2: Using environment variables (restart required)
# Ensure COUCHDB_USER and COUCHDB_PASSWORD are set in .env
docker compose down
docker compose up -d
```

### 2. Environment Variables Not Working

**Check if environment variables are properly set:**
```bash
# Check what CouchDB container sees
docker compose exec couchdb-obsidian-livesync env | grep COUCHDB

# Check docker-compose configuration
docker compose config | grep COUCHDB
```

**Fix environment variable issues:**
```bash
# Verify .env file has correct values
cat .env | grep COUCHDB

# Recreate containers with fresh environment
docker compose down
docker compose up -d
```

### 3. CouchDB Configuration Issues

**Check CouchDB configuration:**
```bash
# Check local.ini configuration
docker compose exec couchdb-obsidian-livesync cat /opt/couchdb/etc/local.ini

# Check if require_valid_user is enabled
docker compose exec couchdb-obsidian-livesync curl http://localhost:5984/_node/_local/_config/chttpd/require_valid_user
```

**Fix configuration:**
```bash
# Temporarily disable authentication for setup
curl -X PUT http://localhost:5984/_node/_local/_config/chttpd/require_valid_user \
     -d '"false"'

# Set up admin user
curl -X PUT http://localhost:5984/_node/_local/_config/admins/obsidian_user \
     -d '"your_password_here"'

# Re-enable authentication
curl -X PUT http://localhost:5984/_node/_local/_config/chttpd/require_valid_user \
     -d '"true"'
```

## Step-by-Step Authentication Setup

### Step 1: Verify CouchDB is Running
```bash
# Basic connectivity test (should return 401)
curl -v http://localhost:5984
# Expected: HTTP 401 Unauthorized
```

### Step 2: Check Environment Variables
```bash
echo "COUCHDB_USER: $COUCHDB_USER"
echo "COUCHDB_PASSWORD: $COUCHDB_PASSWORD"

# If empty, check .env file
grep COUCHDB .env
```

### Step 3: Test Authentication
```bash
# Replace with your actual credentials
curl -u "obsidian_user:your_password" http://localhost:5984

# Should return: {"couchdb":"Welcome","version":"3.3.3",...}
```

### Step 4: Access Admin Interface
```bash
# Open Fauxton (CouchDB admin interface)
echo "Access: http://localhost:5984/_utils"
echo "Username: obsidian_user"
echo "Password: your_password"
```

## Fix Authentication Issues

### Method 1: Environment Variable Setup
```bash
# 1. Update .env file
cat > .env << EOF
PUID=99
PGID=100
UMASK=0022
TZ=Asia/Shanghai
COUCHDB_USER=obsidian_user
COUCHDB_PASSWORD=your_secure_password_here
COUCHDB_CORS_ORIGINS=*
COUCHDB_DOMAIN=localhost
EOF

# 2. Restart containers
docker compose down
docker compose up -d

# 3. Wait for startup
sleep 30

# 4. Test authentication
curl -u "obsidian_user:your_secure_password_here" http://localhost:5984
```

### Method 2: Manual Admin User Creation
```bash
# 1. Temporarily disable authentication
curl -X PUT http://localhost:5984/_node/_local/_config/chttpd/require_valid_user -d '"false"'

# 2. Create admin user
curl -X PUT http://localhost:5984/_node/_local/_config/admins/obsidian_user -d '"your_password"'

# 3. Re-enable authentication
curl -X PUT http://localhost:5984/_node/_local/_config/chttpd/require_valid_user -d '"true"'

# 4. Test
curl -u "obsidian_user:your_password" http://localhost:5984
```

### Method 3: Reset CouchDB Configuration
```bash
# 1. Stop containers
docker compose down -v

# 2. Recreate configuration with authentication disabled for setup
./setup-directories.sh

# 3. Modify local.ini to disable auth temporarily
sed -i 's/require_valid_user = true/require_valid_user = false/' \
    /mnt/user/appdata/couchdb-obsidian-livesync/etc/local.ini

# 4. Start containers
docker compose up -d

# 5. Setup admin user
sleep 30
curl -X PUT http://localhost:5984/_node/_local/_config/admins/obsidian_user -d '"your_password"'

# 6. Re-enable authentication
curl -X PUT http://localhost:5984/_node/_local/_config/chttpd/require_valid_user -d '"true"'
```

## Nginx Proxy Authentication

If using the nginx proxy, you need to configure it to pass authentication:

### Update Nginx Configuration
```nginx
# In nginx.conf, add authentication headers
location / {
    proxy_pass http://couchdb;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    
    # Pass authentication headers
    proxy_set_header Authorization $http_authorization;
    proxy_pass_header Authorization;
}
```

### Test Nginx with Authentication
```bash
# Test through nginx proxy
curl -u "obsidian_user:your_password" http://localhost/

# Test HTTPS (if configured)
curl -k -u "obsidian_user:your_password" https://localhost/
```

## Verification Steps

### Test All Endpoints
```bash
# Basic authentication test
curl -u "obsidian_user:password" http://localhost:5984

# Test admin interface access
curl -u "obsidian_user:password" http://localhost:5984/_utils

# Test database creation (admin privilege)
curl -u "obsidian_user:password" -X PUT http://localhost:5984/test_db

# List databases
curl -u "obsidian_user:password" http://localhost:5984/_all_dbs

# Clean up test database
curl -u "obsidian_user:password" -X DELETE http://localhost:5984/test_db
```

### Browser Access
```bash
echo "🌐 Browser Access:"
echo "URL: http://localhost:5984/_utils"
echo "Username: obsidian_user"
echo "Password: your_password"
echo ""
echo "Or with nginx proxy:"
echo "URL: http://localhost/_utils"
```

## Obsidian LiveSync Configuration

Once authentication is working, configure Obsidian:

```
Remote Database: http://localhost:5984/obsidian
Username: obsidian_user
Password: your_password
Database Name: obsidian
```

## Security Notes

- **Change default password**: Never use default passwords in production
- **Use HTTPS**: Enable SSL certificates for production
- **Limit CORS**: Set specific origins instead of `*`
- **Firewall**: Restrict access to necessary ports only

## Common Authentication Errors

### Error: "Name or password is incorrect"
- Check username/password spelling
- Verify case sensitivity
- Check if user exists in `_config/admins`

### Error: "You are not authorized to access this db"
- User exists but lacks permissions
- Check if user is admin: `/_config/admins`

### Error: "Authentication required"
- CouchDB requires auth but no credentials provided
- Add `-u username:password` to curl commands

## Get Help

If authentication issues persist, gather this info:

```bash
echo "=== Authentication Debug Info ==="
echo "Environment variables:"
docker compose exec couchdb-obsidian-livesync env | grep COUCHDB

echo -e "\nCouchDB config:"
docker compose exec couchdb-obsidian-livesync curl -s http://localhost:5984/_node/_local/_config/admins

echo -e "\nAuthentication test:"
curl -v -u "obsidian_user:test" http://localhost:5984 2>&1 | head -20
``` 