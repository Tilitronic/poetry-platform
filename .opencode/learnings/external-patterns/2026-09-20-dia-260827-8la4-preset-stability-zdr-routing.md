# Preset stability: ZDR routing (muse-balanced contents edit)

Date: 2026-09-20
Ticket: DIA-260827-8la4 '[MEDIUM] Model routing sources disagree (registry vs prompt vs runtime)'
Status: findings registered, awaiting implementation (AGENTS.md 2.5 step-1 gate).

## 1. Root cause (new finding)

The Zen-free code-navigator route was introduced by DIA-260916-7jek to satisfy
the "promo is openai-free" invariant, by swapping
openai/gpt-5.6-luna -> opencode/muse-spark-1.3-contributor-free.
The preset was later renamed muse-balanced (unrecorded rename, learning
2026-09-18-dia-260917-s95f-variant-b-retarget.md L24) and the dead-provider
lane came along. Constraint leak: an openai-free rule paid for with a dead
provider, in a preset whose real constraints are "Go provider works" + "ZDR".

## 2. Confirmed failure

code-navigator is the ONLY muse-balanced lane on the opencode/ (Zen free)
provider (jsonc:436) and fails with:
"Error from provider (Console): OpenCode's free tier can only be used from within OpenCode"
Upstream cluster 2026-09-17: issues #49433 / #49590 / #49596. Deterministic
sub-second failure. Two occurrences in this repo:
ses_f4afb0108ffe49vFZssPmwziHr (2026-09-18) and
ses_f40db3202ffeY5ZTWkl06y3yHL (2026-09-20).

## 3. Refuted causes (do not re-chase)

- Go quota exhaustion: mimo/muse bucket ~98,000 req before the 5h cap vs
  ~120 dispatches/day. Headroom rules this out.
- Model-quality instability: 8 lanes on the same model succeeded in-session.
  Failure is provider-routing, not model quality.

## 4. Second failure mode (separate, unresolved)

3 coder lanes died via session_complete + empty_result_detected x3 ->
failure_cap_reached (registry.jsonl:1126-1149, messages.jsonl:1198).
Model-array fallback does NOT cover silent-empty (retry_on_empty is
council-only, res029). This is why the commit lane needed 4 attempts.

## 5. Third finding

Orchestrator session model disagreed with the preset orchestrator entry;
registry.jsonl:986 shows a reasoning-replay error
("encrypted_content was not issued to this caller") from a mid-session model
switch.

## 6. Preset mechanism divergence

Runtime plugin 2.2.19 resolves OH_MY_OPENCODE_SLIM_PRESET > project
config.preset; vendored fork 2.2.11 resolves PRESET env >
workspace-presets.json and treats config.preset as NOT a fallback.
Therefore `make opencode`'s "Effective preset" line is not runtime proof,
and changing the preset pointer is unreliable.

## 7. Privacy fact

Muse Spark 1.2/1.3 are the only Go models with training "Yes" / retention
"Not ZDR" (Tier-2 https://opencode.ai/docs/go/, page dated 2026-09-20);
every other Go model is "Not used / 0 days".
DeepSeek ZDR agreement valid through 2026-09-30.

## 8. Decision (developer-approved 2026-09-20)

Edit muse-balanced CONTENTS in place to a ZDR-only, opencode-go-only fleet;
do NOT change the preset pointer; do NOT rename the preset. Final fleet:

- Volume lanes (coder, code-navigator, researcher, conspecter, observer,
  resource-manager, memory-manager) -> opencode-go/mimo-v2.5
- Reasoning lanes (orchestrator, architector, openspec-plan, reviewer,
  ai-specialist, coder-escalated, analyzer-escalated) ->
  opencode-go/deepseek-v4-flash (chosen over v4.1-flash for the $30/65,000
  bucket vs $15/32,500 after the 4x promo ends 2026-09-20)
- analyzer + designer -> opencode-go/qwen3.8-flash
- ai-auditor -> opencode-go/glm-5.3-flash (developer override for genuine
  independence from ai-specialist)

Every lane gets a 2-element fallback chain (all lanes are currently
single-element = zero failover).

## 9. Invariants retained

- Zero openai/* hits in this preset (DIA-260916-7jek).
- Reviewer primary must differ from coder primary (jsonc:821).

## 10. Out of scope / separate tickets

- opencode.jsonc:414 coder-escalated override -> DIA-260917-jrph
- Vendored 2.2.11 vs runtime 2.2.19 version skew -> new ticket
- Deeper registry rot (unprefixed ids, retired models still listing lanes)
  -> DIA-260918-rbqk

## 11. Sources

- Gate lane: ses_f40da5be4ffeEMQyejB6Msrij0
- Design lane: ses_f40cbb97affeiQdEiaM4Gdiibx
- Tier-2 Go docs (2026-09-20): https://opencode.ai/docs/go/
- Upstream issues #49433 / #49590 / #49596 (2026-09-17 cluster)
- Registry: registry.jsonl:986, registry.jsonl:1126-1149, messages.jsonl:1198
- Config refs: jsonc:436, jsonc:821, jsonc:414
