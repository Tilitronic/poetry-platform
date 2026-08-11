# DIA-103 - interview batch completeness enforcement: verify workflow captures ALL questions, not just the first

<!-- Analyzer-authored manifest transcribed by the coder lane (2026-08-11).
     Parallel dev infra batch ticket. opencode-config: enforces that when an
     interview agent returns a batch of questions, the workflow requires and
     captures answers to ALL of them before artifact synthesis proceeds.
     Targets openspec-plan and domain-grilling interview flows. -->

---

id: DIA-103
title: "interview batch completeness enforcement: verify workflow captures ALL questions, not just the first"
area: opencode-config
severity: Medium
status: OPEN
blocked_by: []
discovered: 2026-08-11
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

Verify and enforce that when an interview agent (openspec-plan or
domain-grilling) returns a batch of questions, the workflow requires and
captures answers to ALL questions - not just the first. Current openspec-plan
INTERVIEW PROTOCOL (MANDATORY) in oh-my-opencode-slim.jsonc defines Depth
Mode Selection + Phases 1-4, but no mechanical enforcement that all questions
get answered. Problem: a developer should NOT answer only the first question
when the specification-interviewing agent returns a batch of questions. Test:
interview agent returns N questions -> workflow requires + captures all N
answers before proceeding to artifact synthesis.

### Investigation requirements

1. Read openspec-plan interview protocol (oh-my-opencode-slim.jsonc,
   orchestratorPrompt/openspec-plan sections).
2. Read domain-grilling skill (.opencode/skills/domain-grilling/SKILL.md).
3. Identify enforcement gap: is there a mechanical check that all questions
   are answered?
4. Propose enforcement mechanism (e.g., openspec-validate check, or
   practice-protected gate, or prompt-level rule).
5. Define test: N questions returned -> N answers required before synthesis.
   Investigate how multiple questions are currently represented and passed to
   the developer, whether all are preserved, whether answers map reliably
   back to individual questions, whether incomplete answers are detected.

### Deliverables

- Enforcement gap analysis (current state).
- Enforcement mechanism proposal.
- Test case (N questions -> N answers).

## Verification

- [ ] (a) Gap analysis documents current enforcement (or lack thereof).
- [ ] (b) Mechanism proposal tested with 3+ question batch.
- [ ] (c) All N answers captured before synthesis proceeds.
- [ ] (d) Cross-linked with openspec-plan interview protocol.

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
