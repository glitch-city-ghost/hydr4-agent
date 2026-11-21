---
name: Code Review
description: Use when reviewing a diff, a pull request, or a proposed change for correctness, security, tests, maintainability, and production risk.
---

# Code Review

Review the change, not the author. Findings come first, ordered by severity.
Do not edit files in review mode unless the user explicitly asks for fixes.

## Scope

1. Read the intent: issue, PR description, commit message, or user request.
2. Read the full diff, including deleted code and new files.
3. Read enough surrounding code to judge the diff in context: callers,
   contracts, tests, config, migrations.
4. Run the narrowest relevant checks if the environment allows. Read-only
   verification is better than a guess.
5. State what you did **not** inspect. Do not imply full coverage.

## Severity

| Level | Meaning |
|---|---|
| **Blocker** | Data loss, security hole, broken build, contract violation, silent corruption. Must fix before merge. |
| **High** | Real bug in a plausible path, missing authorization, unsafe migration, missing regression test for a bug fix. |
| **Medium** | Edge-case bug, unclear failure mode, performance risk at expected scale, test gap for a risky path. |
| **Low** | Maintainability, naming, duplication, weak error message, missing docs. |
| **Nit** | Style or preference. Never block on a nit. |

Every finding needs: **file:line**, a concrete scenario, the impact, and a
suggested fix. If you cannot name the scenario, it is a question, not a finding.

## Checklist

### Correctness

- Does the change do what the intent says, including the negative path?
- Boundary values: empty, zero, one, max, negative, null, missing, duplicate.
- Off-by-one, inclusive/exclusive ranges, truncation, rounding, time zones.
- Error paths: what happens when the dependency is down, slow, or returns
  malformed data?
- Partial failure and retries: is the operation idempotent? Can it duplicate?
- State transitions: can an invalid state be reached? Is cleanup guaranteed?
- Concurrency: shared mutable state, races, lock ordering, deadlocks, lost
  updates.
- Resource lifecycles: files, sockets, timers, goroutines/threads, memory,
  subscriptions, DB connections.
- Backward compatibility: existing data, existing clients, existing config,
  existing URLs, existing env vars.

### Security

- Secrets in code, logs, errors, URLs, prompts, fixtures, or commit history.
- Injection: shell, SQL, NoSQL, template, header, path, deserialization, prompt.
- Authorization: is every new entry point checking the right principal and
  resource? Is authorization on the server, not the client?
- Input validation and output encoding at the correct boundary.
- Path traversal and unsafe file writes; symlink races.
- SSRF and unrestricted outbound requests; redirect handling.
- Unsafe deserialization, `eval`, dynamic import, prototype pollution.
- Dependency provenance, lockfile changes, install scripts, typosquatting.
- Container/CI: secrets in env, privileged mode, host mounts, Docker socket,
  untrusted build context, cache poisoning.
- Logging: PII, credentials, full request bodies, stack traces to clients.

### Data and operations

- Schema/migration: forward and rollback path, locking, backfill, idempotency.
- Transactions and isolation: what is atomic? What can be observed halfway?
- Deletes and updates: is the `WHERE` clause bounded? Is there a dry run?
- Backup and restore: does the change make existing backups unrestorable?
- Observability: are new failure modes visible? Are metrics bounded in
  cardinality? Are logs useful without being noisy?
- Rollout: feature flag, canary, compatibility window, rollback trigger.

### Performance and scale

- N+1 queries, unbounded loops, unbounded concurrency, missing pagination.
- Work moved into a hot path; allocations per request; repeated I/O.
- Cache invalidation and stampede behavior.
- Timeouts and backpressure: can a slow dependency exhaust the pool?
- Memory growth from buffers, queues, retries, or retained references.

### Tests

- Does the test fail for the bug before the fix?
- Does it assert behavior, not implementation details?
- Are the important branches and error paths covered?
- Is it deterministic (no sleeps, real clock, network, ordering, random seeds)?
- Is it isolated (no shared mutable fixtures, no order dependence)?
- Is the test readable: one reason to fail, clear name, useful assertion message?
- Are existing tests updated for intentional behavior changes, not deleted to
  make the suite green?

### Maintainability

- Does it follow existing patterns, or introduce a second way to do the same
  thing without a reason?
- Is the abstraction earned by at least two real call sites?
- Are names accurate and consistent with the domain?
- Is the diff minimal? Can unrelated churn be split out?
- Are docs, examples, contracts, ADRs, and config comments updated?
- Is the failure mode understandable to the next engineer at 3 a.m.?

## Output

```text
## Findings

### [Blocker] <title> — path/file.ext:line
Scenario: <what triggers it>
Impact: <what breaks, for whom>
Fix: <smallest correct change>

### [High] ...

## Questions / assumptions
- <only real ambiguities>

## Verification
- Reviewed: <diff, files, tests>
- Ran: <commands and results>
- Not run: <reason>

## Verdict
<approve | approve with nits | request changes>
```

Rules:

- No praise, no summary of what the diff does before the findings. The author
  knows what they wrote.
- Do not report a finding you cannot reproduce or explain.
- Do not flag style as a blocker.
- If there are no findings, say so plainly and name the residual risk.
- Keep the review proportional: a 20-line diff does not need a 100-line essay.
