# DIA-260831-ezyv - Bun 1.3.14 segfault/SIGILL crashes opencode during long orchestrator session

---

id: DIA-260831-ezyv
title: "Bun 1.3.14 segfault/SIGILL crashes opencode during long orchestrator session"
area: opencode
severity: Major
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-31
source: inventory
date: 2026-08-31
created: 2026-08-31
updated: 2026-08-31

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

- Symptom: opencode process died with `panic: Segmentation fault at address 0x0` followed by `Illegal instruction    opencode` (SIGILL). Bun's own crash reporter states "This indicates a bug in Bun, not your code."
- Environment: Bun 1.3.14, platform Linux x64 (baseline), OpenCode orchestrator lane (Hy3).
- Resource at crash: RSS 4.12 GB, Peak 5.23 GB, Elapsed 3373370 ms, User 2764426 ms, Machine 16.77 GB.
- Trigger context: crash occurred while the orchestrator was planning an ID-allocation config change (long-running session, high memory).
- Bun crash-report URL: https://bun.report/1.3.14/Ba1Od9b296m/GuhogC4664tE+qURq0+1/Eo/xggF89kgf4tjzzD2j5i5sFsz+lsFi14lsFumg7pF__________msvprCwpthfF0umj9DA2AA
- Recommended action: file a Bun GitHub issue via the link above (redacted crash report); track externally. Also consider whether long orchestrator sessions / high RSS correlate with the crash and whether a session-context guard is warranted.
- Repro: unclear / likely intermittent; single observed instance from a screenshot.

## Verification

- [ ] Bun crash report reviewed and GitHub issue filed (or decision recorded not to file)
- [ ] If session-context guard is warranted, follow-up ticket created or mitigation documented
- [ ] Ticket closed or downgraded once external tracking is in place

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
