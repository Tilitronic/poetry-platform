# DIA-120 batch-aware A1 plugin - delegation-observer warns only on unsafe parallel task batches (2026-08-12)

- **Date:** 2026-08-12
- **Source:** DIA-120 fix ticket (proposal 5 from the DIA-116 task-parallelization analysis, ai--3 session report); coder-lane implementation + this AGENTS.md section 2.5 close-out registration lane (docs lane).
- **Status:** VERIFIED - batch-aware A1 check implemented and gate-verified; behavioral test 16/16 PASS; ai-auditor independent review APPROVE-WITH-NOTES (single-agent helper semantic edge case documented, no fix required).
- **Outcome:** the delegation-observer A1 check (tool.execute.before hook, ~line 733) is now batch-aware: READ_ONLY_LANES {researcher, ai-specialist, ai-auditor, code-navigator, observer}, WRITER_LANES {analyzer, conspecter, memory-manager}; isSafeTaskBatch() classifies parallel task() batches as SAFE (A read-only fan-out / B single-writer+readers -> silent) vs UNSAFE (two writers, two coders, etc. -> warning + a1_violation registry row, advisory not blocking). After DIA-119 legalized approved parallel batches, this keeps A1 from flagging every legitimate batch while preserving the warning for genuinely unsafe concurrency.

## Ticket

- **DIA-120** (Medium, VERIFIED) - "Make delegation-observer A1 warning batch-aware (only warn on unsafe parallel task batches)".
- **Related:** DIA-116 (task-parallelization analysis, parent), DIA-119 (BATCH-DISPATCH rule, sibling proposals 1-4).

## Fixes (implemented 2026-08-12, working tree)

- **A1 check batch-aware** in .opencode/plugins/delegation-observer.ts: READ_ONLY_LANES / WRITER_LANES sets; isSafeTaskBatch() returns true for (A) all-read-only fan-out and (B) at-most-one-writer + read-only lanes; UNSAFE batches keep the existing warning + a1_violation registry row; default behavior preserved for unrecognized patterns (warn).
- **turnToolCalls stores {tool, subagent_type}** so the classifier reads agent types; a1_violation "tools" field preserved as string array.
- **Header comments** updated to batch-aware description matching the DIA-119 BATCH-DISPATCH A/B/C rule.
- **Behavioral test run manually (node) 16/16 PASS:** SAFE A/B/C batches silent; all UNSAFE pairs warned (two coders, analyzer+conspecter, analyzer+memory-manager, conspecter+memory-manager, coder+reviewer, coder+designer, coder+memory-manager, architector+researcher, coder+researcher). Test file deleted after the run per developer instruction.

## Validation (all exit 0)

- Behavioral test 16/16 PASS (manual node run, test file deleted after - .ts tests must not be stored in the repo).
- `node --check .opencode/plugins/delegation-observer.ts` -> exit 0.
- test-ticket-gate.sh -> exit 0.
- make test-config sub-commands all exit 0 (make not installed on host): test-interview-enforcement 5/5, validate-opencode-config ok (x4), validate-agent-names 22, validate-output-contracts 2, validate-reviewer-sections 1, validate-handoff 5, audit-agent-tool-coverage 18 agents 0 gaps, validate-skills 24.

## Outcome

- Config-fix workflow completed per AGENTS.md section 2.5 (Validate + Register steps): gate evidence above; ai-auditor APPROVE-WITH-NOTES 2026-08-12 (note: isSafeTaskBatch returns false for non-A/B/C singleton batches like ['coder'], but the outer check requires calls.length > 1 before invoking - runtime behavior correct, documented); CHANGELOG entry + this learnings entry + ticket OPEN -> VERIFIED (README index + status counts updated: OPEN 28->26, VERIFIED 16->18).
- Restart-smoke (step 5): the batch-aware check ran under the live plugin during the implementation session (behavioral test executed via node against the working-tree plugin). Full daemon restart not performed; plugin change loads on the next natural OpenCode restart. Recorded honestly in the ticket; no fabricated restart evidence.

## Reusable lesson

.ts test files must never be stored in the repo: OpenCode picks up .ts files as potential instruction/plugin sources, so an ephemeral plugin behavioral test belongs outside the tree (run via node, delete after) with the results recorded in the ticket instead. A plugin guard and the prompt rule it enforces must share one batch taxonomy: the A1 plugin's READ_ONLY_LANES/WRITER_LANES must stay in lockstep with the BATCH-DISPATCH A/B/C batches in the preset prompts (DIA-119) or the warning behavior silently disagrees with what agents are told is legal. Keep the "warn, don't block" semantics: a plugin advisory should degrade toward silence when it can't classify, never toward blocking legitimate work.

## Tags

DIA-120, DIA-116, DIA-119, delegation-observer, a1_violation, batch-aware, isSafeTaskBatch, READ_ONLY_LANES, WRITER_LANES, parallelization, plugin, .ts-test-not-stored, test-config, ai-auditor, config-fix-workflow
