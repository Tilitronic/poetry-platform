# DIA-260909-18f4 - Evaluate replacing Qwen3.8 Flash with OpenAI GPT-5.6 Terra High in agent routing

---

id: DIA-260909-18f4
title: "Evaluate replacing Qwen3.8 Flash with OpenAI GPT-5.6 Terra High in agent routing"
area: opencode-config
severity: Medium
status: CLOSED
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-09-09
source: inventory
date: 2026-09-09
created: 2026-09-09
updated: 2026-09-09

# --- Session Attribution (v2 schema, optional) ---

session_id: ""
lane_id: ""
agent: ""
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: "" # ISO-8601; set on DISPATCHED, cleared on COMPLETE
files_touched: []
artifacts: []
evidence: []

---

## Description

Replace every `opencode-go/qwen3.8-flash` occurrence in the active
`muse-qwen-balanced` preset with `openai/gpt-5.6-terra` using `high` reasoning.
Do not modify inactive presets, global council routes, the model registry, or
unrelated fallback surfaces unless the Section 2.5 review identifies an
essential lockstep contract. Inventory each active-preset occurrence before
editing; the requested scope includes primaries and fallbacks alike.

This remains a policy-class routing change: direct OpenAI provider availability,
quota, cost, privacy, and automatic fallback behavior must be verified before
the config edit. Prior direct-provider quota failures make live availability a
hard activation gate.

## Verification

- [x] AI-specialist gate records every active-preset Qwen3.8 Flash occurrence
      and >=2 evidence-backed variants, including status quo.
- [x] Live `/models` and one minimal OpenAI dispatch verify Terra availability
      and `high` variant in this project account.
- [x] The implementation replaces all and only active-preset Qwen3.8 Flash
      references with Terra high; inactive presets remain unchanged.
- [x] Config validation, restart smoke, AI-auditor review, and changelog pass
      before closure.

## Fix

Variant A implemented (developer-approved) - replace Qwen3.8 Flash with GPT-5.6 Terra High in muse-qwen-balanced routing.

5 loci in .opencode/oh-my-opencode-slim.jsonc (preset block L687+), all first-entry primaries retargeted opencode-go/qwen3.8-flash -> openai/gpt-5.6-terra, fallbacks kept for 429-degrade:

1. L730 openspec-plan primary (fallback muse-1.3), variant high.
2. L766 reviewer primary (fallback deepseek-v4-pro), variant high.
3. L779 analyzer primary (fallback muse-1.3), variant high.
4. L827 ai-specialist primary (fallbacks gpt-5.3-codex, big-pickle), variant high.
5. L933 analyzer-escalated fallback (after deepseek-v4-pro max object), variant max.
   Inactive presets (opencode-go, cebula, promo, free) and council seat (deepseek-v4-pro) untouched.

Locksteps:

- .opencode/opencode.jsonc: inline "model": "opencode-go/qwen3.8-flash" on ai-specialist REMOVED (was L607); inline wins in NPM runtime so removal (not retarget) kills the dual-runtime divergence.
- knowledge/model-registry.yaml: added openai/gpt-5.6-terra entry (analysis-primary, lanes openspec-plan/reviewer/analyzer/ai-specialist/analyzer-escalated, source_ref DIA-260909-18f4); qwen3.8-flash entry RETAINED for council seat + inactive presets.

Auditor note-level fixes (close-out):

- Preset comment block L684-686 refreshed: was stale (described pre-Terra muse/deepseek-pro composition), now documents Variant A Terra composition (reviewer/analyzer/openspec-plan/ai-specialist qwen3.8->terra|high, analyzer-escalated fallback qwen3.8->terra|max).
- Registry routing_table: Analyzer + Analyzer-route-back rows aligned to openai/gpt-5.6-terra (match runtime primary); Rung2 keeps qwen3.8-flash with explicit ticket-referenced comment marking intentional divergence (coder volume lane, cost; Terra is analysis-primary only). ASCII-only throughout.

## Re-verify

Close-out re-verify 2026-09-09 (all gates exit 0 unless noted):

- make test-config: exit 0 (incl. validate-plugin-structure structural gates PASS).
- check-orchestrator-prompt-drift.sh: exit 0 (3 presets, 9 markers each, 0 gaps, byte-identical).
- validate-agent-names.sh: exit 0 (24 passed, 0 failed, 0 warnings).
- opencode serve host smoke: HTTP 200 on 127.0.0.1:4099 (config loads under serve; no Docker daemon in this env so container author-studio probe N/A).
- Terra live probe: `opencode run -m openai/gpt-5.6-terra --variant high` returned TERRA-SMOKE-OK, exit 0, self-reported model match, no 429/401 (fresh close-out probe; confirms gate PASS recorded in learnings).
- Changelog: scripts/changelog-add ok (entry DIA-260909-18f4, scope opencode-config); validate-changelog.sh 1 passed 0 failed exit 0; changelog-render ok (133 entries); entry verified via python3 PyYAML partial-read query.
- ai-auditor: GO-with-notes per orchestrator (both notes addressed above: comment refresh + routing_table alignment/divergence note).
- Full TUI restart smoke: DEFERRED to developer (explicitly out of scope for this lane; host serve-200 + config validation stand in).
  Grep guard: active preset holds 0 qwen3.8-flash refs (5 Terra); inactive presets unchanged (qwen retained).
