#!/bin/bash
export OPENCODE_CONFIG=/configs/backends/opencode/config.json
export OPENAI_API_KEY="${HYDRA_API_KEY}"
# The built-in DeepSeek provider activates from DEEPSEEK_API_KEY.
# Route it through the gateway just like the other OpenAI-compatible providers.
export DEEPSEEK_API_KEY="${HYDRA_API_KEY}"
echo "🚀 Starting OpenCode Web Server..."
exec opencode serve --hostname 0.0.0.0 --port 4096

