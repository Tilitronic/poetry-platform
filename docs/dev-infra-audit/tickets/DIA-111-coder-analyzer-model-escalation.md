---
# DIA-111 - model escalation routing for coder and analyzer agents (research-first)

<!-- Filed 2026-08-12 by developer request. Design an escalation ladder for the
coder agent (complex/advanced problem-fix tasks) and the analyzer agent
("we don't understand the problem" -> expert analysis), backed by research
(benchmarks + escalation approaches) BEFORE any implementation. Config
changes, if any, route through the section-10 chain. -->
---

id: DIA-111
title: "model escalation routing for coder and analyzer agents (research-first)"
area: opencode-config
severity: Medium
status: OPEN
blocked_by: []
discovered: 2026-08-12
source: owner-reported
date: 2026-08-12
created: 2026-08-12
updated: 2026-08-12

# --- Session Attribution (v2 schema, optional) ---

session_id: ""
lane_id: ""
agent: ""
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: ""
files_touched: ["docs/dev-infra-audit/tickets/DIA-111-coder-analyzer-model-escalation.md"]
artifacts: []
evidence: []

---

## Description

Developer request (2026-08-12): implement model escalation routing so the
coder agent escalates to stronger models when a task is complex or needs an
advanced problem fix, and the analyzer escalates to GPT-5.6 Luna when it
"doesn't understand the problem".

Developer-provided reference flow (ASCII, verbatim intent):

Qwen3.7 Plus (architecture) / DeepSeek V4 Flash (implementation) handle the
user task; Codex performs the review; on problems the task escalates to
DeepSeek V4 Pro or MiMo V2.5 Pro, then re-review, then DONE. Separately, the
analyzer escalates to GPT-5.6 Luna for "we don't understand the problem"
expert analysis, then routes back to Qwen3.7 Plus.

Requirements:

1. RESEARCH FIRST (before any implementation): current benchmarks for the
   candidate models (deepseek-v4-flash, deepseek-v4-pro, qwen3.7-plus,
   gpt-5.3-codex, gpt-5.6-luna, mimo-v2.5-pro) and established escalation /
   model-routing approaches for agentic coding workflows. Conspect the
   research (see research-pipeline skill; res013-opencode-model-pricing-audit
   already archives 2026-08-12 pricing/benchmarks - reuse it, do not duplicate).
2. Design an escalation ladder for the coder agent: trigger conditions
   (complexity heuristics, repeated test failures, reviewer findings severity,
   reviewer "problems" signal), escalation steps, and fallback order.
3. Design analyzer escalation: "we don't understand the problem" trigger to
   GPT-5.6 Luna expert analysis, with routing back to the primary analyzer
   model after the analysis returns.
4. Any config change routes through the section-10 chain: ai-specialist
   research -> coder implement -> make test-config + restart-verify ->
   ai-auditor -> CHANGELOG.

## Verification

- [ ] Research complete: benchmark table for candidate models + escalation
      approaches summary, dated and sourced (reuse res013 where possible).
- [ ] Escalation design documented: trigger conditions, escalation steps,
      fallback order, re-entry conditions.
- [ ] If config changes: section-10 chain followed, make test-config exit 0,
      restart-verify + functional smoke.
- [ ] Analyzer escalation design documented with routing-back step.
- [ ] Ticket records research phase outcome before any implementation starts.

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.

---
