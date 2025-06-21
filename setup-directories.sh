#!/bin/bash

# Setup script for CouchDB Obsidian LiveSync with HTTPS support
# This script creates the necessary directory structure and configuration files

set -e  # Exit on any error

BASE_DIR="/mnt/user/appdata/couchdb-obsidian-livesync"
NGINX_DOMAIN="${COUCHDB_DOMAIN:-localhost}"

echo "🚀 Setting up CouchDB Obsidian LiveSync directory structure..."

# Create base directories
echo "📁 Creating directories..."
mkdir -p "$BASE_DIR/data"
mkdir -p "$BASE_DIR/etc/local.d"
mkdir -p "$BASE_DIR/nginx/ssl"
mkdir -p "$BASE_DIR/nginx/html"

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

# Create nginx configuration
echo "🌐 Creating Nginx configuration..."
cat > "$BASE_DIR/nginx/nginx.conf" << 'EOF'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';
    
    access_log /var/log/nginx/access.log main;
    
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    
    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/json
        application/javascript
        application/xml+rss
        application/atom+xml;

    # Rate limiting
    limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
    
    # Upstream CouchDB
    upstream couchdb {
        server couchdb-obsidian-livesync:5984;
    }
    
    # HTTP to HTTPS redirect
    server {
        listen 80;
        server_name _;
        return 301 https://$host$request_uri;
    }
    
    # HTTPS server
    server {
        listen 443 ssl http2;
        server_name localhost;
        
        # SSL configuration (self-signed for development)
        ssl_certificate /etc/nginx/ssl/cert.pem;
        ssl_certificate_key /etc/nginx/ssl/key.pem;
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-SHA256:ECDHE-RSA-AES256-SHA384;
        ssl_prefer_server_ciphers off;
        
        # Security headers
        add_header X-Frame-Options DENY;
        add_header X-Content-Type-Options nosniff;
        add_header X-XSS-Protection "1; mode=block";
        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
        
        # Rate limiting
        limit_req zone=api burst=20 nodelay;
        
        # Proxy to CouchDB
        location / {
            proxy_pass http://couchdb;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header X-Forwarded-Port $server_port;
            
            # WebSocket support
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            
            # Timeouts
            proxy_connect_timeout 30s;
            proxy_send_timeout 30s;
            proxy_read_timeout 30s;
            
            # Buffer settings
            proxy_buffering on;
            proxy_buffer_size 4k;
            proxy_buffers 8 4k;
        }
        
        # Health check endpoint
        location /_health {
            access_log off;
            return 200 "healthy\n";
            add_header Content-Type text/plain;
        }
    }
}
EOF

# Check for existing SSL certificates or create self-signed ones
echo "🔒 Checking SSL certificates..."
if [ -f "$BASE_DIR/nginx/ssl/cert.pem" ] && [ -f "$BASE_DIR/nginx/ssl/key.pem" ]; then
    echo "✅ SSL certificates already exist - using existing certificates"
    echo "📝 Certificate: $BASE_DIR/nginx/ssl/cert.pem"
    echo "🔑 Private key: $BASE_DIR/nginx/ssl/key.pem"
    
    # Verify certificate validity
    if openssl x509 -in "$BASE_DIR/nginx/ssl/cert.pem" -noout -checkend 86400 2>/dev/null; then
        echo "✅ Certificate is valid and not expiring within 24 hours"
    else
        echo "⚠️ Certificate may be expired or expiring soon"
        echo "💡 Consider renewing your SSL certificate"
    fi
else
    echo "📝 SSL certificates not found, creating self-signed certificate for development..."
    
    # Create self-signed SSL certificate
    if command -v openssl >/dev/null 2>&1; then
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout "$BASE_DIR/nginx/ssl/key.pem" \
            -out "$BASE_DIR/nginx/ssl/cert.pem" \
            -subj "/C=US/ST=State/L=City/O=Organization/CN=$NGINX_DOMAIN" \
            2>/dev/null && {
                echo "✅ Self-signed SSL certificate created successfully"
                echo "⚠️ This is a self-signed certificate - browsers will show security warnings"
                echo "💡 For production, replace with certificates from a trusted CA"
            } || {
                echo "❌ Failed to create SSL certificate"
                exit 1
            }
    else
        echo "❌ OpenSSL not found. Cannot create SSL certificates."
        echo "📝 Please install OpenSSL or manually provide SSL certificates:"
        echo "   • Certificate: $BASE_DIR/nginx/ssl/cert.pem"
        echo "   • Private key: $BASE_DIR/nginx/ssl/key.pem"
        exit 1
    fi
fi

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
chmod 600 "$BASE_DIR/nginx/ssl/"*.pem 2>/dev/null || true

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
echo "       ├── ssl/              (SSL certificates)"
echo "       └── html/             (Static HTML files)"
echo ""
echo "🚀 You can now run: docker compose up -d"
echo ""
echo "⚠️  IMPORTANT NOTES:"
echo "   • Update COUCHDB_DOMAIN in your .env file with your actual domain"
if [ -f "$BASE_DIR/nginx/ssl/cert.pem" ] && [ -f "$BASE_DIR/nginx/ssl/key.pem" ]; then
    if openssl x509 -in "$BASE_DIR/nginx/ssl/cert.pem" -noout -issuer 2>/dev/null | grep -q "O=Organization"; then
        echo "   • Replace self-signed certificates with real ones for production"
        echo "   • For Let's Encrypt: certbot --nginx -d your-domain.com"
        echo "   • Or manually place cert.pem and key.pem in $BASE_DIR/nginx/ssl/"
    else
        echo "   • SSL certificates detected - ensure they're valid for your domain"
        echo "   • Certificates will be automatically used by Nginx"
    fi
else
    echo "   • SSL certificates not found - HTTPS will not work"
    echo "   • Place cert.pem and key.pem in $BASE_DIR/nginx/ssl/ and re-run this script"
fi
echo "   • Configure your firewall to allow ports 80 and 443"
echo "   • Set up DNS to point your domain to this server"
echo ""
echo "🔧 SSL Certificate Management:"
echo "   • To use existing certificates: Place them in $BASE_DIR/nginx/ssl/"
echo "   • Certificate file: cert.pem (or fullchain.pem for Let's Encrypt)"
echo "   • Private key file: key.pem (or privkey.pem for Let's Encrypt)"
echo "   • Script will automatically detect and use existing certificates"