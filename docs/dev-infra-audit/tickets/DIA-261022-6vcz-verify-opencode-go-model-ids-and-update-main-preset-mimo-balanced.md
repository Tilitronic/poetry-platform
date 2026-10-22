# DIA-261022-6vcz - Verify OpenCode Go model IDs and update main preset mimo-balanced

---

id: DIA-261022-6vcz
title: "Verify OpenCode Go model IDs and update main preset mimo-balanced"
area: scripts
severity: Medium
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-10-22
source: inventory
date: 2026-10-22
created: 2026-10-22
updated: 2026-10-22

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

The mimo-balanced preset (.opencode/oh-my-opencode-slim.jsonc) referenced the non-existent model id opencode-go/deepseek-v4-flash as a fallback in 7 places (models.dev TOML 404; absent from the live Go models payload, probed 2026-10-22). The section 2.5 config gate (ai-specialist read-only, verdict APPROVE-WITH-CHANGES) additionally confirmed: deepseek-v4.1-flash effort ladder is low|high|max (medium invalid); longcat-\*, minimax-m3 and mimo-v2.6-pro publish no effort ladder (variant keys inert there); ZDR clears on longcat-2.0/longcat-2.5-preview-free/minimax-m3/mimo-v2.6-pro; families longcat=Meituan, minimax=MiniMax, mimo=Xiaomi. Gate findings registered at .opencode/learnings/external-patterns/2026-10-22-opencode-go-model-id-drift.md.

Probe decision (BRANCH B): opencode-go/longcat-2.5-preview-free is listed by `opencode models` and in the local cache but is absent from the live Go payload and NOT dispatchable (`opencode run` exit 1, "Upstream request failed: Endpoint is unavailable"). ai-auditor therefore routes opencode-go/longcat-2.0 + opencode-go/minimax-m3; the unverified preview id appears nowhere in the config.

## Verification

- [x] JSONC parses (config parse path + make test-config)
- [x] `grep -rn "deepseek-v4-flash" .opencode/oh-my-opencode-slim.jsonc` returns nothing
- [x] New ids landed: longcat-2.0, minimax-m3, mimo-v2.6-pro, mimo-v2.5
- [x] reviewer block byte-identical to before (deepseek-v4.1-flash + qwen3.8-flash, variant high)
- [x] longcat-2.5-preview-free absent from the config file
- [x] CHANGELOG entry appended via scripts/changelog-add

## Fix

> 2026-10-22 (implementation lane, same-day as gate): EDITS 1-10 in .opencode/oh-my-opencode-slim.jsonc (mimo-balanced preset only, openai-first-cost-balanced untouched): (1/3/4/5/6) dead deepseek-v4-flash fallback replaced with opencode-go/mimo-v2.5 on coder/conspecter/memory-manager/code-navigator/researcher (mimo-v2.6-flash stays primary, mimo-v2.5 is the documented present successor-fallback); (2) analyzer fallback deepseek-v4-flash -> opencode-go/mimo-v2.6-flash; (7) ai-auditor -> [opencode-go/longcat-2.0, opencode-go/minimax-m3], inert variant key removed; (8) reviewer UNTOUCHED; (9) ai-specialist -> [opencode-go/mimo-v2.6-pro, opencode-go/deepseek-v4.1-flash], inert variant key removed; (10) header composition comment rewritten with DIA-261022-6vcz marker. EDIT 11: knowledge/model-registry.yaml grok-4.7 lane -> ["architector"] + DIA-261022-6vcz header note. EDIT 12: CHANGELOG entry via scripts/changelog-add.
>
> Round 2 (2026-10-22, approved follow-ups): CHANGE 1 ai-auditor primary -> opencode-go/gemini-4-argon-contributor (probe BRANCH A: live Go catalog + dispatch probe exit 0 'OK'), fallbacks [longcat-2.0, minimax-m3] retained, variant key stays absent; CHANGE 2 coder-escalated variant medium -> high (invalid rung corrected for the low|high|max ladder); CHANGE 3 registry grok-4.7 fallback deepseek-v4-flash -> deepseek-v4.1-flash (intended at variant max); CHANGE 4 Not-ZDR waiver paperwork: header ZDR-only invariant amended to state the ai-auditor exception (developer-cleared 2026-10-22, DIA-260828-qtsi Muse precedent, no-sensitive-traffic basis), new registry entry with privacy_notes waiver, learnings F7 section; CHANGE 5 second CHANGELOG entry. Pre-existing defect from round-1 risk #1 now CLOSED by CHANGE 2.
>
> Round 3 (2026-10-22, approved follow-ups): ladder READ FIRST from `opencode models --verbose` - opencode-go/gemini-4-argon-contributor declares exactly variants low|medium|high (no max, no xhigh), so MEDIUM_RUNG = medium and MAX_RUNG = high. CHANGE 6 ai-auditor gains "variant": "medium" (model list unchanged: gemini-4-argon-contributor + longcat-2.0 + minimax-m3). CHANGE 7 architector model [opencode-go/grok-4.7, opencode-go/mimo-v2.6-flash] -> [opencode-go/gemini-4-argon-contributor, opencode-go/mimo-v2.6-flash], variant stays "high" because that IS the max rung of the real ladder; options block (reasoningEffort high, thinking.type enabled) left byte-for-byte as-is - no verbose/config-path evidence that those keys are rejected for this model. CHANGE 8 header ZDR exception widened from one lane to two (ai-auditor AND architector), single waiver attribution kept, practical consequence stated (every architector and ai-auditor dispatch is non-ZDR traffic), Muse removal history kept verbatim. CHANGE 9 registry: gemini-4-argon-contributor lane -> ["architector", "ai-auditor"] + privacy_notes widened to both lanes; grok-4.7 lane -> [] (architector moved, dated DIA-261022-6vcz note, entry retained like kimi-k3). CHANGE 10 learnings F8 (variant-ladder rule). CHANGE 11 third CHANGELOG entry via scripts/changelog-add.
>
> Round 4 (2026-10-22, documentation only): no .opencode/oh-my-opencode-slim.jsonc edit in this round - knowledge/model-registry.yaml and the learnings file only, restating CHANGELOG entry 4 ("documentation-only: records the Argon-vs-Grok cost analysis (cache-read economics, 98% cache profile, 5.5x request headroom under promo, ~3x after), the ZDR trade, and both throughput estimates for grok-4.7"). CHANGE 12: a COST ANALYSIS comment block was added between the grok-4.7 and gemini-4-argon-contributor registry entries. It records the cache-read economics - on a Go subscription pool cost per request is driven by the CACHE-READ price, not the output price, because the representative agentic session profile is 410 new input + 71,300 cached + 310 output tokens per request (~98% cache reads): grok-4.7 at $0.50 per 1M cache ~ $0.0383 per request against a $3.00 per-5h slice / $15.00 monthly pool; gemini-4-argon-contributor at $0.20 per 1M cache ~ $0.022-0.027 per request against a $12.00 per-5h slice / $60.00 promo pool, hence roughly 5.5x the request headroom of grok-4.7 under the 2x promo (~2,200 vs ~390 req/mo) and still roughly 3x after the promo ends and the pool reverts to $30.00 - despite grok-4.7 having a 3.3x cheaper output price ($6.00 vs $20.00 per 1M) and a 2.5x higher cache-read price. The ZDR trade is restated in the same block: grok-4.7 wins only where Zero Data Retention is mandatory, because the Contributor tier of Gemini 4 Argon trains on prompts and completions - exactly the trade already accepted in the header waiver covering the architector and ai-auditor lanes (privacy_notes on the gemini entry). All of these figures are DEVELOPER-SUPPLIED 2026-10-22 from https://opencode.ai/v2/docs/console/go/ and are NOT gate-verified; source_ref on both entries was amended to carry that provenance. grok-4.7 quota_notes now carries BOTH throughput estimates side by side with their assumptions, neither replacing the other: (a) the docs baseline ~845 req/mo on the $15 bucket (assumes no cache-read discount, carried from the DIA-260929-wjir gate) and (b) the DEVELOPER-SUPPLIED agentic-profile figure ~78-80 req/5h and ~390 req/mo. The gemini-4-argon-contributor entry gained its developer-supplied economics (Go plan $4.00/$20.00 per 1M vs direct-API list $2.00/$10.00, cached read $0.20 per 1M, pool $60.00 promo / $30.00 base, 5h slice $12.00 / $6.00 base, ~440 req/5h and ~2,200 req/mo under promo) in price fields, req_per_month and quota_notes. Unchanged by this round and carried over: grok-4.7 still has lane [] (zero lane users, architector having moved in round 3) and its entry is retained like kimi-k3 - deletion is a separate decision. The learnings file gained F9 ("Cache-read price decides lane cost"), the round-4 rule restating the two-estimate split. CHANGE 13: fourth CHANGELOG entry via scripts/changelog-add, files recorded as knowledge/model-registry.yaml + .opencode/learnings/external-patterns/2026-10-22-opencode-go-model-id-drift.md.

## Re-verify

> To be filled at re-verify time.
