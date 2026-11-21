---
name: Hydr4 Stack
description: Use when operating, debugging, or changing the hydr4-agent Docker Compose stack, its gateway, its OpenCode container, or its host/agent contracts.
---

# Hydr4 Stack

Use this skill for repository-specific context. Read the linked contract or ADR
before changing an interface; the skill is a map, not a replacement for the
source of truth.

## Topology

```text
Windows host
└── NixOS WSL2 (l3rn4-nix, mirrored networking)
    ├── mihomo            native systemd service, mixed-port 7890
    ├── Traefik          container, file provider only, traefik-net
    ├── hydr4-agent-net  Docker network (this repo)
    │   ├── hydr4-gateway :3001   FreeLLMAPI, OpenAI-compatible
    │   └── hydr4-agent   :4096   OpenCode / DSH, HTTP
    └── traefik-net      external Docker network
        ├── hydr4-gateway :3001
        └── hydr4-agent   :4096
```

Docker DNS names are the Compose **service names**: `gateway` and `agent`.
Container names (`hydr4-gateway`, `hydr4-agent`) are for `docker ps`, logs, and
Traefik's file-provider routes. Do not use container names in service URLs.

## Key paths

| Path | Role |
|---|---|
| `compose.yaml` | Root file; includes `compose/network.yaml`, `compose/gateway.yaml`, `compose/agents.yaml`. |
| `compose/network.yaml` | `hydr4-agent-net` (internal DNS) and external `traefik-net`. |
| `compose/gateway.yaml` | Gateway image, `127.0.0.1:3001:3001`, data mount, proxy env, healthcheck, limits. |
| `compose/agents.yaml` | Agent image, `127.0.0.1:4096:4096`, `/workspace`, `/configs:ro`, SSH:ro, limits. |
| `configs/backends/opencode/` | OpenCode config, prompts, skills, commands, README. |
| `configs/backends/dsh/` | Alternative DSH backend settings. |
| `configs/gateway/freellmapi/freellmapi.env` | Public gateway runtime settings. No secrets. |
| `docker/universal-agent/Dockerfile` | Node 22 slim, git, ripgrep, Python, ttyd, OpenCode, DSH, user `agent` UID 1000. |
| `docker/universal-agent/entrypoint.sh` | Git identity, SSH config, workspace safe.directory, backend dispatch. |
| `docker/universal-agent/backends/opencode.sh` | Exports `OPENCODE_CONFIG`, `OPENAI_API_KEY`, `DEEPSEEK_API_KEY`; `opencode serve`. |
| `scripts/check.sh` | Read-only, host-side shallow health check; no model calls. |
| `scripts/smoke-test.sh` | Host-side proxy, API, and tool-calling smoke test. |
| `hydra` | CLI wrapper around `docker compose --profile opencode`. |

The sibling `workspace/` directory is **not** in this repository. It is mounted
at `/workspace`. The agent repository itself lives at `/workspace/hydr4-agent`
when the workspace is mounted that way; do not assume it is the workspace root.

## Contracts

- `docs/contracts/agent-seam.md`:
  - any backend serves `0.0.0.0:4096`;
  - `GET /global/health` returns 2xx;
  - the backend `exec`s into PID 1 and propagates its exit code;
  - host access via `127.0.0.1:4096` is a debug fallback, not the contract.
- `docs/contracts/gateway.md`:
  - OpenAI API at `http://gateway:3001/v1`;
  - bearer `HYDRA_API_KEY`;
  - SSE streaming, tool forwarding, standard OpenAI error object;
  - `GET /v1/models` returns the model list.
- `docs/contracts/host.md`:
  - networks, bind mounts, SSH key, egress proxy;
  - persistent state is `~/hydr4-data/`, outside the repo;
  - host creates directories with UID/GID 1000.
- `docs/ARCHITECTURE.md` and `docs/DECISIONS.md`:
  - traffic flow, ADR-001..006, Traefik file provider, egress model.

## Invariants that are easy to break

1. **Gateway is the only egress-proxied service.** `HTTP_PROXY`/`HTTPS_PROXY`
   are set on `gateway`, never on `agent`. The agent egresses directly.
2. **Provider keys never reach the agent.** The agent gets only `HYDRA_API_KEY`.
   Do not add `DEEPSEEK_API_KEY`/`GOOGLE_*`/NVIDIA keys to `compose/agents.yaml`.
3. **The agent has no host access.** No Docker socket, no `/var/run`, no host
   home. Do not add one for convenience.
4. **Persistent data is outside the repo.** `~/hydr4-data/gateway` and
   `~/hydr4-data/agent` are state. Never delete, format, or “clean” them.
5. **Traefik labels are inert.** The host uses the file provider
   (`l3rn4-nix/traefik-dynamic/routes.yaml`). Renaming a container requires a
   matching host edit, or ingress returns 502 while containers stay healthy.
6. **The workspace is a bind mount owned by a different UID.** The entrypoint
   adds it to `safe.directory`. Do not `chown -R` the workspace.
7. **The agent port is part of the seam contract.** Changing 4096 means editing
   Compose, both backend scripts, the contract, and the host route.

## Safe operations inside the agent container

The agent image has no Docker daemon and no host filesystem. Run these on the
host, not from the agent:

- `./hydra start`, `stop`, `restart`, `rebuild`, `status`, `logs`, `check`, `cli`;
- `docker compose ...`;
- anything that talks to Traefik or the host proxy;
- editing `~/hydr4-data/`.

Inside the agent container you can:

- read and edit `/workspace/hydr4-agent` and other workspace projects;
- read `/configs` (read-only mirror of the repo's `configs/`);
- run language toolchains installed in the image (`node`, `npm`, `python3`,
  `git`, `rg`);
- run static checks that do not need Docker or the host.

## Troubleshooting (host-side)

Use the smallest check first; do not rebuild to diagnose a provider outage.

1. `./hydra status` — containers, commit, dirty tree.
2. `./hydra check` — compose config, health, gateway `/healthz` and
   `/v1/models`, agent→gateway DNS, `api.localhost`, `agent.localhost`.
3. `./hydra logs gateway` / `./hydra logs agent` — last 100 lines.
4. Provider outage: gateway UI at `http://localhost:3001`; switch model; do not
   rebuild.
5. Traefik 502 with healthy containers: check the host `routes.yaml` and the
   container names, not the Compose labels.
6. Data problem: stop the stack, move the broken `~/hydr4-data/gateway` aside,
   restore a backup. Never delete it in place.
7. Network problem: check that `traefik-net` exists, that `mihomo` listens on
   a host address, and that `UPSTREAM_PROXY` in `.env` points at it.

## Verification matrix for changes

| Change | Minimum verification |
|---|---|
| Compose service/port/volume | `docker compose config --quiet` on host; `./hydra check`. |
| Gateway settings | gateway health, `/v1/models`, one tool-calling request. |
| Agent backend script | `bash -n`, container starts, `/global/health` 200. |
| OpenCode config/prompts/skills | `opencode debug config`, `opencode debug agents`, JSON parse, skill frontmatter. |
| Repo docs/contracts | links resolve, no stale contract, ADR updated. |
| Security boundary | no provider key in agent, no host mount, no Docker socket. |

## Change rules

- Keep the diff inside the requested scope. This repository is small; a
  drive-by refactor is expensive to review and easy to break.
- If a change touches a contract, update the contract and the ADR in the same
  branch. If it is only an implementation detail, do not edit the contract.
- Do not add a new service, network, or volume to solve a local problem.
- Do not add secrets to tracked files, examples, tests, or logs.
- Prefer the existing `scripts/check.sh` and `scripts/smoke-test.sh` over a new
  ad-hoc verification script.
- The host owns Traefik routing and the egress proxy address. The repository
  only declares intent; do not “fix” routing by hardcoding a host IP here.
