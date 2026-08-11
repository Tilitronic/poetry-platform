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

## Session-11 implementation + archive complete (2026-08-11)

All M1-M5 slices fully implemented, reviewed, and archived.

### Slice A: Config-tooling (M1-M4) -- commit 01c2e5a

- M1: analyzer output contract (HTML-comment header block in analyzer.md + validate-output-contracts.sh)
- M2: conspecter output contract (HTML-comment header block in conspecter.md + same validator)
- M3: reviewer Falsification axis (## Falsification section in reviewer.md + validate-reviewer-sections.sh)
- M4: hypothesis question in openspec-propose + domain-grilling skills (<!-- FIRST-QUESTION --> anchor + validate-skills.sh extension)
- Review chain: @coder + @ai-auditor -- APPROVE (ai--1)

### Slice B: Dev-infra (M5) -- commits b9c2818..b9666b9

- 5.1: eval-lite task manifest (docs/dev-infra/eval-lite-tasks.md, 20 curated tasks) -- b9c2818
- 6.1: eval-lite harness script (scripts/eval-lite.sh) -- 4ea25d5
- 7.1: eval-lite bats test suite (scripts/**tests**/eval-lite.bats) -- 168330d
- 8.1: Makefile eval-lite target + test-config validator wiring + bats-wrapper allowlist -- faf8c92
- validate-skills.bats M4 fixture remediation -- b9666b9
- Review chain: @coder + @reviewer -- APPROVE both axes (rev-1)
- Developer acknowledged all 6 minor findings; review loop closed

### Gate summary (all green)

| Gate              | Result                                                                                     |
| ----------------- | ------------------------------------------------------------------------------------------ |
| make eval-lite    | 20 passed, 0 failed, ~22s                                                                  |
| make test-shell   | 193 ok, 0 not-ok (check-host-lsp prereq passes via container-first rust-analyzer, DIA-106) |
| make test-config  | 0 failures (224 pre-existing WARNs)                                                        |
| openspec validate | 15 passed, 0 failed (post-archive)                                                         |

### Archive

Change archived via openspec-archive-change to:
`openspec/changes/archive/2026-08-11-dia-086-m1-m5-agent-contracts-eval-lite/`

M1-M5 fully delivered. Frontmatter status left OPEN (post-merge shelf/CHANGELOG registration is a separate lane).
