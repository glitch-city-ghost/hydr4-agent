---
name: Systematic debugging
description: Use when something is broken or behaves unexpectedly. Reproduce the failure, narrow the cause with evidence, fix the root cause, and add a regression check.
---

# Systematic debugging

1. **Reproduce.** Get a deterministic command, input, and observed failure.
   Record the expected versus actual result.
2. **Locate the boundary.** Trace data and control flow from the entry point to
   the failure. Use `git log`, `git diff`, `grep`, and targeted reads.
3. **Form one hypothesis.** State the smallest cause that explains all observed
   evidence. Write down what would disprove it.
4. **Run one experiment.** Change one variable at a time. Prefer read-only
   probes, logs, and focused tests.
5. **Fix the cause.** Make the minimal change at the failure boundary. Do not
   silence the symptom with retries, sleeps, or broad exception handling.
6. **Regress.** Re-run the reproduction and the nearest relevant test. Add a
   regression test when the project has a test suite.
7. **Report.** Say what was broken, why, what changed, and how you verified it.

## Stop conditions

- If the evidence does not fit the hypothesis, discard it rather than adding
  another guess.
- If the problem is environmental (missing Docker, network, credentials), stop
  and report the missing capability instead of editing code around it.
- Never "fix" a failure by deleting data, disabling a check, widening
  permissions, or pinning an unrelated dependency.
