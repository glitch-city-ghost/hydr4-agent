---
name: Systematic Debugging
description: Reproduce and isolate a bug or failing test before fixing it, instead of guessing at changes
---

# When to use

Use this when a test fails, a bug is reported, a fix did not work, or behavior is unexpected. Do not use it for straightforward feature work.

# Rules

- Never change code before you can reproduce the problem.
- Change one thing at a time. If you change two things and it works, you learned nothing.
- Fix the cause, not the symptom. Do not silence an error, swallow an exception, or weaken an assertion to make a test pass.
- If you cannot reproduce, say so and ask for the missing input instead of inventing a fix.

# Procedure

1. Reproduce. Run the smallest command that shows the failure. Record the exact command and the exact output.
2. Read the error. Identify the file and line the failure originates from, and read that code and its immediate callers.
3. Minimize. Reduce the failing case to the smallest input or test that still fails. Remove unrelated setup.
4. Hypothesize. Write down one specific cause and what evidence would confirm or refute it.
5. Verify the hypothesis without fixing yet. Add a temporary log, a focused test, or a read of the data at the boundary. Confirm the cause.
6. Fix. Make the smallest change that addresses the confirmed cause. Keep unrelated code untouched.
7. Verify. Re-run the original failing command, then the surrounding test suite. Confirm no regression.
8. Clean up. Remove temporary logs and throwaway code you added.

# Output

- Cause: what was actually wrong, in one or two sentences.
- Fix: the file and the change.
- Evidence: the command that now passes, with its result.
- Unverified: anything you did not confirm.
