# Ticket Archive

Completed tickets move here instead of being deleted. The active ledger in
`docs/dev-infra-audit/tickets/README.md` lists only open, deferred, monitored,
and in-flight tickets; the archive keeps finished work browsable.

## Archive triggers

A ticket qualifies for archiving when **all** hold:

- Status is `VERIFIED` or `CLOSED`
- It has stayed at that status for ≥1 full cycle with no reopen
- `Fix` and `Re-verify` sections are populated with concrete evidence (gate
  output / exit code, not placeholders)

## Process

1. `git mv DIA-NNN-<slug>.md archive/DIA-NNN-<slug>.md`
2. Remove the index row from `tickets/README.md`
3. Update the status rollup counts in `tickets/README.md`
4. Commit

## Why not delete?

Commit `23b1e22` deleted 32 validated tickets (25 FIXED + 6 CLOSED +
1 IMPLEMENTED). They remain recoverable via `git log`/`git show`, but without
the commit hash they are invisible — deleted tickets are not discoverable by
anyone browsing the ledger. Archiving keeps completed tickets browsable while
excluding them from the active ledger.
