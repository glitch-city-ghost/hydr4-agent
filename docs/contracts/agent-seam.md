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
| SSH key | `~/hydr4-data/secrets/ssh/` | `/home/agent/.ssh/` (read-only) |

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
