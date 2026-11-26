# DIA-260827-8la4 - [MEDIUM] Model routing sources disagree (registry vs prompt vs runtime)

---

id: DIA-260827-8la4
title: "[MEDIUM] Model routing sources disagree (registry vs prompt vs runtime)"
area: opencode-config
severity: Medium
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-27
source: inventory
date: 2026-08-27
created: 2026-08-27
updated: 2026-08-27

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
evidence:

- oh-my-opencode-slim.jsonc:791-796,1341-1342; knowledge/model-registry.yaml:64-74,153-157; runtime debug

---

## Description

Reaudit (DIA-260827-wfcx, 2026-08-31; W-M1) confirms the active promo preset (oh-my-opencode-slim.jsonc:3) routes analyzer-escalated to DeepSeek (:1306-1314), while AGENTS.md and knowledge/model-registry.yaml:167-171 name GPT-5.6 Luna; the reviewer preset and registry also diverge. Impact: quota/cost/capability policy does not match runtime. Correct fix: one generated routing source plus an effective-runtime validation.

## Verification

Resolved runtime routing matches a single generated source; a validation gate fails on divergence.

## Fix

Detail: analyzer-escalated DeepSeek V4 Pro at oh-my-opencode-slim.jsonc:791-796; prompt GPT-5.6 Luna at 1341-1342; registry GPT-5.6 Luna at knowledge/model-registry.yaml:64-74,153-157; runtime debug confirmed DeepSeek V4 Pro/max; reviewer and coder also differ.

Fix: establish one routing source and validate resolved runtime agents against it.

## Re-verify

> To be filled at re-verify time.
