# DIA-087 — audit picked models and model variants for current agents — is the assignment optimal?

<!-- Filed by the docs lane (code-executor re-route) 2026-08-10. DIA-078 research
     already found V4-Flash beats V4-Pro on agentic benchmarks; extend the audit
     to all agents and presets. -->

---

id: DIA-087
title: "audit picked models and model variants for current agents — is the assignment optimal?"
area: opencode-config
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
files_touched: ["docs/dev-infra-audit/tickets/DIA-087-agent-model-variant-audit.md"]
artifacts: []
evidence: []

---

## Description

Audit picked models and model variants for current agents — is the assignment
optimal? Use simpler/cheaper variants for clear order-following lanes (coder,
mechanical docs) and higher-capability models for creative or ambiguous tasks
(analyzer, architector, designer). DIA-078 research already found V4-Flash beats
V4-Pro on agentic benchmarks; extend the audit to all agents and presets.

## Verification

- [ ] Enumerate each agent's assigned model + variant across .opencode config and all presets.
- [ ] Classify each agent lane: clear order-following vs creative/ambiguous.
- [ ] Compare assignments against DIA-078 findings (V4-Flash > V4-Pro on agentic benchmarks) and adjust where suboptimal.
- [ ] Run make test-config to validate any config change.

## Fix

§10-routed (touches .opencode/ models and presets).

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.

## Scope extension (batch brief 2026-08-11)

1. The batch brief re-affirms the audit scope: determine whether model
   allocation is optimal. Evaluate the hypothesis that simpler/faster models
   suit deterministic tasks, clear instructions, routine execution, strict
   order following, while stronger models suit creative tasks, ambiguous
   requirements, architecture, difficult reasoning, research, hypothesis
   generation, unclear or novel problems. Do not assume the hypothesis is
   correct without evaluation.
2. Verify CURRENT model assignments post-merge (HEAD b005277 merged 8
   teammate commits including agent-scope/permission fixes): check
   .opencode/opencode.jsonc and .opencode/oh-my-opencode-slim.jsonc agent
   model fields for every configured agent.
3. Investigate per agent: task characteristics, model strengths/weaknesses,
   cost/latency, reliability, context requirements, tool-use performance,
   reasoning quality, instruction-following tendency, parallel-execution
   suitability.
4. Recommend changes ONLY where supported by evidence (e.g. DIA-062/DIA-064
   history: deepseek-v4-flash vs pro regressions; benchmark data from the
   model compendium conspect if available).

Deliverable: per-agent allocation table + evidence-based change
recommendations.

Acceptance: every agent audited, recommendations evidence-linked, any
proposed change routed through the S10 workflow.
