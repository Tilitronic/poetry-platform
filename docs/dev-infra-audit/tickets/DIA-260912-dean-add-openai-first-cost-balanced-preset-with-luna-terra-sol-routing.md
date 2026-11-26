# DIA-260912-dean - Add OpenAI-first cost-balanced preset with Luna Terra Sol routing

---

id: DIA-260912-dean
title: "Add OpenAI-first cost-balanced preset with Luna Terra Sol routing"
area: opencode-config
severity: Medium
status: CLOSED
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-09-12
source: inventory
date: 2026-09-12
created: 2026-09-12
updated: 2026-09-14

# --- Session Attribution (v2 schema, optional) ---

session_id: "ses_f607b7d22ffeh9YHrRkv0mY0Zk"
lane_id: "runtime-smoke"
agent: "orchestrator"
model: "openai/gpt-5.6-luna"
parent_session_id: ""
attempts: 0
lease_expires_at: "" # ISO-8601; set on DISPATCHED, cleared on COMPLETE
files_touched:

- .opencode/oh-my-opencode-slim.jsonc
- .opencode/learnings/external-patterns/2026-09-12-dia-260912-dean-openai-first-preset-gate.md
- .opencode/CHANGELOG.yaml
  artifacts:
- .opencode/learnings/external-patterns/2026-09-12-dia-260912-dean-openai-first-preset-gate.md
  evidence:
- make test-config 57/57
- six distinct OpenAI model/variant routes returned non-empty markers after restart
- runtime-smoke:ses_f607b7d22ffeh9YHrRkv0mY0Zk
- runtime-smoke:ses_f607a7691ffe0I4xFVdc0Qluh1

---

## Description

OpenCode Go paid capacity and the available free-model quota were exhausted,
while the active project preset could still select those providers before an
available OpenAI route. Add a strict OpenAI-only, cost-balanced preset in
`.opencode/oh-my-opencode-slim.jsonc`, make it the project default after explicit
developer approval, and prove each distinct model/variant through a real
post-restart agent dispatch.

## Verification

- [x] `openai-first-cost-balanced` defines all 17 project roles with scalar
      `openai/*` model IDs and no cross-provider fallback arrays.
- [x] The project pointer activates the preset after explicit developer approval.
- [x] JSONC/config validation and `make test-config` pass (57/57).
- [x] A restarted OpenCode process resolves the preset and returns a non-empty
      result for Luna medium/high, Terra medium/high, and Sol medium/high.
- [x] The section-2.5 gate is registered and an independent config audit finds
      the implemented mapping correct.
- [x] The source-of-truth changelog records the change and verification.

## Fix

Requested scope (developer decision, 2026-09-12):

Create a new OpenAI-first preset. It must not make a depleted OpenCode Go or
Zen/free route the first attempt for any agent. The developer explicitly
approved activation; `openai-first-cost-balanced` is now the project default.

Required primary routing:

- orchestrator: openai/gpt-5.6-luna, medium
- openspec-plan: openai/gpt-5.6-terra, medium
- coder: openai/gpt-5.6-luna, high
- reviewer: openai/gpt-5.6-terra, medium
- analyzer: openai/gpt-5.6-terra, medium
- architector: openai/gpt-5.6-sol, high
- coder-escalated: openai/gpt-5.6-terra, high

Other active-preset lanes:

- Retain existing OpenAI routes and variants where present: ai-specialist Terra high, ai-auditor Sol medium, resource-manager Luna medium, code-navigator Luna medium.
- Replace a non-OpenAI primary with OpenAI in researcher, memory-manager, conspecter, designer, and observer. Default to Luna medium for these bounded or high-volume lanes.
- analyzer-escalated uses Terra high. It is an explicit escalation, not a default high-volume route.

Fallback policy:

- Native agent model fields are scalar. The strict preset configures no model
  arrays and no automatic provider fallback. A failed OpenAI route is surfaced
  rather than silently consuming OpenCode Go or Zen/free capacity.
- Coder-escalated remains an explicit developer-approved escalation route; it
  does not trigger a replacement dispatch automatically.

Alternatives considered (EBDV):

- A, chosen: OpenAI-first cost-balanced preset. Luna handles volume; Terra is reserved for planning, review, and analysis; Sol is reserved for architecture. This is chosen because OpenCode Go and free-model capacity is currently exhausted.
- B, not chosen: retain the active hybrid preset with OpenCode Go and Zen/free primaries. It may be cheaper when capacity returns, but it currently causes unavailable-primary failures.
- C, not chosen/status quo: keep all existing routes and variants unchanged. It avoids configuration churn but does not meet the developer's current availability and cost constraints.

Acceptance requirements:

- The new preset has an explicit name and becomes active only after developer approval.
- Every agent route in that preset resolves to an available OpenAI model; no
  fallback arrays are present.
- make test-config, JSONC parsing, restart, resolver checks, and one non-empty smoke per distinct OpenAI model/variant pass.
- An ai-specialist gate is registered before implementation and ai-auditor independently reviews the change.

## Re-verify

- `make test-config`: PASS, 8 suites / 57 tests / 57 passed / 0 failed.
- Runtime catalog/resolver: all 17 configured roles resolve to `openai/*`; Luna,
  Terra, and Sol are present in the live OpenAI catalog.
- Restart/default: restarted TUI loaded `openai-first-cost-balanced` and showed
  `orchestrator · gpt-5.6-luna · OpenAI`; `/preset` was available.
- Non-empty distinct-route receipts (2026-09-14):
  - Luna medium: orchestrator marker `LUNA_MEDIUM_OK`.
  - Luna high: coder session `ses_f607b7d22ffeh9YHrRkv0mY0Zk`, marker `LUNA_HIGH_OK`.
  - Terra medium: analyzer session `ses_f607a7691ffe0I4xFVdc0Qluh1`, marker `TERRA_MEDIUM_OK`.
  - Terra high: ai-specialist session `ses_f607b7b71ffe9839180a3xYbOs`, marker `TERRA_HIGH_OK`.
  - Sol medium: ai-auditor session `ses_f607b7a84ffeVQ46l2oM5RDHLV`, marker `SOL_MEDIUM_OK`.
  - Sol high: architector session `ses_f607b7997ffea7H5pJpYtUtn2a`, marker `SOL_HIGH_OK`.
- Reviewer marker dispatch was procedurally rejected for lacking a review
  `FIXED_POINT`; it is not counted as model evidence. Analyzer independently
  proves the identical Terra-medium route.
- Independent config audit: implementation mapping PASS; its former closure
  blockers (ticket placeholders, activation mismatch, missing route smokes, and
  changelog) are resolved by this fixed point.
