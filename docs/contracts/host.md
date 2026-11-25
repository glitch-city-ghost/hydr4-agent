# Host Contract

**Version:** 2.0
**Status:** Active
**Scope:** What this repository needs from the host (`l3rn4-nix`).

The host runs Docker and the outside world. The repository brings the application. The boundary
between the two is small, and this is all of it: two external networks, one directory tree outside
the repository, the credentials mounted there, and the egress proxy address.

## 1. Networks

| Network | Created by | Used for |
|---|---|---|
| `hydr4-agent-net` | this repository (`compose/network.yaml`) | agent <-> gateway traffic, by service name |
| `traefik-net` | `l3rn4-nix` (`systemd.services.traefik-network`) | ingress from Traefik |
| (any bridge) | Docker | egress from the gateway to the host proxy |

`traefik-net` is `external: true`, so `docker compose up` fails until the host has created it. The
agent and gateway both join it, and both are routed by hand in
`l3rn4-nix/traefik-dynamic/routes.yaml`:

| Domain | Container | Port |
|---|---|---|
| `agent.localhost` | `hydr4-agent` | `4096` |
| `api.localhost` | `hydr4-gateway` | `3001` |

Traefik runs with the **file provider only**. It does not read Docker labels and has no access to
`/var/run/docker.sock`. `traefik.*` labels in `compose/*.yaml` are therefore inert — the file above is
the source of truth, and a renamed container needs a matching edit there. When it is missed, ingress
answers `502` while the containers themselves stay healthy.

## 2. Egress proxy

`mihomo` runs on the host as a systemd service (`l3rn4-nix/modules/mihomo.nix`), not as a container. It
binds `*` on `mixed-port: 7890`, which is what makes it reachable from Docker.

The gateway reaches it through `HTTP_PROXY` / `HTTPS_PROXY`, both set from a single `.env` value:

```ini
UPSTREAM_PROXY=http://172.17.0.1:7890
```

The address is host-specific. `127.0.0.1` inside the gateway container is the container, not the host,
and does not reach mihomo. The agent does not get the proxy.

## 3. Data on disk

Persistent state lives in `~/hydr4-data/`, outside the repository:

| Host path | Container path |
|---|---|
| `~/hydr4-data/gateway/` | `/app/server/data` |
| `~/hydr4-data/agent/config` | `/home/agent/.config` |
| `~/hydr4-data/agent/local-share` | `/home/agent/.local/share/opencode` |
| `~/hydr4-data/secrets/ssh` | `/home/agent/.ssh` (read-only) |

The credential mounts are operator configuration, not part of the agent contract. The current
compose file mounts `~/hydr4-data/secrets/ssh` read-only at `/home/agent/.ssh`; the operator may
remove it, leave it empty, or add another read-only mount for the workflow they want the agent to
run. The image carries no credentials, and this repository does not prescribe an account model,
remote topology, or review/merge process. Anything mounted must be readable by uid 1000.

The host creates these directories before the first start, owned by the user running Compose. If
Docker creates a missing directory itself, it belongs to root and the `user: "1000:1000"` of the
agent container cannot write to it (ADR-004, ADR-005).

The workspace is one more directory outside the repository, mounted at `/workspace`.

## 4. Secrets

All secrets are files supplied by the host. None of them is tracked in Git.

| Secret | Where |
|---|---|
| `FREELMAPI_UNIFIED_KEY` | root `.env`; exposed to the agent as `HYDRA_API_KEY` |
| `ENCRYPTION_KEY` | root `.env`; FreeLLMAPI database key |
| `OPENCODE_PASSWORD` | root `.env`; OpenCode Web UI |
| Provider keys | gateway dashboard or `.env`; stored under `~/hydr4-data/gateway/` |
| Git/GitHub credentials (optional) | `~/hydr4-data/secrets/`: an SSH key under `ssh/` (`0700` on the directory, `0600` on the key, `0644` on `known_hosts`) and/or a token file. Which credentials exist, what they grant, and when they expire is the operator's responsibility. |

## 5. Prerequisites

Before the first start, the host provides:

1. Docker Engine and Docker Compose v2.
2. The `traefik-net` network, and Traefik attached to it.
3. The `~/hydr4-data/` tree from §3, owned by the user running Compose (`uid 1000`).
4. Optional: Git/GitHub credentials in `~/hydr4-data/secrets/`, with the permissions from §4. Without them, Git over SSH and GitHub API operations do not work; the stack still starts.
5. `mihomo` running, and `UPSTREAM_PROXY` in `.env` pointing at a host address that reaches it.
6. The agent's sibling `workspace/` directory, created outside this repository.

## 6. Compliance

`./hydra check` covers: compose config, both containers' health, the gateway health endpoint,
gateway DNS from the agent, and both `*.localhost` domains through Traefik. It does not touch the
host proxy or GitHub. GitHub access is operator configuration, not a contract, so the checks below
are examples: run them only for the credentials you actually mounted.

These are the checks it does not cover; run them by hand on the host:

```bash
docker network inspect traefik-net
docker compose exec agent ssh -T git@github.com
docker compose exec gateway curl -s -x "$UPSTREAM_PROXY" https://api.ipify.org
```
