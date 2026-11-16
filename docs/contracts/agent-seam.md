# Agent Seam Contract

**Version:** 1.0  
**Status:** Active  
**Scope:** Defines the boundary between the container infrastructure and any AI agent backend (OpenCode, DSH, Aider, etc.).

## 1. Purpose

This document defines the explicit contract for running an AI agent inside the `hydr4-agent` container. The goal is to make the agent backend **swappable**. Swapping the agent (e.g., from OpenCode to DSH) must not require editing the `Dockerfile`, `entrypoint.sh`, or `docker-compose.yml`. It should only require changing an environment variable and providing the respective configuration folder.

## 2. The Seam

The container image is built with a generic entrypoint. It does not know *which* agent it is running. The entrypoint evaluates the environment variable `AGENT_BACKEND` and executes the corresponding shell script.

**Invocation:**
The container will execute exactly this path:
```bash
/agent/backends/${AGENT_BACKEND}.sh
```

**Directory Structure:**
The `Dockerfile` guarantees the existence of the `/agent/backends/` directory.
- For OpenCode: `/agent/backends/opencode.sh`
- For DSH: `/agent/backends/dsh.sh`

## 3. Environment Contract (Inputs)

The container guarantees that the following environment variables are available to the backend script. The backend *must* use these variables to connect to the model gateway.

| Variable | Required | Description |
|---|---|---|
| `AGENT_BACKEND` | Yes | Selects the script to run (e.g., `opencode`, `dsh`). |
| `OPENAI_BASE_URL` | Yes | The base URL of the model gateway (e.g., `http://aggregator:3001/v1`). |
| `HYDRA_API_KEY` | Yes | The bearer token to authenticate with the model gateway. |
| `GIT_CONFIG_GLOBAL` | Yes | Path to the isolated git config file (e.g., `/home/agent/.config/.gitconfig`). |

*(Note: The backend may map `HYDRA_API_KEY` to standard variables like `OPENAI_API_KEY` internally, but the container guarantees `HYDRA_API_KEY`).*

The entrypoint configures Git for SSH authentication: it sets `GIT_SSH_COMMAND` to use `/home/agent/.ssh/id_ed25519`, sets `GIT_TERMINAL_PROMPT=0`, removes any legacy `credential.helper`, and adds `/workspace` as a safe Git directory.

## 4. Filesystem Contract (Mounts)

The backend must expect the following directories to be mounted and writable/readable:

| Path | Access | Purpose |
|---|---|---|
| `/workspace` | Read/Write | The code repository the agent is working on. |
| `/configs/backends/${AGENT_BACKEND}/` | Read-Only | Backend-specific configuration files (e.g., OpenCode's `config.json`). |
| `/configs/agent/` | Read-Only | Generic agent configuration (shared across all backends). |
| `/home/agent/.ssh/` | Read-Only | Dedicated bot SSH key (`id_ed25519`), `known_hosts`, and optional SSH config for Git access. |

## 5. Rules for Backend Scripts (`${AGENT_BACKEND}.sh`)

Any script placed in `/agent/backends/` must adhere to the following rules:

1. **Do not daemonize.** Use `exec` to replace the shell process. The container's lifecycle is tied to this process.
2. **Do not hardcode ports or URLs.** Read them from the environment variables defined above.
3. **Do not write to global system configs.** Respect `GIT_CONFIG_GLOBAL`. All agent-specific configuration must be loaded from `/configs/backends/${AGENT_BACKEND}/`.
4. **Exit with the agent's exit code.** If the agent crashes, the script must exit with a non-zero code so the container runtime can restart it (or fail).

## 6. Example (OpenCode)

If `AGENT_BACKEND=opencode`, the container executes `/agent/backends/opencode.sh`. The content of this script is:

```bash
#!/bin/bash
set -e

# Point OpenCode to the mounted config
export OPENCODE_CONFIG=/configs/backends/opencode/config.json

# Map the gateway key to what OpenCode expects (if necessary)
export OPENAI_API_KEY="${HYDRA_API_KEY}"

# Start the server
exec opencode serve --hostname 0.0.0.0 --port 4096
```

## 7. Compliance

To verify that a new backend adheres to this contract, run the `hydra status` command. The container logs must show successful connection to `OPENAI_BASE_URL` and successful loading of configuration from `/configs/backends/${AGENT_BACKEND}/`. If the backend fails to start, the container must exit with a non-zero status.