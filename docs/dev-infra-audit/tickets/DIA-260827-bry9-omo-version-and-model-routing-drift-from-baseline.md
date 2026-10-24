# DIA-260827-bry9 - OMO version and model-routing drift from baseline

---

id: DIA-260827-bry9
title: "OMO version and model-routing drift from baseline"
area: opencode-config
severity: High
status: DONE
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: DIA-260827-wfcx
gate_state: "grilled" # grilled | waived | bypassed | partial | skipped
gate_triggers: [cross-cutting] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-27
source: test-lane
date: 2026-08-27
created: 2026-08-27
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
evidence:

- DIA-260827-wfcx

---

## Description

Reaudit (DIA-260827-wfcx, 2026-08-31; S-H3) confirms the global config sets a root model and overlapping agents; runtime resolves orchestrator/reviewer to the global DeepSeek V4 Pro instead of promo Hy3/Muse (oh-my-opencode-slim.jsonc:1154-1160,1230-1235); legacy architect/tester/writer are also present. Impact: the verified cost/quota/model-diversity and role contracts are not the actual runtime. Correct fix: remove global profiles from the project runtime or drop overlapping agent/model blocks; add a mandatory resolved-config test.

## Verification

opencode agent list / opencode debug shows orchestrator and reviewer resolve to promo Hy3/Muse, not the global DeepSeek V4 Pro; legacy architect/tester/writer absent.

## Fix

Remove the global root model and overlapping agent/model blocks from the project runtime, or eliminate overlapping definitions; add a resolved-config test that asserts the active preset's agents/models.

## Re-verify

> To be filled at re-verify time.

## Close-as-stale 2026-09-22 (bounded lane, campaign ticket DIA-260827-bry9)

- Freshness recon ses_f36f90630ffeTXfbokr8S7Jzb2 proved all 3 claims STALE; developer approved close-as-stale 2026-09-22.
- Claim 1 STALE: no top-level model key in .opencode/oh-my-opencode-slim.jsonc (grep '^ "model"' absent; top keys are $schema/preset/compactSidebar/disabled_agents/presets/agents/council).
- Claim 2 STALE: agents block (lines 789-826) has zero model keys (prompt/orchestratorPrompt only; model keys live under presets.\* and council.presets.default).
- Claim 3 STALE: legacy tester/writer absent as agent keys (also architect key absent); only "legacy fallback" prose inside orchestrator prompt text.
- Context: claims predate current 857-line config; live debug shows opencode-go/muse-spark-1.3-contributor for orchestrator+reviewer (active preset muse-balanced). No code change; ticket file only.

## Update 2026-09-17 (re-review cycle 1, docker pin stopgap)

- Standalone pin bumped: tools/opencode-docker/config/opencode.json
  oh-my-opencode-slim@2.2.14 -> oh-my-opencode-slim@2.2.19 (commit 1012e25).
- Load evidence (dry-run install of the exact pin read from the config,
  npm install --dry-run --no-save oh-my-opencode-slim@2.2.19, exit 0):
  evidence line "add oh-my-opencode-slim 2.2.19" ("added 175 packages in 4s",
  no resolve error). Resolver output ASCII-only; allow-scripts warnings are
  pre-existing postinstall notices, not errors.
