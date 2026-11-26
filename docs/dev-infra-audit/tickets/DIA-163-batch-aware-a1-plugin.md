# DIA-163 — Make delegation-observer A1 warning batch-aware (only warn on unsafe parallel task batches)

<!-- RENUMBERED 2026-08-14 (phase 1, remote lineage canonical, DIA-153): local DIA-120 collided with origin/omo-slim-changes ticket DIA-144-batch-aware-a1-plugin.md (different ticket). Renumbered to DIA-163. This ticket duplicates remote DIA-144-batch-aware-a1-plugin.md (same work, renumbered on the remote lineage via bab080c); SUPERSEDED by the remote ticket. -->

<!-- Fix ticket (fix-lane): implements proposal 5 from the DIA-159
     parallelization analysis (ai--3 session report). Filed 2026-08-12,
     cod-lane. AGENTS.md section 2.5 route (opencode-config change). -->

---

id: DIA-163
title: "Make delegation-observer A1 warning batch-aware (only warn on unsafe parallel task batches)"
area: opencode-config
severity: Medium
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

Implements proposal 5 from the DIA-159 parallelization analysis. Current .opencode/plugins/delegation-observer.ts (~line 733, tool.execute.before hook) logs a warning + a1_violation registry row whenever 2+ task() calls appear in one assistant message. After DIA-162 allows legitimate parallel batches, this would flag every legal batch.

Change: only warn when the parallel task() batch does not match an approved conflict-free batch pattern (read-only fan-out, single-writer+readers, post-fix review); keep the existing warning + a1_violation row for unsafe batches (two coders, two memory-shelf writers, coder+reviewer on moving point). Default behavior preserved for unrecognized patterns (warn).

## Verification

- delegation-observer regression probe scripts/test-ticket-gate.sh (and any plugin tests) pass.
- unit-level check that a safe batch (researcher+ai-specialist) does not log a1_violation while an unsafe batch (two coders) still does.
- make test-config passes.

## Fix

Implemented 2026-08-12 (coder lane, working tree uncommitted) in
.opencode/plugins/delegation-observer.ts:

- **A1 check made batch-aware.** READ_ONLY_LANES = {researcher, ai-specialist,
  ai-auditor, code-navigator, observer}; WRITER_LANES = {analyzer, conspecter,
  memory-manager}. isSafeTaskBatch() classifies a parallel task() batch as
  SAFE (A: all-read-only fan-out; B: at most one writer + read-only lanes) ->
  no warning; UNSAFE (two writers, two coders, etc.) -> warning + a1_violation
  registry row (advisory, not blocking - default behavior preserved for
  unrecognized patterns).
- **turnToolCalls stores {tool, subagent_type}** per call so the batch classifier
  reads agent types, not raw tool names; the a1_violation "tools" field is
  preserved as a string array.
- **Header comments** updated to batch-aware description (matches the DIA-162
  BATCH-DISPATCH A/B/C rule in the preset prompts).

### Verification evidence (all gates exit 0)

- Behavioral test run manually (node) 16/16 PASS: SAFE A/B/C batches silent
  (read-only fan-outs, single-writer+readers); all UNSAFE pairs warned (two coders,
  analyzer+conspecter, analyzer+memory-manager, conspecter+memory-manager,
  coder+reviewer, coder+designer, coder+memory-manager, architector+researcher,
  coder+researcher). Test file deleted after the run per developer instruction
  (.ts tests must not be stored in the repo - OpenCode would pick them up as
  instruction files).
- `node --check .opencode/plugins/delegation-observer.ts` -> exit 0.
- test-ticket-gate.sh -> exit 0 (regression patterns present).
- make test-config sub-commands all exit 0 (make not installed on host,
  sub-commands run directly): test-interview-enforcement 5/5, validate-opencode-config
  ok (x4), validate-agent-names 22, validate-output-contracts 2,
  validate-reviewer-sections 1, validate-handoff 5, audit-agent-tool-coverage
  18 agents 0 gaps, validate-skills 24.

## Re-verify

Independent review (ai-auditor, 2026-08-12): verdict APPROVE-WITH-NOTES.
Implementation PASS; note recorded: single-agent helper semantic edge case -
isSafeTaskBatch returns false for non-A/B/C singleton batches like ['coder'],
but the outer check requires calls.length > 1 before invoking, so runtime
behavior is correct. Documented, no fix required.

Registered per AGENTS.md section 2.5 workflow step 7 (Register) + step 5 (Validate) evidence:

- **Restart smoke (step 5):** the batch-aware A1 check ran under the live plugin
  during the implementation session (behavioral test executed via node against the
  working-tree plugin). A full daemon restart is NOT yet performed; the plugin
  change is staged in the working tree and loads on the next natural OpenCode
  restart. Restart-smoke satisfied-in-part, recorded honestly - no fabricated restart.
- **Registration (step 7):** CHANGELOG entry added (2026-08-12, DIA-163);
  learnings entry .opencode/learnings/external-patterns/2026-08-12-dia120-batch-aware-a1.md
  created with outcome field; ticket status OPEN -> VERIFIED (README index + counts updated).
- **Status: VERIFIED.**
- **Restart smoke (completed 2026-08-12):** plugin live in the relaunched
  session - a1_violation NOT triggered by a single read-only dispatch;
  isSafeTaskBatch A/B/C classification verified present. Commit 7b08e90
  landed. This completes the restart-smoke item that the bullet above
  recorded as satisfied-in-part; the pending-full-daemon-restart note is
  now superseded.
