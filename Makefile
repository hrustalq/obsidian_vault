.PHONY: help up down restart logs shell health clean backup restore setup check setup-dirs

# Default target
help: ## Show this help message
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

setup: ## Set up environment file from example
	@if [ ! -f .env ]; then \
		if [ -f .env.example ]; then \
			cp .env.example .env; \
			echo "Created .env file from .env.example"; \
		else \
			cat > .env << 'EOF'; \
# Obsidian CouchDB LiveSync Environment Configuration; \
PUID=99; \
PGID=100; \
UMASK=0022; \
TZ=Asia/Shanghai; \
COUCHDB_USER=obsidian_user; \
COUCHDB_PASSWORD=your_secure_password_here; \
COUCHDB_CORS_ORIGINS=*; \
COUCHDB_DOMAIN=localhost; \
EOF; \
			echo "Created .env file with default values"; \
		fi; \
		echo "Please edit .env file with your configuration"; \
	else \
		echo ".env file already exists"; \
	fi

check: ## Check if environment file exists and validate docker-compose
	@if [ ! -f .env ]; then \
		echo "❌ .env file not found! Run 'make setup' first"; \
		exit 1; \
	fi
	@echo "✅ .env file exists"
	@docker-compose config --quiet && echo "✅ Docker Compose configuration is valid"

setup-dirs: ## Create required directories and configuration files
	@echo "📁 Setting up directory structure..."
	@if [ -f setup-directories.sh ]; then \
		chmod +x setup-directories.sh; \
		./setup-directories.sh; \
	else \
		echo "❌ setup-directories.sh not found"; \
		exit 1; \
	fi

up: check setup-dirs ## Start the Obsidian CouchDB service
	docker-compose up -d
	@echo "🚀 Obsidian CouchDB is starting..."
	@echo "📝 CouchDB will be available at: http://localhost:5984"
	@echo "🔧 CouchDB Admin UI: http://localhost:5984/_utils"

down: ## Stop the Obsidian CouchDB service
	docker-compose down
	@echo "🛑 Obsidian CouchDB stopped"

restart: ## Restart the Obsidian CouchDB service
	docker-compose restart
	@echo "🔄 Obsidian CouchDB restarted"

logs: ## Show logs from the CouchDB service
	docker-compose logs -f couchdb-obsidian-livesync

shell: ## Open shell in the CouchDB container
	docker exec -it obsidian-livesync bash

health: ## Check the health of CouchDB service
	@echo "🏥 Checking CouchDB health..."
	@curl -s http://localhost:5984 | jq . || echo "❌ CouchDB is not responding"
	@echo "📊 CouchDB status:"
	@curl -s http://localhost:5984/_up || echo "❌ CouchDB health check failed"

clean: ## Remove containers and volumes (WARNING: This will delete data!)
	@echo "⚠️  This will remove all containers and volumes, including data!"
	@read -p "Are you sure? (y/N): " confirm && [ "$$confirm" = "y" ] || exit 1
	docker-compose down -v --remove-orphans
	docker system prune -f
	@echo "🧹 Cleanup completed"

backup: ## Create a backup of CouchDB data
	@echo "💾 Creating backup..."
	@mkdir -p backups
	@BACKUP_FILE="backups/couchdb-backup-$$(date +%Y%m%d_%H%M%S).tar.gz"; \
	docker run --rm \
		-v obsidian_vault_couchdb-obsidian-livesync_data:/source:ro \
		-v $(PWD)/backups:/backup \
		alpine tar czf /backup/$$(basename $$BACKUP_FILE) -C /source .; \
	echo "✅ Backup created: $$BACKUP_FILE"

restore: ## Restore CouchDB data from backup
	@echo "📥 Available backups:"
	@ls -la backups/*.tar.gz 2>/dev/null || echo "No backups found"
	@echo "Enter backup filename (from backups/ directory):"
	@read -p "Backup file: " backup_file; \
	if [ -f "backups/$$backup_file" ]; then \
		echo "⚠️  This will replace current data!"; \
		read -p "Are you sure? (y/N): " confirm && [ "$$confirm" = "y" ] || exit 1; \
		docker-compose down; \
		docker run --rm \
			-v obsidian_vault_couchdb-obsidian-livesync_data:/target \
			-v $(PWD)/backups:/backup \
			alpine sh -c "rm -rf /target/* && tar xzf /backup/$$backup_file -C /target"; \
		docker-compose up -d; \
		echo "✅ Restore completed"; \
	else \
		echo "❌ Backup file not found"; \
	fi

update: ## Pull latest CouchDB image and restart
	docker-compose pull
	docker-compose up -d
	@echo "🔄 Updated to latest CouchDB image"

dev: ## Development mode - start with logs
	docker-compose up

status: ## Show service status
	@echo "📊 Service Status:"
	@docker-compose ps 