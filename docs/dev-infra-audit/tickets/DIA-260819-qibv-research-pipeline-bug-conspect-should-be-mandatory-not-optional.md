# DIA-260819-qibv - research pipeline bug: conspect should be mandatory, not optional

---

id: DIA-260819-qibv
title: "research pipeline bug: conspect should be mandatory, not optional"
area: opencode-config
severity: Medium
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-19
source: inventory
date: 2026-08-19
created: 2026-08-19
updated: 2026-08-19

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

The research pipeline skill (`.opencode/skills/research-pipeline/SKILL.md`) has
a Phase 3 "persistence decision" gate that incorrectly treats conspect creation
as optional. After research completes, the orchestrator asks the developer
"KEEP or DELETE?" -- but conspect is the canonical synthesis of research and
should ALWAYS be created. DELETE should never happen (why research if you
won't synthesize?).

**Current behavior (buggy):**

1. Researcher returns findings with PERSISTENCE_RECOMMENDED flag
2. Orchestrator asks developer: "KEEP or DELETE?"
3. Only if KEEP -> dispatch @conspecter

**Expected behavior (correct):**

1. Researcher returns findings
2. @conspecter is AUTOMATICALLY dispatched (no decision needed)
3. Conspect is always created (it's the natural output of research)
4. Analysis is OPTIONAL -- only dispatched when needed (complex trade-offs,
   data visualization, multi-source comparison)
5. When analysis is needed, it should auto-trigger after conspect (no manual gate)

**Root cause:** The research-pipeline skill (Phase 3) has a "persistence
decision" gate that shouldn't exist. The skill was designed with a KEEP/DELETE
binary choice, but DELETE should never happen.

**Fix direction:**

1. Remove Phase 3 "persistence decision" from research-pipeline skill
2. Make conspect dispatch automatic after researcher returns
3. Add analysis trigger logic: when should analysis auto-dispatch? (e.g., when
   researcher flags "needs analysis", when topic has trade-offs, when multiple
   approaches compared)
4. Harness infrastructure: plugin hook that detects researcher completion ->
   auto-dispatches conspecter

**Affected file:** `.opencode/skills/research-pipeline/SKILL.md` (Phase 3
section)

## Verification

- [ ] Research-pipeline skill no longer has a "persistence decision" gate
- [ ] After researcher completes, conspecter is automatically dispatched
- [ ] Conspect is created without developer intervention
- [ ] Analysis dispatch is conditional (only when needed)
- [ ] Manual test: run a research task and verify conspect is auto-created

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
