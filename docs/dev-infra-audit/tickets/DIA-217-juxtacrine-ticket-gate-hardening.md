# DIA-217 - Juxtacrine: hard-block dispatch without ticket via synchronous plugin hook

---

id: DIA-217
title: "Juxtacrine: hard-block dispatch without ticket via synchronous plugin hook"
area: opencode-config
severity: Medium
status: OPEN
blocked_by: [DIA-211]
discovered: 2026-08-18
gate_state: skipped
gate_triggers: [cross-boundary]

# --- Session Attribution ---

session_id: ""
lane_id: ""
agent: ""
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: ""
files_touched: []
artifacts: []
evidence: []

---

## Description

Phase 1 of DIA-211 harness evolution. Harden DIA-063 ticket gate via synchronous plugin hook.

Currently, the DIA-063 gate is a soft correlation check inside the ai-specialist's prompt. This phase moves it to a hard synchronous hook in the `delegation-observer` plugin that fires BEFORE the LLM context is loaded.

**Concrete change:**

- Add `dispatch.before` hook in delegation-observer
- Check JSON payload for valid `ticket_id` (DIA-\d+ format)
- If missing: emit `gate.blocked` event, log to registry, return error to task() caller
- If present but ticket not found in `docs/dev-infra-audit/tickets/`: emit `gate.warn` (weak correlation)
- If present and ticket found: proceed normally

**Files to modify:**

- `.opencode/plugins/delegation-observer.ts` (add dispatch.before hook)
- `.opencode/plugins/__tests__/delegation-observer.*.test.mjs` (add tests)

## Verification

- `make test-config` exit 0
- Plugin typecheck + lint exit 0
- Test: mock dispatch without ticket_id -> blocked
- Test: mock dispatch with valid ticket_id -> proceeds
- Test: mock dispatch with non-existent ticket_id -> warn (not block)

## Fix

Implemented: `tool.execute.before` gate in delegation-observer plugin.
Four review fixes applied:

1. **Prefix match false positive** (Major): Replaced `startsWith(normalizedId)` with exact regex match `/^DIA-(\d+)/i` to prevent DIA-21 matching DIA-217.
2. **Reuse extracted args** (Minor): Replaced duplicate `diaArgs` extraction with existing `taskArgRecord`/`taskSubagent` from hook top.
3. **Extract constant** (Minor): Added `TICKETS_DIR_REL` module-level constant; replaced both inline `"docs/dev-infra-audit/tickets"` occurrences.
4. **Fail-soft logging** (Minor): Changed bare `catch {}` to `catch (err) { appendRow({ event: "gate_scan_failed", error: String(err) }) }`.

**Test file:** `.opencode/plugins/__tests__/dia217-ticket-gate.test.mjs` (5 tests)

## Re-verify

- `make test-config`: DIA-217 passes; 3 pre-existing failures (DIA-218/219/220 `gate_state: pending`)
- Typecheck: pre-existing errors only (module resolution, downlevelIteration)
- Lint: pre-existing errors only (unused vars, unreachable code)
- DIA-217 tests: 5/5 pass
- Existing tests: 10/10 pass (no regressions)
- `git status`: only intended files changed
