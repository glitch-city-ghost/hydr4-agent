Diagnose and fix the following failure:

$ARGUMENTS

Use the Systematic Debugging skill. Reproduce it with the exact command or input first, collect evidence, isolate the cause, and state a falsifiable hypothesis before changing code. Do not shotgun multiple fixes, do not upgrade a dependency at random, and do not weaken an assertion or add a sleep/retry to hide the cause.

If the cause is in this repository, fix the root cause, add a regression test, and rerun the original reproduction plus the adjacent suite. If the cause is the host, Docker, Traefik, a provider, or external state, report the evidence and the exact host-side action; do not fake a local fix.

Report: Symptom, Reproduction, Evidence, Cause, Fix, Verification, Residual risk.
