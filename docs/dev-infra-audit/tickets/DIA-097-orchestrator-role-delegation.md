# DIA-097 - Orchestrator role consolidation: task/resource mgmt, delegation, heavy-thinking separation, bash-delegation, automation-of-repetition

---

id: DIA-097
title: "orchestrator role consolidation: task/resource mgmt, delegation, heavy-thinking separation, bash-delegation, automation-of-repetition"
area: opencode-config
severity: Major
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
discovered:
source: inventory
date: 2026-08-11
created: 2026-08-11
updated: 2026-08-11

# --- Session Attribution (v2 schema, optional) ---

session_id: "" # OpenCode session ID that owned this ticket
lane_id: "" # e.g. cod-1, ai--3
agent: "" # agent name (coder, reviewer, etc.)
model: "" # model ID used
parent_session_id: "" # orchestrator's session ID (populated via get-my-session-id tool)
attempts: 0 # how many delegations attempted
lease_expires_at: "" # ISO-8601; set on DISPATCHED, cleared on COMPLETE
files_touched: [] # list of file paths modified
artifacts: [] # list of artifact references (commits, test outputs)
evidence: [] # list of evidence URIs (messages.md#row, registry.jsonl#seq)

---

## Description

Comprehensive framing of the orchestrator role: (a) orchestrator does
task/resource management, delegation, coordination, parallelization detection;
(b) heavy reasoning delegated to @analyzer/@council; (c) bash-delegation
pattern documented and enforced; (d) repetitive-work to automation workflow
(dispatch @coder to create scripts); (e) delegation rules (what stays with
orchestrator vs what delegates). Subsumes DIA-082 (heavy-thinking delegation),
DIA-083 (task/resource mgmt + automation), DIA-091 (bash-delegation pattern) -
all three close as subsumed.

### Investigation requirements

1. Audit current orchestrator prompts across all 3 presets for role framing.
2. Enumerate delegation boundaries (what orchestrator does inline vs delegates).
3. Identify 2+ recurring delegation patterns suitable for automation scripts.
4. Verify bash-delegation pattern works end-to-end (lane-0 checksum as test case).
5. Document separation: orchestrator=coordination, analyzer=reasoning,
   coder=implementation/bash, reviewer=QA.

### Deliverables

- Updated orchestrator prompt sections in all 3 presets.
- Delegation-rules reference (what stays vs what delegates).
- Automation-candidate list with at least one script created via @coder.
- Cross-references from closed DIA-082/083/091.

## Verification

- (a) Orchestrator prompt in all 3 presets states role boundaries.
- (b) On an analysis-heavy task, orchestrator delegates to @analyzer (not inline).
- (c) On a bash task, orchestrator delegates to coder lane (not inline attempt).
- (d) 1+ recurring pattern automated via @coder-created script.
- (e) DIA-082, DIA-083, DIA-091 closed as subsumed by DIA-097.
- (f) make test-config exit 0.

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
