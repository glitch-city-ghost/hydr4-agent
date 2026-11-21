# hydr4-agent — project instructions

This repository builds the Hydra stack: a Dockerised OpenCode agent behind a
FreeLLMAPI OpenAI-compatible gateway.

## Runtime facts

- The agent container only sees `/workspace` (this repository) and read-only
  `/configs`. The host's Docker socket is not mounted.
- The gateway is `http://gateway:3001/v1` inside Docker. The agent authenticates
  with `HYDRA_API_KEY`; raw provider keys never enter this container.
- The deployed agent config is `configs/backends/opencode/config.json`, mounted
  read-only at `/configs/backends/opencode/config.json`.
- Host-side Docker commands (`./hydra check`, `docker compose ...`) cannot run
  inside this container. Do not claim they ran; ask the user to run them.
- Persistent state lives in `~/hydr4-data` on the host. Never delete or "clean"
  it, and never suggest `docker system prune`.

## Verification inside this container

Run these before claiming a non-trivial change is valid:

```bash
python3 -m json.tool configs/backends/opencode/config.json
bash -n hydra scripts/*.sh docker/universal-agent/*.sh docker/universal-agent/backends/*.sh
git diff --check
git status --short
```

There is no test suite, `docker`, `shellcheck`, `shfmt`, `yamllint`, or `jq`
installed here. Use `bash -n`, Python's JSON parser, and Node/Python for checks.
Do not invent a passing test.

On the host, the authoritative checks are:

```bash
./hydra check      # read-only, no model calls
./hydra status
./hydra logs
```

## Source-of-truth documents

Read before changing the corresponding interface:

- `docs/contracts/agent-seam.md` — agent backend contract.
- `docs/contracts/gateway.md` — OpenAI-compatible gateway contract.
- `docs/contracts/host.md` — host/filesystem/network contract.
- `docs/ARCHITECTURE.md` and `docs/DECISIONS.md` — topology and ADRs.
- `docs/ROADMAP.md` — deliberately deferred work; don't "fix" it casually.
- `WTF_EVERYTHING_BROKE_DOWN_HELP.md` — operational recovery, not a design doc.

## OpenCode configuration rules

- Keep a single custom provider, `hydr4`, pointing at
  `http://gateway:3001/v1`. Do not add direct provider keys or a second
  OpenAI/DeepSeek provider; `policies` intentionally denies all other providers.
- Gateway-ready model IDs: `deepseek-flash`, `nemotron-3-ultra-550b`, `auto`,
  and `fusion`. Do not invent model IDs; verify with `curl /v1/models`.
- `deepseek-flash` is the default/build model. `nemotron-3-ultra-550b` is the
  independent reviewer model. `fusion` is the oracle's panel-and-judge model.
  `auto` is an optional manual fallback because its routing can change.
- Keep `reviewer`, `verifier`, and `oracle` read-only. Do not give them edit,
  commit, or push permissions.
- After changing the config, validate the JSON. Config changes reload without a
  restart, but the model on an existing session does not change; start a new
  session or use `/models`.
- Do not put secrets in tracked files. Use `{env:...}` or `.env.example`.

## Code and change conventions

- Preserve existing shell style: `#!/usr/bin/env bash` or `#!/bin/bash`, strict
  mode where present, quoted variables, and no secrets in command lines.
- Keep gateway/model IDs stable. If an interface changes, update the matching
  contract and ADR rather than only the implementation.
- Keep secrets and host-specific values in the root `.env`; tracked config must
  contain only public settings.
- Use Conventional Commit prefixes (`config:`, `fix:`, `feat:`, `docs:`,
  `refactor:`, `chore:`). Work on a branch; do not push directly to `main`.
- Do not touch `docs/old/` unless the task explicitly asks for historical docs.

## Good default response

For a completed change, report:

1. What changed (paths).
2. Why it is correct.
3. Exact checks run and their result.
4. Anything not verified because it requires the host, Docker, or a provider.
