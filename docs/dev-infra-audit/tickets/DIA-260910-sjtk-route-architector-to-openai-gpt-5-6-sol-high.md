# DIA-260910-sjtk - Route architector to OpenAI GPT-5.6 Sol High

---

id: DIA-260910-sjtk
title: "Route architector to OpenAI GPT-5.6 Sol High"
area: opencode-config
severity: Major
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-09-10
source: inventory
date: 2026-09-10
created: 2026-09-10
updated: 2026-09-10

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

- <https://developers.openai.com/api/docs/models/gpt-5.6-sol>
- <https://developers.openai.com/api/docs/models/gpt-5.6-luna>

---

## Description

Route the architector lane of the active muse-qwen-balanced preset from the
unavailable github-copilot/gemini-3.1-pro-preview to openai/gpt-5.6-sol at high
reasoning (big-pickle fallback retained). Scope is architector-only: the
coder-escalated Terra High change belongs to DIA-260911-rqmw, and Luna
utility-lane routing is tracked outside this ticket. Config target:
.opencode/oh-my-opencode-slim.jsonc (muse-qwen-balanced architector block
only).

## Verification

✓ **Configuration change applied to muse-qwen-balanced preset (architector-only):**

- **architector**: `["openai/gpt-5.6-sol", "opencode/big-pickle"]` at variant `high` ✓

No other lane is changed by this ticket. Orchestrator / coder / researcher /
code-navigator / resource-manager / memory-manager routing and coder-escalated
(Terra High, DIA-260911-rqmw) are out of scope here and left untouched by this
commit.

**Next steps:**

- [x] Run config validation: `make test-config`
- [x] Restart OpenCode + functional smoke test (see Re-verify evidence below)
- [x] Dispatch @ai-auditor for independent review (ses_f6f1794ffffeuW0hxGAd3oo5CD, CONFIG PASS, WORKFLOW CLOSURE BLOCKED on doc/changelog only)
- [ ] Register changelog entry via `scripts/changelog-add`

## Fix

Approved expanded scope, active "muse-qwen-balanced" preset:

- orchestrator: keep opencode/muse-spark-1.3-contributor-free as primary at high reasoning; openai/gpt-5.6-luna remains its fallback. Do not use Terra Fast for this lane.
- architector: replace unavailable github-copilot/gemini-3.1-pro-preview with openai/gpt-5.6-sol at high reasoning; retain opencode/big-pickle fallback.
- coder and researcher: use opencode/muse-spark-1.3-contributor-free as primary; use openai/gpt-5.6-luna as the immediate fallback.
- every remaining Zen Free model in the active preset: place openai/gpt-5.6-luna immediately after the free model, before any paid OpenCode Go fallback.
- code-navigator and resource-manager: use openai/gpt-5.6-luna at medium reasoning as primary. Developer decision 2026-09-11: retain medium for these bounded utility lanes.

Decision record (developer approved):

- A, chosen: the medium-cost hybrid above. It keeps free Zen Muse as the orchestrator primary to preserve OpenCode Go quota; Luna is the paid resilience fallback; Sol High remains reserved for rare architecture decisions.
- B, not chosen: Terra Fast as orchestrator primary. It improves latency but adds direct OpenAI spend without improving reasoning quality.
- C, not chosen/status quo: retain Gemini and OpenCode Go-backed models. Gemini is currently unavailable and does not preserve the remaining OpenCode Go quota.

Evidence:

- Runtime resolver and non-empty smoke confirm orchestrator -> opencode/muse-spark-1.3-contributor-free at high reasoning.
- Official OpenAI model docs describe GPT-5.6 Sol as the flagship model for complex professional work and support high reasoning effort.
- Official OpenAI model docs describe GPT-5.6 Luna as optimized for cost-sensitive, high-volume workloads and support low through max reasoning effort.

Implementation requirements:

- Run the section-2.5 configuration workflow: config validation, JSONC parse, restart plus functional smoke, independent ai-auditor review, then changelog registration.
- Confirm direct OpenAI provider authentication before activating a Luna or Sol route.

## Re-verify

2026-09-11 re-verify evidence

- Corrected active muse-qwen-balanced orchestrator provider from opencode-go/muse-spark-1.3-contributor-free to opencode/muse-spark-1.3-contributor-free.
- make test-config: exit 0. git diff --check: exit 0.
- Restarted an isolated headless OpenCode server on 127.0.0.1:4096; startup log: "opencode server listening on http://127.0.0.1:4096".
- Post-restart model catalog contained openai/gpt-5.6-sol, openai/gpt-5.6-luna, and opencode/muse-spark-1.3-contributor-free.
- Post-restart resolver: orchestrator -> provider opencode, model muse-spark-1.3-contributor-free, variant high.
- Non-empty Zen route smoke: opencode/muse-spark-1.3-contributor-free at high returned ORCHESTRATOR_MUSE_SMOKE_OK with exit 0.
- Previously in this verification session, isolated non-empty smokes also passed: Sol High -> SOL_HIGH_SMOKE_OK; Luna Low -> LUNA_LOW_SMOKE_OK; Luna Medium -> LUNA_MEDIUM_SMOKE_OK; Muse Free Medium -> MUSE_FREE_SMOKE_OK; MiMo Free Medium -> MIMO_FREE_SMOKE_OK. Each returned exit 0.

Scope note 2026-09-11 (architector-only split): Luna utility-lane routing and
the coder-escalated Kimi K3 to GPT-5.6 Terra High change are NOT part of this
ticket. Terra 4-surface changes belong to DIA-260911-rqmw and remain
uncommitted there. This ticket lands only the architector Sol High +
big-pickle route.

There is no remaining model-routing discrepancy. Final ticket closure still requires the independent ai-auditor review and changelog registration required by the section-2.5 workflow.
