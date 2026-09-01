# DIA-260827-6wvm - Embedded OMO suite excluded from root tests hides orchestrator alias regression

---

id: DIA-260827-6wvm
title: "Embedded OMO suite excluded from root tests hides orchestrator alias regression"
area: tests
severity: High
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: DIA-260827-wfcx
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-27
source: baseline
date: 2026-08-27
created: 2026-08-27
updated: 2026-08-27

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

Root workspace package.json:65-68 includes only apps/_ and packages/_; the embedded OMO suite defines its own bun test at .opencode/oh-my-opencode-slim/package.json:64-66. pnpm test exits 0 while the embedded suite exits 1 (1366 pass, 1 fail). The failing test .opencode/oh-my-opencode-slim/src/agents/display-name.test.ts:178-196 proves the displayed orchestrator alias is incorrectly hidden; index.ts:670-678 reuses the boss config with hidden:true for both visible alias and internal key. Impact: root and pre-push JS gates report green while configured orchestrator display aliases can disappear from host UI.

Reaudit (DIA-260827-wfcx, 2026-08-31) confirms: pnpm-workspace.yaml:1-3 excludes the embedded OMO suite; direct bun test shows 1366 pass / 1 fail with the regression at .opencode/oh-my-opencode-slim/src/agents/display-name.test.ts:190-192 and cloning logic src/agents/index.ts:670-678. Impact: pnpm test and pre-push can be green while the user-visible orchestrator alias disappears. Correct fix: repair the visible alias cloning and add OMO tests plus typecheck to the aggregate gate/CI.

## Verification

Embedded bun test plus typecheck wired into a root/Make/pre-push target; visible SDK config cloned with hidden removed, hidden:true retained only on the internal alias; pnpm test and the new target both green; display-name.test.ts passes.

## Fix

Repair the visible alias cloning (remove hidden:true on the visible alias, keep it only on the internal key) and add the embedded OMO bun test plus typecheck to the aggregate gate/CI so the orchestrator display alias regression is caught.

## Re-verify

> To be filled at re-verify time.
