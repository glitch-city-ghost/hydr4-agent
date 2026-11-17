# hydr4-agent Roadmap & Deferred Work

This file tracks the architectural improvements we have deliberately deferred.

Legend: **Pending** — not started. **In Progress** — partially done. **Done** — completed,
kept here for history.

## 🚀 Upcoming & Deferred Work

### 1. Migrate Gateway to LiteLLM
- **Status:** Pending
- **Context:** FreeLLMAPI handles `429 Too Many Requests` poorly: it leaks them to the agent and does not parse `Retry-After`. See `contracts/model-gateway.md` §5.1.
- **Goal:** Replace the FreeLLMAPI image with LiteLLM + Postgres. Keep the same service name, host port, and internal DNS name. Update `.env` and contracts accordingly.
- **Constraint:** the agent-facing contract must not change: `http://gateway:3001/v1`, bearer `HYDRA_API_KEY`, same model IDs.

### 2. Implement Agent Seam (AGENT_BACKEND)
- **Status:** Done.
- **Context:** `docker/universal-agent/entrypoint.sh` dispatches to `/agent/backends/${AGENT_BACKEND}.sh`. The `opencode` and `dsh` backends are implemented.
- **Remaining:** align `contracts/agent-seam.md` with the repository layout (`configs/backends/<name>/`, read-only at `/configs`).

### 3. Harden Agent Filesystem (`read_only: true`)
- **Status:** Pending
- **Context:** The container's root FS is currently writable.
- **Goal:** Add `read_only: true` in `compose/agents.yaml`, mount `tmpfs` for `/tmp`.

### 4. Add DSH as an Alternative Agent
- **Status:** Done.
- **Context:** `docker/universal-agent/backends/dsh.sh` and `configs/backends/dsh/settings.yaml` exist. Selection is via `AGENT_BACKEND=dsh` in `.env`.
- **Remaining:** assert the end-to-end DSH path. `compose/agents.yaml` declares `profiles: ["dsh", "opencode"]`, but the repository wrapper `hydra` always passes `--profile opencode`. Running `dsh` today requires a manual Compose invocation with `--profile dsh`.

### 5. Monitoring and Observability
- **Status:** Pending
- **Context:** We only have Docker logs and the gateway dashboard.
- **Goal:** Deploy Prometheus + Grafana for LLM latency and token metrics.

### 6. Portable egress proxy address
- **Status:** Pending
- **Context:** `UPSTREAM_PROXY` is a host-specific value. On WSL2 it resolves to a host address (`172.17.0.1` where `docker0` uses the default subnet), because mihomo runs natively outside Docker.
- **Goal:** keep the address out of every tracked file. It lives in the gitignored `.env`. `.env.example` documents the shape, and `scripts/smoke-test.sh` must read it from the environment instead of hardcoding its own copy.
- **Depends on:** mihomo staying outside Docker (a `l3rn4-nix` decision). It has no DNS name inside Docker, so `UPSTREAM_PROXY` can never use one.
