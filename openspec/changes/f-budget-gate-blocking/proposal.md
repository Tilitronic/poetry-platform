# Proposal: F budget gate - report-only to blocking

## Why

The F binding budget from the de-bloat audit (prod net LOC <= 0 vs baseline 5900,
shell LOC monotonic vs 4037, no test-scaffold duplication vs 515 LOC) is today
enforced only by hand-recorded numbers in ticket Re-verify blocks - no script or
CI enforcement exists. Promotion report-only -> blocking was APPROVED IN PRINCIPLE
(DIA-260903-o7n0, 2026-09-09) for pure-refactor/test-debloat scope only, with the
D4 review-verification precondition satisfied (D4 chain 2350ee8 + 921394d +
e3744fa + a1fffb2, auditor close-out CLOSED). Without a machine gate, the next
phase's de-bloat gains can silently regress; with a naive global LOC gate, normal
feature work would be blocked - so the gate needs a reliable scope signal, which
does not exist anywhere today.

## What Changes

- New gate script `scripts/check-budget-gate.sh` (name per design.md) that
  measures the F budgets against a committed, ticket-bound baseline manifest
  `scripts/budget-baselines.json` (jq-parsed; jq is an existing `make
test-shell` prerequisite).
- New blocking enforcement in a **commit-msg git hook** (husky): the trailer
  contract `Budget-Scope: refactor|test-debloat|feature` decides whether the
  production-LOC budgets (A, C) apply; absent trailer = feature scope = A/C
  report-only. A refactor/test-debloat trailer without a matching approved
  manifest entry fails CLOSED.
- Duplication budget (B) blocks **unconditionally** for commits touching scoped
  plugin test paths, using a normalize-then-fixed-string detector (whitespace
  stripped, quote variants folded) over approved, semantically narrow patterns
  from the manifest; violation = matched-file count strictly above the
  per-pattern baseline (newly-introduced only).
- Exception flow: `Budget-Exception: DIA-NNN` trailer, valid only after a
  well-formed `Budget-Scope` trailer and a matching approved manifest have both
  resolved (no rescue); the exception ticket must carry a developer-approved
  record (reason, allowed delta, scoped paths, one-commit or expiry
  applicability). Manifest init/edit commits require the normal refactor trailer
  plus matching ticket, never Budget-Exception as bootstrap bypass.
- Measurement target: staged content via `git show :<path>` over the bounded
  scoped file set - the gate measures exactly what becomes history.
- Defense-in-depth: the gate gains a `--range <revs>` mode wired into the
  existing `scripts/verify-pre-push.sh` chain; pre-push and CI ALWAYS run in
  blocking mode and ignore the kill-switch.
- Rollback kill-switch: `BUDGET_GATE_MODE=report` downgrades the local hook to
  report-only (never off) and prints an explicit warning with the reason on
  every activation.
- Worktree propagation: `scripts/worktrees.sh` hook-copy list extended to the
  new `.husky/commit-msg` hook so fresh worktrees cannot bypass the gate.
- Hermetic bats suite `scripts/__tests__/budget-gate.bats` covering the
  mandated negative-fixture battery plus fail-closed edges, with every sub-gate
  validated in both directions (injected FAIL + real PASS).

## Capabilities

### New Capabilities

- `commit-budget-gate`: Commit-time enforcement of the F binding budget -
  scope-trailer contract, baseline-manifest authority, fail-closed rules,
  duplication detection semantics, exception flow, kill-switch and
  defense-in-depth range checking.

### Modified Capabilities

(none - `openspec/specs/` contains only `container-engine-socket-selection`,
untouched by this change)

## Impact

- `scripts/`: new gate script + new baseline manifest + new bats file
  (auto-discovered by `make test-shell`).
- `.husky/commit-msg`: new tracked hook invoking the gate (follows existing
  husky conventions, including sourcing `scripts/guards/home-qualt.sh`).
- `scripts/verify-pre-push.sh`: invokes the gate in `--range` mode as part of
  the push chain.
- `scripts/worktrees.sh`: hook-copy list gains the commit-msg hook (fresh
  worktrees otherwise silently bypass commit gates - the DIA-094 precedent).
- `docs/dev-infra-audit/tickets/`: exception tickets must carry the structured
  approval record; no ledger schema change (free-text section convention).
- Not affected: plugin production/test code itself, `make test-config` gates,
  the delegation-observer runtime.

## Rollback plan

Per the dev-infra rule (AGENTS.md 2.4) and interview Q6:

1. Emergency (instant, machine-local): `BUDGET_GATE_MODE=report` - the hook
   keeps measuring and warns, never blocks; it can never disable the gate
   entirely, and pre-push/CI range mode ignores the switch.
2. Persistent downgrade: manifest `mode` change through the normal ticket flow.
3. Full removal: revert the hook-wiring commit (single hook file + one
   verify-pre-push.sh line); the gate script and manifest are inert without
   the hook.

## Testing Decisions

A good test for this change is a hermetic fixture git repo (copy of the gate
script + hooks under `$BATS_TEST_TMPDIR`, real commits driven through the
commit-msg hook) proving BOTH directions for every sub-gate: a clean commit
exits 0 and an injected violation exits non-zero - the R-B acceptance the
ticket already requires of the budget gate. Modules tested: trailer parsing and
scope resolution, manifest backing (fail-closed on missing/malformed/mismatch),
staged measurement of A/C, normalize-then-fixed-string detection of B
(including the reformat-evasion fixture), exception validation (approval-record
fields, scope-required rule), kill-switch warning behavior, and `--range` mode.
Prior art: `scripts/__tests__/post-push.bats` (hermetic fixture repo + hook
copy pattern), `scripts/__tests__/check-orchestrator-prompt-drift.bats`
(Makefile/hook wiring assertions), `scripts/validate-grilling-gate.sh` /
`validate-decision-variants.sh` (`TICKETS_DIR` env override for hermetic
ticket fixtures).

## Alternatives considered

- Global repository mode flag in the manifest (toggle blocking for a campaign
  window): rejected - the approval scopes blocking per-change ("pure-refactor/
  test-debloat scope only"), a stale flag falsely blocks feature work, an
  off flag blocks nothing (Tier-1: DIA-260903-o7n0 promotion block, 2026-09-09).
- Heuristic auto-classification of commit scope (diff-shape inference):
  rejected - production refactors touch production files exactly like features
  do, and net-LOC sign lets a bloaty refactor that also deletes comments
  escape; [INFERENCE] (not the sole basis - the failure modes are concrete).
- Regex-tolerant or AST duplication detector: rejected for now -
  normalize-then-fixed-string defeats the entire reformat threat class with no
  regex/AST machinery; AST is the documented upgrade path if a real bypass is
  observed (Tier-1: audit report section 7.3 measurement commands).
- Enforcement in pre-commit or `make test-config`: rejected - pre-commit runs
  before the message file exists (no trailer access); test-config validates
  tree state, not commits (developer ruling, Q4a).
- Status-quo / do nothing (keep report-only): rejected - de-bloat regressions
  stay hand-caught only, and the approved promotion (with its D4 precondition
  now met) goes unimplemented; acceptable only as the fallback if the blocking
  battery proves false-positive-prone in practice.
  Chosen option: per-commit Budget-Scope trailer + ticket-bound baseline
  manifest, commit-msg enforcement - because the trailer makes scope a
  per-change property as the approval requires, the manifest keeps one
  authority for numbers and backing, and fail-closed backing means an
  unattested or malformed refactor claim cannot slip through.
