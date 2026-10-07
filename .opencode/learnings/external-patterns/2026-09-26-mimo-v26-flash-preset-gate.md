---
title: MiMo V2.6 Flash preset swap gate (DIA-260926-n49u)
date: 2026-09-26
ticket: DIA-260926-n49u
source: ai--1 / ses_f20040f28ffeVLTQQvV2vhSTRe (read-only, AGENTS.md 2.5 step 1)
verdict: GO-with-conditions
---

## Confirmed (official opencode.ai/docs/go, fetched 2026-09-26)

- Exact ID: `opencode-go/mimo-v2.6-flash` (bare `mimo-v2.6-flash`; Go config form is `opencode-go/<id>`).
- Availability: on OpenCode Go (not Zen-only). Caveat: a community tracker (julien.cloud, 2026-09-23) flags a possible subscription restriction even though the official docs list it - resolve via TUI `/models`.
- Privacy: MiMo-V2.6-Flash = "Not used" (training) / 0 days retention - same ZDR group as MiMo-V2.5; satisfies the muse-balanced ZDR-only constraint (DIA-260827-8la4).
- Pricing: $0.14 / $0.28 per 1M (Go), 1,048,576 ctx, $60 bucket ~150,400 req/mo - IDENTICAL to MiMo-V2.5, so the swap is cost-neutral. The developer-supplied $0.16/$0.32 is a CrossModel provider figure, NOT the OpenCode Go price.
- Drop-in: same provider, same endpoint (@ai-sdk/openai-compatible /chat/completions), same pricing/bucket/req-cap, same ZDR, same 1M ctx, same modality, reasoning + tools + temperature. Direct successor (released 2026-09-22).
- MiMo-V2.5 is NOT deprecated - still a current Go model with active pricing.

## Conditions

1. Use the exact ID `opencode-go/mimo-v2.6-flash` (not `mimo-v2.6`, not the Zen free variant `opencode/mimo-v2.6-flash-free`).
2. Verify availability in the live TUI `/models` list before committing.
3. Update the preset inline composition comment that names `mimo-v2.5`.
4. Add a `mimo-v2.6-flash` entry to knowledge/model-registry.yaml in lockstep (no V2.6 entry exists yet; DIA-208 precedent = preset swap + registry refresh together).
5. Use $0.14/$0.28 in registry/comment text, not $0.16/$0.32.
6. Optional: post-promo fallback references to `mimo-v2.5` (not required while V2.5 remains current).

## Sources

- https://opencode.ai/docs/go/ (primary, fetched 2026-09-26)
- https://models.dev/models/xiaomi/mimo-v2.6-flash/
- https://julien.cloud/opencode-go-models/ (community tracker, 2026-09-23)
- https://opencode.ai/docs/zen/ (disambiguation of the free variant)

## Outcome

- DONE (2026-09-26): @coder config-work completed. Preset 13 replacements (12 inline model IDs + 1 comment line) in `oh-my-opencode-slim.jsonc`, registry entry added to `knowledge/model-registry.yaml`. `make test-config` exit 0. OpenCode restart + TUI `/models` verification pending host-side.
