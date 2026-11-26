# DIA-260901-1mpx - Persist architecture-check findings to memory (DIA-260901-3y39 follow-up)

---

id: DIA-260901-1mpx
title: "Persist architecture-check findings to memory (DIA-260901-3y39 follow-up)"
area: scripts
severity: Medium
status: CLOSED
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-09-01
source: inventory
date: 2026-09-01
created: 2026-09-01
updated: 2026-09-01

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

Post-audit knowledge persistence follow-up for DIA-260901-3y39 (CLOSED). Dispatch @memory-manager to store irrecoverable lessons/failures from the architecture-check of commits 54e2dc16..HEAD.

Candidates from DIA-260901-3y39 audit cycle:

1. @architector model misconfig (github-copilot/gemini-3.1-pro-preview not found, deferred to Copilot connect)
2. @code-navigator no-bash limitation for diff-based audits
3. Audit-process lesson that @reviewer alone suffices for architecture-check of committed ranges
4. Structural repo notes (delegation-observer SRP breach, opusFormattingFilter Orchestrator bypass) only if judged non-recoverable from code

Writes to `.opencode/memory/` (lessons.md, failures.md, repo.md). Only persist what is irrecoverable from code/history — no duplication of recoverable facts.

Upstream: DIA-260901-3y39 (CLOSED). No code changes beyond memory files.

## Verification

- [x] @memory-manager dispatched and findings from DIA-260901-3y39 triaged for irrecoverability
- [x] Irrecoverable lessons/failures appended to `.opencode/memory/lessons.md` / `failures.md` (if any); structural notes to `repo.md` only if non-recoverable
- [x] No recoverable/duplicated facts persisted (code-readable facts excluded)
- [x] Memory files remain well-formed and committed

## Fix

@memory-manager (mem-1) completed persistence for DIA-260901-3y39 follow-up.

## Re-verify

N/A -- knowledge-persistence ticket. Verification checkboxes above confirm triage and persistence completion.

## Outcome / Evidence (2026-09-01 -- CLOSED)

- **@memory-manager (mem-1) completed persistence**
- **STORED:** `.opencode/memory/lessons.md` entries:
  - L20260901-004 -- code-navigator lacks bash: diff-based audits route to @reviewer/@coder, NOT @code-navigator
  - L20260901-005 -- architecture-check of committed ranges: @reviewer alone sufficient; parallel @architector + @code-navigator added errors/blockers without coverage
- **NOT STORED (deliberately, per core rule):**
  - architector model misconfig (transient, recoverable from config, covered by existing lesson L20260824-002)
  - architecture findings (recoverable from code)
  - no failures.md / repo.md entries (no irrecoverable failures or structural notes meeting the non-recoverable threshold)
- **Verification:** duplicate-checked lessons.md, no matches
- **Upstream:** DIA-260901-3y39 (CLOSED)
