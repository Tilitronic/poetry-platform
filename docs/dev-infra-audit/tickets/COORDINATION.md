# DIA Ledger - Multi-Device Coordination Protocol

Status: adopted 2026-08-13 (DIA-125 res-2 recommendation: keep-local text
ledger + shared git remote + claim convention; res021 conspect section 4).
Applies to every device and OpenCode session that reads or writes
docs/dev-infra-audit/tickets/.

## Why this file exists

The ledger is a set of plain-text .md files under docs/dev-infra-audit/tickets/.
Parallel OpenCode sessions (possibly on different devices) can clobber each
other: two sessions may allocate the same DIA number, or both start the same
ticket. This protocol makes ticket-taking single-writer without a server:
git is the transport, and the frontmatter lease fields are the write token.

## 1. Shared git remote

- The ledger is text and git-syncable by construction; it rides the normal
  project git workflow through a shared remote. Use a free private GitHub
  repo used PURELY as a git remote, or a bare repo on a tiny VPS. No issue
  tracker is involved: the .md files are the system of record.
- Before any session starts: `git pull --ff-only`. After any ledger edit:
  commit + `git push` so the next device sees the change.

## 2. Claim convention (single-writer token)

- A ticket is TAKEN when its frontmatter carries a live lease: session_id +
  lease_expires_at set to now + about 4h, for example:

      session_id: "ses_abc123"
      lease_expires_at: "2026-08-13T20:00:00Z"

- Claim by editing those two fields in DIA-NNN-<slug>.md and committing
  (ASCII only). A ticket whose lease is in the future belongs to the session
  named in session_id - do not start it.
- `tickets new` does NOT claim (lease_expires_at stays ""); claiming happens
  at take-time, per this protocol.
- On COMPLETE: clear the lease (lease_expires_at: "") and set the final
  status. A lease is not a permanent lock: if it expires with no progress,
  anyone may reclaim.

## 3. Fetch-before-take

- Before claiming a ticket, ALWAYS: git fetch + pull, then read the ticket
  frontmatter. A teammate may have claimed it since your last pull.
- If the lease is live: pick another ticket, or coordinate with the session
  named in session_id.
- Same discipline for number allocation: pull before `tickets new` - the
  allocator scans the LOCAL files, so a stale checkout can produce a
  collision. The collision guard refuses to overwrite, but a pull avoids the
  error entirely.

## 4. ASCII-only (DIA-079)

All ledger edits - frontmatter, bodies, commit messages - are ASCII-only.
No em-dashes, no smart quotes. `tickets new` enforces this on input; hand
edits must follow the same rule. Note: embedded double quotes in a title are
converted to single quotes when written into the YAML title field (the field
is always double-quoted) so the frontmatter stays valid YAML; the H1 and the
README row keep the raw title.

## 5. Tooling reference

`tickets --help` is the canonical usage text; the summaries below mirror it.

- scripts/tickets new "<title>" [--area <area>] [--severity <sev>]
  [--blocked-by <DIA-NNN,...>] [--parent-epic <DIA-NNN>]
  [--source <inventory|baseline|test-lane|fix-lane>]
  allocate the next free DIA number, write DIA-NNN-<slug>.md from the
  \_TEMPLATE.md frontmatter conventions (defaults: area=scripts,
  severity=Medium, source=inventory), insert the README index row in DIA
  sort position, and recompute the severity/status counts. Does not
  auto-claim (lease_expires_at stays empty).
- scripts/tickets rollup [--check] recompute the README severity/status
  count tables from the actual ticket frontmatter; --check reports the
  before/after delta without writing (exit 1 when counts are stale).
- scripts/tickets frontier print the blocker frontier (OPEN tickets
  with no OPEN blockers) sorted by severity then DIA-NNN, plus a
  blocker-graph summary of blocked tickets; live-lease notes flag tickets
  already claimed by another session.

Spec and design authority: ticket DIA-125 (docs/dev-infra-audit/tickets/
DIA-125-automate-ticket-management-research.md) and the res021 conspect
(knowledge/res021-ticket-mgmt-automation/res021-ticket-mgmt-automation-conspect.md).
