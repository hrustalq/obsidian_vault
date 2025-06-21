.PHONY: help up down restart logs shell health clean backup restore setup check setup-dirs debug troubleshoot auth-debug empty-reply-debug

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

check: ## Check if environment file exists and validate docker compose
	@if [ ! -f .env ]; then \
		echo "❌ .env file not found! Run 'make setup' first"; \
		exit 1; \
	fi
	@echo "✅ .env file exists"
	@docker compose config --quiet && echo "✅ Docker Compose configuration is valid"

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
	docker compose up -d
	@echo "🚀 Obsidian CouchDB is starting..."
	@echo "📝 CouchDB will be available at: http://localhost:5984"
	@echo "🔧 CouchDB Admin UI: http://localhost:5984/_utils"

down: ## Stop the Obsidian CouchDB service
	docker compose down
	@echo "🛑 Obsidian CouchDB stopped"

restart: ## Restart the Obsidian CouchDB service
	docker compose restart
	@echo "🔄 Obsidian CouchDB restarted"

logs: ## Show logs from the CouchDB service
	docker compose logs -f couchdb-obsidian-livesync

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
	docker compose down -v --remove-orphans
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
		docker compose down; \
		docker run --rm \
			-v obsidian_vault_couchdb-obsidian-livesync_data:/target \
			-v $(PWD)/backups:/backup \
			alpine sh -c "rm -rf /target/* && tar xzf /backup/$$backup_file -C /target"; \
		docker compose up -d; \
		echo "✅ Restore completed"; \
	else \
		echo "❌ Backup file not found"; \
	fi

update: ## Pull latest CouchDB image and restart
	docker compose pull
	docker compose up -d
	@echo "🔄 Updated to latest CouchDB image"

dev: ## Development mode - start with logs
	docker compose up

status: ## Show service status
	@echo "📊 Service Status:"
	@docker compose ps

debug: ## Quick 502 troubleshooting (run when getting Bad Gateway)
	@echo "🔍 502 Bad Gateway Troubleshooting"
	@echo "=================================="
	@echo ""
	@echo "📊 Container Status:"
	@docker compose ps || echo "❌ Docker Compose not running"
	@echo ""
	@echo "🏥 CouchDB Health Check:"
	@docker compose exec couchdb-obsidian-livesync curl -f http://localhost:5984 2>/dev/null && echo "✅ CouchDB responding" || echo "❌ CouchDB not responding"
	@echo ""
	@echo "🌐 Network Connectivity:"
	@docker compose exec nginx-proxy ping -c 1 couchdb-obsidian-livesync >/dev/null 2>&1 && echo "✅ Network connectivity OK" || echo "❌ Network connectivity failed"
	@echo ""
	@echo "🔌 Port Check:"
	@docker compose exec nginx-proxy nc -zv couchdb-obsidian-livesync 5984 2>/dev/null && echo "✅ Port 5984 accessible" || echo "❌ Port 5984 not accessible"
	@echo ""
	@echo "📋 Recent Logs:"
	@echo "--- CouchDB Logs ---"
	@docker compose logs couchdb-obsidian-livesync --tail=10 2>/dev/null || echo "No CouchDB logs available"
	@echo ""
	@echo "--- Nginx Logs ---"
	@docker compose logs nginx-proxy --tail=10 2>/dev/null || echo "No Nginx logs available"
	@echo ""
	@echo "💡 Next steps: Check troubleshoot-502.md for detailed debugging"

troubleshoot: debug ## Alias for debug command

auth-debug: ## Debug 401 authentication issues
	@echo "🔐 CouchDB Authentication Troubleshooting"
	@echo "========================================="
	@echo ""
	@echo "📊 Container Status:"
	@docker compose ps couchdb-obsidian-livesync 2>/dev/null || echo "❌ CouchDB container not running"
	@echo ""
	@echo "🔍 Environment Variables:"
	@docker compose exec couchdb-obsidian-livesync env 2>/dev/null | grep COUCHDB || echo "❌ Cannot access container environment"
	@echo ""
	@echo "🏥 Basic Connectivity (expect 401):"
	@curl -s -I http://localhost:5984 2>/dev/null | head -1 || echo "❌ CouchDB not responding"
	@echo ""
	@echo "🔑 Testing Authentication:"
	@if [ -f .env ]; then \
		COUCHDB_USER=$$(grep COUCHDB_USER .env | cut -d'=' -f2); \
		COUCHDB_PASSWORD=$$(grep COUCHDB_PASSWORD .env | cut -d'=' -f2); \
		if [ -n "$$COUCHDB_USER" ] && [ -n "$$COUCHDB_PASSWORD" ]; then \
			echo "Testing with credentials from .env: $$COUCHDB_USER"; \
			curl -s -u "$$COUCHDB_USER:$$COUCHDB_PASSWORD" http://localhost:5984 2>/dev/null | head -1 || echo "❌ Authentication failed"; \
		else \
			echo "⚠️ COUCHDB_USER or COUCHDB_PASSWORD not set in .env"; \
		fi; \
	else \
		echo "⚠️ .env file not found"; \
	fi
	@echo ""
	@echo "⚙️ CouchDB Admin Config:"
	@docker compose exec couchdb-obsidian-livesync curl -s http://localhost:5984/_node/_local/_config/admins 2>/dev/null || echo "❌ Cannot access admin config"
	@echo ""
	@echo "💡 Next steps:"
	@echo "   1. Check troubleshoot-401.md for detailed solutions"
	@echo "   2. Verify .env file has COUCHDB_USER and COUCHDB_PASSWORD"
	@echo "   3. Try: curl -u \"username:password\" http://localhost:5984"

empty-reply-debug: ## Debug empty reply from server issues (CouchDB not responding)
	@echo "🔄 Empty Reply from Server Troubleshooting"
	@echo "=========================================="
	@echo ""
	@echo "📊 Container Status:"
	@docker compose ps || echo "❌ Docker Compose not available"
	@echo ""
	@echo "🔍 Container Process Check:"
	@docker compose exec couchdb-obsidian-livesync ps aux 2>/dev/null | grep -E "(couchdb|beam|PID)" || echo "❌ Cannot access container processes"
	@echo ""
	@echo "🌐 Port Listening Check:"
	@docker compose exec couchdb-obsidian-livesync netstat -tuln 2>/dev/null | grep -E "(5984|Active|Proto)" || echo "❌ Cannot check ports"
	@echo ""
	@echo "🔗 Internal Connection Test:"
	@docker compose exec couchdb-obsidian-livesync curl -v localhost:5984 2>&1 | head -10 || echo "❌ Cannot test internal connection"
	@echo ""
	@echo "📈 Container Resource Usage:"
	@docker stats couchdb-obsidian-livesync --no-stream 2>/dev/null || echo "❌ Cannot check container stats"
	@echo ""
	@echo "📋 Recent Startup Logs:"
	@docker compose logs couchdb-obsidian-livesync --tail=30 2>/dev/null || echo "❌ Cannot read logs"
	@echo ""
	@echo "⚙️ Configuration File (first 20 lines):"
	@docker compose exec couchdb-obsidian-livesync cat /opt/couchdb/etc/local.ini 2>/dev/null | head -20 || echo "❌ Cannot read config"
	@echo ""
	@echo "💡 Next steps:"
	@echo "   1. Check troubleshoot-empty-reply.md for detailed solutions"
	@echo "   2. Try: make restart"
	@echo "   3. Check if CouchDB process is running: docker compose exec couchdb-obsidian-livesync ps aux | grep beam" 