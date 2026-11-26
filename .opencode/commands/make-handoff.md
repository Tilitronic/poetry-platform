---
description: >-
  Write a manual session handoff to
  .opencode/session/handoffs/HANDOFF-<date>-<branch>.md.
# DIA-261126-q9r9 (ADR 16): manual handoff replaces the deleted automatic
# plugin handoff contract. No ticket-gate bypass - read-only ticket queries.
---

# Make Handoff

Gather state, then write ONE file. If the invoking agent has no bash tool, have
one coder lane collect these facts and report them back.

1. Active tickets and statuses: `scripts/tickets list --status OPEN` plus
   `scripts/tickets list --status IN_PROGRESS` (script output is the source of
   truth - never read docs/dev-infra-audit/tickets/ directly).
2. Branch and HEAD: `git rev-parse --abbrev-ref HEAD`, `git rev-parse HEAD`.
3. `git status --porcelain` - uncommitted changes.
4. `git log --oneline <last-handoff-sha>..HEAD` - done since the last handoff,
   with commit hashes.
5. Open blockers: developer decisions, a missing gate, a failed check.
6. The exact next step - one concrete action, not a theme.

Then write `.opencode/session/handoffs/HANDOFF-<YYYY-MM-DD>-<branch>.md`
(slashes in the branch name become dashes). Header block first: ISO-8601
timestamp and the HEAD sha. Sections: Tickets, Branch and HEAD, Uncommitted,
Done (commit hashes), Blockers, Next step.

Overwrite only the file whose date and branch match the current session. Never
commit it - the directory is gitignored.
