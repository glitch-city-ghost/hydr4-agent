# Architecture

## Topology

```text
Windows host
└── NixOS WSL2 (l3rn4-nix, networkingMode = mirrored)
    ├── mihomo            native, systemd, listens on *:7890 and 172.17.0.1:9090
    ├── Traefik           container, ports 127.0.0.1:80 / :8080, network traefik-net
    ├── Docker network traefik-net
    │   ├── hydr4-gateway :3001           (this repo, FreeLLMAPI -> LiteLLM)
    │   └── hydr4-agent   :4096           (this repo, OpenCode / DSH)
    └── Docker network hydr4-agent-net
        └── gateway + agent, internal DNS by service name
```

## The networks, one by one

| Network | Created by | Purpose | Notes |
|---|---|---|---|
| `traefik-net` | `l3rn4-nix/modules/traefik.nix` | Ingress | Must exist before `docker compose up` |
| `hydr4-agent-net` | `hydr4-agent`, `compose/network.yaml` | Agent <-> gateway traffic | `agent` resolves `gateway` |
| default bridge (`docker0`) | Docker | Host <-> container | `iptables = false` in `l3rn4-nix`, so no Docker firewall rules |
| WSL mirrored lease | WSL2 | Host <-> Windows | do not target it from containers |

## Traffic & Network

### Agent -> gateway

Docker DNS, **service name, not container name**:

```text
agent: http://gateway:3001/v1   (OpenAI-compatible /chat/completions, /models)
```

- Container names (`hydr4-gateway`, `hydr4-agent`) are not registered in Docker DNS. They are only for `docker ps` and host-side `docker exec`.
- The agent has **no** upstream proxy. It talks to Docker DNS directly.

### Host -> containers

Two independent paths exist:

- `http://agent.localhost` / `http://api.localhost` — through Traefik. **This is the supported path.**
- `127.0.0.1:4096` / `127.0.0.1:3001` — direct port bindings. **Debug fallback only**: for the check scripts, and for reaching a container by hand when Traefik is down or misconfigured. Not part of the contract, bound to loopback so not reachable from the LAN. Marked for removal once container-to-container access through Traefik is the only supported path (see `docs/ROADMAP.md`, last item).

### Gateway -> providers (egress)

- By default: direct NAT from the container.
- Through mihomo: only if `UPSTREAM_PROXY` is set in the root `.env`. `compose/gateway.yaml` maps it to the gateway's `HTTP_PROXY`/`HTTPS_PROXY`.
- mihomo lives on the host (`l3rn4-nix`), not in Docker. It stays there and will not move.
- mihomo config (`l3rn4-nix/mihomo-config.yaml`) binds `*` with `allow-lan: true` on `mixed-port: 7890`.
- The gateway is the only service that gets the proxy. The agent keeps its direct egress path.

Example, on a host where `docker0` is `172.17.0.1`:

```bash
$ ip -4 -br addr show docker0
docker0  UP  172.17.0.1/16

$ curl -sSx http://172.17.0.1:7890 https://api.ipify.org
<exit IP>

$ curl -sSx http://172.19.0.1:7890 https://api.ipify.org   # another host address, same result
<exit IP>

$ curl -sS https://integrate.api.nvidia.com/v1/models      # without the proxy
451 Unavailable For Legal Reasons
```

Any address of the host works while mihomo has `bind-address: "*"` + `allow-lan: true`. Container-internal addresses (`127.0.0.1` inside the gateway) do not.

The compose files contain no IP. Only `UPSTREAM_PROXY` in the root `.env` does, and it is a host-specific value, not project config.

### Traefik -> containers

- Provider: `file` only. Docker provider is disabled.
- Source of truth: `l3rn4-nix/traefik-dynamic/routes.yaml`, maintained by hand.
- Traefik has no access to `/var/run/docker.sock` and no socket proxy.

Consequences for this repo:

- `traefik.*` labels in `compose/*.yaml` are inert. They document intent but do not route traffic.
- A new container is not reachable until an entry is added to `routes.yaml`.
- Renaming a service or container requires a matching edit in `routes.yaml`.

See ADR-006.

## Components

- **l3rn4-nix**: OS, Docker, mihomo, Traefik. Unaware of hydr4 internals.
- **gateway**: OpenAI-compatible proxy, provider failover. Must adhere to `docs/contracts/gateway.md`.
- **agent**: Interchangeable container. Must adhere to `docs/contracts/agent-seam.md`.

## Contracts

All interfaces between these components are strictly defined in the `docs/contracts/` directory.
