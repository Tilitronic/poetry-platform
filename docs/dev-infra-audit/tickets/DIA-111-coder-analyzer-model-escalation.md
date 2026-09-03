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
status: CLOSED
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

### Probe (2026-08-12)

Empirical probe: does OpenCode task() (subagent dispatch) support a
per-dispatch model override? Decision input for Option B (orchestrator-prompt
routing) vs Option C (separate escalated agents).

- opencode version: 1.18.16 (host, /home/qualt/.opencode/bin/opencode);
  dev container has 1.18.4. Probe ran on host 1.18.16.
- task() input schema (from binary source, opencode 1.18.16): fields are
  description, prompt, subagent_type, task_id (optional), command
  (optional), background (optional). NO "model" parameter exists on the
  task tool. Source: `R = b.model ?? {modelID: U.info.modelID,
providerID: U.info.providerID}` -- child model resolved from the
  AGENT DEFINITION (`b.model`) or falls back to the invoking parent's
  model when the agent defines no model. Prompt text cannot change the
  child's model (resolved before the child prompt executes).
- Config mechanisms found: `"model"` key exists under agent definitions
  in both .opencode/opencode.jsonc (openspec-plan, ai-specialist ->
  opencode-go/qwen3.7-plus) and .opencode/oh-my-opencode-slim.jsonc
  (coder -> opencode-go/deepseek-v4-flash, analyzer/designer etc.).
  This is the ONLY model-override mechanism: agent-definition level,
  not per-dispatch.
- Docs (opencode.ai/docs/agents/): "Use the model config to override
  the model for this agent." Subagents without a model use the model of
  the primary agent that invoked them. No per-dispatch task model
  documented.
- Registry evidence: .opencode/session/registry.jsonl (2555+ rows) has
  ZERO "model" fields; delegation-observer.ts explicitly does not write
  gen_ai.request.model ("plugin hooks do not expose the model id").
  Dispatched lane rows record session_id/parent/status only.
- EMPIRICAL (2026-08-12, host 1.18.16):
  Test 1 (top-level override works): `opencode run --model
opencode-go/deepseek-v4-pro` -> session self-reported
  "opencode-go/deepseek-v4-pro". CLI -m/--model overrides the
  TOP-LEVEL session model only.
  Test 2 (per-dispatch override fails): parent session on
  opencode-go/deepseek-v4-pro dispatched task(subagent_type: coder).
  Task input carried ONLY description/subagent_type/prompt (no model
  param possible). Child session self-reported
  "opencode-go/deepseek-v4-flash" -- coder's CONFIG model from
  oh-my-opencode-slim.jsonc. The parent's model was NOT inherited and
  no override was possible.
- VERDICT: NO -- per-dispatch model override via task() is NOT
  supported in opencode 1.18.16. Child model is fixed by the agent
  definition's `model` key, or inherited from the parent only when the
  agent defines no model.
- IMPLICATION for DIA-111: Option B (orchestrator-prompt routing to a
  different model) is NOT feasible -- the task() tool has no model
  param and prompt directives cannot change the child's model. Option C
  (separate escalated agents, e.g., coder-escalated / analyzer-escalated
  defined in config with stronger models) is REQUIRED. The orchestrator
  escalates by dispatching task(subagent_type: "<escalated-agent>").
- Recommendation: design the ladder around Option C -- define escalated
  variants as dedicated agents with the target model + appropriate
  permission/variant; orchestrator picks the escalated agent on trigger
  conditions. Config changes route through the section-10 chain.
  Status stays OPEN.

### Design Requirements (2026-08-12, developer disposition)

Developer disposition on the Session 15 escalation-agent design
(coder-escalated -> opencode-go/kimi-k3, analyzer-escalated ->
opencode-go/gpt-5.6-luna). Verbatim requirement:

> why you chooses KIMI model, not gpt luna for exmample or qwen pro? I dont see strong arguments. It is actually a request for ticket: decisions and propositions must be evident based, argumanted with sources links or experiments done

Design-revision consequence: the Session 15 escalation-agent design
(coder-escalated model assignment, and by extension analyzer-escalated)
was NOT approved as-is; the model choices must be re-justified with cited
benchmarks/experiments before implementation.

Open evidence question: coder-escalated candidate models to compare with
sources = opencode-go/kimi-k3 (93.4% SWE-bench Verified per Go docs),
opencode-go/gpt-5.6-luna, opencode-go/qwen3.7-pro (and/or qwen3.7-plus),
opencode-go/deepseek-v4-pro. The comparison must reuse
knowledge/res013-opencode-model-pricing-audit/,
knowledge/res014-model-escalation-routing/,
knowledge/res015-mimo-v25-pro-evaluation/ conspects where possible (do not
duplicate) plus fresh web-sourced benchmarks.

Status: stays OPEN.

## Re-verify

RESTART-VERIFY PASS (2026-08-12) - escalation-agent config commit b0b3c76.

Config checks 5/5 PASS:

1. hidden:true present in .opencode/opencode.jsonc (coder-escalated line 293,
   analyzer-escalated line 239).
2. task:deny set on both escalated agents (coder-escalated and
   analyzer-escalated).
3. Model mappings consistent across S1-S4 lockstep contract: coder-escalated
   -> opencode-go/kimi-k3, analyzer-escalated -> opencode-go/gpt-5.6-luna.
4. Orchestrator permission.task allow-list present (.opencode/opencode.jsonc
   lines 167/170).
5. make test-config exit 0 with agent-name lockstep 24/0/0.

Live dispatch self-reports (task() runtime): coder-escalated reported
opencode-go/kimi-k3; analyzer-escalated reported opencode-go/gpt-5.6-luna.
Both hidden, both task:deny.

Session evidence: lane-0 checksum MATCH
(d25c724adcac211fa9c3d36fb840f7116b2d40c18555a7d9dd52ee34de3b45ff).

Status stays OPEN pending developer close decision.

CLOSED 2026-08-12 by developer decision (session S16). Restart-verify PASS; escalation ladder implemented (commit b0b3c76), validated (make test-config exit 0, lockstep 24/0/0), independently audited (ai-auditor APPROVE 8/8), and re-verified live (coder-escalated self-report opencode-go/kimi-k3; analyzer-escalated self-report opencode-go/gpt-5.6-luna). Follow-up tracking: DIA-116 (live in-repo Rung-3 benchmark) remains OPEN.

## DIA-116 follow-up resolved (2026-08-12): live in-repo benchmark CANCELLED by developer directive (no self-benchmarking); evidence gap closed via res017 authoritative sources (Vals AI kimi-k3 93.4% independent). Verdict: keep kimi-k3 default, fallback deepseek-v4-pro > mimo-v2.5-pro. No config change.

---
