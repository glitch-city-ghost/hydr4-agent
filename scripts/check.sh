#!/usr/bin/env bash
#
# Shallow, read-only health check for hydr4-agent.
#
# It checks the obvious stuff only:
#   - compose config is valid
#   - containers exist, are running and healthy
#   - gateway answers locally
#   - the agent can resolve the gateway
#   - Traefik ingress answers
#
# It does NOT call any model provider, so it spends no tokens.
# It does NOT change the repository, containers, or data.
#
# Usage: ./hydra check   (or: bash scripts/check.sh)

set -uo pipefail

cd "$(dirname "$0")/.." || exit 1

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

FAILED=0
WAITING=0

ok()      { printf '%b[OK]%b   %s\n'   "$GREEN"  "$NC" "$*"; }
fail()    { printf '%b[FAIL]%b %s\n'   "$RED"    "$NC" "$*"; FAILED=$((FAILED + 1)); }
pending() { printf '%b[WAIT]%b %s\n'   "$YELLOW" "$NC" "$*"; WAITING=$((WAITING + 1)); }

# Load secrets without printing them.
if [ -f .env ]; then
    set -a
    # shellcheck disable=SC1091
    . ./.env
    set +a
fi

COMPOSE=(docker compose --profile opencode)

# --- 1. Compose config -------------------------------------------------------
if config_err=$("${COMPOSE[@]}" config --quiet 2>&1); then
    ok "compose config"
else
    fail "compose config: ${config_err:-unknown error}"
fi

# --- 2. Containers -----------------------------------------------------------
mapfile -t SERVICES < <("${COMPOSE[@]}" config --services 2>/dev/null)

if [ "${#SERVICES[@]}" -eq 0 ]; then
    fail "no services found in compose config"
else
    PS=$("${COMPOSE[@]}" ps --all --format '{{.Service}}|{{.Status}}' 2>/dev/null || true)

    for svc in "${SERVICES[@]}"; do
        status=$(printf '%s\n' "$PS" | awk -F'|' -v s="$svc" '$1 == s { print $2; exit }')

        if [ -z "$status" ]; then
            fail "$svc: not created"
            continue
        fi

        case "$status" in
            *"(unhealthy)"*)       fail "$svc: unhealthy" ;;
            *"(health: starting)"*) pending "$svc: still starting" ;;
            *"(healthy)"*)         ok "$svc: running, healthy" ;;
            Up*|Running*)          ok "$svc: running" ;;
            *)                     fail "$svc: $status" ;;
        esac
    done
fi

# --- 3. Gateway local health -------------------------------------------------
gw_code=$(curl --noproxy '*' -sS -o /dev/null -w '%{http_code}' \
    --max-time 5 http://127.0.0.1:3001/healthz 2>/dev/null || true)

if [ "$gw_code" = "200" ]; then
    ok "gateway /healthz -> 200"
else
    fail "gateway /healthz -> ${gw_code:-no response}"
fi

# --- 4. Gateway model list (local DB only, no provider call) -----------------
if [ -z "${FREELMAPI_UNIFIED_KEY:-}" ]; then
    fail "FREELMAPI_UNIFIED_KEY is not set in .env"
else
    models_resp=$(curl --noproxy '*' -sS -w $'\n%{http_code}' --max-time 5 \
        -H "Authorization: Bearer ${FREELMAPI_UNIFIED_KEY}" \
        http://127.0.0.1:3001/v1/models 2>/dev/null || true)

    models_code=${models_resp##*$'\n'}
    models_body=${models_resp%$'\n'*}

    if [ "$models_code" = "200" ] && printf '%s' "$models_body" | grep -q '"data"'; then
        ok "gateway /v1/models -> 200"
    else
        fail "gateway /v1/models -> ${models_code:-no response}"
    fi
fi

# --- 5. Agent -> gateway DNS -------------------------------------------------
if "${COMPOSE[@]}" exec -T agent getent hosts gateway >/dev/null 2>&1; then
    ok "agent -> gateway DNS"
else
    fail "agent -> gateway DNS"
fi

# --- 6. Traefik ingress ------------------------------------------------------
check_ingress() {
    local host=$1
    local code

    code=$(curl --noproxy '*' -sS -o /dev/null -w '%{http_code}' \
        --max-time 5 "http://${host}/" 2>/dev/null || true)

    case "$code" in
        # 401/403 are fine: it means Traefik reached the agent and auth kicked in.
        200|301|302|303|307|308|401|403) ok "${host} -> ${code}" ;;
        *)                               fail "${host} -> ${code:-no response}" ;;
    esac
}

check_ingress api.localhost
check_ingress agent.localhost

# --- Summary -----------------------------------------------------------------
echo

if [ "$FAILED" -gt 0 ]; then
    printf '%b%d check(s) failed.%b Run ./hydra logs, then read WTF_EVERYTHING_BROKE_DOWN_HELP.md\n' \
        "$RED" "$FAILED" "$NC"
    exit 1
fi

if [ "$WAITING" -gt 0 ]; then
    printf '%b%d check(s) still waiting.%b Rerun ./hydra check in a few seconds.\n' \
        "$YELLOW" "$WAITING" "$NC"
    exit 1
fi

printf '%bAll checks passed.%b\n' "$GREEN" "$NC"
