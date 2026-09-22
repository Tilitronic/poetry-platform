---
name: promo-review
description: Use when the user says "promo review", "check promotions", "review model pricing", or when 14 days have elapsed since the last promo-registry review. Re-verifies the promoted OMO preset against live OpenCode Go pricing/promos using a stable-vs-volatile split (benchmarks from memory shelf, promos fetched live from landing page + tracker + aggregator) and recommends routing deltas.
compatibility: opencode
metadata:
  audience: orchestrator
  workflow: promo-cadence
---

# Promo Review - Stable/Volatile Split Re-Verification (DIA-260828-qtsi)

Activated by the orchestrator when: (a) the user explicitly asks to review
promotions / model pricing, or (b) 14 days have passed since `last_reviewed`
in `.opencode/promo-registry.json`. The promo preset is a pointer-swap clone
of the active preset with DeepSeek V4 Flash promo routing (see `scripts/promo-preset-apply`); this skill checks whether
the underlying promo economics still justify it.

## Data classification (P1)

The core control: separate STABLE facts (cached on the memory shelf, never
re-fetched) from VOLATILE facts (must be fetched LIVE every review). Mixing
them was the root cause of the prior bug (fetching `docs/go` alone missed all
promo tiers).

### STABLE - from memory shelf, never re-fetch, never deprecate

Benchmarks, params, architecture, licensing, and training-on-data status.
Source of truth: `knowledge/res041-opencode-go-promo-benchmarks/` (registered
on the memory shelf). If a newer `res*` conspect supersedes res041, read that
instead (see Input #5).

| Model | Input $/1M | Output $/1M | Context | Intelligence | Coding | GPQA | License / training-on-data |
|---|---|---|---|---|---|---|---|
| Muse Spark 1.2 Contributor | 0.10 | 0.20 | 1.05M | 56.8 | 72.2 | 90.4 | Meta proprietary; Contributor trains on prompts/completions |
| Tencent Hy3 | 0.14 | 0.58 | 262K | 42.2 | 58.8 | 89.7 | Apache 2.0; NOT used for training, 0-day retention |
| MiMo V2.5 | 0.14 | 0.28 | 1M | 38.0 | 56.8 | 84.9 | MIT; NOT used for training, 0-day retention |

These numbers are STABLE. Do NOT re-fetch them from the web. Reuse the shelf.

### VOLATILE - MUST fetch LIVE every review, never trust the shelf

Go promos, usage multipliers, pricing deltas, expiry dates, request caps.
These change without notice (res030: DeepSeek V4 Flash moved +57-371%
overnight). Fetch from ALL THREE live sources every review (see Procedure 3).

- OpenCode Go promo multipliers (6x general, Hy3-specific 8x, etc.)
- Model-specific discounts (-98% MiMo, 2x GLM-5.3-Flash, etc.)
- Usage caps ($12 / 5h, $30 / week, $60 / month)
- Expiry dates and "limited time" / "through <date>" markers
- Request-per-month caps and rate limits

## Inputs (P3)

1. `.opencode/promo-registry.json` - current promos, `last_reviewed`, `next_review`.
2. `.opencode/oh-my-opencode-slim.jsonc` - the generated `promo` preset (read-only here).
3. `knowledge/model-registry.yaml` - dispatch routing + quota guards.
4. `knowledge/ana036-weekend-coding-preset-efficiency` - the routing rationale (ana036 R7 = Muse privacy exclusion).
5. `knowledge/res041-opencode-go-promo-benchmarks/res041-opencode-go-promo-benchmarks-conspect.md` - STABLE benchmarks. READ FIRST, before any web fetch. If a newer `res*` conspect supersedes res041, read that instead.

## Procedure

### 1. Elapsed check
Read `last_reviewed` (ISO date). If `today - last_reviewed < 14 days` AND no
explicit user trigger, report "no review due yet (next_review = <next_review>)"
and stop. Otherwise proceed.

### 2. Load STABLE from shelf (P3, P5)
Read Input #5 (res041 or newer). These benchmarks are the STABLE baseline.
Do NOT re-fetch them from the web. If the shelf file is MISSING (SHELF-GAP),
flag it and route to `@memory-manager` to re-persist the benchmarks (do not
guess). While the shelf exists, never load STABLE twice in one review.

### 3. Fetch VOLATILE LIVE - ALL THREE sources (P2)
The prior bug: fetching `docs/go` alone missed every promo tier. Fetch ALL
THREE, in parallel:
- `https://opencode.ai/go` (the LANDING page, NOT just `docs/go`)
- `https://julien.cloud` (the promo tracker)
- `https://commandcode.ai/models` (the aggregator)

Never trust the shelf for any of these. Re-fetch every review.

### 4. Promo-tier capture (P2)
Search each live source for promo signals. For EVERY match, QUOTE VERBATIM
the model name + multiplier + applicability. List price alone is insufficient.
Search terms: `xN` (x2, x6, x8), `multiplier`, `% off`, `expiry`,
`through <date>`, `limited time`, `promo`, `discount`.

Canonical example (Hy3 x8): quote `Hy3 8x usage` verbatim; effective price
= list / 8 = $0.14/8 in, $0.58/8 out = ~$0.02 / $0.07. Record the verbatim
quote and the computed effective price.

### 5. Model-specific promo verification + ROUTING-INVERSION (P4)
For each model present in `promo-registry.json`:
- Read its model-specific multiplier from the live fetch (Procedure 4).
- Compute `effective_price = list_price / multiplier` (list from STABLE table).
- Compare EFFECTIVE price vs the registry's recorded promo price; flag mismatch.
- ROUTING-INVERSION flag: when a CHEAPER model should be primary but is not,
  and the effective-price gap exceeds 2x (threshold: >2x only). Example: under
  Hy3 x8, promo-Hy3 effective ~$0.02/$0.07 is ~7x cheaper than mimo-v2.5
  ($0.14/$0.28); if the preset still routes worker traffic to mimo-v2.5, that
  is a ROUTING-INVERSION (>2x) - flag it. Do NOT activate the promo preset as-is.

### 6. Muse Spark explicit comparison (developer-raised)
Muse Spark 1.2 Contributor is the CHEAPEST input ($0.10) and HIGHEST
Intelligence (56.8) of the three, with the largest context (1.05M). It is NOT
worse than Hy3 ($0.14/$0.58, Intelligence 42.2) or MiMo V2.5 ($0.14/$0.28,
Intelligence 38.0). It is excluded for PRIVACY, not benchmarks:
- Meta Contributor tier trains on prompts/completions (Meta Model API).
- Rate limit 100 RPM vs 3000 RPM Standard.
- Region-limited availability.

ADMISSION (DIA-260828-qtsi, 2026-08-28): developer cleared privacy - no
sensitive traffic confirmed, so the Meta Contributor training-on-data
condition is accepted for NON-SENSITIVE traffic. muse-spark is now ADMITTED:
`active: true`, status `promo-admitted`, primary for 6 lanes
[coder, reviewer, analyzer, researcher, conspecter, openspec-plan] with DeepSeek V4 Flash
fallback. The skill MUST NEVER silently skip Muse. Every report includes an
explicit Muse row: benchmarks (from STABLE), the privacy exclusion rationale
(retained for audit), and the admission condition (non-sensitive traffic
only; re-exclude if sensitive traffic appears).

### 7. Persistence (P5)
- STABLE: never re-fetch if the shelf exists; do not load twice. If SHELF-GAP,
  fetch missing benchmarks and persist via `@memory-manager`.
- VOLATILE: do NOT persist as durable truth. If any volatile data is written to
  `promo-registry.json`, stamp it with `fetched_at` + a 7-day stale marker so
  the next review knows it is suspect.

### 8. Route to @ai-specialist (boundary)
Any NEW / EXPIRED / >20% CHANGE / ROUTING-INVERSION / privacy-status change
MUST be routed through `@ai-specialist` (read-only gate, AGENTS.md section 2.5
Phase 1) before any config edit. This skill NEVER edits `oh-my-opencode-slim.jsonc`
pricing/routing or the promo preset. The specialist re-evaluates, then the
orchestrator dispatches `@coder` to update `scripts/promo-preset-apply` ROUTING
and re-run it.

### 9. Update review timestamps (boundary)
After a completed review (even if "no change"), update `last_reviewed = today`
and `next_review = today + 14 days` in `promo-registry.json`. This is the ONLY
file this skill writes.

## Output contract (P6)
Return a report with these sections:
- STABLE: the benchmark table as loaded from the shelf (Input #5), quoted as-is.
- VOLATILE: the live-fetched promos with verbatim multiplier quotes (model +
  multiplier + applicability) and computed effective prices.
- flags: list (NEW / EXPIRED / >20% / CAP / ROUTING-INVERSION / MUSE-PRIVACY)
  with model + delta + verbatim quote where relevant.
- urgency: LOW | MEDIUM | HIGH (weekend-coding cadence, ana036 section 4).
- muse: explicit row - benchmarks, exclusion reason, admission path.
- recommendation: "no change" | "<routing delta summary>".
- routed_to: "@ai-specialist" (if any flag) | "none".
- next_review: <date>.

## Constraints
- ASCII-only output (DIA-079). No em-dashes, smart quotes, or non-ASCII punctuation.
- Never set the promo preset active from here; activation is a developer decision.
- muse-spark ADMITTED 2026-08-28 for non-sensitive traffic (privacy cleared DIA-260828-qtsi, no sensitive traffic confirmed) - primary for 6 lanes [coder,reviewer,analyzer,researcher,conspecter,openspec-plan] with DeepSeek V4 Flash fallback; still document exclusion rationale + admission condition.
- Skill writes ONLY `last_reviewed` / `next_review` timestamps. Pricing/routing
  changes route via @ai-specialist -> @coder.
