Implement the following task end to end:

Task: $ARGUMENTS

Follow `AGENTS.md` and the Build agent prompt. Ground yourself in the existing code first, use `todowrite` for multi-step work, keep the diff minimal, and verify with the narrowest relevant check before the broad one.

Commit and push the topic branch as part of delivery, unless the task says local-only or do not push. Create `agent/<topic>` if the current branch is main/master, commit there, push only that branch, and never merge. If the task is read-only, leave the tree untouched.

If a requirement is ambiguous and the wrong choice would be expensive, ask one focused question instead of guessing. Otherwise make the reasonable choice, state it in the final report, and finish the work.

Final report: Summary, Changed, Verified, Not verified, Risk / follow-up. Include the branch name and push/PR link if you delivered.
