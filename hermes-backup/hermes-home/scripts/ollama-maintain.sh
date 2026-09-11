#!/bin/bash
# ~/.hermes/bin/ollama-maintain.sh
# Automated Ollama maintenance: weekly version check + model sync

set -e

LOG_FILE="$HOME/.hermes/logs/ollama-maintain.log"
mkdir -p "$HOME/.hermes/logs"

log() {
echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log "Starting Ollama maintenance..."

# 1. Check current vs latest version
CURRENT=$(ollama --version 2>&1 | awk '{print $NF}')
LATEST=$(curl -fsSL https://api.github.com/repos/ollama/ollama/releases/latest 2>/dev/null | grep -oE '"tag_name":\s*"v[^"]+"' | head -1 | grep -oE 'v[0-9.]+')
log "Current: $CURRENT | Latest: $LATEST"

if [ "$CURRENT" != "$LATEST" ]; then
  log "Update needed: upgrading Ollama..."
  if command -v brew >/dev/null 2>&1; then
    brew upgrade ollama 2>&1 | tail -3 | tee -a "$LOG_FILE"
    brew services restart ollama 2>&1 | tail -3 | tee -a "$LOG_FILE"
    sleep 3
    log "Updated to $(ollama --version 2>&1 | awk '{print $NF}')"
  else
    log "ERROR: brew not found. Manual update required."
    exit 1
  fi
fi

# 2. Verify all bot-swarm models are pulled
MODELS=(
  "minimax-m3:cloud"
  "deepseek-v4-flash:cloud"
  "kimi-k2.7-code:cloud"
  "granite4.1-guardian:8b"
  "lfm2.5"
  "qwen3.8:27b"
)

for model in "${MODELS[@]}"; do
  if ollama list 2>/dev/null | grep -q "^${model%%:*}"; then
    log "✓ $model present"
  else
    log "⚠ $model missing - pulling..."
    ollama pull "$model" 2>&1 | tail -3 | tee -a "$LOG_FILE"
  fi
done

log "Maintenance complete."