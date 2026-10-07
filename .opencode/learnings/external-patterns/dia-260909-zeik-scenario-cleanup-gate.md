# Scenario cleanup gate findings - DIA-260909-zeik (2026-09-09)

Source: ai-specialist GO gate
Campaign ticket: DIA-260909-zeik
Lane: docs-only registration (no production code)
Scope: read-only gate + learnings registration. No source edits in this lane.

## Verdict

GO. 0 blockers. 4 minor risks (carry into implementation, none gate-blocking).

## Minor risks

1. LOC range may land -30..-45 vs -45..-70 estimate.
   Report actual LOC delta, never pad to meet an estimate.
2. fail() escape hazard.
   Needs header comment: awaited-body only. fail() must not escape
   the awaited body into unawaited or shared scope.
3. Failure stderr contract-identical, not byte-identical.
   Fix design L76 wording: assert contract-identical stderr behavior,
   not byte-identical output.
4. Lib count 8 vs guard 7.
   Moot, untouched. No action; record only to avoid re-flagging.

## Ground truth (verified)

- Runner absent: no shared scenario runner exists pre-change.
- 24 sites: 4 + 8 + 12 duplicated setup sites.
- 428 lines: 100 + 153 + 175 duplicated setup lines.
- Helper 4 exports: single shared helper with 4 exports covers all sites.
- Bats frozen: harness-scenario bats expectations unchanged.
- Budget-B baseline 0: budget-B grep-needle gate baseline is 0 pre-change.
- Backing test-debloat approved: backing plan test-debloat is approved.
- Fkiy disjoint: fkiy change set is fully disjoint, zero shared files.
- ASCII clean: all touched surfaces ASCII-only verified.
- Mock-before-import preserved: bun mock-before-import ordering preserved.

## Best-practice alignment

- Fowler duplicated code: 24-site / 428-line duplication is the
  duplicated-code smell; extraction into one helper is the textbook fix.
- Ponytail reuse: reuse existing helper shape first; no new abstraction
  beyond the single 4-export helper.
- Best-practices atomic commit: one atomic commit per extraction step,
  each green before the next.
- AGENTS.md 2.4 test + rollback: test strategy plus rollback plan
  required for the change; bats + bun gates are the test leg.
- EBDV compliant: decision variants recorded with abort/status-quo
  option per evidence-backed decision rule.

## Forward-compat note (fkiy)

- Runner composes createTempWorkspace; zero shared files with this slice.
- One-line risk on signature change: if createTempWorkspace signature
  changes, runner call site needs a one-line update. No lockstep needed
  otherwise.

## Decision

- Gate verdict: GO, proceed to implementation lane within stated risks.
- This file is record-only; it makes no source change.
