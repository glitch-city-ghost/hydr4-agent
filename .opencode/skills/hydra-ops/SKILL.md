---
name: Hydra operations
description: Use for hydr4-agent stack tasks involving Docker Compose, the gateway, the agent container, persistent data, backups, or safe host-side checks.
---

# Hydra operations

## Inside the agent container

The agent can verify network and config shape without Docker:

```sh
getent hosts gateway
curl -sS -H "Authorization: Bearer $HYDRA_API_KEY" http://gateway:3001/v1/models
curl -sS -o /dev/null -w '%{http_code}\n' http://gateway:3001/
python3 -m json.tool configs/backends/opencode/config.json
bash -n hydra scripts/*.sh docker/universal-agent/*.sh docker/universal-agent/backends/*.sh
```

These are not provider tests. A model request is the only real provider check.

## Host-side only

`docker`, `docker compose`, and `./hydra` are not available inside the agent
container. Ask the user to run:

```sh
./hydra status
./hydra check
./hydra logs gateway
./hydra logs agent
./hydra restart     # recreates containers and picks up configs/
./hydra rebuild     # rebuilds the agent image
```

Never claim a host-side command ran from inside this container.

## Data safety

- Persistent state lives in `~/hydr4-data/` on the host: gateway DB, agent
  config, sessions, and SSH material. It is not cache.
- Before risky work, the user should back it up:
  `cp -a ~/hydr4-data ~/hydr4-data.bak-$(date +%F-%H%M%S)`.
- Never delete, prune, or "clean" that directory. Never run
  `docker system prune -a --volumes`.
- If the data looks wrong, stop and restore from backup; do not rebuild over it.

## Topology facts

- Agent -> gateway uses Docker DNS `gateway:3001`, never the container name.
- The agent has no egress proxy; only the gateway uses `UPSTREAM_PROXY`.
- Traefik lives in `l3rn4-nix` and uses the file provider. Renaming a container
  requires a matching `routes.yaml` edit on the host.
- The `traefik.*` labels in this repo document intent but do not route traffic.
