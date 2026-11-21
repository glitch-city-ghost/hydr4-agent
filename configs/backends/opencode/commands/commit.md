Prepare a topic branch, stage the intended changes, write a Conventional Commit, and push the branch. Do not push `main`/`master`, do not force, and do not merge.

Scope / hint: $ARGUMENTS

Steps:
1. Run `git status --short --branch`, `git diff`, and `git diff --cached`.
2. If on `main` or `master`, create `agent/<short-topic>` first. If `HEAD` is detached, stop and report it; do not push from a detached HEAD.
3. Stage only the files that belong to this change, by explicit path. Never stage `.env`, keys, databases, temp files, or unrelated work.
4. Run `git diff --check`. Fix whitespace errors or conflict markers.
5. Write a Conventional Commit subject: imperative, lower-case, no trailing period, at most 72 characters. The body explains why, not a file list.
6. Commit without `--no-verify`. If a hook fails, fix the cause or report it.
7. Push the current topic branch: `git push -u origin HEAD`. Never force-push, never push tags, never use `--all` or `--mirror`, and never target `main`/`master`.
8. Report the branch, commit hash, subject, files changed, push result, and the GitHub compare URL for opening the PR.

If the push is rejected because the remote moved, stop and report it. Do not force-push.
