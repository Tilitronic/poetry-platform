# DIA-087 — audit picked models and model variants for current agents — is the assignment optimal?

<!-- Filed by the docs lane (code-executor re-route) 2026-08-10. DIA-078 research
     already found V4-Flash beats V4-Pro on agentic benchmarks; extend the audit
     to all agents and presets. -->

---

id: DIA-087
title: "audit picked models and model variants for current agents — is the assignment optimal?"
area: opencode-config
severity: Medium
status: CLOSED
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

Implemented 2026-08-11 (commits bcd4df0 + dcc7260 + 2fb3f48). Per-agent allocation
table, all recommendations evidence-linked:

| Rec | Change                                                                                                                                  | Evidence / rule                                                                              |
| --- | --------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------- |
| R1  | 4 gpt-5-mini primaries -> deepseek-v4-flash (cebula preset: conspecter / resource-manager / memory-manager / code-navigator)            | Model tiering by lane complexity - volume/mechanical lanes; DIA-062/064 flash-vs-pro history |
| R2  | architector -> gemini-3.1-pro-preview (fallback big-pickle retained)                                                                    | Creative/ambiguous lanes get the strongest capable model                                     |
| R3  | opencode-go preset coder + 5 agents (resource-manager / conspecter / memory-manager / code-navigator / researcher) -> deepseek-v4-flash | DIA-078: V4-Flash beats V4-Pro on agentic benchmarks                                         |
| R4  | stale V4 Pro pricing $1.74/$3.48 -> $0.435/$0.87 in ai-assist-sources.yaml                                                              | Web-fresh pricing - web-verified 2026-08-08, official DeepSeek pricing                       |
| R5  | MiMo evaluation QUEUED (deferred)                                                                                                       | Not enough evidence at audit time                                                            |
| R6  | inline resource-manager model override removed from opencode.jsonc:350                                                                  | Single source of truth - preset already declares the same model                              |

Post-implementation ai-auditor findings 8+9 (2fb3f48): code_navigator role mapping
corrected to "DS V4 Flash (Go)" in model_selection_guidelines; header
pricing-storage contradiction clarified (authoritative pricing NEVER stored; inline
prices are reference-only snapshots); strong_sides snapshot note added.

## Re-verify

Verified 2026-08-11:

- make test-config exit 0 (224 known WARNs) after all config changes.
- husky pre-commit ran live (no --no-verify) on every commit; docker gate
  poetry-dev + poetry-postgres healthy.
- No stale gpt-5-mini primaries remain for the R1 lanes; opencode.jsonc:350 no
  longer carries an inline resource-manager override; ai-assist-sources.yaml
  header + strong_sides snapshot semantics match the audit outcome.
- R5 (MiMo) explicitly queued - not silently dropped.
- Status: CLOSED.

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
