# Gate FINDINGS - OpenCode Go model ID drift (DIA-261022-6vcz, 2026-10-22)

> Section 2.5 config gate (read-only ai-specialist lane, verdict APPROVE-WITH-CHANGES) for the mimo-balanced preset model-ID refresh. Registered per AGENTS.md section 2.5 step 1. Governing ticket: DIA-261022-6vcz.

date: 2026-10-22

## Source

- ai-specialist read-only config gate, 2026-10-22, mimo-balanced preset (.opencode/oh-my-opencode-slim.jsonc) model-ID audit. Independent probe re-confirmed live catalog facts below.

## Findings

- **F1 Dead model ID (CRITICAL)** - `opencode-go/deepseek-v4-flash` does not exist: models.dev TOML returns 404 and the id is absent from the live Go models payload (https://opencode.ai/inference/go/v1/models, 36 models, probed 2026-10-22). It was used as a fallback in 7 config places (coder, analyzer, conspecter, memory-manager, code-navigator, researcher, ai-auditor). Purged per this ticket.
- **F2 Docs-vs-live-catalog drift (MAJOR)** - `opencode-go/longcat-2.5-preview-free` appears in `opencode models` output and in the local cache (~/.cache/opencode/models.json under .opencode-go.models) but is NOT in the live Go payload (live longcat = longcat-2.0 only) and is NOT dispatchable: `opencode run -m opencode-go/longcat-2.5-preview-free` exits 1 with "Upstream request failed: Endpoint is unavailable." BRANCH B applied - id excluded from config entirely. The id also exists under the `opencode/` Zen prefix, but the preset's opencode-go-only invariant (no opencode/* Zen ids) forbids it.
- **F3 Effort-ladder facts** - deepseek-v4.1-flash ladder is low|high|max only; `medium` is INVALID for that model. longcat-*, minimax-m3 and mimo-v2.6-pro expose NO effort ladder (thinking toggle only, or nothing); any `variant` key on those lanes is inert. Reviewer keeps variant high (valid rung, no variant change needed).
- **F4 Pre-existing defect exposed (NOT fixed here)** - coder-escalated uses deepseek-v4.1-flash with variant "medium" (oh-my-opencode-slim.jsonc coder-escalated block); medium is invalid for that ladder. Out of scope for this ticket; reported as remaining risk.
- **F5 ZDR posture (candidates)** - ZDR clears on longcat-2.0, longcat-2.5-preview-free, minimax-m3, mimo-v2.6-pro (0-day retention, not used for training).
- **F6 Vendor family map** - longcat = Meituan; minimax = MiniMax; mimo = Xiaomi. ai-auditor (Meituan longcat lane) vs ai-specialist (Xiaomi mimo-v2.6-pro) satisfies the registry different-family independence invariant.

## Live catalog snapshot (2026-10-22, go/v1/models, 36 ids)

- longcat: longcat-2.0 only. mimo: mimo-v2.5, mimo-v2.5-pro, mimo-v2.6-flash, mimo-v2.6-pro. deepseek: deepseek-v4.1-flash, deepseek-v4-pro (NO v4-flash). minimax: minimax-m2.5, minimax-m2.7, minimax-m3, minimax-m3.1-flash-free.

## F7 - Not-ZDR waiver on the ai-auditor lane (round 2, 2026-10-22)

- ai-auditor primary moved to opencode-go/gemini-4-argon-contributor (BRANCH A: listed in live Go catalog + dispatch probe PASS), which trains on prompts/completions (NOT-ZDR). Developer-cleared 2026-10-22 under DIA-261022-6vcz on the same no-sensitive-traffic basis as the DIA-260828-qtsi Muse precedent; waiver recorded as privacy_notes in knowledge/model-registry.yaml.
- Rule: any lane on a trains-on-data model MUST carry an explicit registry waiver (privacy_notes), never a silent exception; the preset header invariant comment must state the exception rather than assert blanket ZDR-only.

## F8 - Variant-ladder rule (round 3, 2026-10-22)

- RULE: read the model's DECLARED ladder before writing any `variant` value - from `opencode models --verbose` (the `variants` object for that exact id) or models.dev `reasoning_options`. Never assume a rung name from another model's ladder or from habit.
- Assuming a rung produced three invalid values inside ONE ticket: reviewer `medium` (deepseek-v4.1-flash ladder is low|high|max), coder-escalated `medium` (same ladder, corrected round 2), and the pre-existing escalations carried the same wrong rung.
- Ladder for opencode-go/gemini-4-argon-contributor is exactly low|medium|high: MEDIUM_RUNG = medium, MAX_RUNG = high (no `max`, no `xhigh` in that id).
- Undeclared variant handling: OpenCode resolves `model.variants[variant]` at request build time, so an undeclared rung contributes `{}` options and is effectively silently dropped (no error surfaced in the config path); OMO's schema types `variant` as a plain optional string with no enum, so `make test-config` never catches a bad rung. Therefore a wrong value fails SILENTLY at runtime - the ladder read is the only real defense.

## F9 - Cache-read price decides lane cost (round 4, 2026-10-22)

- RULE: on a Go subscription pool, cost per request is decided by the CACHE-READ price, not the output price - agentic OpenCode sessions are ~98% cache reads (representative profile: 410 new input + 71,300 cached + 310 output tokens per request).
- Consequence: a model with a 3.3x cheaper output price (grok-4.7 at $6.00 vs gemini-4-argon-contributor at $20.00 per 1M) can still be ~5.5x MORE expensive per request on a subscription pool, because its cache-read price is 2.5x higher ($0.50 vs $0.20 per 1M): ~390 vs ~2,200 req/mo headroom, still ~3x after the 2x promo ends and the pool reverts to $30.00.
- The grok-4.7 throughput figures therefore carry TWO estimates with different assumptions, both DEVELOPER-SUPPLIED 2026-10-22 from https://opencode.ai/v2/docs/console/go/ and neither gate-verified: (a) docs baseline ~845 req/mo (no cache-read discount assumed); (b) agentic profile ~78-80 req/5h / ~390 req/mo (cache-dominated). Neither replaces the other - the assumption (cache discount or not) picks the figure.

## Outcome

- Registered 2026-10-22; fixes applied same day per DIA-261022-6vcz (see ticket Fix section + CHANGELOG entry). Full longcat/mimo-v2.6-pro registry pricing/benchmark entries pending a separate gate.
