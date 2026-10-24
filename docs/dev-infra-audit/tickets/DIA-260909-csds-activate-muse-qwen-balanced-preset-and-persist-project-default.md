# DIA-260909-csds - Activate Muse Qwen balanced preset and persist project default

---

id: DIA-260909-csds
title: "Activate Muse Qwen balanced preset and persist project default"
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
source: fix-lane
date: 2026-09-09
created: 2026-09-09
updated: 2026-09-11

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

`/preset muse-qwen-balanced` works for the current process but does not survive
a full OpenCode restart in this project. OMO 2.2.17 writes the selection only to
the user config (best effort), while `.opencode/oh-my-opencode-slim.jsonc` is
the project config and therefore takes precedence at startup. Its root pointer
was still `promo`.

Make `muse-qwen-balanced` the persistent project default and change only its
orchestrator primary from Qwen3.8 Flash to paid OpenCode Go Muse Spark 1.3
Contributor with high reasoning. Preserve the existing fallback chain. This
does not change arbitrary future `/preset` selections: user-config persistence
is intentionally lower priority than the project config, except for the
higher-priority `OH_MY_OPENCODE_SLIM_PRESET` environment override.

## Verification

- [ ] JSONC and project config validation pass.
- [ ] Static effective config resolves `preset: muse-qwen-balanced` and the
      orchestrator primary is `opencode-go/muse-spark-1.3-contributor` / high.
- [ ] In the actual OpenCode container, `/models` lists the paid Muse ID and a
      fresh restart reports `muse-qwen-balanced` as active.
- [ ] One minimal orchestrator dispatch completes using the expected model.
- [ ] Independent AI-auditor review and changelog registration complete.

## UPDATE (2026-09-09, coder verification lane, campaign ticket DIA-260909-csds)

Developer privacy acceptance (VERBATIM):

"Yes. I explicitly accept routing the orchestrator to paid opencode-go/muse-spark-1.3-contributor with high reasoning. I understand it is training-enabled, non-ZDR, and region-limited. No secrets, API keys, credentials, private tokens, or sensitive personal data may appear in user prompts, dispatch payloads, handoffs, tickets, or agent results. Keep the existing DeepSeek Flash and MiMo Free fallbacks."

## Fix

Already-applied state; this lane made NO JSONC edits and NO commits.

The working tree already contains the fix (uncommitted, applied by a prior
lane): `.opencode/oh-my-opencode-slim.jsonc` root pointer `"preset": "promo"`
-> `"preset": "muse-qwen-balanced"`, and the `muse-qwen-balanced`
orchestrator block primary `"opencode-go/qwen3.8-flash"` ->
`"opencode-go/muse-spark-1.3-contributor"` with `"variant": "medium"` ->
`"variant": "high"`. Fallback chain unchanged:
`opencode-go/deepseek-v4-flash`, `opencode/mimo-v2.5-free`.

Gate file reference: ai-specialist gate learnings at
`.opencode/learnings/external-patterns/2026-09-09-dia-260909-csds-preset-precedence-and-muse-high-gate.md`
(documents OMO 2.2.17 project-config precedence over user-config `/preset`
persistence, plus the paid-Muse privacy gate). Origin preset block:
DIA-260909-tp5e 'add muse qwen balanced agent routing preset' (commit 918ff65).

## Re-verify

Closed per developer 2026-09-11: stale paid-Muse expectation, no longer wanted.
Superseded by DIA-260910-sjtk which covers Zen Muse Free routing.
No further work under this ticket; ledger close only.
