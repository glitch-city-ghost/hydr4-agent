---
name: Refactoring
description: Use when restructuring existing code without changing observable behavior — renaming, extracting, splitting, deduplicating, or paying down local complexity safely.
---

# Refactoring

Refactoring changes structure, not behavior. If behavior changes, it is a
feature or a fix and needs its own test and commit.

## Preconditions

- The behavior is covered by at least one test, or you can add a
  characterization test before touching the code.
- The change is scoped to one idea. "Refactor and add a feature" is two commits.
- You know the call sites: `rg`/`grep` for the symbol, not just the file.
- The working tree is clean enough that a failed step can be reverted without
  losing the user's work.

If a precondition is missing, stop and say which one. A refactor without a
safety net is a rewrite with better marketing.

## Method

1. **Characterize.** Run the existing tests. If there are none, add a small test
   or a reproducible check that pins the current behavior, including the ugly
   edge cases.
2. **Name the smell.** Duplication, a long function, a hidden dependency, a
   leaky abstraction, inconsistent naming, a wrong layer, a temporal coupling. Be
   concrete; "it's messy" is not a reason.
3. **Choose the smallest move.** Extract a function, rename a symbol, move a
   module, introduce a parameter, replace a conditional with a lookup. Avoid a
   big-bang rewrite.
4. **Change in mechanical steps.** One rename or extraction per step. Run the
   tests after each step. If a step cannot be tested alone, make it smaller.
5. **Keep the commit honest.** No behavior change in the refactor commit. If a
   bug appears, fix it in a separate commit and mention it.
6. **Review the diff for accidental change.** Whitespace, ordering, error
   messages, defaults, and log lines often drift during a move. Compare the old
   and new behavior at the boundaries.

## Rules

- Do not mix a refactor with a feature, a bug fix, a dependency upgrade, or a
  formatting sweep. Separate commits, separate PRs when possible.
- Do not rename public interfaces without updating every caller and the
  docs. A rename is an API change.
- Do not change error types, messages, status codes, or retry behavior by
  accident. If the refactor changes them, call it out and test it.
- Do not change database schema, wire format, file format, or config shape
  without a migration and a compatibility plan. That is not a refactor.
- Do not “clean up” unrelated files in the same diff. It makes review
  harder and hides the real change.
- Preserve comments that explain why. Delete comments that explain what the
  new code now says clearly.
- Prefer duplication over a premature abstraction when the two call sites are
  likely to diverge. Extract only when the shared behavior is stable.
- Keep the abstraction at the same level as its callers. A helper that takes
  five booleans is not simpler than the code it replaced.
- Names should describe the domain, not the implementation (`retryable_error`,
  not `flag2`).

## Verification

- The characterization/regression tests pass before and after.
- The diff is mostly moves and renames; logic changes are small and explained.
- `git diff --check` is clean.
- Callers, imports, types, docs, and tests are updated.
- Error paths and boundaries are unchanged, or the change is called out.
- No dead code, unused export, or commented-out old implementation remains.
- The final report names the smell, the move, the behavior preserved, and the
  verification.

## Report

```text
Smell:      <what was wrong>
Move:       <what changed structurally>
Behavior:   <unchanged; or the exact intentional change>
Verified:   <tests/commands>
Not run:    <reason>
Risk:       <review surface, compatibility>
```
