# Obsidian Self-Hosted Vault with CouchDB LiveSync

This project provides a Docker Compose setup for running CouchDB to enable Obsidian LiveSync functionality for self-hosted synchronization.

[Original Guide](https://www.reddit.com/r/selfhosted/comments/1eo7knj/guide_obsidian_with_free_selfhosted_instant_sync/)

## Quick Start

1. **Setup environment:**
   ```bash
   make setup
   # or manually create .env file with the variables below
   ```

2. **Start the service:**
   ```bash
   make up
   ```

3. **Access CouchDB:**
   - Database endpoint: http://localhost:5984
   - Admin interface: http://localhost:5984/_utils

## Available Commands

Run `make help` to see all available commands:

```bash
make help          # Show available commands
make up            # Start CouchDB service
make down          # Stop CouchDB service  
make logs          # View service logs
make health        # Check service health
make backup        # Create data backup
make clean         # Remove all data (destructive!)
```

## Environment Variables

### Local Development (.env file)

Create a `.env` file with these variables for local development:

| Name | Type | Description | Example | Default |
|------|------|-------------|---------|---------|
| PUID | number | Process User ID | 1000 | 99 |
| PGID | number | Process Group ID | 1000 | 100 |
| UMASK | number | File creation mask | 0022 | 0022 |
| TZ | string | Timezone | Asia/Shanghai | Asia/Shanghai |
| COUCHDB_USER | string | Database username | obsidian_user | obsidian_user |
| COUCHDB_PASSWORD | string | Database password | your_secure_password | (required) |
| COUCHDB_CORS_ORIGINS | string | CORS allowed origins | `*` or `https://mydomain.com` | `*` |
| COUCHDB_DOMAIN | string | CouchDB domain/hostname | `localhost` or `couchdb.example.com` | `localhost` |

### CI/CD Environment Variables

Additional variables used in GitHub Actions workflow:

| Name | Type | Description | Used In |
|------|------|-------------|---------|
| SSH_HOST | string | Server IP address or domain | Deployment |
| SSH_USERNAME | string | SSH username on target server | Deployment |
| SSH_KEY | string | Private SSH key content | Deployment |
| SSH_PORT | number | SSH port number | Deployment (default: 22) |
| DEPLOY_PATH | string | Deployment directory path | Deployment |

## GitHub Actions & Deployment

The project includes a comprehensive CI/CD pipeline with the following features:

### 🔍 **Validation & Testing**
- Docker Compose configuration validation
- Automated container startup and health checks
- Smart timeout handling with progressive feedback
- Comprehensive CouchDB API testing

### 🛡️ **Security Scanning**
- **Configuration Scan**: Checks Docker Compose and config files
- **Filesystem Scan**: Scans for vulnerabilities in project files
- **Severity Filtering**: Focuses on CRITICAL, HIGH, and MEDIUM issues
- **GitHub Security Integration**: Results appear in Security tab

### 🚀 **Automated Deployment**
- SSH-based deployment to your server
- Intelligent health checks with 90-second timeout
- Automatic recovery attempts on failure
- Authentication testing for CouchDB credentials
- Concurrency control to prevent conflicting deployments

### 🔧 **Workflow Features**
- **Parallel Execution**: Validation and security scans run simultaneously
- **Conditional Deployment**: Only runs on main branch pushes
- **Graceful Failure**: Skips deployment if secrets aren't configured
- **Detailed Logging**: Comprehensive error reporting and diagnostics

### GitHub Secrets Configuration

For automated deployment to your server, you'll need to set up SSH keys and configure secrets.

**📖 [Complete SSH Setup Guide](./SSH_SETUP_GUIDE.md)**

#### Required Secrets for Deployment

| Secret Name | Description | Example |
|-------------|-------------|---------|
| `SSH_HOST` | Server IP address or domain | `192.168.1.100` or `example.com` |
| `SSH_USERNAME` | SSH username on target server | `ubuntu` or `root` |
| `SSH_KEY` | Private SSH key content | Full private key with headers |
| `DEPLOY_PATH` | Path where app is deployed | `/home/user/obsidian_vault` |
| `COUCHDB_PASSWORD` | Database password | `secure_password_123` |

#### Optional Secrets (with defaults)

| Secret Name | Default Value | Description |
|-------------|---------------|-------------|
| `COUCHDB_USER` | `obsidian_user` | Database username |
| `COUCHDB_CORS_ORIGINS` | `*` | CORS allowed origins |
| `COUCHDB_DOMAIN` | `localhost` | CouchDB domain/hostname |
| `SSH_PORT` | `22` | SSH port number |
| `PUID` | `99` | Process User ID |
| `PGID` | `100` | Process Group ID |
| `UMASK` | `0022` | File creation mask |
| `TZ` | `Asia/Shanghai` | Timezone |

### Deployment Workflow

When you push to the main branch:

1. **🔍 Validation**: Tests Docker Compose configuration
2. **🛡️ Security**: Scans for vulnerabilities
3. **🚀 Deploy**: SSH to server and deploy (if secrets configured)
   - Pulls latest code
   - Exports environment variables
   - Starts services with `make up`
   - Runs comprehensive health checks
   - Attempts automatic recovery on failure

## Data Persistence

CouchDB data is persisted in Docker volumes. Use `make backup` and `make restore` for data management.