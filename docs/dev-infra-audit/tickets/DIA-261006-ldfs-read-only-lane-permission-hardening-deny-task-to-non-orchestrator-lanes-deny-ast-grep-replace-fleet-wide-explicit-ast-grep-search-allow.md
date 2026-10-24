# DIA-261006-ldfs - read-only lane permission hardening: deny task to non-orchestrator lanes, deny ast_grep_replace fleet-wide, explicit ast_grep_search allow

---

id: DIA-261006-ldfs
title: "read-only lane permission hardening: deny task to non-orchestrator lanes, deny ast_grep_replace fleet-wide, explicit ast_grep_search allow"
area: scripts
severity: Medium
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-10-06
source: inventory
date: 2026-10-06
created: 2026-10-06
updated: 2026-10-06

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

Read-only lanes inherit OpenCode's built-in baseline (\* allow), so an undeclared permission key resolves to ALLOW. Two consequences found by the 2026-10-06 read-only permission audit:

- task (delegation) is effectively enabled on code-navigator, observer, designer, memory-manager, council and coder - none declares a task key, so all inherit allow. A read-only lane with task enabled can delegate to a write-capable lane and mutate the repo transitively, defeating its own edit:deny.
- ast_grep_replace is effectively enabled on every agent except orchestrator and ai-auditor. Its OMO implementation never calls a permission ask, so it can be neither path-scoped nor ask-gated: any grant is a silent, unrestricted write.

Decisions: delegation is the orchestrator's monopoly; ast_grep_replace is denied fleet-wide; ast_grep_search stays allowed fleet-wide (read-only, in active use) and is made explicit.

## Change set

A. Add "task": "deny" to agent.<name>.permission for: code-navigator, observer, designer (that block has no permission key - add the object), memory-manager, council, coder. The orchestrator keeps its task allow-list map.
B. Add a GLOBAL "ast_grep_replace": "deny" in the global permission block (covers every agent, including coder-escalated, so no coder/coder-escalated lockstep mirroring is needed).
C. Add a GLOBAL "ast_grep_search": "allow" (explicit intent instead of an inherited baseline default).
C+1. Add "ast_grep_search": "deny" to the orchestrator permission block - an agent deny wins over the global allow (findLast). The orchestrator denies grep and path-scopes read/glob by design; a codebase AST search tool contradicts that.
C+2. Add "ast_grep_search": "deny" to the conspecter permission block - same override. Pure synthesis over already-archived knowledge/<resid>/sources/, no search step in its workflow.
D. Fix the stale comment at opencode.jsonc:313-315 which claims coder "must ... dispatch subagents" - reworded to state coder does NOT dispatch (delegation is the orchestrator's monopoly; its prompt only says "escalate to orchestrator", a return message, and subagent_depth=1 already blocked nested spawns at runtime).

## Gate verdict

**PASS.** `make test-config` exit 0 on 2026-10-06:

- `ok: coder/coder-escalated permission lockstep (2 keys compared, task-related ignored)` - the GLOBAL ast_grep_replace key never reaches the lockstep comparison, confirming design B.
- `22 agents audited, 0 gaps, 362 warnings` (scripts/audit-agent-tool-coverage.sh - 0 HARD gaps; the 362 warnings are unrelated unlisted non-write-capable tools).
- `PASS: N2 orchestrator task allow-list admits no build/plan/scout`.
- validate-agent-names, validate-decision-variants (406/406), validate-grilling-gate (406/406), validate-plugin-structure all PASS.
- Runtime assertion via `opencode debug agent <name>`: ast_grep_replace=false on all 13 checked agents; task=false on all 12 non-orchestrator agents; orchestrator keeps its 23-rule task map; ast_grep_search=false only on orchestrator + conspecter, true elsewhere.

## Deferred drifts (routed to a separate follow-up ticket)

Three undeclared-permission gaps were found by the same audit and deliberately NOT fixed here, to keep this change set to the delegation/AST surface:

1. `envsitter_*` mutators - only ai-auditor and orchestrator declare deny; every other agent inherits allow.
2. coder `webfetch` / `websearch` - both undeclared on the implementation lane (allow), while the orchestrator denies websearch.
3. designer `bash` - the designer block had no permission key at all; this ticket added only `task`, so designer bash is still allow.

Tracked in a separate follow-up ticket; NOT in this change set.

## Verification

- [x] make test-config exit 0 (covers validate-opencode-config lockstep, audit-agent-tool-coverage, builtin containment) - EXIT=0, 2026-10-06.
- [x] opencode debug agent <name> for every agent: ast_grep_replace=false for ALL; task=false for every non-orchestrator agent (orchestrator keeps its allow-list map); ast_grep_search=false ONLY for orchestrator and conspecter, true elsewhere.
- [ ] Restart + functional smoke is a developer step.

## Evidence

- Read-only permission audit, 2026-10-06 (opencode.jsonc citations; effective permission matrix; ast_grep_replace = 1 dry-run call ever with 0 writes; ast_grep_search = 9 calls).
- Delegation-dependency check, 2026-10-06 (no lane prompt instructs delegation; council is synthesis-only; only the orchestrator has ever called task - 1005 calls).
- .opencode/learnings/external-patterns/2026-10-06-undeclared-permission-baseline-allow-drift.md (section 2.5 step 0 registration) + .opencode/learnings/index.md entries.
- .opencode/memory/repo.md SECURITY repo fact.
- Governing study ticket: DIA-260929-nc6w (Analysis A, code-navigator).

## Risks

- RISK: the coder/coder-escalated permission lockstep excludes only the task key; a GLOBAL ast_grep_replace deny avoids the lockstep entirely.
- RISK: council is mode "all" and could be selected as primary; its prompt has no tools and no dispatch flow, and it has 0 task calls ever.
- ast_grep_search is deliberately NOT denied fleet-wide: it is read-only and in active use (orchestrator + conspecter carry the only two denies).
- A global deny is a DEFAULT, not a lock: a later per-agent `ast_grep_search: allow` / `ast_grep_replace: allow` would silently re-open the tool (agent rules append after global rules, findLast wins). Documented in the learnings entry.

## Fix

Applied 2026-10-06 in `.opencode/opencode.jsonc` (change set A, B, C, C+1, C+2, D) plus `.opencode/learnings/external-patterns/2026-10-06-undeclared-permission-baseline-allow-drift.md` and `.opencode/learnings/index.md`. `make test-config` exit 0; `opencode debug agent` assertion table green.

## Re-verify

> To be filled at re-verify time.
