# DIA-260819-mh6p - Agentic workflow compliance analysis and fixes

---

id: DIA-260819-mh6p
title: "Agentic workflow compliance analysis and fixes"
area: opencode-config
severity: Critical
status: COMPLETE
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

Multiple issues have been observed in agentic workflows across recent sessions:

- Orchestrator workflow routing inconsistencies (incorrect lane selection, missing gate checks)
- Workflow compliance gaps (interview-first gate bypassed, verification evidence missing)
- Agent dispatch routing errors (config work without ai-specialist gate, missing reviewer cycles)
- Session handoff and checksum verification gaps
- Truncated/empty subagent results not properly handled per DIA-099 protocol

This ticket covers a systematic analysis of recent session logs (registry.jsonl, messages.jsonl) to:

1. Identify concrete instances of workflow violations and their root causes
2. Categorize issues by type (routing, gating, verification, handoff, truncation)
3. Propose specific fixes -- config changes, agent prompt updates, new guard rails
4. Ensure existing DIA tickets covering these areas (DIA-063, DIA-099, DIA-104, DIA-174, DIA-175, DIA-214, DIA-217, DIA-230, DIA-232) are properly enforced
5. Recommend new guard rails or plugin hooks where existing mechanisms are insufficient

## Verification

- [x] Analysis report produced with concrete examples from session logs
- [x] Issues categorized by type with root cause for each
- [x] Specific fix proposals for each category (config changes, prompt updates, new hooks)
- [x] Gap analysis: which existing DIA tickets are not properly enforced and why
- [x] Recommendations prioritized by impact (Critical > Major > Medium)
- [x] Findings persisted to knowledge/ or .opencode/memory/ as appropriate
- [x] P0 fixes implemented: routing catch-block bug (DIA-230), empty result escalation (DIA-099), orchestrator redispatch instruction
- [x] Documentation fidelity gaps fixed: DIA-224 ticket text, in-code comment
- [x] Validation gates pass: make test-config, validate-changelog.sh, validate-memory-shelf.sh

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.

<!-- UPDATE 2026-08-19: All P0 fixes committed (9bdc0bc). Status -> COMPLETE. -->
