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
| TZ | string | Time zone | America/New_York |
| COUCHDB_USER | string | Database username | obsidian_user |
| COUCHDB_PASSWORD | string | Database password | your_secure_password |

## GitHub Actions & Deployment

The project includes CI/CD workflows that:
- Validate Docker Compose configuration
- Run security scans with Trivy
- Deploy automatically on main branch pushes (when secrets are configured)

### GitHub Secrets Configuration

For automated deployment, configure these repository secrets:
- `COUCHDB_PASSWORD` (required)
- `COUCHDB_USER` (optional, defaults to obsidian_user)
- `PUID` (optional, defaults to 99)
- `PGID` (optional, defaults to 100)
- `UMASK` (optional, defaults to 0022)
- `TZ` (optional, defaults to America/New_York)

## Data Persistence

CouchDB data is persisted in Docker volumes. Use `make backup` and `make restore` for data management.