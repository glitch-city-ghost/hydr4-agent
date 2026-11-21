---
name: Testing
description: Use when adding or changing behavior and you need to choose, write, run, or repair automated tests — including regression tests for a bug and verification evidence for the final report.
---

# Testing

Tests exist to make change safe. A test that cannot fail for the right
reason costs time without buying safety.

## Choose the level

| Level | Use it for | Cost |
|---|---|---|
| Unit | Pure logic, parsing, validation, edge cases, error mapping. | Low |
| Integration | A module boundary: HTTP handler + config, gateway + fake provider, file I/O. | Medium |
| Contract | The interface in `docs/contracts/` must not change: status, shape, headers, DNS name. | Medium |
| End-to-end | A thin, high-value user path. | High |
| Manual | Visual, interactive, or environment-specific behavior that cannot be automated yet. | Human time |

Prefer the lowest level that can catch the regression. Do not mock the thing
you are trying to prove.

## Process

1. **Find the existing suite.** Read `package.json` scripts, `pyproject.toml`,
   `pytest.ini`, `Makefile`, CI config, and the nearest test file. Follow the
   project's convention before inventing one.
2. **Run the narrowest test first.** Confirm the suite and the failing test run
   in this environment.
3. **For a bug fix, write the failing test first.** It must fail for the
   reported reason, not for a syntax or import error. Then fix the code until
   it passes.
4. **For a feature, test behavior at the boundary.** Public function, API
   response, config effect, or user-visible result. Avoid asserting private
   call order unless that order is the contract.
5. **Add the negative case.** Invalid input, missing dependency, empty
   collection, timeout, permission denied, duplicate delivery, retry.
6. **Run the adjacent suite.** The new test must pass with the old tests; no
   test should be deleted or weakened to make room.
7. **Report the command.** "Tests pass" is not evidence. Paste the command and
   the result line.

## Test quality

A good test is:

- **Deterministic** — no real clock, random seed, network, port race, or
  filesystem order without control.
- **Isolated** — creates its own data, cleans up, does not depend on another
  test's side effect.
- **Fast enough** — unit tests in milliseconds; integration tests in seconds.
- **Readable** — one reason to fail, a name that states the behavior, and an
  assertion that explains the expected value.
- **Behavioral** — asserts what the caller observes, not the private shape of
  the implementation.
- **Specific** — a failure points to the broken behavior, not to "expected
  true, got false".

## Patterns

- **Arrange–Act–Assert** for a single behavior.
- **Table-driven** tests for validation boundaries and error mapping.
- **Golden/contract test** for a wire format or a generated file.
- **Regression test** named after the bug: `test_does_not_crash_on_json_model_list`.
- **Property test** only when the input space is large and the invariant is
  crisp; do not add a property framework for one case.
- **Fake, not mock**, at a process boundary: an in-memory HTTP server, a temp
  directory, a stub provider. Mocking the unit under test proves nothing.

## Anti-patterns

- A test that passes when the code is deleted.
- `assert True`, snapshot churn, or asserting only "no exception".
- `sleep` instead of awaiting the actual condition.
- Shared mutable fixture with order dependence.
- Network, real credentials, or production data in a test.
- Weakening an assertion to make a failing fix green.
- Adding a dependency just to test one pure function.
- Marking a test skipped without an issue and a removal date.
- Claiming "all tests pass" when the suite was not run.

## This repository

The repo has no application test suite of its own; its verification is the
Compose stack and the read-only scripts. Inside the agent container there is no
Docker daemon, so host-side checks cannot run here.

What you can run inside the agent:

```bash
bash -n <script>                 # shell syntax
python3 -m json.tool <file>      # JSON syntax
node --check <file.js>          # JavaScript syntax
jq empty <file.json>            # JSON syntax, if jq exists
```

What runs on the host:

```bash
docker compose config --quiet   # Compose validity
./hydra check                   # health, gateway, DNS, ingress; no model calls
./hydra logs agent              # agent start-up and config errors
```

Do not run `scripts/smoke-test.sh` or any model request as a routine "test";
it spends tokens and depends on providers. Use it only when the user asks to
verify provider/tool calling.

## Report

```text
Tests:    <command>
Result:   <pass/fail; count; key line>
Added:    <test files and what they prove>
Not run:  <reason and where it runs>
Risk:     <untested path, flake, environment difference>
```
