# DIA-143 batch-dispatch config changes - BATCH-DISPATCH rule, memory-shelf centralization, ID preallocation, serialization points (2026-08-12)

- **Date:** 2026-08-12
- **Source:** DIA-143 fix ticket (from the DIA-140 task-parallelization analysis, ai--3 session report); coder-lane implementation + this AGENTS.md section 2.5 close-out registration lane (docs lane).
- **Status:** VERIFIED - all four proposals applied and gate-verified; ai-auditor independent review REQUEST-CHANGES (findings D-1..D-5) -> follow-up fixes applied -> re-verified PASS, all gates green.
- **Outcome:** parallelization enabled per the DIA-140 design: PURE-DISPATCH replaced by BATCH-DISPATCH in all 3 preset orchestrator prompts (approved conflict-free batches A/B/C; NEVER two coders / two analyzers / coder+reviewer / two memory-shelf.yaml writers); memory-shelf.yaml writes centralized to @memory-manager as sole shelf writer (analyzer/conspecter shelf-edit permission removed, prompts now Do-Not-Register + report artifact path); ID preallocation moved to the orchestrator (scan knowledge/ for highest <type><nnn>, pass explicit ana<NN>/res<NN> in the dispatch payload, "Never let the agent self-allocate."); A6 Serialization Points documented (coder->reviewer, researcher->conspecter, [all]->memory-manager, openspec-plan->coder, boot gate->any work). Follow-up fixes closed the ai-auditor D-1..D-5 findings (stale Pure-Dispatch refs in A1/NEXT-RUN/routing, analyzer/conspecter self-registration instructions, delegation-observer header comments).

## Ticket

- **DIA-143** (Major, VERIFIED) - "Enable safe task parallelization: BATCH-DISPATCH rule, memory-shelf centralization, ID preallocation, serialization points".
- **Related:** DIA-140 (task-parallelization analysis, parent), DIA-144 (batch-aware A1 plugin, sibling proposal 5).

## Fixes (implemented 2026-08-12, working tree)

- **CHANGE 1 - PURE-DISPATCH -> BATCH-DISPATCH (3 preset orchestrator prompts).** oh-my-opencode-slim.jsonc lines 26/210/401: task() calls MAY share a message only within an approved conflict-free batch - (A) read-only fan-out researcher/ai-specialist/ai-auditor/code-navigator/observer; (B) single-writer [analyzer|conspecter|memory-manager] + read-only lanes; (C) post-fix reviewer + ai-auditor on committed fixed point. NEVER batch: two coders, two analyzers, coder+reviewer, or any pair that both write memory-shelf.yaml. `rg "PURE-DISPATCH"` -> 0 matches in that file.
- **CHANGE 2 - memory-shelf centralization.** Removed ".opencode/memory-shelf.yaml": "allow" from analyzer + conspecter edit permissions in opencode.jsonc (memory-manager retains it, line 285); analyzer.md lines 26/40 + conspecter.md line 29 now instruct Do-Not-Register - report artifact path in the return message; @memory-manager is the sole shelf writer (dispatched last, Mandatory Final Step).
- **CHANGE 3 - ID ALLOCATION rule (3 presets).** Orchestrator scans knowledge/ for the highest existing <type><nnn> and passes the next integer explicitly in the dispatch payload; ends with "Never let the agent self-allocate." (verified x3, lines 26/210/401).
- **CHANGE 4 - A6 Serialization Points.** orchestrator_append.md lines 247-253: coder->reviewer (fixed git point), researcher->conspecter, [all]->memory-manager, openspec-plan->coder, batch-approval boot gate->any work.
- **Follow-up (ai-auditor D-1..D-5):** orchestrator_append.md:151 A1 Pure-Dispatch -> Batch-Dispatch; NEXT-RUN.md:127 Pure-Dispatch -> BATCH-DISPATCH; NEXT-RUN.md:124 routing table config row -> ai-specialist gate -> user decision -> coder -> validate -> ai-auditor (AGENTS.md section 2.5 chain); analyzer.md + conspecter.md self-registration instructions removed (delegated to @memory-manager, matching actual permissions); delegation-observer.ts header comments batch-aware.

## Validation (make test-config sub-commands, all exit 0; make not installed on host)

- test-interview-enforcement 5/5 PASS
- validate-opencode-config ok (x4 checks)
- validate-agent-names 22 passed
- validate-output-contracts 2 passed
- validate-reviewer-sections 1 passed
- validate-handoff 5 passed
- test-ticket-gate ok
- audit-agent-tool-coverage x2: 18 agents, 0 gaps
- validate-skills 24 passed

## Outcome

- Config-fix workflow completed per AGENTS.md section 2.5 (Validate + Register steps): gate evidence above; ai-auditor REQUEST-CHANGES (D-1..D-5) -> follow-up fixes applied -> re-verified all gates green; CHANGELOG entry + this learnings entry + ticket OPEN -> VERIFIED (README index + status counts updated: OPEN 28->26, VERIFIED 16->18).
- Restart-smoke (step 5): config was live throughout the implementation session - dispatches ran under the new config with zero BATCH-DISPATCH / memory-shelf / ID-ALLOCATION regressions. Full daemon restart not performed; staged config loads on the next natural OpenCode restart. Recorded honestly in the ticket; no fabricated restart evidence.

## Reusable lesson

Approved-batch sets are a single source of truth shared between prompts and plugin: the BATCH-DISPATCH A/B/C batch definitions live in the orchestrator prompt (oh-my-opencode-slim.jsonc x3 presets) AND in delegation-observer.ts (READ_ONLY_LANES / WRITER_LANES / isSafeTaskBatch) - when either side drifts, the A1 warnings stop matching the prompts that agents are told to follow. Write-permission centralization beats prompt-level self-restraint: removing the shelf edit permission from analyzer/conspecter and leaving @memory-manager as sole writer made the Do-Not-Register instruction enforced by the permission system, not by agent compliance. Preallocation of resource IDs (ana<NN>/res<NN>) by the orchestrator removes a whole class of concurrent-allocation collisions that parallel dispatch would otherwise make likely - parallelization only works when identity assignment is serialized.

## Tags

DIA-143, DIA-140, DIA-144, batch-dispatch, parallelization, task-parallelization, PURE-DISPATCH, memory-shelf, memory-manager, ID-ALLOCATION, serialization-points, orchestrator_append, oh-my-opencode-slim, delegation-observer, a1_violation, single-source-of-truth, test-config, ai-auditor, config-fix-workflow
