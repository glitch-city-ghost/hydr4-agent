#!/bin/bash
export OPENCODE_CONFIG=/configs/backends/opencode/config.json
export OPENAI_API_KEY="${HYDRA_API_KEY}"
echo "🚀 Запуск OpenCode Web Server..."
exec opencode serve --hostname 0.0.0.0 --port 4096

