---
name: GitHub Pull Requests
description: Create or update a GitHub pull request with gh after the work is committed. Use when asked for a PR, a PR description, CI status, or review feedback.
---

# Rules

- Never merge, approve, close, reopen, or force-push a PR. The human owns merge.
- Never touch a PR that does not belong to this branch.
- Never run `gh api`, `gh auth token`, `env`, or `printenv`; never print a token.
- Never invent verification, issue numbers, screenshots, or CI results.
- No AI/agent attribution. No reviewers, labels, assignees, or milestones unless asked.
- Stop and report if the worktree is dirty, you are on the base branch, or the diff mixes unrelated topics.
- On a permission/auth error, or the same failure twice, stop and report it. Do not look for a workaround.

# Workflow

## 1. Preflight

```bash
gh auth status
git status --porcelain --untracked-files=no
git remote get-url origin
REPO="$(gh repo view --json nameWithOwner --jq .nameWithOwner)"
BASE="$(gh repo view --json defaultBranchRef --jq .defaultBranchRef.name)"
BRANCH="$(git branch --show-current)"
```

Warnings from `gh auth status` are not failures. If the task names a base branch, use it. Stop if
`BRANCH` is empty or equals `BASE`, or if `origin` is not `REPO`.

## 2. Existing PR

```bash
gh pr list --repo "$REPO" --head "$BRANCH" --state all \
  --json number,url,state,isDraft
```

- Exactly one open PR: set `NUMBER` and ignore older merged/closed PRs.
- More than one open: report the numbers and stop.
- No open PR, but any merged or closed one: report its URL and stop; do not reuse the branch.
- None at all: continue.

## 3. Push

```bash
git push -u origin HEAD
```

No force, no delete. On rejection, report the error and stop.

## 4. Write

Read the actual change, not just commit messages:

```bash
git fetch --no-tags origin "$BASE"
git log --oneline --no-merges "origin/$BASE..HEAD"
git diff --stat "origin/$BASE...HEAD"
git diff "origin/$BASE...HEAD"
```

If the diff is empty, stop: there is nothing to PR.

Title: imperative, at most 72 characters, in the repo language and style (last 10 merged PRs).

```bash
gh pr list --repo "$REPO" --state merged --limit 10 --json title
```

Body:

```markdown
## Summary

- <what changed and why>

## Changes

- `<path>`: <what changed>

## Verification

- `<command>`: <result>

## Risk

- <behavior, compatibility, deployment, or security risk; "Low" if none>
```

- Summary: 1-3 bullets. Changes: grouped by path, not every line.
- Verification: only commands actually run. If none, `NOT RUN: <reason>`.
- `Closes #N` only for a known issue.
- No secrets, `.env` contents, tokens, raw logs, customer data, empty sections, TODOs, or unchecked checklists.
- Follow `.github/PULL_REQUEST_TEMPLATE.md` or `.github/pull_request_template.md` if present.
- Write the title to `/tmp/pr-title` and the body to `/tmp/pr-body.md`.

## 5. Create or edit

New PR:

```bash
PR_URL="$(gh pr create \
  --repo "$REPO" \
  --base "$BASE" \
  --head "$BRANCH" \
  --title "$(cat /tmp/pr-title)" \
  --body-file /tmp/pr-body.md)"
NUMBER="${PR_URL##*/}"
```

Existing open PR:

```bash
gh pr edit "$NUMBER" --repo "$REPO" \
  --title "$(cat /tmp/pr-title)" \
  --body-file /tmp/pr-body.md
```

Use `--draft` only when the task says WIP, the branch is a spike, or local checks fail.

## 6. Report

```bash
gh pr checks "$NUMBER" --repo "$REPO"
```

No `--watch`. "No checks reported" is a valid result, not an error to retry. If a check failed:

```bash
gh run list --repo "$REPO" --branch "$BRANCH" --limit 5
gh run view <run-id> --repo "$REPO" --log-failed
```

Summarize the failing step, not the whole log. Report the PR URL, draft state, and check states.
Pending is not a pass. Never claim CI succeeded unless you saw it succeed.
