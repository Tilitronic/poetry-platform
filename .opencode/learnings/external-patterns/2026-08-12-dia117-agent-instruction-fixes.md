# DIA-160 agent-instruction fixes - HANDOFF.md refs, AGENTS.md section-10 repoint, boss_append.md duplicate removal (2026-08-12)

- **Date:** 2026-08-12
- **Source:** DIA-160 fix ticket (from ana016-agent-instruction-audit, DIA-157, audit 2026-08-12); coder-lane implementation + this AGENTS.md section 2.5 close-out registration lane (docs lane).
- **Status:** VERIFIED - all three fixes applied and gate-verified; ai-auditor independent review APPROVE-WITH-NOTES (implementation PASS; only process evidence pending at review time, closed by this registration).
- **Outcome:** config-fix workflow completed per AGENTS.md section 2.5 - fixes implemented, validated (make test-config sub-commands all exit 0), ai-auditor APPROVE-WITH-NOTES, then registered (CHANGELOG entry + this learnings entry + ticket OPEN -> VERIFIED). Restart-smoke: the fixed config was live throughout the implementation session (all dispatches incl. the ai-auditor review ran under it); full daemon restart pending next natural OpenCode restart, recorded honestly rather than fabricated.

## Ticket

- **DIA-160** (Major, VERIFIED) - "Fix agent-instruction audit findings: HANDOFF.md refs, missing AGENTS.md section 10, boss_append.md duplicate".
- **Related:** DIA-157 (agent-instruction-files audit, parent), ana016 (audit knowledge base).

## Fixes (implemented 2026-08-12, working tree)

- **FIX 1 - HANDOFF.md -> .opencode/session/current-handoff.json.** oh-my-opencode-slim.jsonc lines 26/210/401 (3 preset prompts): the prompts referenced "HANDOFF.md" but the runtime handoff file is .opencode/session/current-handoff.json (HANDOFF.md is only a template). `rg "HANDOFF\.md"` -> 0 matches.
- **FIX 2 - "AGENTS.md section 10" -> "AGENTS.md section 2.5".** oh-my-opencode-slim.jsonc lines 26/210/401/581/582/585 + docs/dev-infra-audit/NEXT-RUN.md:124. AGENTS.md has no section 10 - the AI Devtools Modernization Workflow lives at section 2.5; references repointed without breaking the workflow. `rg "section 10|S10"` -> 0 matches in fix-scope files.
- **FIX 3 - boss_append.md deleted.** .opencode/oh-my-opencode-slim/boss_append.md (100 lines, ~80% byte-identical to orchestrator_append.md) git-rm'd; scripts/test-interview-enforcement.sh Check 5 repointed to orchestrator_append.md. `rg "boss_append"` -> 0 matches in both jsonc configs.

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

- Config-fix workflow completed per AGENTS.md section 2.5 (Validate + Register steps): gate evidence above; ai-auditor APPROVE-WITH-NOTES (2026-08-12); CHANGELOG entry + this learnings entry + ticket OPEN -> VERIFIED (README index + status counts updated: OPEN 27->26, VERIFIED 15->16).
- Restart-smoke (step 5): config was live throughout the implementation session - dispatches ran under the new config with zero HANDOFF.md / section-10 / boss_append regressions. Full daemon restart not performed; staged config loads on the next natural OpenCode restart. Recorded honestly in the ticket; no fabricated restart evidence.

## Reusable lesson

Runtime-file references in prompts must point at the actual runtime artifact, not the template: the handoff template is HANDOFF.md but the runtime file is .opencode/session/current-handoff.json - a prompt referencing the template name reads a file that never updates. Likewise section references must resolve to the real AGENTS.md section (the AI Devtools Modernization Workflow is section 2.5, not "section 10"). Dead duplicates are a single-sourcing hazard: boss_append.md was ~80% byte-identical to orchestrator_append.md and drifted separately - delete duplicates and repoint dependents (scripts/test-interview-enforcement.sh Check 5) at the source. For config fixes, evidence verification is mechanical (rg over fix-scope files + config gate sub-commands) - run the greps, record the counts, and never claim a restart that did not happen.

## Tags

DIA-160, DIA-157, ana016, agent-instruction-audit, HANDOFF.md, current-handoff.json, section-2.5, single-source-of-truth, dead-duplicate, boss_append, orchestrator_append, test-config, ai-auditor, config-fix-workflow
