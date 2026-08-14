# DIA-132 - Parallel coders (batch D) + read-only batch expansion - DIA-116 follow-up review and design

---

id: DIA-132
title: "Parallel coders (batch D) + read-only batch expansion - DIA-116 follow-up review and design"
area: opencode-config
severity: Medium
status: IMPLEMENTED
blocked_by: [] # DIA-NNN refs, or empty
discovered: 2026-08-13
source: developer-request
date: 2026-08-13
created: 2026-08-13
updated: 2026-08-14

# --- Session Attribution (v2 schema, optional) ---

session_id: "ses_00321ed57ffe4B1uDy2s42uSeK"
lane_id: "docs"
agent: "coder"
model: "" # unknown
parent_session_id: "ses_00327cd6effet7lPBAkPxJ0M3U"
attempts: 0
lease_expires_at: ""
files_touched: [docs/dev-infra-audit/tickets/DIA-132-parallel-coders-batch-d-expansion.md, docs/dev-infra-audit/tickets/README.md]
artifacts: []
evidence: []

---

## Description

Follow-up to DIA-116 / DIA-119 / DIA-120 (BATCH-DISPATCH rule + batch-aware A1 plugin, implemented 2026-08-12, commits 0697a08 + 7b08e90). Developer returned to the parallel-batch topic on 2026-08-13: wants a review with @ai-specialist and @ai-auditor, and a design for (1) running MULTIPLE coders in parallel and (2) expanding the read-only batch A.

Pre-work findings (2026-08-13, ai-specialist research session, PERSISTENCE_RECOMMENDED: true):

- architector is READ-ONLY by config: opencode.jsonc lines 215-222 have edit deny, bash deny, task deny. Safe to add to READ_ONLY_LANES / batch A.
- researcher and code-navigator are ALREADY in batch A (READ_ONLY_LANES = researcher, ai-specialist, ai-auditor, code-navigator, observer). No change needed for them.
- code-navigator and observer inherit the global bash allow (no explicit bash deny in opencode.jsonc) - technically write-capable via bash while classified read-only. Recommendation: add explicit bash deny for strict read-only classification.
- reviewer is read-only by config (edit/bash/task deny) but correctly excluded from batch A: reviewer needs a committed fixed point (batch C).
- Parallel coders are feasible ONLY with: separate git worktrees per coder, separate tickets, disjoint file ownership, per-worktree review on committed fixed points, serialized squash-merges. NEVER two coders on the same worktree or same ticket (universal community consensus; sources: GitHub Blog, Tim Schipper, Fletch, Fazm, mq-dir, Upsun).
- OpenCode executes multiple task() calls in one message in parallel (Promise.all; OpenCode PRs #14196/#29819/#29848, issue #14195 fixed).
- DIA-116 analysis report (ai--3 session) was never persisted - proposals 1-5 live only in the DIA-119/DIA-120 ticket files and learnings entries. Persistence gap to close.

## Scope

1. @ai-auditor independent review (Phase 6) of the implemented BATCH-DISPATCH change (DIA-119/DIA-120) - blocked by this ticket's creation, pending.
2. Design decision + implementation: add architector to READ_ONLY_LANES in .opencode/plugins/delegation-observer.ts and to batch A in the 3 preset prompts of .opencode/oh-my-opencode-slim.jsonc (~2 lines).
3. Design + implementation of batch pattern D (parallel coders): plugin classification (two coders allowed ONLY when dispatch payload asserts separate worktrees), BATCH-DISPATCH rule text extension in the 3 presets, coder worktree-aware instructions, serialization rules (per-worktree fixed points for reviewer, serialized squash-merges, one memory-manager pass after merges).
4. Optional: explicit bash deny for code-navigator and observer in opencode.jsonc.
5. Close the DIA-116 persistence gap (archive the analysis proposals or mark the ticket superseded by DIA-119/120 + this ticket).

## Verification

- make test-config passes (all validators, exit 0).
- rg evidence: "architector" present in READ_ONLY_LANES; batch D text present in all 3 presets of oh-my-opencode-slim.jsonc; no PURE-DISPATCH remnants.
- delegation-observer behavioral test: architector+researcher batch silent (SAFE); two coders WITHOUT worktree assertion flagged UNSAFE (warning + a1_violation row); two coders WITH separate-worktree assertion SAFE.
- @ai-auditor independent review verdict recorded in Re-verify.

## Fix

Applied 2026-08-13 via OpenSpec change 'batch-d-parallel-coders' (implemented
on 5 worktree feature branches: prompts/plugin/drift/docs/append, base a310465;
merged 2026-08-14 via 5 serialized squash-merges d9db963..301780a on
omo-slim-changes). Summary:

1. BATCH-DISPATCH rule extended with batch D (parallel coders) in all 3 preset
   orchestrator prompts (oh-my-opencode-slim.jsonc): parallel @coder lanes
   allowed ONLY IF each coder uses a separate git worktree AND the dispatch
   payload asserts WORKTREE: <path> per coder, with disjoint file sets;
   NEVER-batch list drops "two coders" (batch D legalizes them), keeps two
   analyzers / coder+reviewer / any pair writing memory-shelf.yaml.
2. delegation-observer.ts: predicate D (coders > 1 => every non-coder lane
   read-only AND every coder asserts a distinct non-empty worktree; Set size ==
   coder count, missing/duplicate fails loud) + WORKTREE: marker extraction
   (exactly-one-marker contract) + F4 singleton-batch exemption (A1 fires only
   when a turn holds >1 task() calls).
3. architector added to batch A on 5 lockstep surfaces (plugin READ_ONLY_LANES
   - 3 preset BATCH-DISPATCH texts + orchestrator_append A1) - F5.
4. F1-F5 config-drift closures: F1 analyzer-escalated sole-writer (opencode.jsonc
   edit block = knowledge/\* only, memory-shelf.yaml allow removed), F2
   bash:deny for code-navigator + observer, F3 conspecter doc alignment,
   F4 singleton exemption (plugin), F5 architector batch A.
5. .sdd/opencode-config/architecture.md NEW with 2 Accepted ADRs (ADR 1 Batch
   Pattern D parallel coders worktree-gated; ADR 2 Singleton-Batch Semantic
   Exemption) + .sdd/README.md index row.
6. A6 item 6 (orchestrator_append.md): per-worktree reviews MUST operate on
   committed fixed points inside that worktree; squash-merges to the main
   branch MUST be serialized (one at a time).
7. coder_append.md worktree-confinement directive (work only inside the
   assigned worktree, commit only to the assigned branch).

Process: TDD RED-GREEN per worktree; two-axis reviews closed (cycle 1/2);
ai-auditor independent audit APPROVE (F1-F7 closed); merged via 5 squash-merges
d9db963..301780a; post-merge verification green (make test-config incl.
validate-agent-names, node --check delegation-observer.ts, behavioral batch-D
cases). T5.3 restart smoke pending (opencode restart + batch D functional
smoke after container up).

## Re-verify

> To be filled at re-verify time.
