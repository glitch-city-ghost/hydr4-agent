#!/bin/bash
export OPENAI_API_KEY="${HYDRA_API_KEY}"
echo "🚀 Starting DeepSeek Harness..."
exec dsh web --port 4096 --host 0.0.0.0

