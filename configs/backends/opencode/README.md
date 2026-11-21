# OpenCode Backend

Production-oriented, **single-agent** OpenCode configuration for the
`hydr4-agent` stack.

There is one worker, not a swarm. It has two modes:

| Mode | Purpose | Can edit? | Can push? |
|---|---|---|---|
| **Build** (`build`) | Implement, test, review, report. | Yes, in `/workspace`. | Yes, `agent/*` only. |
| **Plan** (`plan`) | Investigate, design, review, security-check. | No project files. Only `~/.opencode/plan/*`. | **No.** |

The built-in `general` and `explore` subagents are **disabled**, and the
`subagent` permission is denied. No child sessions, no background agents.
OpenCode still uses its hidden `compaction`, `title`, and `summary` maintenance
routines; they are not selectable workers and are not a sub-agent workflow.

## Layout

```text
configs/backends/opencode/
├── config.json              # the only OpenCode document
├── AGENTS.md                # global engineering instructions
├── README.md                # this file
├── prompts/
│   ├── build.md             # Build agent system prompt
│   └── plan.md              # Plan agent system prompt
├── commands/                # slash-command templates
│   ├── plan.md
│   ├── implement.md
│   ├── review.md
│   ├── test.md
│   ├── debug.md
│   ├── security.md
│   ├── commit.md
│   └── pr.md
└── skills/                  # discoverable via the skills array
    ├── hydr4-stack/SKILL.md
    ├── git-workflow/SKILL.md
    ├── code-review/SKILL.md
    ├── systematic-debugging/SKILL.md
    ├── testing/SKILL.md
    ├── security-review/SKILL.md
    └── refactoring/SKILL.md
```

`config.json` references prompts and command templates with **relative**
`{file:./prompts/...}` paths, so it works both from this repository and from
the read-only `/configs` mount. The `instructions` and `skills` arrays use the
container path `/configs/...`, which is the deployed copy.

## How it is loaded

The agent image exports:

```text
OPENCODE_CONFIG=/configs/backends/opencode/config.json
```

and mounts the repository's `configs/` directory read-only at `/configs`
(see `compose/agents.yaml`). OpenCode therefore reads this document and the
files it references from the deployed checkout.

When you develop inside the workspace clone, the repository copy is at
`/workspace/hydr4-agent/configs/backends/opencode/`. Editing it here does **not**
change the running server until the host checkout at `/configs` is updated
(pull/merge) and the container is restarted. That is intentional: the runtime
configuration is a deployment artifact, not a mutable live file.

## Models

The default model stays `deepseek/deepseek-flash`, routed through the local
gateway. Keeping the existing provider ID preserves the currently selected
session model.

| Reference | Model | Notes |
|---|---|---|
| `deepseek/deepseek-flash` | DeepSeek V4.1 Flash | Default. 1M context, tools. |
| `hydr4/nemotron-3-ultra-550b` | NVIDIA Nemotron 3 Ultra 550B | 1M context, tools. |
| `hydr4/auto` | Gateway router | Picks an available model. Use when a provider is down. |

Switch with `/models` or `/model`. The gateway stays at
`http://gateway:3001/v1`, authenticated with `HYDRA_API_KEY`. Provider keys are
never exposed to the agent.

## Permissions

The policy is **guardrails, not a jail**: prompts and container isolation are
the primary controls, permission rules catch accidents.

- Build may push only its `agent/*` topic branch. `main`/`master`, force-push,
  branch deletion, tags, `--all`, `--mirror`, and `--prune` are denied. Plan
  cannot push at all.
- Build may open a pull request with `gh pr create` when the user asks. Merge,
  close, approve, release, and `gh api` mutations are denied; the human owns
  review and merge.
- No `sudo`, `docker`, `podman`, `systemctl`, `mount`, `dd`, `mkfs`, `shutdown`,
  `reboot`, `pkill`, `killall`, package publishing, or remote-shell tools.
- Destructive `rm -rf` targets (`/`, `/workspace`, `/configs`, `$HOME`, `.git`)
  are denied; `git reset --hard`, `git clean -f`, `git restore`,
  `git checkout --`, and `git rebase` ask first.
- `.env*` (except `.env.example` and the public `freellmapi.env`),
  `~/.ssh/**`, `secrets/**`, `service.json`, OpenCode databases, credentials,
  and `/proc/*/environ` are not readable through the file tools.
- Common shell readers of those paths (`cat`, `head`, `tail`, `rg`, `grep`,
  `sed`, `awk`, `base64`, `git show`, `git diff`, `git log`, `git grep`, ...)
  are denied, including their search flags (`--no-ignore`, `--hidden`, `-u`).
- Editing `.git/**`, `/configs/**`, `~/.config/opencode/**`,
  `~/.local/share/opencode/**`, `secrets/**`, keys, and `service.json` is
  denied.
- The Plan agent has a hard `shell * deny` with a small read-only Git allowlist.
  It cannot install, commit, move, delete, or fetch.

These are best-effort guards. They do not replace the prompt rules, the
read-only mounts, or the missing Docker socket.

**Never paste the output of `opencode api get /api/config` or other server
internals into an issue or a chat.** That endpoint can resolve `{env:...}`
values into real secrets. `opencode debug config` masks provider `apiKey`
fields as `***`, but still review any output before sharing it.

## Commands

All commands run in the **current session** (`subagent: false`).

| Command | Agent | What it does |
|---|---|---|
| `/plan <task>` | plan | Read-only plan: goal, state, options, steps, verification, risks, handoff. |
| `/implement <task>` | build | Implement end to end, verify, report. No commit or push by default. |
| `/review [target]` | plan | Severity-ranked review of the diff/commit. Read-only. |
| `/test [scope]` | build | Run the narrowest then broadest checks; report evidence. |
| `/debug <failure>` | build | Reproduce, isolate, root-cause, fix, regression-test. |
| `/security [target]` | plan | Threat model and security findings. Read-only. |
| `/commit [hint]` | build | Branch if needed, stage explicit paths, Conventional Commit, push the topic branch. Never main, never force. |
| `/pr [context]` | build | Push the topic branch if needed; open a PR with `gh` or print the compare URL. Never merge or close. |

## Skills

Skills are loaded on demand via the `skill` tool; they are not all injected into
every prompt.

| Skill | Load it when |
|---|---|
| `hydr4-stack` | Operating, debugging, or changing this Compose stack. |
| `git-workflow` | Branching, staging, committing, or drafting a PR. |
| `code-review` | Reviewing a diff or PR. |
| `systematic-debugging` | A failure needs a root cause and a regression test. |
| `testing` | Choosing, writing, or running tests. |
| `security-review` | Checking secrets, injection, authorization, supply chain, container boundary. |
| `refactoring` | Restructuring code without changing behavior. |

Skill IDs are the directory names, not the display `name` in frontmatter.

## Git policy

- `main`/`master` is protected. Never commit or push directly to it.
- The Build agent creates `agent/<short-topic>` when it starts from main.
- Build delivers by default: after a verified code change it creates a topic
  branch, commits, and pushes it, then reports the PR or compare URL.
- Say local-only / do not push to keep the change local. Use Conventional Commits.
- Build may push only its topic branch, with `git push -u origin HEAD`.
- Build may open a PR with `gh pr create` when the user asks. If `gh` is
  unavailable or unauthenticated, it reports the GitHub compare URL instead.
- Force-push, branch deletion, tags, `--all`, `--mirror`, and `--prune` are denied.
- **Never merge, close, or approve a PR.** The human owns review and merge.

Push uses the bot SSH key mounted read-only at `/home/agent/.ssh`. The image
ships `git`, not necessarily `gh`: if GitHub CLI is absent or unauthenticated,
`/pr` pushes the topic branch and prints the compare URL, and the human opens the
PR from that URL.

This is enforced by the global prompt (`AGENTS.md`), the agent prompts, the
permission rules, and the Git Workflow skill.

## Validate

Inside the container, from the repository root:

```bash
# JSON parses
python3 -m json.tool configs/backends/opencode/config.json >/dev/null

# OpenCode loads the document and expands the prompts
OPENCODE_CONFIG=/configs/backends/opencode/config.json \
  opencode --standalone debug config

OPENCODE_CONFIG=/configs/backends/opencode/config.json \
  opencode --standalone debug agents
```

Expected:

- only `build` and `plan` are visible primary agents (plus hidden
  `compaction`, `title`, `summary`);
- `build.system` starts with `# Build Agent`;
- `plan.system` starts with `# Plan Agent`;
- no `general` or `explore` in the visible agent list.

To validate the workspace copy without waiting for a deployment, write a
temporary config next to this file (so the relative prompt/command paths
resolve), rewrite the absolute `/configs/...` references for `instructions`
and `skills`, and run the private server:

```bash
sed 's#/configs/backends/opencode#/workspace/hydr4-agent/configs/backends/opencode#g' \
  configs/backends/opencode/config.json > configs/backends/opencode/.validate.json
OPENCODE_CONFIG="$PWD/configs/backends/opencode/.validate.json" \
  opencode --standalone debug agents
rm configs/backends/opencode/.validate.json
```

## Customize

- Add a skill: create `skills/<id>/SKILL.md` with `name`, `description`, and
  instructions. The ID is the directory name. Keep supporting files beside it.
- Add a command: create `commands/<name>.md` and register it under `commands` in
  `config.json` with `agent`, `subagent: false`, and
  `template: "{file:./commands/<name>.md}"`.
- Change an agent prompt: edit `prompts/build.md` or `prompts/plan.md`. The config
  references them by relative path; no JSON change needed.
- Do not add a subagent. This configuration is intentionally single-worker. If a
  task is too large, split it into steps with `todowrite` and keep the same
  session.
- Do not move prompts or commands back to inline JSON strings; the file-based
  layout is what makes this reviewable.

## Definition of done for this config

- `config.json` parses as JSON.
- `opencode --standalone debug config` exits 0.
- `opencode --standalone debug agents` lists only Build and Plan as visible
  primaries.
- Both system prompts expand to their Markdown files.
- `general` and `explore` are disabled; `subagent` is denied.
- `git push` to `main`/`master`, force-push, branch deletion, tags, `--all`,
  `--mirror`, and `--prune` are denied; topic-branch push is allowed.
- `gh pr create` is allowed; `gh pr merge`, `gh pr close`, and `gh pr review`
  are denied.
- A plan session cannot edit project files or run a mutating shell command.
