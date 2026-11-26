---
date: 2026-08-14
topic: interview completeness vs batch question-drop (DIA-103 reframe)
source: ai-specialist phase-1 gate, DIA-103
ticket: DIA-103-interview-batch-completeness
status: active
---

# Interview completeness vs batch question-drop (DIA-103 Phase 1 gate findings)

## (a) Enforcement gap analysis -- current state

Existing enforcement layers:
| Layer | File:Line | What it enforces | Mechanical? |
|-------|-----------|------------------|-------------|
| Interview-First Gate | orchestrator_append.md:36-43 | ALL engineering work passes interview -> spec -> validate -> delegate | Prompt-level |
| One-at-a-time delivery (openspec-plan) | oh-my-opencode-slim.jsonc:614 | Questions delivered sequentially, each with recommended answer | Prompt-level |
| One-at-a-time delivery (openspec-propose skill) | .opencode/skills/openspec-propose/SKILL.md:35 | "One question at a time, each with the model's recommended answer" | Prompt-level |
| One-at-a-time delivery (domain-grilling) | .opencode/skills/domain-grilling/SKILL.md:24 | "Ask the questions one at a time, waiting for feedback on each question" | Prompt-level |
| Transcript-before-synthesis | openspec-propose/SKILL.md:42 | Do NOT proceed to artifact synthesis without interview transcript | Prompt-level |
| openspec validate | openspec-propose/SKILL.md:62 | Structural artifact validation AFTER synthesis | Mechanical (CLI) |
| Banned phrases check | scripts/test-interview-enforcement.sh:88-101 | Interview-first language checks | Mechanical (grep) |
| Fast-Path Opt-In gate | orchestrator_append.md:73-95 | Bypass requires explicit opt-in + eligibility checklist | Prompt-level + audit trail |
| Practice-protected zone | practice-protected.md:9-12 | Developer writes proposal/design substance | Prompt-level |

The gap (NOT enforced):
1. No mechanical count of questions asked vs planned (Q1-Q11 Full / <=5 Compressed).
2. No transcript artifact -- interview lives only in conversation context.
3. No pre-synthesis completeness gate -- only openspec validate AFTER synthesis.
4. No detection of premature termination (agent proceeds after Q3 of 11).

## CRITICAL TENSION

The one-at-a-time rule ALREADY prevents batch question-drops. DIA-103 describes "interview agent returns N questions -> workflow captures all N answers" but both interview agents deliver questions ONE AT A TIME. N simultaneous questions is itself a protocol violation. The REAL risk is PREMATURE TERMINATION: agent skips remaining questions and moves to synthesis.

Scope recommendation: reframe DIA-103 from "batch completeness" to "interview completeness vs depth mode plan." Full mode (11+ questions) real risk; Compressed (<=5) and domain-grilling (unstructured) lower risk.

## (b) Enforcement mechanism EBDV variants

Variant 1 (RECOMMENDED): Status Quo + Soft Prompt Gate. Add a "Completion Self-Check" phase to openspec-plan orchestratorPrompt: before synthesis, state which depth mode was used and confirm all applicable questions asked+answered; if skipped, state why. No new scripts/tools/plugins. Effort ~30 min. Pros: zero infra, works with one-at-a-time, self-documenting, practice-protected compatible. Cons: still prompt-level (fabricatable). Evidence: oh-my-opencode-slim.jsonc:614 (append-only Phase 5), opencode-best-practices.md:29, orchestrator_append.md:73-95 (fast-path self-declaration pattern). §10-routed: YES.

Variant 2: Transcript Artifact + Validator Script. Agent writes .opencode/session/interview-transcript-<change>.json with structured Q&A; scripts/validate-interview-completeness.sh checks against depth-mode battery; wired into openspec-propose as pre-synthesis step + make test-config. Effort 4-6 hrs. Pros: mechanical, testable, follows test-interview-enforcement.sh pattern. Cons: transcript is LLM-generated (fabricatable), question battery not machine-readable (drift risk). §10-routed: YES.

Variant 3: Plugin Hook on Synthesis Transition. delegation-observer intercepts openspec new change/instructions, counts user turns vs threshold (5 Compressed / 11 Full). Effort 8-12 hrs. Pros: truly mechanical. Cons: user-turn count poor proxy, needs depth-mode knowledge, plugin rebuild cycle, affects all OMO users. §10-routed: YES.

Variant 4: ABORT / Status Quo. Close DIA-103 as no-action. Evidence: both skills deliver one-at-a-time; no batch-drop incidents in session history (searched messages.jsonl). Effort 0.

## (c) Test case (Variant 1)

Dispatch @openspec-plan with Full-mode feature. Expected: agent declares "Full", asks Q1->developer responds, ... through all applicable questions; before synthesis states "Completion self-check: depth mode Full, questions asked Q1-Q11 (11/11), all answered." Negative test: after only Q3, self-check reads "Q1-Q3 (3/11), Q4-Q11 skipped because [reason]"; developer decides continue or accept partial.

## (d) Recommendation

Variant 1 (Status Quo + Soft Prompt Gate). Because: (1) the problem as described does not exist -- one-at-a-time prevents batches; (2) real risk is premature termination, soft gate addresses at minimal cost; (3) mechanical enforcement (V2/V3) has diminishing returns -- LLM-generated transcript fabricatable, user-turn count poor proxy, zero incidents in production; (4) reframe DIA-103 scope; (5) downgrade severity Medium -> Low.

## (e) Sources consulted

- DIA-103 ticket: docs/dev-infra-audit/tickets/DIA-103-interview-batch-completeness.md
- oh-my-opencode-slim.jsonc:614 (openspec-plan prompt)
- .opencode/skills/openspec-propose/SKILL.md, openspec-update-change/SKILL.md, openspec-explore/SKILL.md
- .opencode/skills/domain-grilling/SKILL.md:24
- .opencode/oh-my-opencode-slim/orchestrator_append.md:36-95
- .opencode/practice-protected.md
- scripts/test-interview-enforcement.sh
- .opencode/commands/opsx-continue.md
- .opencode/learnings/external-patterns/2026-08-02-interview-gate-enforcement.md
- .opencode/learnings/external-patterns/2026-08-01-boss-aihero-interview-delegation.md
- .opencode/oh-my-opencode-slim/knowledge/opencode-best-practices.md
- .opencode/session/messages.jsonl (incident search: no batch-drop incidents found)
- AGENTS.md (global + project)
