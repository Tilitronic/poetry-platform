# 2026-09-09 - Muse Qwen balanced agent routing preset gate findings (DIA-260909-tp5e)

Date: 2026-09-09
Ticket: DIA-260909-tp5e
Source: ai-specialist gate (developer-approved variant A: balanced Muse-volume + Qwen-reasoning split, shipped INACTIVE)
Scope: Section 2.5 config-work lane precondition

## 1. Preset schema conventions (ground truth)

- Presets in `.opencode/oh-my-opencode-slim.jsonc` are monolithic maps under `presets.<name>`: each preset inlines the full 17-agent config (model + variant + skills + mcps + prompt where applicable). No inheritance, no base preset, no `extends` field.
- Model field polymorphism per OMO schema:
  - `string` single model (e.g. `"opencode-go/qwen3.8-flash"`),
  - `array` primary -> fallbacks (e.g. `["opencode-go/muse-spark-1.3-contributor","opencode-go/deepseek-v4-flash"]`),
  - `array of {id, variant}` for per-model variant overrides (e.g. `[{"id":"opencode-go/kimi-k3","variant":"max"},...]` used in `coder-escalated`/`analyzer-escalated`).
- Verified against `.opencode/oh-my-opencode-slim.jsonc` (`opencode-go`/`cebula`/`promo`/`free`) and `opencode-best-practices.md` / `ai-assist-sources.yaml` per ai-specialist source hierarchy.
- Promotion boundary: flipping `preset` pointer (`"preset": "promo"`) is the ONLY promotion mechanism; adding a new preset block does NOT activate it. Shipping INACTIVE = add block, leave pointer on `promo`.
- Header comment convention for generated/hand-authored blocks: `// DIA-XXXX: ...` comment above the JSON key documents provenance; the promo block header cites `DIA-260828-qtsi`.

## 2. Drift-gate gap note (DO NOT FIX HERE)

- `scripts/check-orchestrator-prompt-drift.sh` audits only `PRESETS="opencode-go cebula free"` (default). The `promo` preset (and any new preset like `muse-qwen-balanced`) is excluded from the marker check by design — promo is auto-generated and intentionally diverged.
- Byte-identity check fires only when exactly 3 prompts are checked (`if [ "${#prompts[@]}" -eq 3 ]`). Adding a 4th preset does not extend the check; a 4-preset run skips byte-identity entirely.
- Both gaps are known and HELD in the `oj59` chain (`DIA-260903-oj59` self-rerun thresholds 60/75 holder). This lane MUST NOT fix the checker, thresholds, or any `oj59` content. Variant A explicitly preserves the current promo 15/25-marker orchestrator prompt text BYTE-IDENTICAL; the `oj59` 60/75 text is out of scope.

## 3. Lineup / pricing / privacy table (dated 2026-09-09)

| Model | Role in variant A | Price in/out $/1M | Req/mo | Privacy | Benchmark |
|-------|-------------------|-------------------|--------|---------|-----------|
| `opencode-go/muse-spark-1.3-contributor` | coder/researcher/conspecter primary; analyzer/openspec-plan fallback | 0.10 / 0.20 | 226600 | trains-on-data, NOT ZDR, region-limited | UNVERIFIED (inherits 1.2 terms; `swe_bench` null pending) |
| `opencode-go/qwen3.8-flash` | orchestrator/reviewer/analyzer/openspec-plan primary | 0.15 / 0.47 | 27000 | 0-day retention, no training | null (benchmark conspect pending separate ticket) |
| `opencode-go/deepseek-v4-flash` | orchestrator/coder/researcher fallback | 0.22 / 0.66 | 18900 est | ZDR via DSF terms (see caveat) | 73.7 |
| `opencode-go/deepseek-v4-pro` | reviewer fallback (fixes same-family collapse) | 0.66 / 1.98 | 5200 est | ZDR via DSF terms | 74.0 |
| `opencode/mimo-v2.5-free` | orchestrator/conspecter fallback | free tier | 150400 (mimo-v2.5) | — | — |
| `opencode-go/kimi-k3`, `opencode-go/gpt-5.6-luna`, `github-copilot/*`, `opencode-go/kimi-k2.7-code`, `opencode/big-pickle` | escalated / unchanged promo lanes | as per model-registry.yaml | as per registry | per registry | per registry |

- DSF ZDR caveat: DeepSeek V4 Flash/Pro ZDR terms are via Data Sharing Framework through 2026-09-30 — after that date ZDR status must be re-verified before sensitive traffic.
- Muse 1.3 admission basis: DIA-260828-qtsi (privacy cleared by developer: no sensitive traffic; region-limited; 1.05M ctx). New 1.3 entry mirrors 1.2 fields plus `privacy_notes: trains-on-data NOT-ZDR region-limited` and `swe_bench_verified: null` (benchmark-pending) with `source_ref` dated 2026-09-09.
- Variant A composition (balanced Muse volume + Qwen reasoning, INACTIVE): orchestrator qwen3.8-flash -> deepseek-v4-flash, mimo-v2.5-free | medium; architector UNCHANGED from promo; coder muse-1.3 -> deepseek | medium; reviewer qwen3.8 -> deepseek-v4-pro | high (fixes same-family collapse); analyzer qwen3.8 -> muse-1.3 | high; openspec-plan qwen3.8 -> muse-1.3 | high; researcher muse-1.3 -> deepseek | medium; conspecter muse-1.3 -> mimo-v2.5-free | medium; designer/observer/ai-specialist/ai-auditor/resource-manager/memory-manager/code-navigator/coder-escalated/analyzer-escalated UNCHANGED from promo. Preset pointer stays `promo`.
- Promotion = pointer-swap boundary: the only activation path is `scripts/promo-preset-apply` or manual `"preset": "muse-qwen-balanced"` flip; the block addition alone is mechanical.

## 4. Four-surface mechanical-change lesson (DIA-260828-qtsi / DIA-260828 follow-up)

Config-work that adds a model preset touches 4 surfaces atomically:
1. `.opencode/oh-my-opencode-slim.jsonc` — the preset block itself.
2. `knowledge/model-registry.yaml` — model entry with pricing/privacy/benchmark honesty fields.
3. `knowledge/promo-registry.json` (or `.opencode/promo-registry.json` per generation) — `fetched_at` dated entry + 7-day stale stamp (stable-vs-volatile split: benchmarks stable, promos volatile, fetched live).
4. Ticket + learnings — Description/Verification/UPDATE + gate findings file.

Skipping any one surface causes audit drift (registry stale, promo stale stamp missing, or ticket unverifiable). This lane completes all four.

## 5. Decision variants (EBDV DIA-115; developer approved variant A)

- Variant A (RECOMMENDED + APPROVED): Balanced Muse-volume (coder/researcher/conspecter) + Qwen-reasoning (orchestrator/reviewer/analyzer/openspec-plan) split, shipped INACTIVE, with same-family-collapse fix on reviewer (qwen -> deepseek-pro). Because it reuses the promo skeleton, preserves orchestrator byte-identity (15/25 text), avoids held oj59 drift, and isolates Muse (trains-on-data) to non-sensitive lanes with containment grep.
- Variant B: Muse-everywhere primary (cheapest/highest intelligence everywhere) — more volume savings but violates lane-containment (Muse on orchestrator/escalated) and privacy boundary.
- Variant C: Qwen-everywhere reasoning — strongest reasoning retention but loses Muse volume economics on coder/researcher.
- Variant D (ABORT / status-quo): Keep promo only, no balanced preset. Avoids change but leaves volume/reasoning split unexploited.

Chosen: Variant A. Because it balances 226600/mo Muse volume on coder/researcher/conspecter (where $0.10/$0.20 dominates) with Qwen reasoning on orchestrator/reviewer/analyzer/openspec-plan (where $0.15/$0.47 reasoning is retained), fixes the reviewer same-family fallback collapse (qwen -> deepseek-pro vs qwen->muse), and ships INACTIVE so promotion remains a deliberate pointer-swap.

## 6. Sources (tiered per ai-specialist hierarchy)

- Tier-1 committed: `.opencode/oh-my-opencode-slim.jsonc` preset blocks (monolithic, no inheritance; model string/array/{id,variant}); `knowledge/model-registry.yaml` (pricing/quota/privacy fields); `scripts/check-orchestrator-prompt-drift.sh` (PRESETS default, byte-identity guard).
- Tier-1 committed: `.opencode/learnings/external-patterns/2026-08-28-muse-spark-admission.md` (Muse 1.2 pricing/privacy/region/benchmark basis inherited by 1.3).
- Tier-2 dated (2026-09-09): provider pricing/privacy pages for muse-spark-1.3-contributor (0.10/0.20, trains-on-data NOT-ZDR region-limited), qwen3.8-flash (0.15/0.47, 0-day retention no training, 27000/mo), DeepSeek V4 Flash/Pro DSF ZDR through 2026-09-30.
- Tier-2 dated: oh-my-opencode-slim schema docs (preset monolithic, no inheritance) — fetched live per hierarchy.
- Developer approval: variant A approved (campaign ticket DIA-260909-tp5e scope).

## 7. Open items / held chains

- `oj59` chain owns drift-checker inclusion + 60/75 threshold migration; this lane does not touch it.
- Muse 1.3 `swe_bench_verified` stays null (benchmark-pending) until independent reproduction archived (res gap per DIA-133).
- ZDR re-verification required at 2026-09-30 for DSF-backed DeepSeek lanes.

## 8. Verification pointers (for implementer)

- `make test-config` must stay exit 0; `scripts/check-orchestrator-prompt-drift.sh` must stay exit 0 (new preset ignored).
- `scripts/validate-agent-names.sh` must stay exit 0 (17 agents present).
- JSONC parse must stay valid.
- Containment grep: `muse-spark-1.3` appears ONLY in coder/researcher/conspecter primaries + analyzer/openspec-plan fallbacks; zero hits on orchestrator/ai-specialist/ai-auditor/coder-escalated/analyzer-escalated/council.
