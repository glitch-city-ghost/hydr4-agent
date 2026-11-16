# System Boundary Contract

**Version:** 1.0  
**Status:** Active  
**Scope:** Defines the explicit expectations and boundaries between the `hydr4-agent` application layer (this repository) and the host system layer (`l3rn4-nix`).

## 1. Purpose

This document eliminates implicit assumptions. `hydr4-agent` runs as a set of Docker containers. It relies on the host system for networking, ingress routing (Traefik), and egress proxying (mihomo). 

If the host configuration changes, it must not break this application silently. This contract defines exactly what the application expects from the host.

## 2. Network Boundaries

### 2.1 Ingress (Traefik)
The host provides an external Docker network named `traefik-net`. The `hydr4-agent` containers attach to this network to expose their web interfaces. 
The host's Traefik instance is expected to:
- Listen on the `web` entrypoint (HTTP).
- Route based on the `Host` header.
- Respect Docker labels for routing.

**Routing Expectations:**
| Domain | Target Service | Target Port | Purpose |
|---|---|---|---|
| `agent.localhost` | `agent` | `4096` | OpenCode Web UI / DSH Web UI |
| `api.localhost` | `gateway` | `3001` | Model Gateway Dashboard |

### 2.2 Internal Networking
The application creates its own network `agent-net` (`hydr4-agent-net`). Services inside this network resolve each other by service name via Docker's internal DNS (e.g., `http://gateway:3001`).

### 2.3 Egress (Proxy)
The host provides a proxy (`mihomo`) for outbound LLM traffic (to bypass geo-blocking). The application expects this proxy to be reachable from inside the containers.

- **Current Implementation (Tech Debt):** The application uses `UPSTREAM_PROXY=http://172.17.0.1:7890`. This relies on the default Docker bridge IP, which is fragile.
- **Target Implementation:** The application should use `http://host.docker.internal:7890` (or a specific DNS alias). All hardcoded `172.17.x.x` IPs must be purged from `compose/` and `.env.example`.

## 3. Storage Boundaries (Bind Mounts)

The application does not store persistent state inside the Docker overlay. It expects the host to provide specific directories, mounted into the containers.

**Host Path:** `~/hydr4-data/`
The host guarantees this directory exists and is writable by the user running `docker compose`.

| Host Path | Container Path | Purpose |
|---|---|---|
| `~/hydr4-data/agent/config` | `/home/agent/.config` | Persistent agent state (gitconfig, backend auth). |
| `~/hydr4-data/agent/local-share` | `/home/agent/.local/share/opencode` | OpenCode local data. |
| `~/hydr4-data/secrets/ssh` | `/home/agent/.ssh` | Read-only bot SSH key, `known_hosts`, and SSH config for Git operations. |
| `~/hydr4-data/aggregator/` | `/app/server/data` | Gateway state (legacy data path; currently SQLite, later Postgres data). |

## 4. Secrets Boundary

The host is responsible for injecting secrets into the filesystem before the containers start.
- **GitHub SSH key:** `~/hydr4-data/secrets/ssh/id_ed25519` (private) and `known_hosts`. The host must keep the directory at `chmod 700`, the private key at `chmod 600`, and `known_hosts` at `chmod 644`. The key belongs to a dedicated bot account, not the human account. The container mounts the directory read-only.
- **LLM Provider Keys:** Passed via the `.env` file on the host. The container does not store these keys on disk.

## 5. Host Prerequisites

For `hydr4-agent` to function, the host (`l3rn4-nix`) **must** guarantee:
1.  Docker Engine and Docker Compose v2 are installed and running.
2.  The external network `traefik-net` exists (`docker network create traefik-net`).
3.  The Traefik container is running and attached to `traefik-net`.
4.  The egress proxy (`mihomo`) is running and accessible on port `7890`.
5.  `~/hydr4-data/secrets/ssh` exists with the bot key, `known_hosts`, and correct permissions.

## 6. Compliance

To verify the boundary is intact:
1.  `docker network inspect traefik-net` shows Traefik and hydr4-agent containers.
2.  `curl -H "Host: agent.localhost" http://127.0.0.1` resolves to the agent container.
3.  `docker compose exec gateway curl -s -x $UPSTREAM_PROXY https://api.ipify.org` returns an IP address, proving egress works.
4.  `docker compose exec agent ssh -T git@github.com` returns `Hi <bot-account>!` and no shell access banner.