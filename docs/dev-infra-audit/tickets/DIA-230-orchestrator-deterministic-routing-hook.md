# DIA-230 - orchestrator-deterministic-routing-hook

---

id: DIA-230
title: "orchestrator-deterministic-routing-hook"
area: scripts
severity: Critical
status: CLOSED
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-18
source: baseline
date: 2026-08-18
created: 2026-08-18
updated: 2026-08-18

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

Delegation-observer plugin lacks mechanical enforcement of AGENTS.md section 2.5 routing rules -- orchestrator bypassed @ai-specialist gate and @ai-auditor review for agent infrastructure changes (DIA-204/212/214/215/229), sending @coder directly on 'investigate and fix' tasks.

This violates the deterministic routing contract: agent infra changes MUST route through @ai-specialist (research) -> user decision -> @coder (exact instructions) -> @ai-auditor (independent review).

The plugin's `tool.execute.before` hook should detect when @coder is dispatched on config-work (file paths matching `.opencode/plugins/`, `.opencode/oh-my-opencode-slim/`, `orchestrator_append.md`) without a prior @ai-specialist dispatch in the session, and emit a `ROUTING_VIOLATION` warning to `registry.jsonl` + `messages.jsonl`.

This is a mechanical enforcement gap -- the orchestrator LLM cannot be trusted to self-police routing rules under context pressure.

## Verification

- [ ] `tool.execute.before` hook detects @coder dispatches on config-work file paths
- [ ] Session is scanned for prior @ai-specialist dispatch before allowing config-work @coder
- [ ] ROUTING_VIOLATION event emitted to `registry.jsonl` on violation
- [ ] ROUTING_VIOLATION event emitted to `messages.jsonl` on violation
- [ ] Non-config-work @coder dispatches are not affected (no false positives)
- [ ] `make test-infra` passes
- [ ] `make test-shell` passes

## Fix

Upgraded routing-order gate from advisory to blocking. `tool.execute.before` hook now throws an actionable error when @coder is dispatched on config-work (file paths matching `.opencode/`, `AGENTS.md`) without a prior @ai-specialist gate review in the session. Non-config-work dispatches are unaffected.

**Files:** `scripts/__tests__/routing-order-gate.test.mjs`, `.opencode/oh-my-opencode-slim/orchestrator_append.md`, `AGENTS.md`

## Re-verify

- `make test-config` passes (56 pass, 0 fail)
- `bun test scripts/__tests__/routing-order-gate.test.mjs` passes
