# DIA-260909-9c9x - whitespace polish for already-committed files

---

id: DIA-260909-9c9x
title: "whitespace polish for already-committed files"
area: scripts
severity: Low
status: CLOSED
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-09-09
source: inventory
date: 2026-09-09
created: 2026-09-09
updated: 2026-09-09

# --- Session Attribution (v2 schema, optional) ---

session_id: ""
lane_id: ""
agent: ""
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: "" # ISO-8601; set on DISPATCHED, cleared on COMPLETE
files_touched: []
artifacts: []
evidence: []

---

## Description

Whitespace-polish ticket (non-blocking, Low severity) from ponytail audit /tmp/architecture-review-20260909-170245.html (ephemeral; substance carried here). Parent context: DIA-260903-o7n0 de-bloat + observer-lib extraction follow-up.

Apply whitespace polish to already-committed files flagged by the audit and prettier: trailing whitespace, missing final newlines, indentation drift, and prettier-ignore baselines that should be normalized. This is formatting-only - no logic changes.

Scope: files already committed (no new behavior). Audit noted whitespace drift in plugin tests, bats helpers, and generated ledger fixtures. Run prettier (edit-time formatter, DIA-105) and fix any remaining whitespace-only diffs.

Severity Low, non-blocking - can be taken at any time, no dependency on items 2-5 or current push. Safe to batch with other polish commits.

Guard (MANDATORY): do NOT delete the 7 extracted production modules, capability loader guards, or independent checksum logic. Whitespace changes must not touch logic lines beyond formatting.

Campaign ticket DIA-260901-91qy. Item 1 already fixed at 420ce4f.

## Verification

- [ ] `prettier --check` passes on touched files (or edit-time formatter shows no drift)
- [ ] `git diff -w` shows no logic changes (whitespace-only)
- [ ] 7 extracted production modules, capability loader guards, checksum logic untouched
- [ ] No unrelated behavior changes in diff

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.

## Targets

1. .opencode/plugins/**tests**/capability.test.mjs:1 - trailing whitespace / blank first line (delete line 1, file starts at /\*\*).
2. .opencode/plugins/lib/stall-sweep.ts:263 - trailing whitespace (delete line 263, 8 spaces inside try block).
3. .opencode/plugins/lib/ticket-gate.ts:310 - extra blank line at EOF (file ends }\n exactly).
