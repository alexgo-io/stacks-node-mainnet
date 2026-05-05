#!/bin/bash
# Health check script for Stacks node
set -e
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
cd "$DIR"

echo "=== Stacks Node Health Check ==="
echo ""

# Check if containers are running
echo "Container Status:"
docker-compose ps --format "table {{.Name}}\t{{.State}}\t{{.Health}}" 2>/dev/null || docker-compose ps
echo ""

# Check local node block height
echo "Local Node Status:"
LOCAL_HEIGHT=$(curl -s http://127.0.0.1:3999/extended 2>/dev/null | jq -r '.chain_tip.block_height // "N/A"' 2>/dev/null || echo "N/A")
echo "  Block Height: $LOCAL_HEIGHT"

# Check reference node
echo ""
echo "Reference Node (Hiro API):"
REMOTE_HEIGHT=$(curl -s https://api.hiro.so/v2/info 2>/dev/null | jq -r '.stacks_tip_height // "N/A"' 2>/dev/null || echo "N/A")
echo "  Block Height: $REMOTE_HEIGHT"

# Calculate sync status
echo ""
if [ "$LOCAL_HEIGHT" != "N/A" ] && [ "$REMOTE_HEIGHT" != "N/A" ]; then
  DIFF=$((REMOTE_HEIGHT - LOCAL_HEIGHT))
  if [ "$DIFF" -le 0 ]; then
    echo "✅ Node is fully synced!"
  elif [ "$DIFF" -le 10 ]; then
    echo "✅ Node is almost synced (${DIFF} blocks behind)"
  else
    echo "⏳ Node is syncing (${DIFF} blocks behind)"
  fi
else
  echo "⚠️  Unable to determine sync status"
fi
