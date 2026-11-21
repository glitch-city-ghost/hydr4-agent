---
name: Systematic Debugging
description: Use when something is broken, flaky, slow, or behaves differently from the documented contract — reproduce it, isolate the cause, fix the root cause, and prove the fix.
---

# Systematic Debugging

Debugging is a controlled experiment, not a hunt for a plausible edit. The goal
is a **root cause** with evidence, a **minimal fix**, and a **regression test**
that would fail without it.

## Phase 0 — Safety

- Read the error, the full stack trace, and the failing command. Do not skim.
- Capture the exact reproduction: command, input, environment, version, and
  observed vs expected output.
- Check `git status` and recent history. The cause is often the last change.
- If the failure can destroy data, stop the stack or copy the data directory
  before experimenting. Never "test" destructive commands on real state.
- Never read or paste secrets while debugging. Redact tokens and keys.

## Phase 1 — Establish facts

Write down, without interpretation:

1. What fails? (symptom)
2. What works? (boundary of the failure)
3. When did it start? (first bad commit, first bad run, config change)
4. Where does it fail? (component, process, request, line)
5. What is the exact error? (text, code, status, log line)
6. What is the environment? (container, host, version, env vars, network)

Use read-only evidence first:

```bash
git status --short --branch
git log --oneline -10
git diff
git diff --cached
git bisect log
```

For this stack, the useful read-only probes are documented in
`docs/contracts/` and `WTF_EVERYTHING_BROKE_DOWN_HELP.md`:

- `./hydra status` — containers and deployed commit;
- `./hydra check` — compose, health, gateway, DNS, ingress; no model calls;
- `./hydra logs gateway` / `./hydra logs agent` — last 100 lines;
- `getent hosts gateway` from the agent — Docker DNS;
- `curl http://127.0.0.1:3001/healthz` on the host — gateway;
- `curl http://127.0.0.1:4096/global/health` on the host — agent;
- `curl http://agent.localhost` — Traefik route.

Do not rebuild to diagnose. Rebuilding destroys the evidence and takes time.

## Phase 2 — Isolate

Reduce the failure to the smallest unit that still fails. Change one variable at
a time.

- **Environment:** host vs container, network, user/UID, env var, version.
- **Input:** smallest payload, empty, one field, boundary value, encoding.
- **Path:** direct port vs Traefik, service name vs container name, gateway
  direct vs through the agent.
- **Time:** first run vs later run, cache, retry, race, clock, timeout.
- **State:** fresh data dir vs existing DB, clean checkout vs dirty tree.
- **Scope:** one model vs all models, one provider vs all, one request vs a
  stream.

Useful techniques:

- **Bisect** commits or config changes: `git bisect start`, `git bisect bad`,
  `git bisect good <sha>`. Keep it read-only until the culprit is known.
- **Differential debugging:** compare the working and failing request, diff the
  config, diff the environment.
- **Minimal reproduction:** a script or single request that fails in isolation.
  If you cannot reproduce it, you cannot verify the fix.
- **Instrument, don't guess:** add one temporary log at the boundary that
  distinguishes hypotheses. Remove it before finishing.
- **Read the dependency:** the bug may be in the gateway, Docker DNS, Traefik,
  or the provider. Check the version and the configuration actually in use.

Do not change several things at once. If a "fix" works, you will not know which
change mattered.

## Phase 3 — Hypothesize

Write a falsifiable hypothesis:

```text
If <cause> is true, then <test> should produce <result>.
```

Rank hypotheses by likelihood and cost to test. Test the cheapest discriminating
one first.

Good hypothesis: "The gateway returns 429 with `Retry-After`, but the agent's
timeout is 0, so the request fails immediately; a direct request with a 30 s
timeout should succeed."

Bad hypothesis: "Maybe it's a network thing." That is a category, not a test.

## Phase 4 — Fix the root cause

- Fix the cause, not the symptom. Do not add a retry around a deterministic
  failure, a sleep around a race, or a catch-all around a missing case.
- Make the smallest correct change. Do not refactor the neighborhood.
- Preserve the contract. If the fix changes an interface, update the contract
  and the callers.
- Add a regression test that fails before the fix and passes after it.
- If the root cause is outside this repository (host, provider, Docker), report
  the evidence and the exact host-side action. Do not "fix" it by weakening the
  local code.

## Phase 5 — Verify

1. The original reproduction now passes.
2. The new regression test fails without the fix and passes with it.
3. The adjacent checks still pass (unit, integration, health, ingress).
4. The error path is still sane: the dependency down, slow, and malformed.
5. No secrets or debug logs were added.
6. The diff is minimal and reviewed end to end.

If you cannot verify a point, say so. Do not close a bug on a guess.

## Phase 6 — Report

```text
Symptom:   <what the user observed>
Repro:     <smallest command/input that failed>
Evidence:  <logs, diff, bisect result>
Cause:     <root cause, with file:line>
Fix:       <what changed and why it addresses the cause>
Verify:    <commands and results>
Residual:  <what is still untested or could regress>
Prevent:   <test, guard, alert, or doc added>
```

## Anti-patterns

- Shotgun changes: editing five files to see which one helps.
- Random dependency upgrades or downgrades without evidence.
- Disabling a test, a check, or auth to make the symptom disappear.
- Catch-all exceptions that turn a failure into a silent default.
- Retrying a non-idempotent operation without understanding duplicates.
- `sleep` to "fix" a race.
- Declaring success because the process started, without exercising the path.
- Blaming the provider before checking DNS, proxy, timeout, and local config.
