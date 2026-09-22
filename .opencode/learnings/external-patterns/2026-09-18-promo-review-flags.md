# Learnings: promo-review flags + EBDV V1 (DIA-260918-czsi)

- Date: 2026-09-18
- Ticket: DIA-260918-czsi 'promo preset refresh' (campaign ticket, OPEN)
- Sources:
  - ai-specialist STABLE lane ses_f4af984f8ffeqk11eSN7IlAcgM (F1-F7)
  - ai-specialist flag-verdict lane ses_f4af6d3f2ffeO7K1bJPecGwhbC (F-A to F-G)
  - analyzer report ses_f4af82745ffeus6ALUu1EVx5zG
- Status: LEARNINGS REGISTRATION (AGENTS.md section 2.5 step 1). No config edits in this lane.

## STABLE (source: res041, cached on memory shelf - never re-fetch)

Res041-opencode-go-promo-benchmarks is the durable STABLE source. Benchmarks and
params below are STABLE per 2026-08-28 split; reuse shelf, do not re-fetch live.

| Model | Intelligence | Coding | GPQA | Context | Input $/M | Note |
|---|---|---|---|---|---|---|
| Muse Spark 1.2 Contributor | 56.8 | 72.2 | 90.4 | 1.05M | 0.10 | cheapest + highest intelligence, excluded for privacy (Meta trains on prompts), pending review |
| Hy3 | 42.2 | 58.8 | 89.7 | 262K | promo-effective ~0.02 | 8x promo confirmed live earlier; re-verify multiplier in VOLATILE fetch |
| MiMo V2.5 | 38.0 | 56.8 | 84.9 | 1M | promo-effective ~0.14 | -98% promo earlier; re-verify live |
| GLM-5.3-Flash | - | - | - | - | 2x promo earlier | re-verify live |

F1-F7 (STABLE lane ses_f4af984f8ffeqk11eSN7IlAcgM): benchmarks/params STABLE,
reuse res041; promos/usage-limits/pricing VOLATILE, fetch live every review
from opencode.ai/go landing (NOT docs/go alone) + julien.cloud tracker +
commandcode.ai/models; landing-page + tracker fetch with promo-multiplier
capture; >2x ROUTING-INVERSION threshold; explicit Muse Spark comparison +
admission path for non-sensitive traffic.

## VOLATILE (fetched_at: 2026-09-18 - never cached as durable truth)

- fetched_at: 2026-09-18 (this review cycle). Stale after 7 days per split rule.
- Must re-fetch live next review: promo multipliers, usage caps, expiry dates,
  pricing deltas. If written to promo-registry.json, timestamp with fetched_at.

## Flags F-A to F-G (verdicts, flag-verdict lane ses_f4af6d3f2ffeO7K1bJPecGwhbC)

- F-A post-expiry: V1 revert-to-list. Expired promos fall back to list pricing;
  no grandfathering assumption without live confirmation.
- F-B cap-only promo: NON-BINDING at low volume. Caps ($12/5h $30/wk $60/mo
  family) do not bind weekend 6-8h coding windows at current burn; do not
  route on cap headroom alone.
- F-C timestamp auth: promo-registry.json writes require fetched_at + 7-day
  stale rule; undated promo truth is unauthoritative.
- F-D script-unsafe: scripts/promo-preset-apply is UNSAFE when the promo block
  is missing + id is non-canonical. Missing-block path + non-canonical id must
  hard-fail, never silent-write. (Root: find_promo_region assumes canonical
  header marker; absent marker = no safe span to replace.)
- F-E routing inversion: >2x effective-price inversion flips routing; re-check
  worker->mimo vs promo-Hy3 ordering live each cycle.
- F-F Muse Spark admission: cheapest + highest intelligence but privacy-excluded
  (Meta Contributor trains on prompts/completions, 100 RPM vs 3000,
  region-limited); admission path only for non-sensitive traffic pending review.
- F-G newest-conspect pick: manual pick of newest conspect each review; never
  auto-reuse a stale volatile snapshot.

## EBDV (analyzer ses_f4af82745ffeus6ALUu1EVx5zG)

- V1 (RECOMMENDED): revert-to-list on expiry + treat cap-only promo as
  non-binding at low volume. Because caps do not bind the 6-8h weekend window
  at current burn, routing on cap headroom alone overfits; list-price fallback
  is the conservative correct default post-expiry.
- Alternatives considered: (a) hold promo pricing post-expiry (rejected - no
  live confirmation of grandfathering); (b) route on cap headroom (rejected -
  non-binding at low volume); (c) abort/status-quo, keep current preset
  untouched (valid fallback if live fetch fails).
- Script-unsafe (F-D): do NOT run scripts/promo-preset-apply when the promo
  block is missing + id is non-canonical; hard-fail path. Fix belongs in a
  coder lane under the campaign ticket, not in this registration lane.

## Next review

- next_review: prefer 2026-09-30 to cover ZDR Sep 30 (expiry-date review).
  Re-fetch VOLATILE live at that review; re-verify F-A expiry + F-E inversion.

## Lane scope guard

- This lane did NOT edit .opencode/oh-my-opencode-slim.jsonc or
  .opencode/promo-registry.json (registration only).
- Outcome: PENDING coder/validator lanes under DIA-260918-czsi.
