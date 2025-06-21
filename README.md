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

Create a `.env` file with these variables:

| Name | Type | Example | Default |
|------|------|---------|---------|
| PUID | number | Process ID | 99 |
| PGID | number | PG ID | 100 |
| UMASK | number | UMASK | 0022 |
| TZ | string | Time zone | Asia/Shanghai |
| COUCHDB_USER | string | Database username | obsidian_user |
| COUCHDB_PASSWORD | string | Database password | your_secure_password |

## GitHub Actions & Deployment

The project includes CI/CD workflows that:
- Validate Docker Compose configuration
- Run security scans with Trivy
- Deploy automatically on main branch pushes (when secrets are configured)

### GitHub Secrets Configuration

For automated deployment to your server, you'll need to set up SSH keys and configure secrets.

**📖 [Complete SSH Setup Guide](./SSH_SETUP_GUIDE.md)**

**Required secrets for deployment:**
- `SSH_HOST` - Your server IP address
- `SSH_USERNAME` - SSH username on your server
- `SSH_KEY` - Private SSH key content
- `DEPLOY_PATH` - Path where the app is deployed
- `COUCHDB_PASSWORD` - Database password

**Optional secrets (have defaults):**
- `COUCHDB_USER` (defaults to obsidian_user)
- `SSH_PORT` (defaults to 22)
- `PUID`, `PGID`, `UMASK`, `TZ` (system defaults)

## Data Persistence

CouchDB data is persisted in Docker volumes. Use `make backup` and `make restore` for data management.