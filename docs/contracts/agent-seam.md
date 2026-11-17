# Agent Seam Contract

**Version:** 1.1
**Status:** Active
**Scope:** Defines the boundary between the container infrastructure and any AI agent backend (OpenCode, DSH, Aider, etc.).

## 1. Purpose

This document defines the explicit contract for running an AI agent inside the `hydr4-agent` container. The goal is to make the agent backend **swappable**: swapping the agent (for example from OpenCode to DSH) must not require editing the `Dockerfile` or the entrypoint, only selecting a backend and its configuration folder.

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

## 3. Environment Contract (Inputs)

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

### 3.1 Git configuration done by the entrypoint

Before delegating, the entrypoint prepares Git for the agent:

- sets `GIT_CONFIG_GLOBAL` to `/home/agent/.config/.gitconfig`;
- sets the committer identity (`user.name`/`user.email`), defaulting to `hydr4-agent` unless `GIT_USER_NAME` / `GIT_USER_EMAIL` override it;
- removes any legacy `credential.helper`;
- sets `GIT_TERMINAL_PROMPT=0`, so Git never prompts;
- if `/home/agent/.ssh/id_ed25519` exists, sets `GIT_SSH_COMMAND` to that key with `known_hosts` and strict host-key checking;
- adds `/workspace` to `safe.directory`.

### 3.2 Configuring DSH

The DSH backend script is two lines: export `OPENAI_API_KEY` from `HYDRA_API_KEY`, then `exec dsh web ... 4096`. The agent must still configure DSH to point at the gateway, exactly like the OpenCode example:

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

### 3.3 Minimal rules for backend scripts (`${AGENT_BACKEND}.sh`)

Any script placed in `/agent/backends/` must:

1. **Not daemonize.** Use `exec` for the last command so the container's lifecycle stays tied to the agent process.
2. **Not hardcode the gateway URL.** Read it from `OPENAI_BASE_URL` / `HYDRA_API_KEY` (or map those to whatever the tool expects).
3. **Not write to global system configs.** Respect `GIT_CONFIG_GLOBAL`.
4. **Propagate the exit code.** If the agent crashes, the container must exit non-zero so the runtime can restart it or fail visibly.

## 4. Running a backend

`compose/agents.yaml` declares `profiles: ["dsh", "opencode"]`, so the `agent` service starts only
when one of them is selected on the Compose command line. They are **not** tied to the
`AGENT_BACKEND` value, and nothing in the image reads them.

- The repository wrapper `hydra` always passes `--profile opencode`.
- `AGENT_BACKEND` is passed to the container as an environment variable (`${AGENT_BACKEND:-opencode}`).
  It selects the *script*, not the profile.
- DSH therefore needs both: its profile selected, and `AGENT_BACKEND=dsh`. That is a manual path today:
  `AGENT_BACKEND=dsh docker compose --profile dsh up -d`. `hydra` does not offer it.

## 5. Reference implementation: `opencode.sh`

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

## 6. Compliance

To verify that a new backend adheres to this contract, run:

```bash
./hydra restart
./hydra logs agent
```

A passing backend:

1. prints `Delegating to backend: <name>` in the logs;
2. leaves `hydr4-agent` running and eventually `healthy` in `docker compose ps`;
3. answers `http://127.0.0.1:4096/global/health` (the container healthcheck);
4. is reachable as `http://agent.localhost` once `l3rn4-nix/traefik-dynamic/routes.yaml` points at
   `hydr4-agent:4096`.

If the backend fails to start, the container must exit with a non-zero status.

Note: `./hydra status` only prints container state; it does not inspect logs.
