Perform a read-only security review of:

$ARGUMENTS

If the target is empty, review the uncommitted diff and any files it touches. Use the Security Review skill. Threat-model the change against the hydr4-agent boundary: provider keys, gateway key, bot SSH key, workspace, `/configs`, container-to-host escape, and prompt injection from repository or web content.

Report findings first, ordered by severity, each with asset, attack path, impact, evidence, and the smallest fix. Explicitly cover secrets exposure, injection, authorization, SSRF, path traversal, supply chain, and container configuration. Do not print or reproduce any secret value. End with what you did not review and a verdict: safe to merge, merge with fixes, or do not merge.
