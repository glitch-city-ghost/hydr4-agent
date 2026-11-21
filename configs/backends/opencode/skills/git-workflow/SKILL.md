---
name: Git Workflow
description: Use when preparing a branch, staging changes, writing commits, pushing a topic branch, or opening a pull request for this repository. Main is protected; the human owns review and merge.
---

# Git Workflow

## The model

`main` is protected on GitHub. The agent works on `agent/<topic>`, may commit
and push that topic branch, and may open a pull request when the user asks.

The agent never merges, closes, or approves a pull request. It never force-pushes,
deletes a remote branch, pushes tags, or pushes `main`/`master`.

Branch protection is the final gate. These rules keep the agent from relying on it.

A completed Build task **delivers by default**: it commits the verified change
and pushes the topic branch, then reports the PR or compare URL. "Local only",
"do not commit", or "do not push" means stop before that step. Plan never commits
or pushes.

## Branch

- `main` is the integration branch. Never commit directly to it.
- If the current branch is `main` or `master`, create a branch before the first
  tracked-file edit:

  ```bash
  git switch -c agent/<short-topic>
  ```

- If the current branch is already a topic branch, stay on it. Do not stack a
  second branch unless the user asks.
- Naming:
  - `agent/opencode-config`
  - `agent/gateway-timeout`
  - `agent/fix-healthcheck`
  - `agent/docs-contracts`
- One topic per branch. If a second, unrelated change appears, stop and ask
  whether it belongs here or in its own branch.

## Before staging

Run all three, in this order:

```bash
git status --short --branch
git diff --stat
git diff
```

Read the diff, not just the stat. Check for:

- debug prints, `console.log`, `print()`, `pdb`, `breakpoint()`;
- temporary files, backups (`*.bak`, `*.orig`, `*.rej`), editor droppings;
- commented-out code and `TODO` placeholders without an issue;
- secrets, tokens, private keys, `.env` content, database files;
- unrelated formatting or renamed symbols;
- generated files that should not be committed.

Stage files explicitly:

```bash
git add path/to/file path/to/test
```

Do not use `git add -A` or `git add .` when the working tree contains work you
did not make. If the user's uncommitted changes overlap yours, stop and ask.

## Commit message

Use Conventional Commits:

```text
<type>(<scope>): <subject>

Why this change is needed. What behavior changes. Anything a reviewer cannot
infer from the diff (trade-off, migration, follow-up, risk).
```

- Types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `build`, `ci`,
  `perf`, `style`.
- Scope is optional; use the area (`opencode`, `gateway`, `compose`, `docs`).
- Subject: imperative mood, lower-case, no trailing period, <= 72 characters.
- Body: explain **why**, not a file list. Wrap at 72 columns.
- One logical change per commit. Do not mix a refactor with a behavior change.
- Never add a `Co-Authored-By` or generated-by trailer unless the user asks.

Examples:

```text
feat(opencode): add production-ready build and plan agents

Replace the default prompt with role-specific instructions for a single-worker
setup. The plan agent is read-only and the build agent owns implementation and
verification.

fix(gateway): accept JSON model list in check script

The gateway returns an OpenAI object, not a bare array. Match both shapes so
`hydra check` does not report a false failure.
```

## Diff review

Before committing, read the full diff once:

```bash
git diff --check      # whitespace errors
git diff              # unstaged
git diff --cached     # staged
```

`git diff --check` must be clean. Re-read the staged diff, not the unstaged one;
staging is where mistakes happen.

## Push

Push only when the user asks (explicitly, or via `/commit`). Push only the
current `agent/<topic>` branch:

```bash
git status --short --branch
git push -u origin HEAD
```

Rules:

- Current branch must be `agent/*` and must not be `main`/`master`. Do not push
  from a detached HEAD.
- Use `HEAD` or the exact branch name. Do not push a different branch by accident.
- Never `--force`, `-f`, `--force-with-lease`, or a `+ref` refspec.
- Never `--delete` or `:branch`.
- Never `--tags`, `--all`, `--mirror`, or `--prune`.
- Never `git push origin main` / `master`, and never `HEAD:main` / `HEAD:master`.
- If the push is rejected because the remote moved, stop and report it. Do not
  force. Fetch and inspect if the user asks; integrate in a separate, explicit
  step.
- If auth or SSH fails, report the exact error. Do not switch to a PAT, paste a
  key, or disable host verification.
- If `origin` is an HTTPS GitHub URL and there is no credential helper, switch
  it to the equivalent SSH URL once rather than inventing a token:
  `git remote set-url origin git@github.com:<owner>/<repo>.git`.
  The bot key and `~/.ssh/config` are mounted read-only for this path.

After a successful push, report `origin/<branch>` and the commit hash.

## Pull request

Open a PR only when the user asks. Use the GitHub CLI if it is installed and
authenticated:

```bash
gh --version
gh auth status
gh pr create --base main --head <branch> --title "<title>" --body-file /tmp/pr.md
```

If `gh` is unavailable or unauthenticated, push the branch and print the compare
URL instead:

```text
https://github.com/<owner>/<repo>/compare/main...<branch>?expand=1
```

Rules:

- Never `gh pr merge`, `gh pr close`, `gh pr review`, or `gh api`.
- Never approve your own PR.
- Draft is fine while work is in progress.
- Report the PR URL, title, body, and the checks that ran.
- The human owns review and merge.

## PR body

```text
Title: <type>(<scope>): <subject>

## What
<1-3 bullets describing the change>

## Why
<the problem, the constraint, or the incident>

## How
<the approach and the main files>

## Verification
- <command> -> <result>
- <manual check> -> <result>

## Risk / rollback
- Risk: <what could break>
- Rollback: <revert this PR / restore previous config / no data migration>

## Notes
<follow-ups, open questions, screenshots, contract links>
```

## History rules

- Do not rebase, amend, or force-push a branch that exists on the remote.
- `git commit --amend` is allowed only for your own commit that has never been
  pushed, and only when the user asks.
- Do not use `git reset --hard` or `git clean -fdx` to discard user work. If a
  reset is needed, use `git reset` (mixed) and explain what remains.
- Do not rewrite `main`.
- Prefer `git revert` over history surgery for a bad commit that is already
  shared.

## Conflicts and dirty trees

- A conflict is resolved by understanding both sides, not by choosing "ours"
  or "theirs" blindly. If intent is unclear, stop and ask.
- Do not stash the user's work without asking.
- Do not reset a dirty tree to make a test pass.
- If a pre-commit hook fails, fix the cause. Do not bypass it with
  `--no-verify`.
- If the branch is behind and the user asks to update it, prefer a merge from
  the integration branch unless the repository explicitly uses rebase. Never
  force-push.

## Handoff

```text
Branch:  agent/<topic>
Commit:  <sha> <subject>
Push:    done origin/agent/<topic> | not requested | failed <error>
PR:      <url> | not created (compare URL: <url>) | not requested
Checks:  <commands and results>
Next:    human review and merge
```
