# DIA-260915-u8js - Reconcile inactive Muse Qwen balanced Zen-free routing and OpenAI Luna fallback

---

id: DIA-260915-u8js
title: "Reconcile inactive Muse Qwen balanced Zen-free routing and OpenAI Luna fallback"
area: opencode-config
severity: Low
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-09-15
source: inventory
date: 2026-09-15
created: 2026-09-15
updated: 2026-09-15

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

The inactive `muse-qwen-balanced` preset has an uncommitted routing update in
`.opencode/oh-my-opencode-slim.jsonc`. It replaces paid OpenCode Go Muse and
DeepSeek routes with Zen-free `opencode/muse-spark-1.3-contributor-free` and
OpenAI Luna fallback, and moves bounded utility roles to Luna. The model IDs
are present in the live catalogs, but the preset composition comment still
describes the old paid Muse/DeepSeek/MiMo chain. The diff has no OPEN owner:
`DIA-260909-csds` is CLOSED and explicitly superseded, while the later Sol,
Terra, and OpenAI-first tickets are also CLOSED.

Reconcile the comment and exact role mapping, retain the OpenAI-first preset as
the active default, and validate the inactive preset without consuming paid
OpenCode Go quota. Keep this change isolated from memory hygiene.

## Verification

- [ ] The composition comment matches every changed primary/fallback route.
- [ ] `opencode/muse-spark-1.3-contributor-free`, `opencode/mimo-v2.5-free`,
      and `openai/gpt-5.6-luna` resolve in the live model catalogs.
- [ ] The active preset remains `openai-first-cost-balanced`.
- [ ] `make test-config` and JSONC validation exit 0.
- [ ] After restart, selecting `muse-qwen-balanced` resolves only the approved
      free/OpenAI routes and returns a non-empty smoke response.
- [ ] Independent config audit, changelog, and isolated commit are complete.

## Fix

- [x] Updated the inactive `muse-qwen-balanced` composition comment to match the approved Zen-free/OpenAI fallback routes.
- [x] Preserved the `openai-first-cost-balanced` active preset pointer and all model route values.

## Re-verify

- [x] Static JSONC/config validation completed; no route or active-pointer changes were introduced.
- [x] `make test-config` passed (exit 0); runtime restart, smoke, independent audit, and changelog remain pending by design.
