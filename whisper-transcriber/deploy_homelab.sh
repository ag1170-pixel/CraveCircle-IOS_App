#!/usr/bin/env bash
# CraveCircle Homelab Deployment Script
# Usage: ./deploy_homelab.sh <user@homelab-ip-or-hostname> [remote_dir]
# Example: ./deploy_homelab.sh anas@192.168.1.50

set -e

SSH_HOST="${1:-$HOMELAB_SSH}"
REMOTE_DIR="${2:-~/stacks/cravecircle/whisper-transcriber}"

if [ -z "$SSH_HOST" ]; then
  echo "❌ Error: SSH target is required."
  echo "Usage: ./deploy_homelab.sh <user@homelab-ip-or-hostname>"
  echo "Example: ./deploy_homelab.sh anas@192.168.1.100"
  exit 1
fi

echo "🚀 Deploying CraveCircle backend to Homelab ($SSH_HOST)..."

# 1. Ensure remote directory exists
echo "📁 Preparing remote directory: $REMOTE_DIR"
ssh "$SSH_HOST" "mkdir -p $REMOTE_DIR"

# 2. Sync codebase
echo "📦 Syncing whisper-transcriber to homelab..."
rsync -avz --exclude ".venv" --exclude "__pycache__" --exclude ".tmp"   "$(dirname "$0")/" "$SSH_HOST:$REMOTE_DIR/"

# 3. Build & start docker container on Homelab
echo "🐳 Starting container on homelab..."
ssh "$SSH_HOST" "cd $REMOTE_DIR && docker compose up -d --build"

# 4. Check Health
echo "⏳ Checking health status on homelab (port 8009)..."
ssh "$SSH_HOST" "sleep 3 && curl -s http://localhost:8009/health"

echo ""
echo "✅ Backend successfully deployed and running on $SSH_HOST!"
