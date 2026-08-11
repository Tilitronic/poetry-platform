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
updated: 2026-08-10

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
