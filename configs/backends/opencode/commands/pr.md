Push the current topic branch if needed, then prepare or open its pull request. Never merge, close, approve, or force-push.

Context: $ARGUMENTS

1. Read `git status --short --branch` and `git log --oneline origin/main..HEAD` (fall back to `main`).
2. If the branch is `main`/`master`, stop. Create `agent/<topic>` for the change instead. If `HEAD` is detached, stop and report it.
3. If the branch has no upstream, push it explicitly: `git push -u origin HEAD`. Never push `main`, never force, never push tags.
4. Check whether GitHub CLI is available and authenticated: `gh --version` and `gh auth status`.
5. If `gh` works, create the PR (draft is fine):
   `gh pr create --base main --head <branch> --title "<title>" --body-file <file>`
   Otherwise print the compare URL:
   `https://github.com/<owner>/<repo>/compare/main...<branch>?expand=1`
6. Do not run `gh pr merge`, `gh pr close`, `gh pr review`, or `gh api`.
7. Report the branch, push result, PR URL (or compare URL), title, body, and checks.

If the push is rejected because the remote moved, stop and report it. Do not force-push.
