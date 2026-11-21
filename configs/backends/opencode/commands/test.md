Run the relevant checks for the current change and report the evidence. Do not weaken, skip, or delete a test to make the result green.

Scope: $ARGUMENTS

If the scope is empty, derive it from `git diff --name-only` and the project's existing test configuration. Run the narrowest test first, then the broader suite, plus syntax/lint checks that exist in the repository. For this repository, remember that host-side checks (`./hydra check`, `docker compose`, `scripts/check.sh`) cannot run inside the agent container; use static checks here and say which host command the human should run.

Report: commands, result lines, failures with file:line, tests added/changed, what was not run and why, and residual risk.
