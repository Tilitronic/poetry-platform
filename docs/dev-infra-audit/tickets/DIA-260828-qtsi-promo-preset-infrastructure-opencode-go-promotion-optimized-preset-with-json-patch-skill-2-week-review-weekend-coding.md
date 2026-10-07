# DIA-260828-qtsi - promo preset infrastructure: opencode-go promotion-optimized preset with json patch + skill (2-week review, weekend coding)

---

id: DIA-260828-qtsi
title: "promo preset infrastructure: opencode-go promotion-optimized preset with json patch + skill (2-week review, weekend coding)"
area: opencode-config
severity: Major
status: CLOSED
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-28
source: inventory
date: 2026-08-28
created: 2026-08-28
updated: 2026-09-01

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

The promo-review skill was rewritten from 85 to 157 lines to encode six controls plus an explicit Muse Spark comparison section:

1. Stable-vs-volatile split - benchmarks/params cached on the memory shelf (res041) as STABLE, never re-fetched; promos/usage-limits fetched LIVE every review as VOLATILE.
2. Landing-page + tracker fetch - fetch opencode.ai/go (landing, not just docs/go), julien.cloud tracker, and commandcode.ai/models aggregator; the prior bug fetched docs/go alone and missed all promo tiers.
3. Shelf reuse res041 - read STABLE benchmarks from knowledge/res041-opencode-go-promo-benchmarks/ before any web fetch; never deprecate the cache.
4. Model-specific verification - compute effective_price = list / multiplier, compare vs registry, flag mismatch.
5. Persistence - stable -> shelf (never deprecated); volatile -> live fetch only, never cached as durable truth; if written to promo-registry.json, stamp fetched_at + 7-day stale marker.
6. Sectioned output - report with STABLE / VOLATILE / flags / urgency / muse / recommendation / routed_to / next_review sections.

Plus a Muse Spark explicit comparison section: Muse is cheapest input ($0.10) and highest Intelligence (56.8) but excluded for PRIVACY (Meta Contributor trains on prompts/completions, 100 RPM vs 3000, region-limited), active:false pending privacy review (ana036 R7). The skill must never silently skip Muse.

## Verification

- ai-specialist gate ses_fb7ed8294ffeTMXVmlTLxwLXTf: PASS (read-only research, stable-vs-volatile split design).
- coder ses_fb7461351ffen4qXzaoFM2Fbg3: make test-config exit 0 (skill frontmatter + schema valid).
- ai-auditor ses_fb74464ecffeUJafBakf198bq3: PASS (0 blockers, 6 minors).
- ASCII-only (DIA-079) on all edited lines.

## Fix

Skill landed at .opencode/skills/promo-review/SKILL.md (157 lines, 6 controls + Muse Spark section). Next scheduled Review: 2026-09-11 (14-day cadence from 2026-08-28). The skill never sets the promo preset active (activation is a developer decision); oh-my-opencode-slim.jsonc preset pointer unchanged.

## Re-verify

Commits: 762ce8c, 62088c1
Tests: make test-config exit 0 (57 pass)
Confirm: promo preset infrastructure + promo-review skill landed.
