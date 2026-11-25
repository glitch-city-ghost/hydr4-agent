# Agent Seam Contract

**Version:** 2.0
**Status:** Active
**Scope:** The interface every agent backend must implement.

The agent is an interchangeable container. Anything that satisfies this contract is a valid backend.

## 1. Inputs

| | In the repo | In the container |
|---|---|---|
| Backend scripts | `docker/universal-agent/backends/` | `/agent/backends/` |
| Backend configs | `configs/backends/` | `/configs/backends/` |
| Workspace | sibling `workspace/` | `/workspace` (read/write) |

Credential mounts are not part of this contract. The operator supplies whatever the chosen workflow
needs — an SSH key, a GitHub token, both, or nothing — as read-only mounts or environment. A backend
must not assume a particular Git provider, account model, remote layout, or permission set.

| Environment variable | Meaning |
|---|---|
| `AGENT_BACKEND` | Which backend to run: `<name>` selects `/agent/backends/<name>.sh`. |
| `OPENAI_BASE_URL` | The model gateway, OpenAI-compatible: `http://gateway:3001/v1` |
| `HYDRA_API_KEY` | Bearer token for that gateway. |

## 2. Outputs

| | Requirement |
|---|---|
| Port | Serve on `0.0.0.0:4096` |
| Health endpoint | `GET /global/health` answers 2xx |
| Protocol | HTTP |
| Lifecycle | `exec` the agent into PID 1; do not daemonize |
| Exit code | The container exits with the agent's exit code |

That is the whole contract. Configuration format, CLI flags, and log output are the backend's
business. Other containers reach the agent as `hydr4-agent:4096` on `traefik-net` and
`hydr4-agent-net`.

## 3. Host access is a debug fallback

The agent is served to the host by Traefik (`http://agent.localhost` → `hydr4-agent:4096` on
`traefik-net`). That is the supported path.

`compose/agents.yaml` also publishes the port on the host:

```yaml
ports:
  - "127.0.0.1:4096:4096"
```

This loopback binding is a **debug fallback only**. It exists so that the stack can be reached
directly at `http://127.0.0.1:4096` when Traefik is down, misconfigured, or not started, and it is
used by the check scripts. It is not part of the contract, it is not exposed to the network, and
no backend may depend on it.

It is expected to be removed once container-to-container access through Traefik is the only
supported path. See `docs/ROADMAP.md` (last item, lowest priority).
