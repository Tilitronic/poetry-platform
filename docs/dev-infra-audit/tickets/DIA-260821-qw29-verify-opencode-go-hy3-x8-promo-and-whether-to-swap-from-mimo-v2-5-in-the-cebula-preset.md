# DIA-260821-qw29 - Verify opencode-go Hy3 x8 promo and whether to swap from mimo-v2.5 in the cebula preset

---

id: DIA-260821-qw29
title: "Verify opencode-go Hy3 x8 promo and whether to swap from mimo-v2.5 in the cebula preset"
area: opencode-config
severity: Info
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-21
source: inventory
date: 2026-08-21
created: 2026-08-21
updated: 2026-08-28

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

- "opencode.ai/go (landing page, Hy3 8x usage)"
- "julien.cloud (tracker, Hy3 8x usage 2026-07-06 active)"
- "knowledge/res041-opencode-go-promo-benchmarks/"
- "res030"
- ".opencode/learnings/external-patterns/2026-08-28-promo-review-stable-volatile-split.md"

---

## Description

Developer asks: does opencode-go currently offer an x8 promo on the Hy3 model, and should we swap it in across the cebula preset in place of opencode-go/mimo-v2.5 (currently the coder/conspecter/researcher/etc. default per res030)? Cached price for Hy3 (res030, 2026-08-17): $0.14/$0.58, 21,500 req/mo - but no mention of any x8 promo. Pricing is volatile (Tier-2); fresh research needed before any model-swap decision. Follow EBDV (DIA-115) requirement for the eventual recommendation.

## Verification

<Acceptance criteria as checkboxes - how to prove the ticket is done.>

## Fix

Hy3 x8 promo CONFIRMED live. Evidence: opencode.ai/go landing page shows "Hy3 8x usage"; julien.cloud tracker shows "Hy3 (8x usage) 2026-07-06 | active". Effective price = list / 8 = $0.14/8 in, $0.58/8 out = ~$0.02 / $0.07.

Stable benchmarks from memory shelf res041 (cached, never re-fetched, reuse):

- Muse Spark 1.2 Contributor: Intelligence 56.8, Coding 72.2, context 1.05M
- Tencent Hy3: Intelligence 42.2, Coding 58.8, context 262K
- MiMo V2.5: Intelligence 38.0, Coding 56.8, context 1M

promo-Hy3 effective ~$0.02/$0.07 is ~7x cheaper than mimo-v2.5 list $0.14/$0.28. The cebula preset currently routes worker traffic to mimo-v2.5 (per res030, the coder/conspecter/researcher default). Under Hy3 x8, that worker->mimo routing is now SUBOPTIMAL - a >2x ROUTING-INVERSION per the promo-review skill control.

Recommendation: do NOT activate the promo preset as-is. Keep cebula-hy3 (the current active preset). Any swap to promo-Hy3 requires routing through @ai-specialist (AGENTS.md 2.5 Phase 1 gate) first, plus a Muse Spark privacy review (ana036 R7) before any Muse admission.

Evidence refs:

- opencode.ai/go (landing page, "Hy3 8x usage")
- julien.cloud (tracker, "Hy3 (8x usage) 2026-07-06 | active")
- knowledge/res041-opencode-go-promo-benchmarks/ (STABLE shelf benchmarks)
- res030 (cached Hy3 $0.14/$0.58, 21,500 req/mo; mimo-v2.5 default routing)
- .opencode/learnings/external-patterns/2026-08-28-promo-review-stable-volatile-split.md (Hy3 x8 confirmation + routing inversion)

## Re-verify

> To be filled at re-verify time.
