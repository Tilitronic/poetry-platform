# Dispatch Routing Registry Design (DIA-133) - Conspect (res023)

<!-- CONSPECTER-OUTPUT-CONTRACT
schema-version: 1.0
agent: conspecter
phase-a-source-count: 6
phase-a-failures: 0
shelf-registration: .opencode/memory-shelf.yaml (shelf.conspects)
-->

Conspect for DIA-133 (data-driven dispatch routing: orchestrator selects lane by model benchmarks + pricing + quota, area opencode-config, OPEN). This is the Phase 3 persistence of the res-4 researcher findings (dispatch-routing research), PARTIAL persistence per the res-4 recommendation and developer KEEP decision of 2026-08-13 (binary per DIA-135: persist ONE design/decision conspect covering (a) the DIA-133 registry schema + routing design and (b) the NEW Tier-2 web-fresh quota-guard precedents NOT yet in the shelf). Six external URLs were archived locally in `sources/` (2026-08-13, all Tier-1 trafilatura direct, zero failures); every external-design claim below is grounded either in an archived source file or in a project-internal document (DIA-133 ticket, res013/014/016/017 conspects, ana014 report, res022 EBDV). Pricing/benchmark figures are NOT re-archived here - they are cross-referenced to res013/016/017 per the developer-approved partial-persistence scope.

## 1. Decision context (DIA-133)

DIA-133 (filed 2026-08-13, severity Medium, area opencode-config) mandates data-driven dispatch: the orchestrator must justify "dispatch lane X with model Y" from a single authoritative registry of model capabilities (benchmarks), prices, and monthly quotas, and mechanically refuse an escalated dispatch when the monthly quota is exhausted (fallback or wait_for_user instead). Current state the ticket fixes: escalation lanes (coder-escalated kimi-k3, analyzer-escalated gpt-5.6-luna) are dispatched by HARDCODED trigger conditions in the orchestratorPrompt (oh-my-opencode-slim.jsonc lines 593, 596), and quota facts (kimi-k3 490 req/mo, gpt-5.6-luna 10,250 req/mo) live only in prose.

**Developer decisions (2026-08-13, DIA-133 header):** (1) mechanism = registry + codified policy in prompt (no plugin/tool); (2) signals = workflow signals + quota only (orchestrator cannot read repo files); (3) quota-guard = yes, consult registry.jsonl before escalated dispatch; (4) process = DIA ticket + section-10 chain.

**Developer KEEP decision (2026-08-13):** per res-4's PERSISTENCE_RECOMMENDED: true, this conspect is kept (binary per DIA-135). Scope is deliberately PARTIAL: registry schema + routing design + NEW Tier-2 quota-guard precedents (OhanaSec, Budibase, Codex, Alibaba, OmniRoute). Pricing/benchmark content is NOT re-archived (already in res013/016/017) - it is cross-referenced only.

**Binding constraints:**

- **ana014 no-self-benchmarking directive (2026-08-12):** the in-repo Rung-3 benchmark protocol (ana014) was CANCELLED by developer directive; only authoritative external evidence may enter the registry, with a `source` reference per figure. res017 then closed the evidence gap with authoritative third-party reproductions. No invented figures (DIA-133 "Research-first workflow" point 1).
- **Verified constraints (DIA-133):** dynamic model routing does NOT exist in OpenCode (issue #18644 closed-not-planned; PR #14961 auto-closed). Mechanism stays: static lanes with pinned models + orchestrator picks the lane by policy. Orchestrator has no bash; read scope is limited to .opencode/session/*, tickets/*, NEXT-RUN.md, AGENTS.md, practice-protected.md (+ DIA-126(a) overnight expansion to knowledge/*, learnings/*, plugins/*, scripts/*, docs/*, .sdd/*, openspec/*, skills/*, memory-shelf.yaml, oh-my-opencode-slim.jsonc, architecture.md, CONTEXT.md - verified at opencode.jsonc L158-183). No native per-agent wall-clock timeout / empty-result handling (res020, DIA-132 Tier 1 only: "steps": 50) - quota guard is orchestrator-side, not plugin-side.
- **Section-10 / config-review matrix (AGENTS.md 2.5):** DIA-133 is an opencode-config change; implementation routes through @ai-specialist gate (Phase 1, read-only) + @architector design (Phase 3) + @ai-auditor independent review (Phase 6) + CHANGELOG/learnings registration. This conspect is the research-phase closure artifact, not the implementation.

## 2. Registry design (from res-4)

res-4 (the DIA-133 research run) recommended the registry schema and location below. Choice A1a was adopted: **registry lives at `knowledge/model-registry.yaml`** (evidence-co-located with the knowledge base, ZERO read-scope change).

**Choice A1a verification (this conspect):** the DIA-133 ticket anticipated a read-scope change ("A4 - Read-scope change in .opencode/opencode.jsonc to make the registry readable"). That change is now UNNECESSARY: the DIA-126(a) overnight-read expansion (developer-approved 2026-08-13, opencode.jsonc L166-183) already allows the orchestrator to read `knowledge/*` (read L172, glob L195). Placing the registry under knowledge/ therefore costs ZERO permission changes - verified against the installed config (this conspect's read of opencode.jsonc L158-201). Alternative locations (.opencode/model-registry.yaml as the ticket sketch A1 suggested) would require the read-scope one-liner (Choice D, section 6).

### 2.1 Per-model schema fields

The registry is a YAML list of model entries plus a routing section. Per-model fields (synthesized from the DIA-133 ticket sketch A1 + OhanaSec model-registry.yaml precedent, section 5.1):

| Field | Type | Meaning | Grounding |
|---|---|---|---|
| model_id | string | Machine-readable model identifier (e.g. kimi-k3) | DIA-133 A1 sketch; OhanaSec `slug` field (ohanasec-model-registry.md L214) |
| role | string | Lane/role the model serves (coder, analyzer, reviewer, architector, ...) | DIA-133 A1 sketch |
| price_in_1m | number | Price per 1M input tokens (USD) | DIA-133 A1; OhanaSec `pricePerMTokenInput` (L232) |
| price_out_1m | number | Price per 1M output tokens (USD) | DIA-133 A1; OhanaSec `pricePerMTokenOutput` (L234) |
| req_per_month | number or null | Monthly request cap; null when unbounded or non-request-metered (Copilot-credit lanes) | DIA-133 A1; res013 Go caps |
| swe_bench_verified | number or null | SWE-bench Verified score (%) | DIA-133 A1: every score MUST carry source |
| source_ref | string | Citation for the benchmark/price figure (res013 / res016 / res017) - no invented figures | DIA-133 research-first point 1; ana014 directive |
| lane | string | Primary lane the model is pinned to | DIA-133 A1; routing table section 3 |
| fallback[] | list | Ordered fallback model_ids when quota exhausted or lane fails | DIA-133 A1; res014 ladder |
| quota_notes | string | Cap context (e.g. "490 req/mo binding cap", "Copilot credits - skip guard") | res016/017; section 4 |
| active | boolean | Whether the model is currently dispatchable | OhanaSec `active: true` (L236); OhanaSec add-model workflow sets active then benchmarks (L176-186) |

res-4 also noted a `tb21` (Terminal-Bench 2.1) score field in the ticket sketch; the field set is finalized by @architector in the design phase - this conspect records the proposed surface only. The DIA-133 verification requires: registry is valid YAML; every benchmark score has a `source` field; no self-benchmarking figures.

### 2.2 Model set summary (cross-referenced, NOT re-archived)

Pricing/benchmark figures are cross-referenced to res013 (pricing/limits), res016 (coder-escalated evidence), res017 (Rung-3 reproductions); no pricing content is re-archived here per the approved partial scope.

| model_id | Lane | price_in/out_1m | req_per_month | swe_bench_verified | source |
|---|---|---|---|---|---|
| deepseek-v4-flash | coder default (Rung0) | $0.14/$0.28 | 158K | (volume king) | res013 |
| qwen3.7-plus | arch/analyzer | $0.40/$1.60 | 21,600 | 77.7 (BenchLM) | res016 |
| kimi-k3 | coder-escalated (Rung3) | $3/$15 | 490 (binding cap) | 93.40 (Vals, independent) | res016 |
| gpt-5.6-luna | analyzer-escalated | $0.20/$1.20 | 10,250 | (subagent-weak, AA 74.6) | res016 |
| deepseek-v4-pro | Rung-3 fallback | $0.435/$0.87 | ~16-17K | 74 (CAISI, independent) | res017 (REVERSAL of res015) |
| mimo-v2.5-pro | fallback-2 | $0.435/$0.87 | 16,300 | 78.9 (vendor-only; benchmark-gap OPEN) | res015/017 |
| gpt-5.3-codex | reviewer (Rung4) | Copilot AI-credits | null (not request-metered) | - | res013 (Copilot plan) |

Notes: (a) res017 REVERSED the DIA-114 provisional MiMo pick (res015): deepseek-v4-pro is the preferred Rung-3 fallback because it has independent CAISI evidence (74%) while mimo-v2.5-pro has none (vendor-only 78.9%, benchmark-gap OPEN - DIA-087 R5); (b) gpt-5.3-codex runs on GitHub Copilot AI credits (subscription), not the Go request meter, so req_per_month = null and the quota guard SKIPS this lane (section 4); (c) per-model `fallback[]` semantics: kimi-k3 fallback = [deepseek-v4-pro, mimo-v2.5-pro] per res016/res017 verdicts.

## 3. Routing table (res014 Rung0-4 ladder codified)

The dispatch policy codifies the res014 escalation ladder (section 4 of res014, updated by res016/res017), expressed as a signal-to-lane table for the orchestrator prompt (DIA-133 artifact A2):

| Rung | Signal (trigger condition) | Lane / model | Quota-guarded |
|---|---|---|---|
| Rung0 | Start / routine work | coder / deepseek-v4-flash | no (158K req/mo headroom) |
| Rung1 | Verify-fail #1 / Minor finding | coder retry (same model) | no |
| Rung2 | Verify-fail #2 | coder + qwen3.7-plus | no (21,600 req/mo) |
| Rung3 | 2x failed re-review loops OR Critical severity | coder-escalated / kimi-k3 | YES (490 req/mo cap) |
| Rung3-fallback | kimi-k3 quota exhausted or SILENT_FAILURE | deepseek-v4-pro, then mimo-v2.5-pro | yes (per their caps) |
| Rung4 | Re-review after fixes | reviewer / gpt-5.3-codex | skip (Copilot credits) |
| Analyzer | Default analysis | analyzer / qwen3.7-plus | no |
| Analyzer-escalated | "cannot comprehend domain" / abort-on-complexity | analyzer-escalated / gpt-5.6-luna | YES (10,250 req/mo) - subagent-weak caveat (res016 C2) |
| Analyzer route-back | After escalated pass | back to analyzer / qwen3.7-plus | no |

The hardcoded trigger lines the ticket replaces (orchestratorPrompt lines 593, 596) map exactly to the Rung3 and Analyzer-escalated rows above: "2 consecutive failed re-review loops" or "Critical severity findings" = Rung3; "cannot comprehend domain" = analyzer-escalated. The codification adds the quota-guard step (section 4) and the res017 fallback chain.

**DIA-132 lesson (binding, from DIA-133 A2):** before re-dispatching any lane that previously failed, check registry.jsonl for a SILENT_FAILURE dispatch_state of that lane; do not blindly re-dispatch (kimi-k3 ONE-SHOT silent failure on DIA-130 context, res020). The quota guard and the silent-failure check run as one pre-dispatch gate.

## 4. Quota-guard mechanism (Choice C1)

res-4's Choice C1 (adopted): a PROCEDURAL clone of the existing COUNCIL-BUDGET-GUARD (documented in NEXT-RUN.md) - no new tooling, the orchestrator executes the check from registry.jsonl before any escalated dispatch.

**Procedure (per escalated dispatch to a quota-metered lane):**

1. Determine the target model's `req_per_month` from the registry. If null (Copilot-credit lane, e.g. gpt-5.3-codex) - SKIP the guard.
2. Count `registry.jsonl` rows with `event: 'session_spawn'` (or equivalent plugin dispatch event) for that model, filtered to the current YYYY-MM window. Counting source = **registry.jsonl, NOT messages.jsonl**: the plugin is the sole writer of registry.jsonl and it carries `dispatch_state` (including SILENT_FAILURE, needed for the DIA-132 check); messages.jsonl is an orchestrator-derived view and was identified as an anti-pattern counting source in ana007 (session-log silencing - messages.md can be silenced/stale). This resolves the DIA-133 open question "Quota counting source: messages.jsonl vs registry.jsonl" in favor of registry.jsonl.
3. If count >= 80% of cap: WARN (state the remaining headroom in the dispatch justification).
4. If count+1 > cap: HARD-STOP - do NOT dispatch; use `fallback[]` (e.g. kimi-k3 -> deepseek-v4-pro -> mimo-v2.5-pro) or `wait_for_user`, mirroring COUNCIL-BUDGET-GUARD hard-stop semantics.
5. Before re-dispatch of a previously-failed lane: check `dispatch_state` for SILENT_FAILURE (DIA-132 lesson). If SILENT_FAILURE present, treat like quota-stop (fallback or wait_for_user) rather than blind retry.

**Budibase precedent mapping (section 5.2/5.3):** the 80% warn threshold and the hard-stop at 100% mirror Budibase's percentage-trigger system (`Quota.triggers: number[]` = "array of whole numbers (1-100) that dictate the percentage that this quota should trigger at", budibase-quota-types.md L436-450; `percentage = (totalValue / quota.value) * 100` with overflow clamped to 100, budibase-quotas-ts.md L1522-1528). The warn-at-80% is the 80-trigger; hard-stop is the 100-trigger. The dry-run-then-commit pattern (tryIncrement runs `updateUsage` with dryRun:true BEFORE executing the wrapped function, budibase-quotas-ts.md L1204-1228) maps to "check count BEFORE dispatch, then dispatch" - the orchestrator's count check IS the dry run.

## 5. Tier-2 web-fresh quota-guard precedents (NEW - not previously in the shelf)

All six sources archived 2026-08-13 via trafilatura (Tier 1, direct). These precedents are NEW shelf content: none of them appears in res013-022. Claim-to-source mapping in section 8.

### 5.1 OhanaSec jc-pentest-harness model-registry.yaml (models list + routingTable separation)

The OhanaSec pentest harness keeps its model roster in a YAML registry (`agents/pentest/model-registry.yaml`) SEPARATE from the routing logic: the add-model workflow instructs "Add a routing-table entry in config/config.yaml under llmRouter.routingTable" (ohanasec-model-registry.md L182) - i.e. the registry declares models, the routing table (elsewhere) maps them to roles. Per-model entries carry: slug, label, provider, modelId, keyEnvVar, ssmKey, tier1Gate, validatePin, benchScore, pricePerMTokenInput, pricePerMTokenOutput, active, notes (L212-308). Two design lessons for DIA-133:

- **benchScore is populated AFTER a scored run, not invented:** "benchScore: null # populated after first scored run" (L230) and the workflow step "Run a supervised benchmarking pass ... Update benchScore after scoring completes" (L184-186). Directly supports the ana014 no-self-benchmarking directive: a registry may carry null scores rather than fabricated ones - same handling as mimo-v2.5-pro benchmark-gap-OPEN (null/vendor-only, flagged).
- **validatePin / tier1Gate as lane-pinning flags:** model registry carries routing-policy flags (which model is the pinned Validate-stage model, swap by flipping validatePin, L202-204) - precedent for the registry carrying lane/pinning metadata alongside pure model facts, exactly what DIA-133's `lane` field does.

### 5.2 Budibase quotas.ts (monthly quota counter: dry-run-then-commit, USAGE_LIMIT_EXCEEDED)

Budibase's quota SDK (`packages/pro/src/sdk/quotas/quotas.ts`) is a monthly-metered usage counter. Claim-to-source (all from the archive):

- **dry-run-then-commit:** `tryIncrement` first runs `updateUsage` with `dryRun: true` to verify quotas are not exceeded, THEN runs the wrapped function, THEN commits with `dryRun: false` (budibase-quotas-ts.md L1204-1228, L1258-1286). "dry run first to check that the quotas are not exceeded" (L1204). This is the precedent for the orchestrator's count-before-dispatch (section 4).
- **Percentage triggers with clamp:** `checkTriggers` computes `percentage = (totalValue / quota.value) * 100`, clamps overflow to 100 (L1522-1528), iterates `quota.triggers` (ascending percentages), sends a trigger request when `percentage >= triggerPercentage` (L1532-1560). Precedent for warn-at-80% / stop-at-100%.
- **USAGE_LIMIT_EXCEEDED:** `usageLimitIsExceeded` runs the dry-run update and catches `APIWarningCode.USAGE_LIMIT_EXCEEDED` to return a boolean (L1894-1929); the hard violation throws `UsageLimitWarning` when `totalValue > quota.value && usageChange > 0` (L1716-1726). Precedent for the hard-stop condition and its error code.
- **Monthly window keying:** monthly usage is keyed by `db.quotas.utils.getCurrentMonthString()` (L1426) with a `quotaReset` date (L1514-1516) - the "current month string" is exactly the YYYY-MM filter of the DIA-133 guard.
- **Decrement allowed when exceeded:** "allow for decrementing usage when the quota is already exceeded" (L1720) and `totalValue = Math.max(0, totalValue)` (L1730) - quota overrun is recoverable, never negative.

### 5.3 Budibase quota.ts (types: MonthlyQuotaName, QuotaUsageType, Quota interface)

The type-level counterpart (`packages/types/src/sdk/licensing/quota.ts`) defines the quota vocabulary: `QuotaUsageType.STATIC | MONTHLY` (budibase-quota-types.md L258-264), `MonthlyQuotaName` enum (QUERIES, AUTOMATIONS, BUDIBASE_AI_CREDITS, ACTIONS - L292-302), and the `Quota` interface `{ name, value, triggers: number[] }` where triggers are "whole numbers (1-100) that dictate the percentage that this quota should trigger at" (L430-450). Design lesson: quota types are explicitly declared (monthly vs static vs constant); DIA-133's req_per_month = null for Copilot lanes is the analogous "this quota type does not apply" declaration.

### 5.4 OpenAI Codex types.rs (min_rate_limit_remaining_percent)

Codex config (`codex-rs/config/src/types.rs`) gates memory-rollout work on remaining rate-limit headroom: `DEFAULT_MEMORIES_MIN_RATE_LIMIT_REMAINING_PERCENT: i64 = 25` (codex-config-types-rs.md L1986) with the config field `min_rate_limit_remaining_percent: Option<i64>` (L2454) documented as "Minimum remaining percentage required in Codex rate-limit windows before memory startup runs" (L2450), defaulted from the constant (L2522) and overridable via TOML (L2606-2610). Also `hide_rate_limit_model_nudge` (L3342-3344): Codex nudges the user to switch models under rate pressure. Design lessons: (a) a threshold-on-remaining-headroom (not on consumed count) is a valid guard formulation - DIA-133 could additionally warn when remaining < 25% rather than only consumed >= 80%; (b) a model-switch nudge is a UI affordance the orchestrator mirrors as "fallback[] or wait_for_user".

### 5.5 Alibaba open-code-review post_review.py (proactive throttle + idempotent retry)

Alibaba's GitLab-CI review poster (`examples/gitlab_ci/post_review.py`) implements proactive rate-limit throttle. Claim-to-source:

- **Rate-limit header parsing:** `_parse_rate_limit_header(headers, "RateLimit-Remaining")` / `"RateLimit-Limit"` (alibaba-post-review-py.md L2990, L3034-3036), with per-response classification into `is_rate_limit_exhausted` / `is_transient` / `is_network_error` / `rate_limit_remaining` (L3048-3096).
- **Exponential backoff with cap + jitter:** `_compute_retry_delay` computes `retry_base_delay * (2 ** attempt)`, capped at `max_retry_delay`, with +/-25% jitter, honoring `Retry-After` when present (L3098-3180).
- **Proactive threshold check:** before an API call, `rate_limit_remaining <= rate_limit_threshold` triggers wait-until-reset ("wait-until-reset when the primary rate limit is exhausted", L2076; `threshold = self.config.get("rate_limit_threshold", 0)`, L3452; L3428-3452). This is the proactive-headroom guard: check remaining BEFORE acting, not reactively after a 429 - the same posture as the DIA-133 pre-dispatch count.
- **Idempotent retry:** per-comment id tags with reconcile-before-retry (L2070, L3388-3394) - retries never double-post; the DIA-133 analogue is never double-dispatch when the first dispatch may have landed (ties to the SILENT_FAILURE check, section 4).

### 5.6 OmniRoute (quota-aware scheduling; field-name claim FLAGGED)

OmniRoute (diegosouzapw/OmniRoute) is a multi-provider router with quota-aware routing. Claim-to-source from the archived README (omniroute.md):

- **Quota-aware routing strategies:** `headroom` = "Pick the target with the most remaining quota" (L90), `reset-window` = "Prefer the target whose quota window resets soonest" (L91), `reset-aware` = "Rank by quota reset time" (L92), `fill-first` = "Fill each target's quota fully before moving on" (L82), and the `auto/offline` mode = "Most quota / rate-limit headroom first" (L74). The Auto-Combo engine scores candidates on 14 factors including "health, quota, cost, latency, success rate, freshness" (L101).
- **Quota telemetry:** `X-OmniRoute-*` cost/usage headers on every endpoint, per-key USD spend quotas (L150); quota telemetry and quota-aware scheduling listed as roadmap features (L21-22); webhooks push "usage, quota, errors, routing" events (L238).
- **FLAG (DIA-072 handling):** the res-4/prompt claim that OmniRoute exposes literal `freeMonthlyQuota` / `costPerQuery` fields could NOT be confirmed in the archived README - those field names do not appear in omniroute.md. They would live in the provider catalog (`docs/reference/PROVIDER_REFERENCE.md` / `docs/reference/FREE_TIERS.md`, which the README references at L7, L185, L489 but which were NOT archived). The archived evidence supports the general design (quota-aware scheduling, headroom/reset strategies, quota telemetry) but NOT the specific field names. The field-name claim is recorded here as researcher-supplied-not-archived, consistent with the res022 convention for unconfirmed precedents.

**Synthesis for DIA-133:** across the five precedents, the converged quota-guard design is: (1) count consumption against a monthly window (Budibase currentMonthString, OmniRoute reset-window), (2) dry-run before acting (Budibase dryRun, Alibaba threshold check, Codex min-remaining-percent), (3) warn at a percentage trigger and hard-stop at cap (Budibase triggers array), (4) on stop, fail over through an ordered fallback chain (OhanaSec dual-model pattern, OmniRoute combos, res014/017 fallback[]), (5) keep idempotency so retries never double-dispatch (Alibaba reconcile, DIA-132 SILENT_FAILURE check). Choice C1 (section 4) operationalizes all five.

## 6. Design-gate (who decides what)

The DIA-133 ticket mandates a section-10 chain (AGENTS.md 2.5). This conspect records the routing of each decision:

| Choice | Content | Gate | Rationale |
|---|---|---|---|
| A (registry schema fields + model set) | Section 2.1/2.2 | @architector design phase (DIA-133 step 3) | Non-trivial config design (3+ files); EBDV variants needed per res022 |
| B (routing table wording in orchestrator prompt) | Section 3 | @architector (with @ai-specialist Phase-1 findings) | Prompt-surface change; DIA-133 step 1/3 |
| C (quota-guard procedure) | Section 4 | @architector | Procedural policy wording in orchestrator prompt |
| D (read-scope one-liner for the registry path) | Registry at knowledge/ -> NOT NEEDED (verified); IF a future location change moves it out of knowledge/*, add ONE literal allow entry | pure config (no design gate) | opencode.jsonc L172/195 already allow knowledge/* (DIA-126(a)); a future non-knowledge path needs a single-file literal allow entry like `.opencode/model-registry.yaml` - NOT a bare `.opencode/*` wildcard (DIA-126a wildcard lesson: single-star patterns cross path separators, so bare dir-wide wildcards over-broaden scope) |

**DIA-126a wildcard lesson (cross-reference):** the DIA-126(a) verification confirmed single-star patterns match across path separators (one `*` becomes `.*` with the s flag, opencode.jsonc L167-171). Consequence: any future registry read-scope entry must be a single-file literal (e.g. `.opencode/model-registry.yaml`) rather than a directory wildcard - a bare `.opencode/*` would grant read over everything under .opencode. The knowledge/* entry already present is the literal-scoped exception that makes Choice A1a zero-cost.

**EBDV note (res022):** the design-phase presentation of Choices A/B/C to the developer must follow the Evidence-Backed Decision Variants format (>=2 real variants + recommendation + abort/status-quo, T1/T2/T3 evidence tiers) because DIA-133 is a policy-class decision (model/tool-selection with >=2 candidates + opencode-config change triggers both DIA-115 trigger classes). This conspect's Tier-2 precedents (section 5) are the T2 evidence pool for the quota-guard variants.

## 7. Cross-references

- **res013** (OpenCode Model Pricing Audit, DIA-108): Go pricing/limits, Copilot AI-credit plan, deepseek-v4-flash $0.14/$0.28 158K req/mo - pricing source for the registry, NOT re-archived here.
- **res014** (Model Escalation Routing, DIA-111): Rung0-4 ladder + 6 routing patterns - codified in section 3.
- **res015** (MiMo-V2.5-Pro Evaluation, DIA-114): mimo-v2.5-pro identity/benchmarks - PARTIALLY REVERSED by res017 for fallback ordering; benchmark-gap OPEN.
- **res016** (Coder-Escalated Model Evidence, DIA-111): kimi-k3 93.40% SWE-V + 490 req/mo cap, luna subagent-weak, qwen3.7-plus - Rung3/analyzer facts in section 2.2.
- **res017** (Rung-3 Benchmark Evidence, DIA-116): independent CAISI deepseek-v4-pro 74%, REVERSAL of res015 MiMo pick, evidence-gap statuses - fallback-chain ordering in section 2.2/3.
- **ana014** (Rung-3 Benchmark Protocol, DIA-111): in-repo benchmark CANCELLED by developer directive 2026-08-12 - no-self-benchmarking binding on registry scores.
- **res022** (EBDV, DIA-115): evidence-tier presentation requirement for the design-phase variants (section 6).
- **res020 / DIA-132** (OpenCode Agent Config Watchdog): no native timeout/empty-result; SILENT_FAILURE check before re-dispatch (section 3/4).
- **ana007** (Session-Log Silencing): messages.jsonl is a silenced-able derived view - anti-pattern counting source; registry.jsonl (plugin sole-writer, dispatch_state) is the guard source (section 4).
- **DIA-126(a)** (overnight read expansion): knowledge/* allow at opencode.jsonc L172/195 - makes Choice A1a zero-cost; wildcard semantics lesson (section 2/6).
- **DIA-135** (research-pipeline optimization / binary persistence decision): the binary KEEP framing that scoped this conspect (partial persistence).

## 8. Source URLs, MLA citations, claim-to-source mapping

Archived 2026-08-13, Tier 1 (trafilatura direct), all 6 successful, 0 failures. Sources in `knowledge/res023-dispatch-routing-registry/sources/`.

| # | URL (per .source-urls.txt) | Local file | Bytes/Lines | Status |
|---|---|---|---|---|
| 1 | https://github.com/OhanaSec/jc-pentest-harness/blob/main/agents/pentest/model-registry.yaml | ohanasec-model-registry.md | 308 lines | OK |
| 2 | https://github.com/Budibase/budibase/blob/master/packages/pro/src/sdk/quotas/quotas.ts | budibase-quotas-ts.md | 1930 lines | OK |
| 3 | https://github.com/Budibase/budibase/blob/master/packages/types/src/sdk/licensing/quota.ts | budibase-quota-types.md | 454 lines | OK |
| 4 | https://github.com/openai/codex/blob/main/codex-rs/config/src/types.rs | codex-config-types-rs.md | 3546 lines | OK |
| 5 | https://github.com/alibaba/open-code-review/blob/main/examples/gitlab_ci/post_review.py | alibaba-post-review-py.md | 3740 lines | OK |
| 6 | https://github.com/diegosouzapw/OmniRoute | omniroute.md | 611 lines | OK |

**MLA citations:**

OhanaSec. "model-registry.yaml." *JC PenTest Harness*, GitHub, 10 June 2026 (file header), github.com/OhanaSec/jc-pentest-harness/blob/main/agents/pentest/model-registry.yaml. Archived 13 Aug. 2026.

Budibase. "quotas.ts." *Budibase*, GitHub, master branch, github.com/Budibase/budibase/blob/master/packages/pro/src/sdk/quotas/quotas.ts. Archived 13 Aug. 2026.

Budibase. "quota.ts." *Budibase*, GitHub, master branch, github.com/Budibase/budibase/blob/master/packages/types/src/sdk/licensing/quota.ts. Archived 13 Aug. 2026.

OpenAI. "types.rs." *Codex*, GitHub, main branch, github.com/openai/codex/blob/main/codex-rs/config/src/types.rs. Archived 13 Aug. 2026.

Alibaba. "post_review.py." *Open-Code-Review*, GitHub, main branch, github.com/alibaba/open-code-review/blob/main/examples/gitlab_ci/post_review.py. Archived 13 Aug. 2026.

Diegosouzapw. "OmniRoute." *GitHub*, github.com/diegosouzapw/OmniRoute. Archived 13 Aug. 2026.

**Claim-to-source mapping:**

| Claim (section) | Source evidence (file + line) |
|---|---|
| Registry/routingTable separation (5.1) | ohanasec-model-registry.md L182 (routing-table instruction), L212 (models: list) |
| benchScore populated after scored run (5.1) | ohanasec-model-registry.md L230 ("populated after first scored run"), L184-186 |
| validatePin lane-pinning swap (5.1) | ohanasec-model-registry.md L202-204 |
| Dry-run-then-commit (5.2) | budibase-quotas-ts.md L1204 ("dry run first"), L1206-1228, L1260-1286 |
| Percentage triggers 1-100 (5.2/5.3) | budibase-quotas-ts.md L1522-1560; budibase-quota-types.md L436-450 |
| USAGE_LIMIT_EXCEEDED (5.2) | budibase-quotas-ts.md L1894-1929, L1716-1726 |
| getCurrentMonthString monthly key (5.2) | budibase-quotas-ts.md L1426, L1514-1516 |
| MonthlyQuotaName / QuotaUsageType (5.3) | budibase-quota-types.md L258-264, L292-302 |
| min_rate_limit_remaining_percent default 25 (5.4) | codex-config-types-rs.md L1986, L2450-2454, L2522, L2606-2610 |
| hide_rate_limit_model_nudge (5.4) | codex-config-types-rs.md L3342-3344 |
| Rate-limit header parsing (5.5) | alibaba-post-review-py.md L2990, L3034-3036 |
| Exponential backoff cap+jitter, Retry-After (5.5) | alibaba-post-review-py.md L3098-3180 |
| Proactive threshold wait-until-reset (5.5) | alibaba-post-review-py.md L2076, L3428-3452 |
| Idempotent reconcile-before-retry (5.5) | alibaba-post-review-py.md L2070, L3388-3394 |
| Quota-aware strategies: headroom/reset-window/reset-aware/fill-first (5.6) | omniroute.md L90-92, L82, L74 |
| 14-factor scoring incl. quota (5.6) | omniroute.md L101 |
| X-OmniRoute cost/usage headers + per-key spend quotas (5.6) | omniroute.md L150 |
| FLAG: freeMonthlyQuota/costPerQuery field names NOT in archive (5.6) | omniroute.md - NOT FOUND (researcher-supplied; would be in unarchived PROVIDER_REFERENCE.md/FREE_TIERS.md) |
| Choice A1a zero read-scope change (2/6) | .opencode/opencode.jsonc L172 (read), L195 (glob) - verified 2026-08-13 |
| Rung0-4 ladder + fallback ordering (3) | res014/res016/res017 conspects (cross-referenced, not re-archived) |
| registry.jsonl over messages.jsonl (4) | ana007 anti-pattern (cross-referenced); DIA-133 open question resolved |
