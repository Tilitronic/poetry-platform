# DIA-235 -- Orchestrator bugs analysis and fix

---

id: DIA-235
title: "Orchestrator bugs analysis and fix"
area: opencode-config
severity: Critical
status: OPEN
blocked_by: []
parent_epic: ""

gate_state: "skipped"
gate_triggers: []
gate_waivers: []
gate_override: ""
discovered:
source: fix-lane
date: 2026-08-19
created: 2026-08-19
updated: 2026-08-19

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

Investigate 4 critical orchestrator bugs from session ses_fe5a29aa1ffeJmz7Pu3Bjeryb0:

1. **Batch-approval gate violation** -- dispatched lane-0 without explicit approval.
   The orchestrator bypassed the batch-approval gate and dispatched a worker lane
   before receiving developer confirmation. This violates the batch-dispatch
   contract and risks unreviewed code reaching the codebase.

2. **DCP observability gap** -- lane-0 errored silently, no visible DCP output.
   When lane-0 encountered an error, there was no visible diagnostic output in the
   DCP (Delegation Context Protocol) stream. The error was swallowed silently,
   making it impossible to diagnose the failure without manual log inspection.

3. **Repetition loop** -- orchestrator repeated acknowledgments and failed file reads.
   The orchestrator entered a loop where it repeatedly acknowledged the same state
   and retried failed file reads without progressing. This wasted context window
   tokens and stalled the workflow.

4. **Orchestrator asking developer for information it could find itself** -- ana<NN>
   ID allocation. The orchestrator asked the developer to provide analysis IDs
   (ana<NN>) that it should have allocated or looked up autonomously. This breaks
   the autonomous delegation model and stalls the workflow for no reason.

These bugs affect the core orchestration workflow and block reliable autonomous operation.

## Verification

- Reproduce each bug condition from session ses_fe5a29aa1ffeJmz7Pu3Bjeryb0 logs
- Verify batch-approval gate enforcement (dispatch blocked until explicit approval)
- Verify DCP error propagation (lane errors surface in delegation context)
- Verify no repetition loops (orchestrator progresses after acknowledgment)
- Verify ID allocation autonomy (orchestrator allocates ana IDs without developer input)

## Bug 5: Routing gate blocks on missing learnings registration

- **Symptom:** Routing gate says "@coder dispatched on config-work without prior @ai-specialist gate review" even though ai--1 completed.
- **Root cause:** Orchestrator skipped step 1 of AGENTS.md section 2.5 (register findings in learnings).
- **Severity:** Medium (workflow gap, not a code bug).
- **Fix:** Orchestrator must register ai-specialist findings in learnings before dispatching @coder.

## Bug 6: Routing gate doesn't recognize completed ai-specialist dispatch + registered findings

- **Symptom:** Routing gate blocks @coder with "without prior @ai-specialist gate review" even though ai--1 completed AND findings registered at `.opencode/learnings/external-patterns/2026-08-19-dia235-orchestrator-prompt-fixes.md`.
- **Root cause:** Gate appears to check for recent ai-specialist dispatch in session (temporal), not just existence of findings.
- **Severity:** Medium (workflow gap).
- **Fix:** Either (a) gate should check for learnings file existence, or (b) orchestrator must re-dispatch @ai-specialist before each @coder dispatch on config-work.

## Fix

Applied 2026-08-19 (main implementation):

### Bug 1 (batch-approval gate violation) -- FIXED in prompt

- All 3 preset prompts (opencode-go/cebula/free) restructured: new MANDATORY RULES section
  at top, rule 1 is the batch-approval gate. It now resolves the handoff via the DIA-085
  chain (active.json -> handoffs/<id>.json -> mtime-scan -> legacy fallback) instead of
  blindly reading `.opencode/session/current-handoff.json`, presents batch approval to the
  developer BEFORE any delegation, logs via log_decision, and delegates lane-0 checksum
  verification automatically after approval (VERIFICATION ONLY, never writes the file).

### Bug 2 (DCP observability gap) -- FIXED in prompt

- New MANDATORY RULES rule 4 (lane-error surfacing): orchestrator must explicitly surface
  lane errors in session summaries, DCP-independent. Silent lane-0 errors can no longer
  pass without a visible report.

### Bug 3 (repetition loop) -- FIXED in prompt

- The single-paragraph prompt (4327 chars, 2 `\n` breaks) is replaced by a structured
  multi-section prompt (MANDATORY RULES / CORE OPERATING CONSTRAINTS / WORKFLOW
  PROTOCOLS / DISPATCH RULES / DELEGATION DIRECTORY), one rule per paragraph, removing the
  dense prose that produced repeated acknowledgment/retry loops.

### Bug 4 (ID allocation autonomy) -- FIXED in prompt

- ID ALLOCATION rule retained in CORE OPERATING CONSTRAINTS + WORKFLOW PROTOCOLS: scan
  knowledge/ for the highest existing <type><nnn> and assign the next integer in the
  dispatch payload; never let the agent self-allocate.

### Bug 5 (learnings registration) -- FIXED in prompt

- New MANDATORY RULES rule 3: before any @coder config-work dispatch, register
  ai-specialist findings in `.opencode/learnings/external-patterns/` (AGENTS.md section
  2.5 step 1). Findings for this ticket registered at
  `.opencode/learnings/external-patterns/2026-08-19-dia235-orchestrator-prompt-fixes.md`.

### Bug 6 (routing gate deadlock) -- FIXED in code, commit 10b02d1

- Routing gate now scans paracrine `dispatch.started` rows (which carry session_id +
  agent) instead of delegation rows (which do not). Already merged before this prompt fix.

### Additional fixes in the same pass

- Stale READ-SCOPE fixed: the full DIA-126a 18-path allow-list is now stated in CORE
  OPERATING CONSTRAINTS (was a note about a 2026-08-13 expansion).
- Stale `.opencode/session/current-handoff.json` references removed from all 3 prompts
  (batch-approval + checksum sections now use the DIA-085 resolved slot).
- `orchestrator_append.md` line 144 fixed: exit-checksum section now names the DIA-085
  resolved slot (`.opencode/session/handoffs/<session-id>.json`) with the legacy
  current-handoff.json only as chain-fallback; line 243 intentional fallback kept.
- ASCII-only (DIA-079) throughout the new prompt text.
- All 8 drift markers (delegation-only, batch-approval, DIA-133, pure-dispatch,
  no-bash-tool, READ-SCOPE, EBDV, threshold-15-25) preserved; prompts byte-identical
  across all 3 presets (5095 chars each, `check-orchestrator-prompt-drift.sh` exit 0).

## Re-verify

Re-verify after this fix (2026-08-19):

- [x] `make test-config` -- drift checker exit 0 (3 presets x 8 markers, 0 gaps), JSONC
      schema validation passes
- [x] `make test-shell` -- bats suite exit 0 (incl. check-orchestrator-prompt-drift bats
      fixtures)
- [x] Byte-identity: all 3 preset prompts identical (verified via JSONC parse)
- [x] No `.opencode/session/current-handoff.json` reference remains in any prompt
- [x] `orchestrator_append.md` line 144 references DIA-085 resolved slot; line 243 legacy
      fallback intact
- [ ] Behavioral (post-restart): batch-approval gate presents DIA-085 resolved handoff
      before any delegation; lane-0 checksum delegation fires automatically after
      approval; lane errors surface in session summary; ana<NN> IDs allocated without
      developer input
