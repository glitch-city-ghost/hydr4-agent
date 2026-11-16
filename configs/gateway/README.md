# Gateway Config

The model gateway is an interchangeable component behind an OpenAI-compatible
API. The agent and the containers only depend on the gateway contract in
[`docs/contracts/model-gateway.md`](../../docs/contracts/model-gateway.md), not
on a concrete implementation.

## Current implementation: FreeLLMAPI

Public, non-secret runtime settings are tracked in:

```text
configs/gateway/freellmapi/freellmapi.env
```

Persistent gateway data lives at `~/hydr4-data/gateway`, mounted to
`/app/server/data` in the container. The container-visible path is stable, so
moving the host directory does not change how FreeLLMAPI reads its SQLite
database.

Secrets stay in the root `.env` (gitignored) and are documented in
`.env.example`:

- `ENCRYPTION_KEY` — FreeLLMAPI database encryption key;
- `FREELMAPI_UNIFIED_KEY` — unified API key used by the agent;
- `UPSTREAM_PROXY` — host egress proxy, mapped to `HTTP_PROXY`/`HTTPS_PROXY`
  by `compose/gateway.yaml`.

`compose/gateway.yaml` is intentionally limited to the generic service
definition: image, port, networks, labels, proxy mapping, volume, healthcheck,
and resources. Gateway-specific runtime settings belong in this directory, not
in compose.

## Future implementation: LiteLLM

The target is to add a LiteLLM configuration here (for example
`litellm.config.yaml` plus a gateway-specific env file) and select it through a
gateway-specific compose override. The agent-facing contract must stay stable:
`http://gateway:3001/v1`, bearer `HYDRA_API_KEY`, and the same model IDs.
