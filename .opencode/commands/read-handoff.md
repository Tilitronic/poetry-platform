---
description: >-
  Read the newest manual session handoff for the current branch, re-check its
  ticket references, and summarize before resuming work.
# DIA-261126-q9r9 (ADR 16): read side of the manual handoff pair. Read-only;
# no ticket-gate bypass.
---

# Read Handoff

If the invoking agent has no bash tool, have one coder lane run the commands
below and report the output - this agent only reads and summarizes.

1. Resolve the file: the newest
   `.opencode/session/handoffs/HANDOFF-*-<branch>.md` for the current branch
   (`git rev-parse --abbrev-ref HEAD`, slashes become dashes), or the exact file
   the developer names. If none exists, say so and stop.
2. Re-check every DIA ticket it mentions with `scripts/tickets show <id>` -
   the handoff is a snapshot, the ticket ledger is live.
3. Verify the recorded HEAD sha exists here: `git cat-file -e <sha>^{commit}`.
   Warn when the working tree has moved on (`git rev-parse HEAD` differs) or
   when the sha is unknown to this repo - the handoff may belong to another
   machine or branch.
4. Print a 5-10 line summary: date and sha read, tickets still open vs closed,
   blockers, and the recorded next step.
5. Ask the developer to confirm before resuming work. Do not start.
