# OpenCode profile

This directory contains the OpenCode V2 configuration for the Hydra agent. The
container selects it with `OPENCODE_CONFIG=/configs/backends/opencode/config.json`.

## Design

- **One provider.** `hydr4` is an OpenAI-compatible provider pointing at
  `http://gateway:3001/v1`. `policies` denies every other provider, so the model
  picker cannot offer catalog models the gateway does not serve.
- **No direct provider keys.** The backend script no longer exports
  `OPENAI_API_KEY` or `DEEPSEEK_API_KEY`. Those variables activate built-in
  providers and add unusable models. Only `HYDRA_API_KEY` reaches OpenCode.
- **Role-based models.** Build and plan use DeepSeek Flash; review uses a
  different model family; verification uses a fast low-effort variant; the
  oracle uses the gateway's Fusion panel.
- **Read-only specialists.** `reviewer`, `verifier`, and `oracle` cannot edit
  files. `build` is the only agent expected to change the workspace.
- **Instructions and skills live with the config.** `AGENTS.md` here is loaded
  globally. Project-specific rules live in the repository root `AGENTS.md`, and
  the project skill lives in `.opencode/skills/`.

## Models

| Role / agent | Model | Notes |
|---|---|---|
| default, `build` | `hydr4/deepseek-flash#high` | Fast, 1M context, tools, reasoning |
| `plan` | `hydr4/deepseek-flash#high` | Same reliable model, but planning-only |
| `explore` | `hydr4/deepseek-flash#low` | Search does not need deep reasoning |
| `general` | `hydr4/deepseek-flash#medium` | Balanced subagent |
| `reviewer` | `hydr4/nemotron-3-ultra-550b` | Different model family; read-only |
| `verifier` | `hydr4/deepseek-flash#low` | Cheap checks and exact evidence |
| `oracle` | `hydr4/fusion` | Panel + judge; slower, use for high-value decisions |
| `compaction`, `title`, `summary` | `hydr4/deepseek-flash#low` | Maintenance work |
| manual fallback | `hydr4/auto` | Gateway picks a ready model; routing can change |

Reasoning variants generated for DeepSeek Flash are `#low`, `#medium`, and
`#high`. `#none` is not available. The gateway aliases `auto` and `fusion` can
change their upstream model, so do not build a critical workflow on their exact
behaviour.

## Agents and commands

- `build` — default implementation agent.
- `plan` — read-only planning, with shell mostly ask-gated.
- `reviewer` — read-only review; `/review` and `/review-fast`.
- `verifier` — runs focused checks; `/verify`.
- `oracle` — independent second opinion; `/oracle`.
- `/handoff` — compact summary for continuing later.

Subagents are limited to `explore`, `reviewer`, `verifier`, and `oracle`.
`subagent_depth` is 2, but the read-only specialists deny nested subagents; the
setting only leaves room for a primary agent to use one layer of delegation.

## Permissions

- Normal reads, edits inside the workspace, and ordinary shell commands are
  allowed; the dangerous cases ask or deny.
- `.env` reads/edits are denied; `.env.example` is allowed.
- SSH material is denied. `/configs` is ask-to-read and deny-to-edit.
- `git push`, hard reset, clean, and recursive delete ask; force-push, `sudo`,
  `systemctl`, and `chmod 777` are denied.
- Access outside the workspace asks, except `/tmp/opencode`.
- The three specialist agents are read-only by construction.

## Changing the configuration

1. Check the gateway inventory, not the models.dev catalog:

   ```sh
   curl -sS -H "Authorization: Bearer $HYDRA_API_KEY" \
     http://gateway:3001/v1/models
   ```

2. Edit `config.json` only for IDs with `"available": true`.
3. Validate:

   ```sh
   python3 -m json.tool configs/backends/opencode/config.json
   ```

4. On the host, let the bind mount pick up the change (OpenCode reloads config
   automatically) or use `/reload` in the TUI. If the file is replaced, restart
   the agent container.
5. Existing sessions keep their selected model. Start a new session to pick up
   `model` or `default_agent`.

## Deployment note

In the running agent, `/configs` is a read-only mount of the **host deployment
checkout**, not necessarily this `/workspace` clone. Merge/pull the change into
that checkout before expecting the live agent to change. `./hydra restart`
recreates the containers and picks up `configs/` without rebuilding the image.
