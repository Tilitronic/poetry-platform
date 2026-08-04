# Copilot Legacy-Annual Pricing — Credit Multipliers & Model Selection (2026-08-04)

> Authoritative Copilot model/price guide for the legacy ANNUAL GitHub Copilot Pro plan (credit-multiplier / premium-request billing). Governs all `github-copilot/*` model recommendations for this repo while the legacy annual plan is active.

date: 2026-08-04

## Source

- ai--3 authoritative research, fetched 2026-08-04 from docs.github.com (`model-multipliers-for-annual-plans`, `models-and-pricing`, `supported-models`, `premium-requests`). Owner-approved via §10 Phase 2 — observer fallback swap to gpt-5-mini + full knowledge update.

## Two pricing dimensions

- **(A) $/token list price (AI Credits)** — governs monthly plans (post-June-1-2026). Per-token list prices published on `models-and-pricing`.
- **(B) Credit multiplier / premium-request units (PRU)** — governs legacy ANNUAL plans. Multiplier × request = PRU consumed from the monthly premium-request budget.
- **Which governs for legacy annual subscribers: (B) the credit multiplier.** List price is irrelevant on the legacy plan — what matters is how many premium requests each model consumes.

## Multiplier table (legacy ANNUAL plans, fetched 2026-08-04)

| Model | Multiplier |
|---|---|
| claude-haiku-4.5 | 0.33x |
| claude-sonnet-4.5 | 6x |
| claude-sonnet-4.6 | 9x |
| gemini-3.1-pro | 6x (preview) |
| gemini-3.5-flash | 14x ⚠️ |
| gpt-5-mini | 0.33x |
| gpt-5.3-codex | 6x |
| gpt-5.4 | 6x |
| gpt-5.4-mini | 6x |
| mai-code-1-flash | 0.33x |
| raptor-mini | 0.33x |

- ⚠️ `gemini-3.5-flash` = worst deal on the legacy plan (14x).
- **Warnings (avoid):** `gpt-5.5` 57x, `claude-opus` 27x.
- **NOT on the legacy plan (post-June-2026 catalog only — no multipliers → treat as unavailable on legacy):** `gpt-5.6*`, `claude-sonnet-5` / `opus-5` / `fable-5`, `gemini-3.6-flash`, `grok-4.5`, `kimi-k2.7-code`.

## Legacy plan facts

- 300 premium requests (PRU) / month.
- Budget resets on the 1st of each month.
- NO rollover — unused PRU are lost.
- 10% auto-discount applied to the multiplier.
- Frozen catalog — legacy plans keep the pre-June-2026 model set.
- Fixed 13 PRU per code review.

## ≤6x rule (owner policy)

- Owner policy: only models with multiplier **≤6x** are eligible for `github-copilot/*` lanes.
- Compliant models: `gpt-5-mini` (0.33x), `claude-haiku-4.5` (0.33x), `mai-code-1-flash` (0.33x), `raptor-mini` (0.33x), `claude-sonnet-4.5` (6x), `gemini-3.1-pro` (6x preview), `gpt-5.3-codex` (6x), `gpt-5.4` (6x), `gpt-5.4-mini` (6x).
- Effective interactions per month (300 PRU ÷ multiplier):
  - 0.33x ≈ **909** interactions
  - 6x ≈ **50** interactions
  - 14x ≈ **21** interactions (`gemini-3.5-flash` — the worst deal)

## Usage strategy

- 80/20 mix: 80% of PRU on 0.33x models + 20% on 6x models ≈ **737 interactions/month** (240 ÷ 0.33 ≈ 727 + 60 ÷ 6 = 10).

## Sources

- https://docs.github.com/en/copilot/managing-copilot/managing-copilot-as-an-individual-subscriber/model-multipliers-for-annual-plans (fetched 2026-08-04)
- https://docs.github.com/en/copilot/concepts/ai-models/models-and-pricing
- https://docs.github.com/en/copilot/concepts/ai-models/supported-models
- https://docs.github.com/en/copilot/managing-copilot/managing-copilot-as-an-individual-subscriber/about-premium-requests
