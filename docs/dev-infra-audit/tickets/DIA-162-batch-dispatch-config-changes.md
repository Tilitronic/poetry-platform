# DIA-162 — Enable safe task parallelization: BATCH-DISPATCH rule, memory-shelf centralization, ID preallocation, serialization points

<!-- RENUMBERED 2026-08-14 (phase 1, remote lineage canonical, DIA-153): local DIA-119 collided with origin/omo-slim-changes ticket DIA-143-batch-dispatch-config-changes.md (different ticket). Renumbered to DIA-162. This ticket duplicates remote DIA-143-batch-dispatch-config-changes.md (same work, renumbered on the remote lineage via bab080c); SUPERSEDED by the remote ticket. -->

<!-- Fix ticket (fix-lane): implements proposals 1-4 from the DIA-159
     parallelization analysis (ai--3 session report). Filed 2026-08-12,
     cod-lane. AGENTS.md section 2.5 route (opencode-config change). -->

---

id: DIA-162
title: "Enable safe task parallelization: BATCH-DISPATCH rule, memory-shelf centralization, ID preallocation, serialization points"
area: opencode-config
severity: Major
status: VERIFIED
blocked_by: []
discovered: 2026-08-12
source: fix-lane
date: 2026-08-12
created: 2026-08-12
updated: 2026-08-12

# --- Session Attribution (v2 schema, optional) ---

session_id: "ses_00b5f2f4affeavJUt86vac4dn6"
lane_id: "cod-lane"
agent: "coder"
model: ""
parent_session_id: "ses_00b5f2f4affeavJUt86vac4dn6"
attempts: 0
lease_expires_at: ""
files_touched: []
artifacts: []
evidence: []

---

## Description

Implements proposals 1-4 from the DIA-159 parallelization analysis (reference docs/dev/dev-infra-audit/tickets/DIA-159-task-parallelization-analysis.md and the ai--3 report):

1. Replace PURE-DISPATCH rule in all 3 preset orchestrator prompts (oh-my-opencode-slim.jsonc lines ~26/210/401) with BATCH-DISPATCH: allow parallel task() calls only within approved conflict-free batches (A: read-only fan-out researcher/ai-specialist/ai-auditor/code-navigator/observer; B: one knowledge-writer [analyzer|conspecter|memory-manager] + read-only lanes; C: post-fix reviewer+ai-auditor on committed fixed point). NEVER batch two coders, two analyzers, coder+reviewer, or two memory-shelf.yaml writers.
2. Centralize memory-shelf.yaml writes: remove ".opencode/memory-shelf.yaml" allow from analyzer and conspecter edit permissions in .opencode/opencode.jsonc; update analyzer/conspecter prompts to report artifact paths in return message instead of self-registering; memory-manager becomes sole shelf writer (dispatched last, Mandatory Final Step).
3. Add ID ALLOCATION rule to orchestrator prompt: orchestrator scans knowledge/ for highest existing <type><nnn> and passes explicit ana<NN>/res<NN> ID in dispatch payload; agents never self-allocate.
4. Add section A6 "Serialization Points" to .opencode/oh-my-opencode-slim/orchestrator_append.md: coder->reviewer (fixed git point), researcher->conspecter, [all]->memory-manager, openspec-plan->coder, batch-approval boot gate->any work.

## Verification

- make test-config passes (all 10 validators).
- grep confirms BATCH-DISPATCH text in 3 presets.
- grep confirms memory-shelf.yaml removed from analyzer/conspecter permissions in opencode.jsonc.
- grep confirms A6 section in orchestrator_append.md.
- config validators confirm agent-name contract intact.
- restart OpenCode + functional smoke (next natural restart).

## Fix

Implemented 2026-08-12 (coder lane, working tree uncommitted). All four
proposals applied per the DIA-159 analysis, plus follow-up fixes for the
ai-auditor D-1..D-5 findings:

- **CHANGE 1 - PURE-DISPATCH -> BATCH-DISPATCH (3 preset orchestrator prompts).**
  oh-my-opencode-slim.jsonc lines 26/210/401: the PURE-DISPATCH rule was replaced
  with BATCH-DISPATCH - task() calls MAY share a message only within an approved
  conflict-free batch (A: read-only fan-out researcher/ai-specialist/ai-auditor/
  code-navigator/observer; B: single-writer [analyzer|conspecter|memory-manager] +
  read-only lanes; C: post-fix reviewer + ai-auditor on committed fixed point).
  NEVER batch: two coders, two analyzers, coder+reviewer, or any pair that both
  write memory-shelf.yaml. When in doubt, serialize.
- **CHANGE 2 - memory-shelf centralization.** Removed ".opencode/memory-shelf.yaml":
  "allow" from analyzer and conspecter edit permissions in opencode.jsonc
  (memory-manager retains it, line 285 - sole shelf writer). Analyzer and conspecter
  prompts now instruct Do-Not-Register: report the artifact path in the return
  message instead of self-registering (analyzer.md lines 26/40, conspecter.md line 29).
- **CHANGE 3 - ID ALLOCATION rule (3 presets).** Orchestrator scans knowledge/ for
  the highest existing <type><nnn> and passes explicit ana<NN>/res<NN> ID in the
  dispatch payload; ends with "Never let the agent self-allocate." (verified x3,
  oh-my-opencode-slim.jsonc lines 26/210/401).
- **CHANGE 4 - A6 Serialization Points.** Added section "A6 - Serialization Points
  (MUST NOT parallelize)" to .opencode/oh-my-opencode-slim/orchestrator_append.md
  lines 247-253: coder->reviewer (fixed git point), researcher->conspecter,
  [all]->memory-manager (Mandatory Final Step), openspec-plan->coder, batch-approval
  boot gate->any work.
- **Follow-up (ai-auditor findings D-1..D-5):** orchestrator_append.md A1 section
  Pure-Dispatch -> Batch-Dispatch (line 151); NEXT-RUN.md:127 Pure-Dispatch ->
  BATCH-DISPATCH; NEXT-RUN.md:124 routing table config row -> gate @ai-specialist
  -> user decision -> @coder implement -> validate -> @ai-auditor independent
  review (AGENTS.md section 2.5 chain); analyzer.md + conspecter.md self-registration
  instructions removed (shelf registration delegated to @memory-manager, matching
  actual permissions); delegation-observer.ts header comments updated to
  batch-aware description.

### Verification evidence (all gates exit 0)

- `rg "PURE-DISPATCH"` over oh-my-opencode-slim.jsonc -> 0 matches (CHANGE 1).
- `rg "BATCH-DISPATCH"` -> present at oh-my-opencode-slim.jsonc lines 26/210/401 (x3 presets).
- `rg "Never let the agent self-allocate"` -> 3 matches (CHANGE 3).
- A6 section confirmed at orchestrator_append.md lines 247-253 (CHANGE 4).
- opencode.jsonc: ".opencode/memory-shelf.yaml": "allow" present only at line 285
  (memory-manager); analyzer/conspecter prompts carry Do-Not-Register instructions
  (CHANGE 2).
- make test-config sub-commands all exit 0 (make not installed on host, sub-commands
  run directly, re-run this close-out lane):
  - test-interview-enforcement 5/5 PASS
  - validate-opencode-config ok (x4 checks)
  - validate-agent-names 22 passed
  - validate-output-contracts 2 passed
  - validate-reviewer-sections 1 passed
  - validate-handoff 5 passed
  - test-ticket-gate ok
  - audit-agent-tool-coverage x2: 18 agents, 0 gaps
  - validate-skills 24 passed

## Re-verify

Independent review (ai-auditor, 2026-08-12): initial verdict REQUEST-CHANGES
(findings D-1..D-5 - Pure-Dispatch references remaining in A1/NEXT-RUN/routing,
self-registration instructions still present in analyzer/conspecter, delegation-
observer header not yet batch-aware). Follow-up fixes applied (see Fix section),
then all gates green -> re-verification PASS. This close-out lane closes the
registration gap.

Registered per AGENTS.md section 2.5 workflow step 7 (Register) + step 5 (Validate) evidence:

- **Restart smoke (step 5):** the fixed config was LIVE throughout the implementation
  session - dispatches (incl. the ai-auditor independent review) ran under the new
  config with no BATCH-DISPATCH / memory-shelf / ID-ALLOCATION regressions. A full
  daemon restart is NOT yet performed; the fix-verified config is staged in the
  working tree and will load on the next natural OpenCode restart. Restart-smoke is
  therefore satisfied-in-part: config-live evidence recorded, full-daemon-restart
  evidence pending next natural restart. Not fabricating a restart.
- **Registration (step 7):** CHANGELOG entry added (2026-08-12, DIA-162);
  learnings entry .opencode/learnings/external-patterns/2026-08-12-dia119-batch-dispatch.md
  created with outcome field; ticket status OPEN -> VERIFIED (README index + counts updated).
- **Status: VERIFIED.**
- **Restart smoke (completed 2026-08-12):** full daemon restart performed
  via bin/opencode-docker relaunch; functional smoke dispatch (researcher
  lane) completed under the new config with no anomalies; BATCH-DISPATCH
  text verified in all 3 preset prompts; memory-shelf.yaml write allow only
  on memory-manager (opencode.jsonc); A6 Serialization Points present in
  orchestrator_append.md. Commit 0697a08 landed. This completes the
  restart-smoke item that the bullet above recorded as satisfied-in-part;
  the pending-full-daemon-restart note is now superseded.
