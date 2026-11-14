#!/bin/bash
export GIT_CONFIG_GLOBAL=/dev/null
export GIT_CONFIG_SYSTEM=/dev/null
export GIT_TERMINAL_PROMPT=0
unset GH_TOKEN GITHUB_TOKEN GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL

# Git identity via environment variables (no global config writes)
export GIT_AUTHOR_NAME="hydr4-agent"
export GIT_AUTHOR_EMAIL="hydr4-agent@noreply.local"
export GIT_COMMITTER_NAME="hydr4-agent"
export GIT_COMMITTER_EMAIL="hydr4-agent@noreply.local"

# --- GitHub PAT Token Setup ---
if [ -s "/home/agent/.config/pat/current-token" ]; then
    echo "🔑 Configuring GitHub PAT credential helper..."
    git config --global credential.helper "/home/agent/.local/bin/git-credential-mount.sh"
    echo "✅ GitHub PAT credential helper configured"
fi

# ------------------------------

if [ "$AGENT_TYPE" = "opencode" ]; then
    echo "🚀 Запуск OpenCode Web Server..."
    exec opencode serve --hostname 0.0.0.0 --port 4096
    
elif [ "$AGENT_TYPE" = "dsh" ]; then
    echo "🚀 Запуск DeepSeek Harness..."
    # Запускаем DSH (порт 3080)
    exec dsh web --port 3080 --host 0.0.0.0
    
else
    echo "❌ Неизвестный AGENT_TYPE: $AGENT_TYPE. Доступны: opencode, dsh."
    exec bash
fi