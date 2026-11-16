#!/bin/bash
set -euo pipefail

# --- Git Identity Setup ---
# Используем путь в примонтированной папке .config, чтобы настройки сохранялись
export GIT_CONFIG_GLOBAL="/home/agent/.config/.gitconfig"

# Commits are authored by the dedicated bot account, not by a random hostname.
git config --global user.name "${GIT_USER_NAME:-hydr4-agent}"
git config --global user.email "${GIT_USER_EMAIL:-hydr4-agent@users.noreply.github.com}"

# Remove the legacy PAT credential helper if it survived in the persisted config.
git config --global --unset-all credential.helper 2>/dev/null || true

# Git never prompts interactively inside the container.
export GIT_TERMINAL_PROMPT=0

# --- GitHub SSH Setup ---
if [ -r "/home/agent/.ssh/id_ed25519" ]; then
    export GIT_SSH_COMMAND="ssh -i /home/agent/.ssh/id_ed25519 -o IdentitiesOnly=yes -o UserKnownHostsFile=/home/agent/.ssh/known_hosts -o StrictHostKeyChecking=yes"
    echo "🔐 Git SSH configured for the bot account"
else
    echo "⚠️  No SSH key at /home/agent/.ssh/id_ed25519; Git over SSH will not work"
fi

# The workspace is bind-mounted and may be owned by a different UID.
if ! git config --global --get-all safe.directory | grep -qxF "/workspace"; then
    git config --global --add safe.directory "/workspace"
fi

if [ -z "${AGENT_BACKEND:-}" ]; then
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

