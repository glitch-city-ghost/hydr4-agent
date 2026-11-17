# Gateway Config

The model gateway is an interchangeable component behind an OpenAI-compatible
API. The agent and the containers only depend on the gateway contract in
[`docs/contracts/model-gateway.md`](../../docs/contracts/model-gateway.md), not
on a concrete implementation.

Current implementation: **FreeLLMAPI**. Target implementation: **LiteLLM**
(see [`docs/ROADMAP.md`](../../docs/ROADMAP.md)).

## Tracked files

```text
configs/gateway/
├── freellmapi/
│   └── freellmapi.env        # FreeLLMAPI runtime settings (no secrets)
└── README.md
```

Any future implementation lives in its own subdirectory next to `freellmapi/`
(for example `configs/gateway/litellm/config.yaml`).

## Public settings vs. secrets

**Public, tracked here** — things that describe the gateway itself:

- `PORT`, `HOST_BIND` — where the gateway listens inside its container;
- `NO_PROXY` — destinations the gateway must reach *directly*, bypassing its
  upstream proxy (for example its own SQLite/Postgres or a local callback);
- provider-level timeouts and budgets (`FALLBACK_TIME_BUDGET_MS`,
  `PROVIDER_TIMEOUT_*`, `PROVIDER_STREAM_STALL_TIMEOUT_MS`).

**Private, never tracked** — things that depend on the host or are secret:

- `ENCRYPTION_KEY` — FreeLLMAPI database encryption key;
- `FREELMAPI_UNIFIED_KEY` — unified API key used by the agent (exposed to the
  agent as `HYDRA_API_KEY`);
- `UPSTREAM_PROXY` — egress proxy address on the host, e.g.
  `http://172.17.0.1:7890`.

They are documented in `.env.example` at the repository root and supplied at
runtime through `.env`.

### Why the proxy address is not in this directory

`UPSTREAM_PROXY` is **not** a gateway setting: it is a property of the host
network. `compose/gateway.yaml` reads it from `.env` and maps it onto the
gateway container's `HTTP_PROXY` / `HTTPS_PROXY`:

```yaml
environment:
  - HTTP_PROXY=${UPSTREAM_PROXY}
  - HTTPS_PROXY=${UPSTREAM_PROXY}
```

The gateway itself knows nothing about `UPSTREAM_PROXY`; like any Node/SQLite
process it only honours `HTTP_PROXY` / `HTTPS_PROXY`. Keeping the host value in
`.env` means the same repository works against any host, and only `.env` changes.

The agent receives **no** proxy. It egresses directly through the host network.

## Persistent data

The gateway data directory is mounted from:

```text
~/hydr4-data/gateway/ → /app/server/data
```

The container-visible path is stable. Moving the host directory does not change
how the gateway reads its data.

## Compose file

`compose/gateway.yaml` is intentionally limited to the generic service
definition: image, port, networks, labels, volume, healthcheck, and resources.
Gateway-specific runtime settings belong in this directory, not in Compose.

Traefik routing is **not** declared by the labels in `compose/gateway.yaml`. The
host runs Traefik with the file provider only, using
`l3rn4-nix/traefik-dynamic/routes.yaml`. The labels are inert and kept for
reference (see ADR-006).
