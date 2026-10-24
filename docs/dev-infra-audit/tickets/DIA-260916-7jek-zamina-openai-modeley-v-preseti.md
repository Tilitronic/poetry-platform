# DIA-260916-7jek - Zamina OpenAI modeley v preseti

---

id: DIA-260916-7jek
title: "Zamina OpenAI modeley v preseti"
area: scripts
severity: Medium
status: CLOSED
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-09-16
source: inventory
date: 2026-09-16
created: 2026-09-16
updated: 2026-09-17

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

<To be filled at creation time: what is wrong / what to build, with exact
files and line references where known.>

## Verification

<Acceptance criteria as checkboxes - how to prove the ticket is done.>

## Fix

## Fix (2026-09-17, close lane)

Goal: promo preset must be openai-free (muse-qwen-balanced RENAMED to promo,
promo is main preset; openai-first-cost-balanced is separate for the openai
subscription). Only these 2 presets exist.

Changes (scoped diffs, committed separately):

1. .opencode/oh-my-opencode-slim.jsonc
   - promo.code-navigator model openai/gpt-5.6-luna ->
     opencode/muse-spark-1.3-contributor-free (dominant promo route, zero
     new model IDs; variant/skills/mcps unchanged). Promo now 0 openai/ hits.
   - openai-first-cost-balanced.orchestrator gained an inline prompt,
     byte-identical to the promo orchestrator prompt (routing-agnostic text;
     model/variant/temp/skills/mcps unchanged, still openai-only by design,
     17 openai/ hits, expected).
   - Stale L13-14 Luna-medium composition comment refreshed to describe the
     current promo routes (muse-spark/mimo/deepseek) + separate openai preset.
2. scripts/test-interview-enforcement.sh Check 1: preset tuple
   (opencode-go, cebula, free) -> (promo, openai-first-cost-balanced).
   Fixes KeyError 'opencode-go'; !openspec-propose intent unchanged.
3. scripts/check-orchestrator-prompt-drift.sh: default PRESETS retargeted to
   both current presets; byte-identity guard generalized (-eq 3 -> loop over
   all collected prompts). Marker set unchanged.
4. scripts/**tests**/check-orchestrator-prompt-drift.bats: fixtures converted
   3->2 presets (same stale-rename class; keeps test-shell green).
5. Gate record: .opencode/learnings/external-patterns/DIA-260916-7jek-preset-gate.md
   (AGENTS.md 2.5 step 1) + outcome section; CHANGELOG.yaml entry + render.

Developer rulings applied: Replace Luna (promo openai-free); Fix script tuple;
Add prompt + audit both (not promo-only).

## Re-verify

## Re-verify (2026-09-17)

Acceptance criteria and results:

- [x] Exactly 2 presets (promo + openai-first-cost-balanced), pointer "preset": "promo".
- [x] grep -n "openai/": 0 hits in promo block, 17 hits only in openai-first-cost-balanced (by design).
- [x] bash .opencode/scripts/validate-opencode-config.sh -> exit 0 (all JSONC valid).
- [x] bash scripts/check-orchestrator-prompt-drift.sh (default, no override) -> exit 0
      (2 presets checked, 9 markers each, 0 gaps, byte-identical).
- [x] make test-config -> exit 0 (tail: validate-plugin-structure.sh all structural gates PASS).
- [x] drift bats suite (bats-wrapper.sh --quick check-orchestrator-prompt-drift.bats) -> 16/16 ok.
- [x] Independent review: auditor ai--2 PASS WITH NOTES, no blockers.

Ticket closed after scoped commits; unrelated tree leftovers (agents/memory/README,
second ticket DIA-260916-ch3o) intentionally uncommitted.
