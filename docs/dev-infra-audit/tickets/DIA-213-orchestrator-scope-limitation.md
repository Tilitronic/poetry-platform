# DIA-213 — Orchestrator scope limitation: delegation + workflow decisions only, content decisions to specialized agents

---

id: DIA-213
title: "Orchestrator scope limitation: delegation + workflow decisions only, content decisions to specialized agents"
area: opencode-config
severity: High
status: OPEN
blocked_by: []
parent_epic: ""

# DIA-104 grilling-gate markers

gate_state: "skipped"
gate_triggers: []
gate_waivers: []
gate_override: ""
discovered:
source: fix-lane
date: 2026-08-17
created: 2026-08-17
updated: 2026-08-17

# --- Session Attribution ---

session_id: ""
lane_id: ""
agent: ""
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: ""
files_touched: []
artifacts: []
evidence: []

---

## Description

**Principle:** orchestrator makes ONLY delegation decisions and workflow/procedure selection. ALL other decisions (git status handling, research direction, content choices) must be made by specialized agents with domain expertise.

**Implementation scope:**

1. Analyzer must be able to run research->conspect->analysis pipeline autonomously when encountering questions beyond local facts.
2. Exploration and git state documentation are part of research, not orchestrator judgment calls.
3. Enforce this scope boundary via harness rules/gates.

**Why it matters:** The orchestrator currently makes content-level judgment calls (interpreting git status output, choosing research direction, deciding what constitutes a "finding") that belong to specialized agents. This creates two failure modes: (a) the orchestrator makes wrong content decisions without domain expertise, and (b) specialized agents are not given the autonomy to make decisions within their expertise. The scope boundary must be explicit and enforced.

### CLARIFICATION (2026-08-17): Analyzer to Orchestrator Research Request Pattern

The analyzer does NOT directly dispatch research. Instead:

1. Analyzer identifies a knowledge gap during analysis
2. Analyzer returns a structured signal: RESEARCH_REQUEST: <topic> + <reason>
3. Orchestrator recognizes the signal, pre-allocates res ID, runs research->conspect->analysis pipeline
4. Orchestrator feeds results back to analyzer for synthesis

This preserves clean responsibility boundaries:

- Analyzer: identifies WHAT it needs (knowledge gaps, research questions)
- Orchestrator: handles HOW to get it (delegates research, manages pipeline, pre-allocates IDs)
- Researcher: does the actual research (Phase A source capture)
- Conspecter: synthesizes findings

The analyzer NEVER directly dispatches @researcher or @conspecter. It returns a signal, the orchestrator routes. This is the "endocrine" pattern: the analyzer emits a systemic signal (research request), the orchestrator (the control center) processes it and coordinates the response.

### SELF-ANALYSIS MECHANISM

The orchestrator scope boundaries defined here are HYPOTHESES, not permanent rules. The analyzer must periodically evaluate:

1. Are the scope boundaries too narrow? (orchestrator making decisions it should delegate)
2. Are the scope boundaries too wide? (analyzer requesting research for things it could resolve locally)
3. Is the research request pattern working? (does the orchestrator actually run the pipeline when signaled?)
4. Are there new decision types that need scope assignment?

This is part of the self-improvement loop (AGENTS.md section 7): analyzer → reflect → outcome-verify. The analyzer should flag scope boundary issues as findings in its analysis reports, and the orchestrator should treat these as high-priority improvement candidates.

The goal is not to enforce a fixed architecture, but to iteratively discover the right boundaries through practice and critical analysis.

## Verification

- Audit orchestrator prompts for content-decision language (git interpretation, research direction, content judgment)
- Verify analyzer prompt enables autonomous pipeline execution
- Test that orchestrator dispatches content decisions to specialist agents rather than making them directly
- Check harness rules/gates enforce scope boundary

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
