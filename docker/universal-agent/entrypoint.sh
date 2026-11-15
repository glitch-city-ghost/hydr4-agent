#!/bin/bash

# --- Git Identity Setup ---
# Используем путь в примонтированной папке .config, чтобы настройки сохранялись
export GIT_CONFIG_GLOBAL="/home/agent/.config/.gitconfig"

if [ ! -f "$GIT_CONFIG_GLOBAL" ]; then
    echo "⚙️  Initializing default Git identity..."
    git config --global user.name "Hydra AI Agent"
    # Генерируем уникальный email на основе hostname контейнера, чтобы не хардкодить PII
    git config --global user.email "agent@$(hostname).local"
fi
# --------------------------

# --- GitHub PAT Token Setup ---
if [ -s "/home/agent/.config/pat/current-token" ]; then
    echo "🔑 Configuring GitHub PAT credential helper..."
    git config --global credential.helper "/home/agent/.local/bin/git-credential-mount.sh"
    echo "✅ GitHub PAT credential helper configured"
fi

# ------------------------------

if [ -z "$AGENT_BACKEND" ]; then
    echo "❌ AGENT_BACKEND is not set. Available: opencode, dsh."
    exit 1
fi

BACKEND_SCRIPT="/agent/backends/${AGENT_BACKEND}.sh"

if [ ! -f "$BACKEND_SCRIPT" ]; then
    echo "❌ Backend script not found: $BACKEND_SCRIPT"
    exit 1
fi

echo "🔄 Delegating to backend: $AGENT_BACKEND"
exec "$BACKEND_SCRIPT"

