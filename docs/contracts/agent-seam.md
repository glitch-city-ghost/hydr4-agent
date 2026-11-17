# Agent Seam Contract

**Version:** 1.1
**Status:** Active
**Scope:** Defines the boundary between the container infrastructure and any AI agent backend (OpenCode, DSH, Aider, etc.).

## 1. Purpose

This document defines the explicit contract for running an AI agent inside the `hydr4-agent` container. The goal is to make the agent backend **swappable**: swapping the agent (for example from OpenCode to DSH) must not require editing the `Dockerfile`, the entrypoint, the Compose files, Traefik routes, or the `hydra` wrapper.

The seam is defined in terms of **interfaces**, not implementations:

- an **environment interface** (which variables the container provides);
- a **filesystem interface** (which paths are mounted, and how);
- a **network interface** (which container name, which port, which health endpoint).

Any agent that satisfies these three interfaces is a valid backend, regardless of its log format, process model, CLI flags, or configuration format.

## 2. The Seam

The image is built once and is backend-agnostic. Its entrypoint (`/home/agent/entrypoint.sh`) prepares Git, checks that `AGENT_BACKEND` is set, and then hands over to the matching script with `exec`:

```bash
/agent/backends/${AGENT_BACKEND}.sh
```

A backend is therefore a **shell script** that ends in a server process (no daemonizing), plus the config that script loads.

### 2.1 Input mapping

| Backend | Script in the image | Script in the repo | Config it loads |
|---|---|---|---|
| `opencode` | `/agent/backends/opencode.sh` | `docker/universal-agent/backends/opencode.sh` | `/configs/backends/opencode/config.json` |
| `dsh` | `/agent/backends/dsh.sh` | `docker/universal-agent/backends/dsh.sh` | none in the repo (see note) |

- `/agent/backends/` is copied by the `Dockerfile`; the repo is the source of truth.
- `/configs/` is `../configs` from the repository root, bind-mounted read-only by `compose/agents.yaml`.
- The Compose file also carries `OPENCODE_CONFIG`. That variable is *OpenCode-specific*: it is a
  single file path, not a backend-directory contract you can rely on. A backend reads whatever
  its own script points at.

Note on DSH: the backend script exists, but DSH's own settings file is not mounted or wired into
the container today. There is no `/configs/backends/${AGENT_BACKEND}/` lookup in the code — any
backend directory is only useful if its script is told to load it.

## 3. The Network Interface

This is the part of the contract that other components depend on. It is fixed, and every backend
must satisfy it, whatever agent runs inside. Two things are standardised:

- **the port** — any agent backend serves on `4096`;
- **the health endpoint** — any agent backend answers `GET /global/health`.

| Property | Value | Consumed by |
|---|---|---|
| Container name | `hydr4-agent` | Traefik routes in `l3rn4-nix` |
| Listening interface inside the container | `0.0.0.0` | Docker port publishing |
| Container port | `4096` | Docker port publishing, the healthcheck |
| Host binding | `127.0.0.1:4096` | local use only, not exposed to the LAN |
| Health endpoint | `GET /global/health` | the Compose healthcheck |

The agent server must bind `0.0.0.0` and not `127.0.0.1`. Binding loopback inside the container
makes the published port unreachable, and the container will never report `healthy`.

The port may change only if the Compose file and the host's `routes.yaml` change together:
`compose/agents.yaml` publishes `4096` and `l3rn4-nix/traefik-dynamic/routes.yaml` routes
`hydr4-agent:4096`. A backend may not choose its own port.

## 4. The Environment Interface

`compose/agents.yaml` sets the following variables for every backend:

| Variable | Source | Required | Description |
|---|---|---|---|
| `AGENT_BACKEND` | `.env` | Yes | Selects the script to run (e.g., `opencode`, `dsh`). |
| `OPENAI_BASE_URL` | compose | Yes | The base URL of the model gateway (e.g., `http://gateway:3001/v1`). |
| `HYDRA_API_KEY` | compose | Yes | The bearer token to authenticate with the model gateway. |
| `OPENCODE_PASSWORD` | `.env` | Only for `opencode` | Password for the OpenCode Web UI. |
| `OPENCODE_CONFIG` | compose | Only for `opencode` | Path to OpenCode's config file. |
| `GIT_CONFIG_GLOBAL` | compose | Yes | Path to the isolated git config file (e.g., `/home/agent/.config/.gitconfig`). |

*(Note: the backend may map `HYDRA_API_KEY` to standard variables like `OPENAI_API_KEY` internally, but the container guarantees `HYDRA_API_KEY`).*

### 4.1 Git configuration done by the entrypoint

Before delegating, the entrypoint prepares Git for the agent:

- sets `GIT_CONFIG_GLOBAL` to `/home/agent/.config/.gitconfig`;
- sets the committer identity (`user.name`/`user.email`), defaulting to `hydr4-agent` unless `GIT_USER_NAME` / `GIT_USER_EMAIL` override it;
- removes any legacy `credential.helper`;
- sets `GIT_TERMINAL_PROMPT=0`, so Git never prompts;
- if `/home/agent/.ssh/id_ed25519` exists, sets `GIT_SSH_COMMAND` to that key with `known_hosts` and strict host-key checking;
- adds `/workspace` to `safe.directory`.

### 4.2 Configuring DSH

The DSH backend script is two lines: export `OPENAI_API_KEY` from `HYDRA_API_KEY`, then `exec dsh web --port 4096`. The agent must still configure DSH to point at the gateway, exactly like the OpenCode example:

```yaml
llm-pi-ai:
  providers:
    hydra:
      api: openai-completions
      baseURL: http://gateway:3001/v1
      apiKeyEnv: OPENAI_API_KEY
```

`apiKeyEnv` names the environment variable that holds the key, so the backend must export it
before `dsh` starts. The file is not mounted yet; this block is the reference to copy when it is.

## 5. Rules for Backend Scripts (`${AGENT_BACKEND}.sh`)

Any script placed in `/agent/backends/` must:

1. **Not daemonize.** Use `exec` for the last command so the container's lifecycle stays tied to the agent process.
2. **Bind the standard port.** Serve on `0.0.0.0:4096` and expose `GET /global/health`. Do not pick another port.
3. **Not hardcode the gateway URL.** Read it from `OPENAI_BASE_URL` / `HYDRA_API_KEY` (or map those to whatever the tool expects).
4. **Not write to global system configs.** Respect `GIT_CONFIG_GLOBAL`.
5. **Propagate the exit code.** If the agent crashes, the container must exit non-zero so the runtime can restart it or fail visibly.

## 6. Running a backend

`compose/agents.yaml` declares `profiles: ["dsh", "opencode"]`, so the `agent` service starts only
when one of them is selected on the Compose command line. They are **not** tied to the
`AGENT_BACKEND` value, and nothing in the image reads them.

- The repository wrapper `hydra` always passes `--profile opencode`.
- `AGENT_BACKEND` is passed to the container as an environment variable (`${AGENT_BACKEND:-opencode}`).
  It selects the *script*, not the profile.
- DSH therefore needs both: its profile selected, and `AGENT_BACKEND=dsh`. That is a manual path today:
  `AGENT_BACKEND=dsh docker compose --profile dsh up -d`. `hydra` does not offer it.

## 7. Reference implementation: `opencode.sh`

The repository script, for reference:

```bash
#!/bin/bash
export OPENCODE_CONFIG=/configs/backends/opencode/config.json
export OPENAI_API_KEY="${HYDRA_API_KEY}"
# The built-in DeepSeek provider activates from DEEPSEEK_API_KEY.
# Route it through the gateway just like the other OpenAI-compatible providers.
export DEEPSEEK_API_KEY="${HYDRA_API_KEY}"
echo "🚀 Starting OpenCode Web Server..."
exec opencode serve --hostname 0.0.0.0 --port 4096
```

## 8. Compliance

A backend is compliant if the following holds, regardless of which agent binary is inside it:

1. its script lives at `/agent/backends/${AGENT_BACKEND}.sh` in the image;
2. that script ends with `exec <agent>` and the agent process becomes PID 1 of the container;
3. the agent listens on `0.0.0.0:4096` and answers `GET /global/health` on that port;
4. the process exits non-zero when the agent exits non-zero.

The contract says nothing about log contents. `docker compose ps`, the container healthcheck and
Traefik all operate on the network facts above; a log line is not an interface.
