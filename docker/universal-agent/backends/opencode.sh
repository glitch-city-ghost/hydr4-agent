#!/bin/bash
set -euo pipefail

if [ -z "${HYDRA_API_KEY:-}" ]; then
    echo "❌ HYDRA_API_KEY is not set. OpenCode cannot reach the gateway."
    exit 1
fi

export OPENCODE_CONFIG=/configs/backends/opencode/config.json

# All models go through the single `hydr4` gateway provider configured in
# config.json. Do not export OPENAI_API_KEY or DEEPSEEK_API_KEY: those activate
# the built-in providers and add models that the gateway does not serve.
export OPENCODE_DISABLE_FREE_MODELS=1

echo "🚀 Starting OpenCode Web Server..."
exec opencode serve --hostname 0.0.0.0 --port 4096

