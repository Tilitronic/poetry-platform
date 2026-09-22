# Delta spec: commit-budget-gate

## Purpose

Commits to this repository enforce the F binding budget (production LOC
ceilings and test-scaffold duplication limits) at commit time, distinguishing
pure-refactor/test-debloat work from feature work via an explicit scope trailer
backed by a ticket-bound baseline manifest, so de-bloat gains cannot silently
regress while normal feature work is never blocked by LOC ceilings.

## ADDED Requirements

### Requirement: Commit scope trailer contract

The gate SHALL read commit scope from a `Budget-Scope:` trailer in the commit
message with allowed values `refactor`, `test-debloat`, and `feature`. A commit
with no `Budget-Scope` trailer SHALL be treated as feature scope for the
production-LOC budgets (measured and reported, never blocked). A
`refactor`/`test-debloat` scope claim SHALL be honored only when a matching
approved entry exists in the baseline manifest; a missing, malformed, or
mismatched manifest backing SHALL fail closed (commit blocked).

Seam: commit-msg hook (message file + staged tree).

#### Scenario: Feature commit without trailer is reported, not blocked

- **GIVEN** a commit that grows production LOC above the manifest ceiling
- **WHEN** the commit message carries no `Budget-Scope` trailer
- **THEN** the gate exits 0 and prints the measured production-LOC report line

#### Scenario: Refactor trailer without manifest backing fails closed

- **GIVEN** a commit message carrying `Budget-Scope: refactor`
- **WHEN** the baseline manifest contains no approved entry matching the
  declared refactor campaign
- **THEN** the gate blocks the commit with a fail-closed reason naming the
  missing manifest backing

#### Scenario: Approved refactor commit exceeding the LOC ceiling is blocked

- **GIVEN** a commit with `Budget-Scope: refactor` and a matching approved
  manifest entry, touching scoped production paths
- **WHEN** the staged production LOC total exceeds the manifest ceiling
  (de-bloat regression)
- **THEN** the gate blocks the commit (negative fixture (a))

### Requirement: Ticket-bound baseline manifest is the numeric authority

The gate SHALL take all budget numbers from a committed baseline manifest: the
production-LOC ceiling (net <= 0 vs baseline 5900; current measured 5814), the
shell-LOC monotonic ceiling (baseline 4037), and one entry per approved
duplication pattern with its per-pattern baseline file count and its single
authorized site. Every manifest entry SHALL be bound to the approving DIA
ticket. The manifest SHALL be the only source of these numbers; no value may be
hardcoded in the gate.

Seam: baseline manifest file consumed by the gate CLI.

#### Scenario: Manifest edit without proper scope trailer is blocked

- **GIVEN** a staged change to the baseline manifest
- **WHEN** the commit message lacks a well-formed pure-refactor
  `Budget-Scope` trailer with a matching ticket
- **THEN** the gate blocks the commit, and a `Budget-Exception` trailer alone
  never authorizes a manifest edit (no bootstrap bypass)

### Requirement: Production-LOC budgets are scope-gated

Budgets A (production net LOC) and C (shell LOC monotonic) SHALL block only
commits whose scope resolves to manifest-backed `refactor`/`test-debloat`.
Feature-scope commits SHALL never be blocked by A or C regardless of LOC
growth, which is reported for the record.

Seam: commit-msg hook (message file + staged tree).

#### Scenario: Normal feature change adding production LOC is not blocked

- **GIVEN** a commit adding production LOC under the delegation-observer
  surface
- **WHEN** the scope resolves to feature (no trailer, or `Budget-Scope:
feature`)
- **THEN** the gate exits 0 with a report line (negative fixture (b))

### Requirement: Duplication budget is unconditional on scoped test paths

For any commit touching scoped plugin test paths, the gate SHALL block when a
known duplication pattern's matched-file count is strictly greater than that
pattern's baseline count in the manifest (newly-introduced duplication only;
grandfathered baseline counts pass). The occurrence in a pattern's authorized
site SHALL never count as a match. Detection SHALL be limited to the approved,
semantically narrow pattern set in the manifest; generic textual similarity
SHALL NOT be a blocking rule.

Seam: commit-msg hook (staged tree over scoped test paths).

#### Scenario: Third copy of a known scaffold is blocked on a feature commit

- **GIVEN** a pattern whose baseline count is 2 (excluding its authorized site)
- **WHEN** a feature-scope commit introduces the pattern in a third file under
  a scoped test path
- **THEN** the gate blocks the commit even though A/C do not apply

#### Scenario: Duplication exactly at baseline passes

- **GIVEN** a pattern at its baseline matched-file count
- **WHEN** a commit touching scoped test paths does not increase that count
- **THEN** the gate exits 0 for that pattern

### Requirement: Duplication detection survives reformatting

The detector SHALL normalize staged file content by removing all whitespace and
folding all quote variants to a single character before matching, and SHALL
match each pattern's canonical literal as a fixed string against the normalized
content. Pure reformatting of a duplicated scaffold (re-indentation,
line-splitting between tokens, quote-style changes) SHALL NOT evade detection.

Seam: commit-msg hook (staged tree over scoped test paths).

#### Scenario: Reformatted duplicate still blocks

- **GIVEN** a duplicated scaffold copy that has been re-indented, had its
  quotes flipped, and its call split across lines
- **WHEN** the commit is gated
- **THEN** the detector counts the file as a match and the commit is blocked
  (negative fixture (d))

### Requirement: Exception flow requires scope, manifest, and an approval record

A `Budget-Exception: DIA-NNN` trailer SHALL exempt a commit from blocking only
after a well-formed `Budget-Scope` trailer and matching approved manifest
backing have both resolved successfully; the exception never rescues a
missing, malformed, or mismatched scope claim. Every exception - including for
unconditional duplication blocks - SHALL require an explicit valid scope
trailer; trailer-less commits SHALL have no exception path. The referenced
ticket SHALL exist and SHALL contain a developer-approved exception record with
reason, allowed delta, scoped paths, and one-commit or expiry applicability;
existence and status alone SHALL NOT suffice. An accepted exception applies
only per its recorded applicability (this commit, or until expiry).

Seam: commit-msg hook (message file + ticket ledger + staged tree).

#### Scenario: Approved exception passes

- **GIVEN** a manifest-backed refactor commit that exceeds a budget, carrying
  `Budget-Exception: DIA-NNN` whose ticket holds a complete approval record
  covering the commit's paths and delta
- **WHEN** the gate evaluates the commit
- **THEN** the gate exits 0 with a report line noting the applied exception
  (negative fixture (c))

#### Scenario: Exception without scope trailer is blocked

- **GIVEN** a commit violating the duplication budget and carrying
  `Budget-Exception: DIA-NNN` with a valid ticket
- **WHEN** the commit message has no `Budget-Scope` trailer
- **THEN** the gate blocks the commit

#### Scenario: Exception ticket without approval record is blocked

- **GIVEN** a commit with valid scope and manifest backing and a
  `Budget-Exception: DIA-NNN` trailer
- **WHEN** the referenced ticket lacks any required approval-record field
  (reason, allowed delta, scoped paths, or applicability)
- **THEN** the gate blocks the commit

### Requirement: The gate measures staged content, not the working tree

All budget measurements SHALL be computed from the staged tree (the exact
content that will become history), not from working-tree files, so a dirty
working tree can neither falsely block nor falsely pass a commit.

Seam: commit-msg hook (staged tree).

#### Scenario: Unstaged drift does not affect the verdict

- **GIVEN** a staged commit that satisfies all budgets while the working tree
  holds additional unstaged LOC growth
- **WHEN** the gate evaluates the commit
- **THEN** the gate exits 0 based on staged content only

### Requirement: Enforcement surfaces and defense-in-depth

Blocking enforcement SHALL run in the commit-msg hook (the only pre-history
surface with access to the message file); pre-commit and `make test-config`
SHALL NOT host the budget gate. The gate SHALL additionally support a range
mode used by the pre-push chain and CI that re-checks every commit in the
pushed range; range mode SHALL always run blocking and SHALL ignore the
report-only kill-switch, so a `--no-verify` bypass cannot escape policy. Fresh
git worktrees SHALL receive the commit-msg hook via the worktree setup copy
list.

Seam: gate CLI (hook invocation and `--range` invocation).

#### Scenario: Hook-bypassed commit is caught at push

- **GIVEN** a budget-violating manifest-backed refactor commit created with
  `git commit --no-verify`
- **WHEN** the branch is pushed and the pre-push chain runs the gate in range
  mode
- **THEN** the push is blocked even if `BUDGET_GATE_MODE=report` is set
  locally

### Requirement: Report-only kill-switch never disables the gate

A local `BUDGET_GATE_MODE=report` setting SHALL downgrade only the commit-msg
hook to report-only: every budget SHALL still be measured, every violation
SHALL still be printed, and an explicit warning naming the switch and its
reason SHALL be emitted whenever it is active. The switch SHALL NOT be able to
turn the gate off, and SHALL NOT affect pre-push range mode or CI.

Seam: commit-msg hook (environment).

#### Scenario: Kill-switch warns but does not silence

- **GIVEN** `BUDGET_GATE_MODE=report` and a budget-violating refactor commit
- **WHEN** the hook runs
- **THEN** the commit is allowed, and the output contains both the violation
  report and an explicit kill-switch warning line
