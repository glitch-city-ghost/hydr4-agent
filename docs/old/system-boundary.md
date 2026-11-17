# System Boundary Contract

**Version:** 1.1
**Status:** Active
**Scope:** Defines the explicit expectations and boundaries between the `hydr4-agent` application layer (this repository) and the host system layer (`l3rn4-nix`).

## 1. Purpose

This document eliminates implicit assumptions. `hydr4-agent` runs as a set of Docker containers. It relies on the host system for networking and ingress routing (Traefik) and for the egress proxy (mihomo).

If the host configuration changes, it must not break this application silently. This contract defines exactly what the application expects from the host.

## 2. Network Boundaries

### 2.1 Ingress (Traefik)

The host provides an external Docker network named `traefik-net`. The `hydr4-agent` containers attach to this network to be reachable through Traefik.

The host's Traefik instance runs with the **file provider only**:

- it listens on the `web` entrypoint (HTTP, `127.0.0.1:80`);
- it routes by the `Host` header;
- it does **not** read Docker labels, and it has no access to `/var/run/docker.sock`.

Routes are declared by hand in `l3rn4-nix/traefik-dynamic/routes.yaml`. Therefore every service this repository exposes is registered **in that file** as well, against the container name and the internal port:

```yaml
hydr4-gateway:
  loadBalancer:
    servers:
      - url: "http://hydr4-gateway:3001"
```

`traefik.*` labels in `compose/*.yaml` are inert. They are kept for reference only. The source of truth is `routes.yaml`.

**Routing Expectations:**

| Domain | Target Container | Target Port | Purpose |
|---|---|---|---|
| `agent.localhost` | `hydr4-agent` | `4096` | OpenCode Web UI / DSH Web UI |
| `api.localhost` | `hydr4-gateway` | `3001` | Model Gateway Dashboard |

Renaming a service or a container requires a matching edit in `l3rn4-nix/traefik-dynamic/routes.yaml`. If the edit is missed, ingress returns `502` while the containers themselves stay healthy.

### 2.2 Internal Networking

The application creates its own network `agent-net` (`hydr4-agent-net`). Services inside this network resolve each other by **service name** via Docker's internal DNS (e.g., `http://gateway:3001`). Container names (`hydr4-gateway`) are not part of that DNS namespace.

`traefik-net` and `hydr4-agent-net` are independent. Each service simply joins both.

### 2.3 Egress (Proxy)

The host provides a proxy (`mihomo`) for outbound LLM traffic to bypass geo-blocking. mihomo is a **native host service** managed by `l3rn4-nix` (systemd), not a Docker container, and it will stay that way.

Configuration on the host side (`l3rn4-nix/mihomo-config.yaml`):

- `mixed-port: 7890`;
- `allow-lan: true`;
- `bind-address: "*"` — it listens on every interface, including Docker bridges.

Because of `bind-address: "*"`, any address of the host is reachable from a container. Examples on a host where `docker0` is `172.17.0.1/16`:

```text
http://172.17.0.1:7890          # docker0 bridge address
http://172.19.0.1:7890          # address of another bridge
http://host.docker.internal:7890  # Docker-provided host alias
```

Addresses inside the container (`127.0.0.1`, the container's own IP) do **not** reach mihomo.

`hydr4-agent` does not pin any of these addresses. The value is chosen by the host operator and passed in `.env`:

```ini
UPSTREAM_PROXY=http://172.17.0.1:7890
```

`compose/gateway.yaml` maps it to the gateway's `HTTP_PROXY` / `HTTPS_PROXY`. No other service receives the proxy: the agent keeps direct egress. `.env.example` carries an example value with a short note; it is not a requirement.

The `NO_PROXY` list is part of the gateway's own container-internal traffic and lives with the gateway settings, in `configs/gateway/freellmapi/freellmapi.env`.

## 3. Storage Boundaries (Bind Mounts)

The application does not store persistent state inside the Docker overlay. It expects the host to provide specific directories, mounted into the containers.

**Host Path:** `~/hydr4-data/`
The host guarantees this directory exists and is writable by the user running `docker compose`.

| Host Path | Container Path | Purpose |
|---|---|---|
| `~/hydr4-data/agent/config` | `/home/agent/.config` | Persistent agent state (gitconfig, backend auth). |
| `~/hydr4-data/agent/local-share` | `/home/agent/.local/share/opencode` | OpenCode local data. |
| `~/hydr4-data/secrets/ssh` | `/home/agent/.ssh` | Read-only bot SSH key, `known_hosts`, and SSH config for Git operations. |
| `~/hydr4-data/gateway/` | `/app/server/data` | Gateway state (currently SQLite, later Postgres data). |

## 4. Secrets Boundary

The host is responsible for injecting secrets into the filesystem before the containers start.

- **GitHub SSH key:** `~/hydr4-data/secrets/ssh/id_ed25519` (private) and `known_hosts`. The host must keep the directory at `chmod 700`, the private key at `chmod 600`, and `known_hosts` at `chmod 644`. The key belongs to a dedicated bot account, not the human account. The container mounts the directory read-only.
- **LLM Provider Keys:** Passed via the `.env` file on the host. The container does not store these keys on disk.
- **Gateway unified key:** `FREELMAPI_UNIFIED_KEY` in `.env`. `compose/agents.yaml` exposes it to the agent as `HYDRA_API_KEY`.

## 5. Host Prerequisites

For `hydr4-agent` to function, the host (`l3rn4-nix`) **must** guarantee:

1.  Docker Engine and Docker Compose v2 are installed and running.
2.  The external network `traefik-net` exists. `l3rn4-nix` creates it via `systemd.services.traefik-network`.
3.  The Traefik container is running and attached to `traefik-net`.
4.  The egress proxy (`mihomo`) is running and reachable from Docker containers on port `7890`. The host operator records its address in `.env` as `UPSTREAM_PROXY`.
5.  `~/hydr4-data/secrets/ssh` exists with the bot key, `known_hosts`, and correct permissions.

## 6. Compliance

To verify the boundary is intact:

1.  `docker network inspect traefik-net` shows Traefik and the `hydr4-agent` containers.
2.  `curl -H "Host: agent.localhost" http://127.0.0.1` resolves to the agent container.
3.  `docker compose exec gateway curl -s -x "$UPSTREAM_PROXY" https://api.ipify.org` returns an IP address, proving egress works.
4.  `docker compose exec agent ssh -T git@github.com` returns `Hi <bot-account>!` and no shell access banner.
5.  `docker compose exec agent curl -fsS http://gateway:3001/healthz` returns `200`, proving internal DNS resolves the gateway service name.
