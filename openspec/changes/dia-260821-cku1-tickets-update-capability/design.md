## Context

`scripts/tickets` is a bash CLI for managing DIA tickets in
`docs/dev-infra-audit/tickets/`. It currently provides `new`, `list`, `show`,
`search`, `stats`, `rollup`, `frontier`, and `help` subcommands. Tickets are
markdown files with YAML frontmatter and body sections (`## Description`,
`## Verification`, `## Fix`, `## Re-verify`). The README index row and
severity/status count tables are derived from the frontmatter via the rollup
machinery (`compute_ledger_counts` + `rewrite_readme`).

Constraints:

- ASCII-only input and output (DIA-079).
- Bash-3 compatible (no `[[ ]]`, no associative arrays, no
  mapfile/namerefs/compgen).
- No new dependencies (coreutils only).
- Frontmatter is YAML; the `evidence:` field is a YAML array.
- README rollup contract: index row + count tables must stay in sync with
  frontmatter.

See proposal.md for motivation and scope.

## Goals / Non-Goals

**Goals:**

- Add a `tickets update <id>` subcommand that mutates a controlled allowlist
  of fields in an existing DIA ticket file.
- Atomic copy-rename mutation model: write to a temp file, validate, then
  `mv` over the original. On validation failure the original is untouched.
- After a successful mutation, trigger a README rollup so the index row's
  Status column and the count tables stay in sync.
- ASCII-only input and output. Non-ASCII in `--evidence` values fails
  validation. Non-ASCII in `--fix-file` / `--reverify-file` contents is
  sanitized on write.
- Extend the existing bats suite (`scripts/__tests__/tickets.bats`) with
  ~15-20 test cases covering happy path, validation failures, atomicity,
  rollup integration, and ASCII sanitization.

**Non-Goals:**

- Field removal (no `--remove-evidence`, no `--clear-fix`).
- Structural field updates (title, area, severity, blocked_by, parent_epic -
  hand-edit only).
- Gate marker updates (gate_state, gate_triggers, gate_waivers, gate_override -
  set at creation or during grilling gate).
- Session attribution updates (session_id, lane_id, agent, lease_expires_at -
  owned by delegation-observer plugin).
- Description/Verification updates (original spec - hand-edit only).
- Ticket deletion/archival (manual `mv` to `archive/`).
- Batch updates (one ticket per invocation; batch = shell loop).
- Undo/rollback subcommand (git checkout is the rollback mechanism).
- `--dry-run` flag (validation surfaces errors before any write).

## Decisions

### Decision 1: Single `update` subcommand with allowlist

**Choice:** One `tickets update <id>` subcommand that accepts flags for the
allowlisted fields (`--status`, `--evidence`, `--fix-file`, `--reverify-file`).
Structural fields are not mutable via this command.

**Rationale:** The allowlist is the safety surface. It prevents accidental
corruption of structural fields (title, severity, blocked_by) while providing
a validated, atomic mutation path for the fields that legitimately change
during a ticket's lifecycle (status, Fix, Re-verify, evidence).

**Alternatives considered:**

- Multiple separate commands (`tickets set-status`, `tickets add-evidence`,
  etc.): rejected - surface explosion, each command needs its own rollup
  integration.
- Unrestricted field editing (`tickets update <id> --field value`): rejected -
  no safety boundary, can corrupt structural fields.

### Decision 2: CLI input representation

**Choice:** Scalar flags for `--status` and repeatable `--evidence`. File
paths for `--fix-file` and `--reverify-file` (multi-line body content).

**Rationale:** Multi-line inline strings in bash are a quoting trap
(backticks, `$`, pipes). Forcing file input eliminates an entire class of
input-validation bugs. A pipe can be redirected to a temp file by the caller
(`tickets update DIA-123 --fix-file <(echo "...")`), so stdin support adds
code without adding capability.

**Alternatives considered:**

- Inline multiline fields (`--fix "multi-line text"`): rejected - quoting
  trap.
- Stdin mode: rejected - YAGNI, caller can redirect to temp file.

### Decision 3: Atomic copy-rename mutation model

**Choice:** Copy the ticket file to a temp file in the same directory
(`mktemp -p "$TICKETS_DIR"`), apply all mutations to the temp file, validate
the temp file, then `mv` the temp file over the original (atomic on the same
filesystem). On validation failure, delete the temp file and leave the
original untouched. On `mv` failure, leave the temp file with a `.partial`
suffix for inspection.

**Rationale:** Atomicity prevents partial mutations from corrupting the
ticket file. The copy-rename pattern is a standard Unix idiom for atomic
file updates. The `.partial` suffix on `mv` failure preserves the attempted
mutation for inspection (not silently lost).

**Alternatives considered:**

- In-place edit (sed -i): rejected - not atomic, partial writes can corrupt
  the file.
- Backup-then-edit: rejected - adds complexity (cleanup of backups), and git
  already provides version-controlled rollback.

### Decision 4: Rollup integration

**Choice:** After a successful mutation, trigger a README rollup (reuse
existing `compute_ledger_counts` + `rewrite_readme` machinery) so the index
row's Status column and the count tables stay in sync. If rollup fails, emit
a warning to stderr and exit 2 (partial success - the caller's data is
saved, the README is stale, `tickets rollup` can repair).

**Rationale:** The README rollup contract requires the index row and count
tables to stay in sync with the frontmatter. Reusing the existing rollup
machinery ensures consistency and avoids duplicating the rollup logic. Exit 2
on rollup failure signals the caller to run `tickets rollup` without losing
the mutation.

**Alternatives considered:**

- Skip rollup (require caller to run `tickets rollup` manually): rejected -
  breaks the invariant that `tickets update` leaves the ledger in a
  consistent state.
- Inline rollup (duplicate the logic): rejected - violates DRY, risks drift
  from the canonical rollup implementation.

### Decision 5: Test strategy

**Choice:** Extend the existing bats suite (`scripts/__tests__/tickets.bats`)
with ~15-20 test cases (~300 lines). The fixture-tree isolation pattern is
already established (setup_tree, 4 fixture tickets DIA-130..133, fake README
with all-zero counts).

**Rationale:** Adding a new test file would duplicate setup for no gain. The
existing suite's isolation pattern (fixture tree, fake ledger) is the right
seam for testing `cmd_update()`.

**Alternatives considered:**

- New test file (`scripts/__tests__/tickets-update.bats`): rejected -
  duplicates setup_tree, no gain.

## Seams

**Test seam:** `scripts/__tests__/tickets.bats` - the existing bats suite for
`scripts/tickets`. The new tests extend this suite with test cases for
`cmd_update()`.

**Public boundary:** the `tickets update` CLI surface is the public boundary.
The internal implementation (`cmd_update()` function, helper functions for
mutation and validation) is not a public boundary.

## Risks / Trade-offs

**Risk:** Concurrent updates on the same ticket can race. The copy-rename
atomicity model prevents corruption, but the second update may overwrite the
first's changes.
→ **Mitigation:** The ticket dir is version-controlled, and concurrent
updates on the same ticket are a workflow error, not a tooling error. The
delegation-observer plugin's lease mechanism (COORDINATION.md) is the
workflow-level guard. No tooling mitigation needed.

**Risk:** Legacy tickets (DIA-001..049, v1 schema, no session attribution
block) may not have an `evidence:` field. If `--evidence` is used on a v1
ticket, the command must append an `evidence:` line without restructuring the
frontmatter.
→ **Mitigation:** If `evidence:` is missing, append it after the `updated:`
line (before the first `---` separator). This keeps the frontmatter valid
without restructuring the ticket.

**Risk:** Tickets created before the Fix/Re-verify template was standardized
may lack `## Fix` or `## Re-verify` sections. If `--fix-file` or
`--reverify-file` is used on such a ticket, the command must append the
section.
→ **Mitigation:** If the section heading is missing, append it at the end of
the file (after the last line). This handles legacy tickets without breaking
the template contract.

**Trade-off:** The command does not provide field removal (no
`--remove-evidence`, no `--clear-fix`). If a caller needs to remove an
evidence entry or rewrite Fix, they must hand-edit the file.
→ **Acceptable:** Field removal is rare, and hand-editing is acceptable for
rare operations. The command is append-only for evidence, replace-only for
Fix/Re-verify. Adding removal capability would double the surface area for
a rare use case (YAGNI).

**Trade-off:** The command does not provide a `--dry-run` flag. Validation
surfaces errors before any write, but the caller cannot preview the full
mutation without actually running it.
→ **Acceptable:** A full dry-run would duplicate the mutation path for no
gain. The caller can inspect the ticket before/after with `tickets show
<id>`. Validation catches the common errors (bad status, non-ASCII, file not
readable).

## Migration Plan

**Deployment:** the change is additive (new subcommand). No migration needed.
The existing `scripts/tickets` CLI continues to work as before. The new
`update` subcommand is available immediately after the change is merged.

**Rollback:** revert the commit. The `update` subcommand is removed, and the
existing subcommands continue to work. No data migration, no state to roll
back.

**Open Questions:** none.
