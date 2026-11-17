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

### 7. Make the agent port configurable
- **Status:** Pending
- **Context:** The agent port is currently written literally as `4096` in several places: `compose/agents.yaml` (`ports`, `healthcheck`, the `traefik.*` label), `docker/universal-agent/backends/opencode.sh` (`--port 4096`), and `docker/universal-agent/backends/dsh.sh` (`--port 4096`). The contract in `docs/contracts/agent-seam.md` requires any backend to serve on `0.0.0.0:4096`.
- **Goal:** make the port a single variable, `HYDR4_AGENT_HTTP_PORT`, defaulting to `4096`.
  - Define it once in the root `.env`; compose substitutes it into `ports`, the `healthcheck` test, and the agent `environment`.
  - Backend scripts read `HYDR4_AGENT_HTTP_PORT` instead of the literal (`--port "${HYDR4_AGENT_HTTP_PORT}"`).
  - The contract states `Serve on 0.0.0.0:${HYDR4_AGENT_HTTP_PORT}` instead of a literal port.
- **Remaining:** the `traefik.*` label in `compose/agents.yaml` is inert, since the host runs Traefik with the file provider only (ADR-006). Changing the port therefore also means editing `l3rn4-nix/traefik-dynamic/routes.yaml` by hand.
- **Depends on:** `docs/contracts/agent-seam.md` §2 and §1.
