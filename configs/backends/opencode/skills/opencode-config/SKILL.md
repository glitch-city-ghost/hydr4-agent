---
name: OpenCode configuration
description: Use when editing this agent's OpenCode config, providers, models, agents, permissions, commands, instructions, or skills. Explains the V2 shape and the gateway-specific constraints.
---

# OpenCode configuration

The live config is `/configs/backends/opencode/config.json`, mounted read-only
from this repository. Edit `configs/backends/opencode/config.json` in the repo;
never edit `/configs` directly.

## V2 rules that matter here

- Use `providers` at the root. A provider has `package`, `settings`, `models`,
  and optional `compatibility`.
- A model key is the ID exposed to OpenCode. Use `modelID` only when the ID sent
  upstream differs.
- Use `permissions` (array of `{action, resource, effect}`), not V1 `permission`.
  The last matching rule wins; broad rules first, exceptions last.
- Use `agents`, not V1 per-agent `tools`/`maxSteps`. Useful V2 fields:
  `mode`, `model`, `system`, `permissions`, `steps`, `description`, `hidden`.
- Use `policies` for hard provider/tool denies. Policies never grant access.
- `instructions` accepts paths, globs, and URLs. `skills` accepts directories or
  catalogs.
- Do not put secrets in config. Use `env` plus `{env:VAR}` references.

## Gateway constraints

- Only one provider is active: `hydr4`, an OpenAI-compatible provider at
  `http://gateway:3001/v1` using `HYDRA_API_KEY`.
- Do not export `OPENAI_API_KEY` or `DEEPSEEK_API_KEY` in the backend script:
  they activate built-in providers and expose models the gateway cannot serve.
- Do not invent model IDs. Check the gateway:

```sh
curl -sS -H "Authorization: Bearer $HYDRA_API_KEY" \
  http://gateway:3001/v1/models
```

- Only models with `"available": true` are currently usable. `auto` and `fusion`
  are gateway router aliases and may change their upstream model.
- `deepseek-flash` supports reasoning variants. The generated effort variants
  are `#low`, `#medium`, and `#high`; `#none` is not available.

## Validation and reload

```sh
python3 -m json.tool configs/backends/opencode/config.json
```

- OpenCode normally reloads config automatically. In the TUI, `/reload` forces
  it. Existing sessions keep their selected model; start a new session to pick
  up `model` or `default_agent`.
- Config errors appear in the server log. Do not assume a config was accepted
  just because the file is valid JSON.
- If you add an absolute path such as `/configs/...`, verify it exists inside the
  container; the host repo path is not visible there.

## Safety

- Keep `reviewer`, `verifier`, and `oracle` read-only.
- Keep `.env`/SSH reads denied and external directories gated.
- Do not weaken a deny rule to make a task pass. Explain the conflict instead.
