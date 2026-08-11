# DIA-086 — improve workflows with a modern scientific-methodology approach — evidence-based reasoning, source citing, reproduction, hypothesis building

<!-- Filed by the docs lane (code-executor re-route) 2026-08-10. -->

---

id: DIA-086
title: "improve workflows with a modern scientific-methodology approach — evidence-based reasoning, source citing, reproduction, hypothesis building"
area: docs
severity: Medium
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
discovered: 2026-08-10
source: inventory
date: 2026-08-10
created: 2026-08-10
updated: 2026-08-11

# --- Session Attribution (v2 schema, optional) ---

session_id: "ses_0133de7fdffeKc3ClhE6fqFy0X"
lane_id: "docs"
agent: "code-executor"
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: ""
files_touched: ["docs/dev-infra-audit/tickets/DIA-086-scientific-methodology-workflow.md"]
artifacts: []
evidence: []

---

## Description

Investigate how to improve workflows with a modern scientific-methodology
approach: evidence-based reasoning, research-backed claims, source citing,
validation through reproduction/recreation, hypothesis building, and theory
formation. Check how agentic-AI systems already implement this (e.g.,
researcher + conspect + analysis pipelines, hypothesis-test loops).

## Verification

- [ ] Survey existing agentic-AI implementations of scientific-methodology workflows (researcher + conspect + analysis pipelines, hypothesis-test loops).
- [ ] Map current project workflow (research-pipeline, knowledge/, tdd-craftsman) to the scientific-method stages.
- [ ] Identify gaps and propose a documented workflow incorporating evidence-based reasoning, source citing, reproduction, hypothesis building.

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.

## Scope extension (batch brief 2026-08-11)

1. Investigate modern scientific methodology for agentic workflows:
   hypothesis formation, explicit assumptions, theory construction,
   literature/research review, evidence collection, experiment design,
   controlled testing, validation, reproduction, independent verification,
   falsification, confidence/uncertainty, provenance/citations, experiment
   logs, competing hypotheses, systematic comparison, peer/reviewer-style
   critique.
2. Survey how similar approaches are implemented in agentic AI systems, AI
   research agents, scientific-agent frameworks, software engineering
   agents, autonomous coding/research workflows.
3. Determine: which practices are realistically useful for this project;
   which are already implemented; which are missing; which should become
   mandatory workflow steps; which stay optional depending on task
   complexity.
4. Produce a concrete proposed workflow, not a generic discussion.

SCOPE GUARD: this is a solo-developer system, not a research lab. Weight the
output toward "what's cheap and actually gets used" over building a full
methodology framework - flag anywhere the recommendation risks adding
process overhead disproportionate to the team size.

Acceptance: concrete workflow proposal, already-implemented inventory,
mandatory-vs-optional split, overhead-risk flags.

## Session-11 dispositions (2026-08-11)

Pipeline complete. External survey persisted at
`knowledge/res012-scientific-methodology/` (50/50 sources archived, conspect +
memory-shelf entry). Workflow proposal at
`knowledge/ana012-scientific-workflow-proposal/` (M1-M5 mandatory, O1-O6
rejected per SCOPE GUARD).

Developer APPROVED M1-M5 for implementation via the spec chain. Interview-first
gate applies: dispatch `openspec-plan` next to author the change artifacts
(proposal/design/tasks) before implementation.

DIA-085 coordination build DEFERRED until parallel work starts.

Status: OPEN (implementation pending).
