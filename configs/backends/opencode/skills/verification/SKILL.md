---
name: Verification
description: Use when a change needs proof. Runs the narrowest reliable checks, reads the output, and reports exact commands and results instead of claiming success.
---

# Verification workflow

1. **Define the claim.** What must be true for this change to be correct?
2. **Find the existing gate.** Prefer project tests, lint, typecheck, smoke
   scripts, or CI commands already documented in the repo. Do not invent a new
   harness when the project has one.
3. **Run the narrowest check first.** Start with syntax, JSON/YAML parsing, or a
   single focused test. Expand only when the change is broad.
4. **Read the output.** A zero exit code is not enough if the command skipped
   work or printed a warning that matters.
5. **Report exactly.** Include the command, working directory, exit status, and
   the relevant output. If a check cannot run, say why and what the user must run.

## Common checks

```sh
python3 -m json.tool path/to/file.json
bash -n script.sh
node --check file.js
git diff --check
```

- For shell scripts, `bash -n` is a syntax check, not a behavioural test.
- For Compose changes, `docker compose config --quiet` must run on the host; the
  agent container has no Docker socket.
- For documentation-only changes, check links and commands you quote, not just
  spelling.

## Rules

- Never say "tests pass" when no test was run.
- Do not weaken, skip, or delete a failing test to get green.
- If the verification scope is incomplete, state exactly what is unverified.
