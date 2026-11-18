# Gateway Contract

**Version:** 2.0
**Status:** Active
**Scope:** The interface every model gateway must implement.

The gateway is an interchangeable container. Anything that satisfies this contract is a valid
gateway.

## 1. Compatibility

The gateway speaks the **OpenAI API**. That is the whole contract: any client written for OpenAI
works against it unchanged, and any gateway that speaks OpenAI is a drop-in replacement.

## 2. Inputs

| | Value |
|---|---|
| Reachable as, from other containers | `http://gateway:3001/v1` |
| Published on the host | `127.0.0.1:3001` — local only |
| API key | `HYDRA_API_KEY` (the agent's `Authorization: Bearer ${HYDRA_API_KEY}`) |
| Configuration | `configs/gateway/` (read-only) |
| Persistent data | `~/hydr4-data/gateway/` → `/app/server/data` |
| Egress proxy | `UPSTREAM_PROXY` from the root `.env`, mapped to `HTTP_PROXY`/`HTTPS_PROXY` |

The service name is `gateway` and the container name is `hydr4-gateway`. Clients inside Docker use
the service name (`gateway`); the host reaches the same container through Traefik at
`http://api.localhost`.

## 3. Outputs

| | Requirement |
|---|---|
| API | OpenAI-compatible: `POST /v1/chat/completions`, `GET /v1/models` |
| Protocol | HTTP |
| Port | Answers on `0.0.0.0:3001` |
| Streaming | `stream: true` returns SSE |
| Tools | `tools` are passed upstream, `tool_calls` come back |
| Errors | Standard OpenAI error object |

That is the whole contract. Provider routing, fallbacks, retry policy, and storage format are the
gateway's business. The agent only sees the OpenAI API.

## 4. Host access is a debug fallback

The gateway is served to the host by Traefik (`http://api.localhost` → `hydr4-gateway:3001` on
`traefik-net`). That is the supported path.

`compose/gateway.yaml` also publishes the port on the host as `127.0.0.1:3001:3001`. This loopback
binding is a **debug fallback only**, used by the check scripts and for reaching the gateway by hand
when Traefik is down or misconfigured. It is not part of the contract and no client may depend on it.

It is expected to be removed together with the agent port, once container-to-container access
through Traefik is the only supported path. See `docs/ROADMAP.md` (last item, lowest priority).
