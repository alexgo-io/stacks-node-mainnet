.PHONY: help setup start stop restart logs status clean health

# Default target
help:
@echo "Stacks Node Mainnet - Available Commands"
@echo ""
@echo "  make setup     - Install prerequisites (requires root)"
@echo "  make start     - Start all services"
@echo "  make stop      - Stop all services (graceful, 60min timeout)"
@echo "  make restart   - Restart all services"
@echo "  make logs      - Follow container logs"
@echo "  make status    - Show container status"
@echo "  make health    - Check node sync status"
@echo "  make clean     - Remove all data (DESTRUCTIVE)"
@echo ""

setup:
@echo "Running setup script (requires root)..."
sudo ./setup.sh

start:
@echo "Starting Stacks node..."
./start.sh

stop:
@echo "Stopping Stacks node (this may take up to 60 minutes)..."
./stop.sh

restart: stop start

logs:
docker-compose logs -f

status:
@docker-compose ps
@echo ""
@echo "Container health:"
@docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep stacks || true

health:
@echo "Checking node sync status..."
@echo "Local node:"
@curl -s http://127.0.0.1:3999/extended 2>/dev/null | jq '.chain_tip.block_height // "API not responding"' || echo "API not responding"
@echo ""
@echo "Reference (Hiro API):"
@curl -s https://api.hiro.so/v2/info 2>/dev/null | jq '.stacks_tip_height // "Cannot reach Hiro API"' || echo "Cannot reach Hiro API"

clean:
@echo "WARNING: This will delete all blockchain data!"
@read -p "Are you sure? (yes/no): " confirm && [ "$$confirm" = "yes" ] || exit 1
./stop.sh || true
rm -rf ./stacks-node ./postgresql
@echo "Data cleaned. Run restore scripts to re-download."
