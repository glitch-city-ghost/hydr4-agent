Review the current changes read-only for correctness, security, and missing tests. Do not edit files.

Target: $ARGUMENTS

If the target is empty, review the uncommitted diff (`git diff` plus untracked files) and the last commit (`git show --stat HEAD`). Use the Code Review skill. Report findings first, ordered by severity, each with file:line, a concrete failure scenario, impact, and the smallest fix. Then list open questions and what you did not inspect. End with a verdict: approve, approve with nits, or request changes.
