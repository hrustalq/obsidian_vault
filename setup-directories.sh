#!/bin/bash

# Setup script for CouchDB Obsidian LiveSync with Cloudflare SSL support
# This script creates the necessary directory structure and configuration files

set -e  # Exit on any error

BASE_DIR="/mnt/user/appdata/couchdb-obsidian-livesync"
NGINX_DOMAIN="${COUCHDB_DOMAIN:-localhost}"

echo "🚀 Setting up CouchDB Obsidian LiveSync directory structure..."

# Create base directories
echo "📁 Creating directories..."
mkdir -p "$BASE_DIR/data"
mkdir -p "$BASE_DIR/etc/local.d"
mkdir -p "$BASE_DIR/nginx/html"
# Note: Not creating nginx/ssl directory since we're using Cloudflare for SSL

# Set proper permissions
echo "🔧 Setting permissions..."
chmod 755 "$BASE_DIR"
chmod 755 "$BASE_DIR/data"
chmod 755 "$BASE_DIR/etc"
chmod 755 "$BASE_DIR/etc/local.d"
chmod 755 "$BASE_DIR/nginx"

# Create CouchDB local.ini configuration
echo "⚙️ Creating CouchDB configuration..."
cat > "$BASE_DIR/etc/local.ini" << 'EOF'
[couchdb]
single_node=true

[httpd]
enable_cors = true
bind_address = 0.0.0.0
port = 5984

[cors]
origins = *
credentials = true
methods = GET, PUT, POST, HEAD, DELETE
headers = accept, authorization, content-type, origin, referer, x-csrf-token

[ssl]
enable = false

[log]
level = info

[chttpd]
require_valid_user = true
bind_address = 0.0.0.0
port = 5984

[admins]
; Admin users will be set via environment variables
EOF

# Create nginx configuration for Cloudflare SSL termination
echo "🌐 Creating Nginx configuration for Cloudflare SSL..."
cat > "$BASE_DIR/nginx/nginx.conf" << 'EOF'
events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    
    # Logging
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;
    
    # Gzip compression
    gzip on;
    gzip_types text/plain application/json;
    
    # Upstream CouchDB
    upstream couchdb {
        server couchdb-obsidian-livesync:5984;
    }
    
    # Main server - HTTP only (Cloudflare handles SSL termination)
    server {
        listen 80;
        server_name ${COUCHDB_DOMAIN:-couchdb.yourdomain.com};
        
        # Trust Cloudflare's forwarded headers
        real_ip_header CF-Connecting-IP;
        set_real_ip_from 173.245.48.0/20;
        set_real_ip_from 103.21.244.0/22;
        set_real_ip_from 103.22.200.0/22;
        set_real_ip_from 103.31.4.0/22;
        set_real_ip_from 141.101.64.0/18;
        set_real_ip_from 108.162.192.0/18;
        set_real_ip_from 190.93.240.0/20;
        set_real_ip_from 188.114.96.0/20;
        set_real_ip_from 197.234.240.0/22;
        set_real_ip_from 198.41.128.0/17;
        set_real_ip_from 162.158.0.0/15;
        set_real_ip_from 104.16.0.0/13;
        set_real_ip_from 104.24.0.0/14;
        set_real_ip_from 172.64.0.0/13;
        set_real_ip_from 131.0.72.0/22;
        
        # Security headers
        add_header X-Frame-Options DENY;
        add_header X-Content-Type-Options nosniff;
        add_header X-XSS-Protection "1; mode=block";
        
        # Proxy to CouchDB
        location / {
            proxy_pass http://couchdb;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto https;  # Always https since Cloudflare handles SSL
            proxy_set_header X-Forwarded-Port 443;
            
            # CouchDB specific settings
            proxy_buffering off;
            proxy_request_buffering off;
            
            # Handle WebSocket connections for real-time sync
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            
            # Increase timeouts for large database operations
            proxy_connect_timeout 60s;
            proxy_send_timeout 60s;
            proxy_read_timeout 60s;
        }
        
        # Health check endpoint
        location /_health {
            access_log off;
            return 200 "OK\n";
            add_header Content-Type text/plain;
        }
    }
}
EOF

# Create nginx HTML files
echo "📄 Creating default HTML files..."
cat > "$BASE_DIR/nginx/html/index.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>CouchDB Obsidian LiveSync</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .container { max-width: 600px; margin: 0 auto; }
        .status { padding: 20px; border-radius: 5px; margin: 20px 0; }
        .success { background-color: #d4edda; color: #155724; border: 1px solid #c3e6cb; }
        .info { background-color: #d1ecf1; color: #0c5460; border: 1px solid #bee5eb; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🗄️ CouchDB Obsidian LiveSync</h1>
        <div class="status success">
            <strong>✅ Server is running</strong>
        </div>
        <div class="status info">
            <p><strong>CouchDB Admin:</strong> <a href="/_utils" target="_blank">Access Fauxton</a></p>
            <p><strong>API Endpoint:</strong> <code>/</code></p>
            <p><strong>Health Check:</strong> <a href="/_health" target="_blank">/_health</a></p>
        </div>
        <p>This is your CouchDB instance for Obsidian LiveSync. Use the admin interface to manage your databases.</p>
    </div>
</body>
</html>
EOF

# Create 404 error page
cat > "$BASE_DIR/nginx/html/404.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>404 - Not Found</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; text-align: center; }
        .error { color: #dc3545; }
    </style>
</head>
<body>
    <h1 class="error">404 - Not Found</h1>
    <p>The requested resource was not found on this server.</p>
    <a href="/">← Back to Home</a>
</body>
</html>
EOF

# Set final permissions
echo "🔐 Setting final permissions..."
chmod 644 "$BASE_DIR/etc/local.ini"
chmod 644 "$BASE_DIR/nginx/nginx.conf"
chmod -R 644 "$BASE_DIR/nginx/html/"

echo "✅ Setup complete!"
echo ""
echo "📋 Created structure:"
echo "   $BASE_DIR/"
echo "   ├── data/                 (CouchDB data directory)"
echo "   ├── etc/"
echo "   │   ├── local.d/          (CouchDB config directory)"
echo "   │   └── local.ini         (CouchDB main config)"
echo "   └── nginx/"
echo "       ├── nginx.conf        (Nginx configuration)"
echo "       └── html/             (Static HTML files)"
echo ""
echo "🚀 You can now run: docker compose up -d"
echo ""
echo "⚠️  IMPORTANT NOTES:"
echo "   • Update COUCHDB_DOMAIN in your .env file with your actual domain"
echo "   • Configure Cloudflare SSL/TLS mode to 'Full' or 'Full (strict)'"
echo "   • Point your Cloudflare DNS to your server's IP address"
echo "   • Ensure your firewall allows inbound port 80"
echo "   • SSL termination is handled by Cloudflare (no local certificates needed)"
echo ""
echo "🌐 Cloudflare Configuration:"
echo "   • SSL/TLS Mode: Full (recommended) or Full (strict)"
echo "   • Origin Server: Point to your_server_ip:80"
echo "   • Always Use HTTPS: Enable"
echo "   • Edge Certificates: Auto (handled by Cloudflare)"