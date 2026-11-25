#!/bin/bash
set -euo pipefail

# OpenCode uses this scratch directory. Recreate it when /tmp is fresh or tmpfs.
mkdir -p /tmp/opencode

# --- Git Identity Setup ---
# Use a path inside the mounted .config folder so settings persist
export GIT_CONFIG_GLOBAL="/home/agent/.config/.gitconfig"

# Commits are authored by the dedicated bot account, not by a random hostname.
git config --global user.name "${GIT_USER_NAME:-hydr4-agent}"
git config --global user.email "${GIT_USER_EMAIL:-hydr4-agent@users.noreply.github.com}"

# Remove the legacy PAT credential helper if it survived in the persisted config.
git config --global --unset-all credential.helper 2>/dev/null || true

# Git never prompts interactively inside the container.
export GIT_TERMINAL_PROMPT=0

# --- Git SSH Setup ---
# Identity selection belongs to ~/.ssh/config: Host aliases can point different
# repositories at different keys. Only enforce host-key verification here.
# If the config is missing or unparsable, fall back to the legacy single key.
SSH_DIR="/home/agent/.ssh"
SSH_CONFIG="$SSH_DIR/config"
SSH_KEY="$SSH_DIR/id_ed25519"
KNOWN_HOSTS="$SSH_DIR/known_hosts"

if [ -r "$SSH_CONFIG" ] && ssh -G -F "$SSH_CONFIG" github.com >/dev/null 2>&1; then
    export GIT_SSH_COMMAND="ssh -F $SSH_CONFIG -o UserKnownHostsFile=$KNOWN_HOSTS -o StrictHostKeyChecking=yes"
    echo "🔐 Git SSH configured from $SSH_CONFIG"
elif [ -r "$SSH_KEY" ]; then
    export GIT_SSH_COMMAND="ssh -F /dev/null -i $SSH_KEY -o IdentitiesOnly=yes -o UserKnownHostsFile=$KNOWN_HOSTS -o StrictHostKeyChecking=yes"
    echo "⚠️  SSH config missing or invalid; using fallback key $SSH_KEY"
else
    unset GIT_SSH_COMMAND
    echo "⚠️  No usable SSH config or key; Git over SSH will not work"
fi

# The workspace is bind-mounted and may be owned by a different UID.
if ! git config --global --get-all safe.directory | grep -qxF "/workspace"; then
    git config --global --add safe.directory "/workspace"
fi

# --- GitHub CLI (optional) ---
# gh is a GitHub API client for pull requests and CI. It is not a git transport:
# commits are pushed over SSH above, and we deliberately never call
# `gh auth setup-git`, which would reintroduce a credential helper.
export GH_CONFIG_DIR="${GH_CONFIG_DIR:-/home/agent/.config/gh}"
export GH_PROMPT_DISABLED=1
export GH_NO_UPDATE_NOTIFIER=1
export GH_PAGER=cat
mkdir -p "$GH_CONFIG_DIR"

GH_TOKEN_FILE="${GH_TOKEN_FILE:-/home/agent/.secrets/github/token}"
# -f, not -r: a missing source file may be created by Docker as a directory.
if [ -z "${GH_TOKEN:-}" ] && [ -f "${GH_TOKEN_FILE}" ] && [ -r "${GH_TOKEN_FILE}" ]; then
    GH_TOKEN="$(tr -d '\r\n' < "${GH_TOKEN_FILE}")"
    if [ -n "${GH_TOKEN}" ]; then
        export GH_TOKEN
    fi
fi

if [ -n "${GH_TOKEN:-}" ]; then
    echo "🔑 GitHub CLI token configured"
else
    echo "ℹ️  GitHub CLI token not mounted; gh will run unauthenticated"
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

