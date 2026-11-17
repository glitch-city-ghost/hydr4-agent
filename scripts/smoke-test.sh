#!/usr/bin/env bash

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Load the key from .env
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
else
    echo -e "${RED}Error: .env file not found!${NC}"
    exit 1
fi

if [ -z "$FREELMAPI_UNIFIED_KEY" ]; then
    echo -e "${RED}Error: FREELMAPI_UNIFIED_KEY is not set in .env!${NC}"
    exit 1
fi

echo -e "${YELLOW}=== Running smoke tests for hydr4-agent ===${NC}\n"

# 0. Ask FreeLLMAPI which model is currently active
echo -n "0. Fetching the model list from FreeLLMAPI... "
MODELS_JSON=$(curl -s -H "Authorization: Bearer $FREELMAPI_UNIFIED_KEY" http://127.0.0.1:3001/v1/models)

# Extract the first model ID from the JSON (looking for the "id":"..." pattern)
ACTIVE_MODEL=$(echo "$MODELS_JSON" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

if [ -z "$ACTIVE_MODEL" ]; then
    echo -e "${RED}ERROR (could not get a model. Check the keys in the dashboard)${NC}"
    # If there are no models, use 'auto' as a fallback
    ACTIVE_MODEL="auto"
    echo -e "${YELLOW}Using fallback: $ACTIVE_MODEL${NC}"
else
    echo -e "${GREEN}OK (active model: $ACTIVE_MODEL)${NC}"
fi

# Build the JSON payload with the dynamic model
JSON_PAYLOAD=$(cat <<EOF
{
  "model": "${ACTIVE_MODEL}",
  "messages": [{"role": "user", "content": "What is the weather in Moscow?"}],
  "tools": [{
    "type": "function",
    "function": {
      "name": "get_weather",
      "description": "Get the current weather",
      "parameters": {
        "type": "object",
        "properties": {"location": {"type": "string"}},
        "required": ["location"]
      }
    }
  }]
}
EOF
)

# 1. Check the mihomo proxy
echo -n "1. Checking the mihomo proxy from inside the container... "
PROXY_IP=$(docker compose exec -T gateway node -e "
const { request, ProxyAgent } = require('undici');
const proxyAgent = new ProxyAgent('http://172.17.0.1:7890');
request('https://api.ipify.org', { dispatcher: proxyAgent })
  .then(r => r.body.text()).then(ip => console.log(ip)).catch(() => console.log('FAIL'));
" 2>/dev/null | tr -d '\r\n')

if [ "$PROXY_IP" != "FAIL" ] && [ -n "$PROXY_IP" ]; then
    echo -e "${GREEN}OK (IP: $PROXY_IP)${NC}"
else
    echo -e "${RED}ERROR (could not get an IP through the proxy)${NC}"
fi

# 2. Check API availability
echo -n "2. Checking the FreeLLMAPI API from WSL... "
HEALTH=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:3001/healthz)
if [ "$HEALTH" = "200" ]; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${RED}ERROR (HTTP $HEALTH)${NC}"
fi

# 3. Check tool calling from WSL
echo -n "3. Checking tool calling from WSL (POST)... "
RESPONSE=$(curl -s --max-time 20 http://127.0.0.1:3001/v1/chat/completions \
  -H "Authorization: Bearer $FREELMAPI_UNIFIED_KEY" \
  -H "Content-Type: application/json" \
  -d "$JSON_PAYLOAD")

if echo "$RESPONSE" | grep -q '"tool_calls"'; then
    echo -e "${GREEN}OK (tool calls work)${NC}"
else
    echo -e "${RED}ERROR (tool calls not found)${NC}"
    echo -e "${YELLOW}Server response: $RESPONSE${NC}"
fi

# 4. Check tool calling from inside Docker
echo -n "4. Checking tool calling from inside Docker... "
DOCKER_RESPONSE=$(docker compose exec -T gateway node -e "
fetch('http://127.0.0.1:3001/v1/chat/completions', {
  method: 'POST',
  headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${FREELMAPI_UNIFIED_KEY}'},
  body: JSON.stringify(${JSON_PAYLOAD})
}).then(r=>r.text()).then(console.log).catch((e)=>console.log('FAIL:', e.message))
" 2>/dev/null)

if echo "$DOCKER_RESPONSE" | grep -q '"tool_calls"'; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${RED}ERROR${NC}"
    echo -e "${YELLOW}Response from Docker: $DOCKER_RESPONSE${NC}"
fi
