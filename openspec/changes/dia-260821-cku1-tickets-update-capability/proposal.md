## Why

Agents and developers currently hand-edit ticket markdown files to update
status, fill Fix/Re-verify evidence, or bump the `updated:` timestamp. This
bypasses the README rollup contract (the index row's Status column drifts
from the frontmatter), skips input validation (typos in status values,
non-ASCII leaks), and leaves no audit trail of what changed. A single
controlled `scripts/tickets update` subcommand provides a validated, atomic,
rollup-aware mutation path for the fields that legitimately change during a
ticket's lifecycle.

## What Changes

- Add a `tickets update <id>` subcommand to `scripts/tickets` that mutates
  a controlled allowlist of fields in an existing DIA ticket file.
- Allowlisted mutations: `status:` frontmatter field, `updated:` timestamp
  (always set to today), `evidence:` frontmatter array (append, dedup),
  `## Fix` body section (replace from file), `## Re-verify` body section
  (replace from file).
- Structural fields are NOT mutable via this command: `id`, `title`, `area`,
  `severity`, `blocked_by`, `parent_epic`, `gate_*`, `discovered`, `source`,
  `date`, `created`, session-attribution block, `## Description`,
  `## Verification`. These remain hand-edit only.
- Atomic copy-rename mutation model: write to a temp file in the same
  directory, validate, then `mv` over the original. On validation failure
  the original is untouched. On `mv` failure the temp file is left with a
  `.partial` suffix for inspection.
- After a successful mutation, trigger a README rollup (reuse existing
  `compute_ledger_counts` + `rewrite_readme` machinery) so the index row's
  Status column and the count tables stay in sync.
- ASCII-only input and output (DIA-079). Non-ASCII in `--evidence` values
  fails validation. Non-ASCII in `--fix-file` / `--reverify-file` contents
  is sanitized on write (replaced with `?`, warning to stderr).
- Bash-3 compatible (no `[[ ]]`, no associative arrays, no
  mapfile/namerefs/compgen) - same contract as the rest of `scripts/tickets`.
- No new dependencies (coreutils only: date/grep/sed/sort/tr/mktemp/mv/cp).

## Capabilities

### New Capabilities

None. This is a dev-infra tooling change (new CLI subcommand). No spec-level
behavior changes to any existing capability.

### Modified Capabilities

None.

## Impact

- **Code:** `scripts/tickets` gains a `cmd_update()` function (~200 lines)
  and a `update` entry in the `main()` dispatch table. Help text extended.
- **Tests:** `scripts/__tests__/tickets.bats` gains ~15-20 test cases
  (~300 lines) covering happy path, validation failures, atomicity, rollup
  integration, and ASCII sanitization.
- **APIs:** new CLI surface: `tickets update <id> [--status <STATUS>]
[--evidence <uri>]... [--fix-file <path>] [--reverify-file <path>]`.
- **Dependencies:** none added.
- **Systems:** README rollup contract is preserved (index row + count tables
  stay in sync with frontmatter after status changes).

## Alternatives considered

- **Multiple separate commands** (`tickets set-status`, `tickets
add-evidence`, `tickets set-fix`, `tickets set-reverify`): rejected -
  surface explosion, each command needs its own rollup integration, and the
  common case (status + fix + reverify + evidence in one call) requires
  four invocations. Evidence: Tier-1 (interview Q2 - developer agreed
  single command is simpler).
- **Unrestricted field editing** (`tickets update <id> --field value`):
  rejected - no safety boundary, can corrupt structural fields (title,
  severity, blocked_by). The allowlist is the safety surface. Evidence:
  Tier-1 (interview Q3 - developer agreed allowlist is the right boundary).
- **Inline multiline fields** (`--fix "multi-line text"`): rejected -
  multi-line inline strings in bash are a quoting trap (backticks, `$`,
  pipes). Forcing file input (`--fix-file <path>`) eliminates an entire
  class of input-validation bugs. Evidence: Tier-1 (interview Q2 - developer
  agreed file input is safer).
- **Status-quo / do nothing** (continue hand-editing markdown): rejected -
  README drift, no validation, no audit trail, no atomicity. The closure
  lane and fix/re-verify workflow require these mutations; doing them by
  hand is error-prone. Evidence: Tier-1 (interview Q1 - problem statement
  confirmed by developer).

Chosen option: single controlled `update` subcommand with allowlist -
because it provides validated, atomic, rollup-aware mutations for the
fields that legitimately change during a ticket's lifecycle, without
exposing structural fields to accidental corruption.

## Testing Decisions

**What makes a good test for this change:** the existing bats suite
(`scripts/__tests__/tickets.bats`) already establishes the isolation
pattern (fixture tree with 4 tickets DIA-130..133, fake README with
all-zero counts, script copied into temp tree). A good test extends this
pattern: set up a fixture ticket, run `tickets update` with specific flags,
assert the file contents match expectations (status line rewritten, updated
bumped, evidence appended, Fix/Re-verify sections replaced, README index
row updated, count tables updated).

**Which modules will be tested:** the `cmd_update()` function in
`scripts/tickets`. The existing rollup machinery (`compute_ledger_counts`,
`rewrite_readme`) is already tested by the existing `cmd_rollup` tests; the
new tests verify that `cmd_update` calls it correctly, not that the rollup
logic itself works.

**Prior art in the codebase:** `scripts/__tests__/tickets.bats` (1320 lines,
established isolation pattern, fixture-tree strategy). The new tests follow
the same pattern: `setup_tree` creates the fixture, individual test cases
run `tickets update` and assert outcomes.
