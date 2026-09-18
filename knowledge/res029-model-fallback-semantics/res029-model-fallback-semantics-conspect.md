# res029 — Model Fallback Semantics: OpenCode Native Contract vs OMO Runtime Extension

<!-- CONSPECTER-OUTPUT-CONTRACT
schema-version: 1.0
agent: conspecter
phase-a-source-count: 3
phase-a-failures: 0
shelf-registration: memory-shelf.yaml (shelf.conspects), delegated to @memory-manager
-->

- **Topic:** model-fallback-semantics (how OpenCode resolves agent model config; how oh-my-opencode-slim extends it with model-array auto-fallback)
- **Date:** 2026-08-17
- **Ticket:** DIA-189 (research-pipeline Phase 4, conspect synthesis)
- **Sources:** 3 archived external (Phase A, D5) + 5 in-repo runtime artifacts (cited by path)
- **Research lane:** ai-auditor (standing in for the failing ai-specialist lane); developer disposition: KEEP

---

## Summary

OpenCode's native contract for agent model configuration is a **single model string** (`provider/model-id`): the official config JSON schema types `AgentConfig.model` as `"type": "string"` and the agents documentation describes the field as an override, with no array or fallback semantics anywhere in the documented surface. Model-array fallback is an **oh-my-opencode-slim (OMO) runtime extension**: when `agents.<name>.model` is configured as an array, OMO stores it as an ordered fallback chain, applies the first entry at config time, and a foreground-fallback manager auto-switches to the next untried entry when it detects failure signals (rate-limit/quota/error/session-status patterns) through the plugin event system. One documented OMO option, `retry_on_empty`, is implemented **only in the council path**, not globally — a silent empty response without an error signal may therefore not trigger fallback for non-council agents. Practical consequence for this project: adding `github-copilot/gpt-5.3-codex` as the second entry of the ai-specialist model array (cebula preset) yields automatic fallback when `qwen3.7-plus` fails with error signals — and the 2026-08-17 ai-specialist failures were session errors (DIA-099 signal D2), a signal class the fallback manager detects.

---

## Key Findings

### 1. OpenCode native: `AgentConfig.model` is a single string — no native array fallback

The official published config schema types the agent model field as a string referencing the models.dev Model schema: `"model": { "type": "string", "$ref": "https://models.dev/model-schema.json#/$defs/Model" }` (OpenCode, "Config JSON Schema", `AgentConfig` def, lines 172-175). The same contract appears verbatim in the res020 archive of the schema (res020 archive, `opencode-config-schema.json`, lines 172-175), confirming the live schema is stable across captures. The agents documentation describes the field the same way: "Use the `model` config to override the model for this agent," with the ID format `provider/model-id` (OpenCode, "Agents", "Model" section). Neither source documents an array type or any fallback semantics for `model` — the schema is `additionalProperties: false` on `AgentConfig` and the documented type is string-only. **Conclusion: model-array fallback is not an OpenCode-documented feature; it is an OMO extension layered on top.**

### 2. OMO runtime extension: model arrays are ordered fallback chains

OMO's agent factory stores a model array as `_modelArray` and clears `config.model` so OpenCode does not pre-resolve a stale value; the first entry is written back as the launch-time model (oh-my-opencode-slim, `src/agents/index.ts`, lines 147-163). At plugin init, a single pass over agent definitions builds two structures from `_modelArray` entries: `modelArrayMap` (agent name → array of `{id, variant}`) and `runtimeChains` (agent name → ordered list of model IDs) (oh-my-opencode-slim, `src/index.ts`, lines 196-208). At config-application time, the first entry of the array is selected as the active model — with the caveat that a user-selected model (via `/model`) takes precedence over the config chain to preserve runtime selections (oh-my-opencode-slim, `src/index.ts`, lines 510-545). The chain is therefore: **first entry active at startup; later entries are ordered fallbacks, not load-balanced alternatives.**

### 3. Fallback manager: auto-switch on detected failure signals

The `ForegroundFallbackManager` is instantiated with the runtime chains, an enabled flag (`config.fallback?.enabled !== false`) and a retry budget (`config.fallback?.maxRetries ?? 3`); it is enabled by default even without chains so it can abort rate-limited sessions after max retries to prevent infinite freezes (oh-my-opencode-slim, `src/index.ts`, lines 302-307). Detection is signal-based, not exception-based (foreground sessions cannot be wrapped in try/catch): the manager subscribes to `message.updated`, `session.error`, and `session.status` events (oh-my-opencode-slim, `src/hooks/foreground-fallback/index.ts`, lines 4-10) — an event surface that exists in the OpenCode plugin system (OpenCode, "Plugins", "Session Events": `session.error`, `session.status`, `message.updated`). Failure signals matched:

- **Error-text patterns** — a regex list covering HTTP 429, rate limit, too many requests, quota/usage exceeded, ExceededBudget, over budget, overloaded, resource exhausted, insufficient quota/balance, high/reduce concurrency, service unavailable, and monthly/5-hour/weekly usage limits (oh-my-opencode-slim, `src/hooks/foreground-fallback/index.ts`, lines 32-52).
- **`message.updated`** — a rate-limit error on an individual message triggers `tryFallback` when the intervention guard passes; a successful response clears the retry count (lines 157-165).
- **`session.error`** — a rate-limit error on the session triggers `tryFallback` (lines 168-181).
- **`session.status`** — status messages containing rate-limit phrases go through the retry budget check before `tryFallback` (lines 183-207).

The switch itself: find the next untried model in the chain; if the chain is exhausted but has fallbacks, reset the tried set and stick to the deepest fallback model (so the dead primary is not re-tried on every message); if there is no fallback at all, abort the session (lines 338-367). The last user message is re-queued with the new model via `promptAsync` (non-blocking); if the session is busy, the manager falls back to abort + delay + re-queue (lines 381-433). Retry count resets on model switch so the new model starts fresh (lines 369-370).

### 4. `retry_on_empty` is council-only — silent empties may not trigger fallback elsewhere

The OMO config surface exposes `fallback.retry_on_empty` (default `true`), but the only implementation site is the council path: `runCouncillor` throws `'Empty response from provider'` when extraction is empty and `retry_on_empty` is set (oh-my-opencode-slim, `src/council/council-manager.ts`, lines 307-311), and `runCouncillorWithRetry` retries the *same* model on that specific empty-response error while any other error advances to the next model in the chain (lines 411-414, 480-483). The foreground-fallback manager, by contrast, keys exclusively on rate-limit/error/status *signals* — a provider that returns an empty success with no error text is not detected by the foreground path. **Implication: silent-empty-without-error may not trigger fallback for non-council agents; the foreground manager covers error-signal failures, not silent empties.**

### 5. Practical implication for this project (ai-specialist lane)

Adding `github-copilot/gpt-5.3-codex` as the second entry in the ai-specialist model array (cebula preset) gives automatic fallback when the primary `qwen3.7-plus` fails with error signals: the first entry stays active at startup, and the foreground-fallback manager switches to the Copilot model on detected rate-limit/quota/error/session-status patterns. The 2026-08-17 ai-specialist failures were **session errors (DIA-099 signal D2)** — precisely the `session.error` event class the manager handles (finding 3). No exclusivity constraint blocks this: the model-registry row for gpt-5.3-codex carries no exclusivity flag (cross-reference below).

### 6. Cross-reference: model-registry.yaml gpt-5.3-codex row

`knowledge/model-registry.yaml` (lines 76-86) records gpt-5.3-codex as: role `reviewer`, price $1.75/$14.00 per 1M tokens, `req_per_month: null` (Copilot AI credits — the quota guard SKIPS this lane), `swe_bench_verified: 85.0`, lane `reviewer`, `fallback: []`, `active: true`. The null request-meter means a fallback switch to gpt-5.3-codex does not consume the Go request-meter quota; the Copilot-credit skip-guard behavior is also documented in res023 (dispatch-routing-registry, section 4) and res014 (Rung 4 reviewer routing). The registry row has no exclusivity constraint, so dual use (reviewer lane + ai-specialist fallback) is not prohibited by the registry.

---

## Source List

### Archived external sources (Phase A, D5 — all pass researcher evaluation)

1. OpenCode. "Agents." *OpenCode Docs*, opencode.ai, 2026, https://opencode.ai/docs/agents. Archived: `knowledge/res029-model-fallback-semantics/sources/opencode-docs-agents.md`. **Relevance: High, Reliability: High.** Documents the agent `model` config field ("override the model for this agent", format `provider/model-id`); negative evidence — single model string, no array/fallback semantics documented.
2. OpenCode. "Config JSON Schema." *OpenCode Docs*, opencode.ai, 2026, https://opencode.ai/config.json. Archived: `knowledge/res029-model-fallback-semantics/sources/opencode-config-json.md`. **Relevance: High, Reliability: High.** Live published schema; `AgentConfig.model` is `"type": "string"` with `$ref` to the models.dev Model schema (lines 172-175) — authoritative contract that the native field is a single string, not an array.
3. OpenCode. "Plugins." *OpenCode Docs*, opencode.ai, 2026, https://opencode.ai/docs/plugins. Archived: `knowledge/res029-model-fallback-semantics/sources/opencode-docs-plugins.md`. **Relevance: Low, Reliability: High.** Context source only: documents the plugin/hook event surface (including `session.error`, `session.status`, `message.updated`) that OMO's foreground-fallback hook subscribes to; contains zero mentions of "model" or "fallback".

### In-repo runtime evidence (archived in-repo; cited by path)

4. oh-my-opencode-slim, `src/index.ts` — runtime chain construction (`modelArrayMap`/`runtimeChains` from `_modelArray`, lines 196-208); `ForegroundFallbackManager` wiring (lines 302-307); config-time first-entry model resolution with user-selection precedence (lines 510-545).
5. oh-my-opencode-slim, `src/agents/index.ts` — model-array storage as `_modelArray`, first entry written to `config.model`, stale value cleared (lines 147-163).
6. oh-my-opencode-slim, `src/hooks/foreground-fallback/index.ts` — auto-switch logic: mechanism doc (lines 4-10), rate-limit pattern list (lines 32-52), event handlers for `message.updated`/`session.error`/`session.status` (lines 157-207), chain walk + sticky-fallback + abort + `promptAsync` re-queue (lines 338-441).
7. oh-my-opencode-slim, `src/council/council-manager.ts` — `retry_on_empty` implementation in the council path only (lines 307-311, 411-414, 480-483).
8. res020 archive, `knowledge/res020-opencode-agent-config-watchdog/sources/opencode-config-schema.json` — `AgentConfig.model` string contract (lines 172-175), corroborating source 2.

### Unarchived / Excluded

None. The Phase A manifest records "NOT ARCHIVED: none" and "Excluded sources: none" — the local in-repo runtime code and the res020 archive were already archived in-repo and are referenced by path per the manifest's instruction (`.source-urls.txt`, lines 31-33).

---

## Cross-References

- `knowledge/model-registry.yaml` — gpt-5.3-codex row (lines 76-86): Copilot credits, skip guard, reviewer lane, no exclusivity constraint.
- `knowledge/res023-dispatch-routing-registry/res023-dispatch-routing-registry-conspect.md` — Copilot-credit skip-guard semantics (section 4); gpt-5.3-codex reviewer routing.
- `knowledge/res014-model-escalation-routing/res014-model-escalation-routing-conspect.md` — Rung 4 reviewer routing to gpt-5.3-codex.
- `knowledge/res020-opencode-agent-config-watchdog/` — prior capture of the OpenCode config schema (AgentConfig.model string contract).
- `knowledge/res021-opencode-agent-presets/res021-opencode-agent-presets-conspect.md` — cebula preset context (ai-specialist lane model assignment).
- DIA-099 — session-error signal taxonomy (signal D2 = session errors), the failure class the 2026-08-17 ai-specialist incidents exhibited.

---

## Confidence Assessment

| Claim | Confidence | Basis |
|---|---|---|
| Native `AgentConfig.model` is a single string, no native array fallback | **High** | Two independent captures of the official schema (sources 2, 8) + official agents docs (source 1); all agree |
| OMO model arrays are ordered fallback chains, first entry active at config time | **High** | Direct runtime code evidence (sources 4, 5) |
| Foreground fallback auto-switches on rate-limit/quota/error/session-status signals | **High** | Direct runtime code evidence (source 6); event surface corroborated by source 3 |
| `retry_on_empty` is council-only, not global | **High** | Direct runtime code evidence (source 7); no other implementation site found in the reviewed files |
| gpt-5.3-codex as second ai-specialist entry yields fallback for the 2026-08-17 failure class | **Medium-High** | Mechanism verified in code (source 6); the specific incident classification (DIA-099 signal D2) is taken from the research lane's ticket context, not re-verified here |
| Silent-empty-without-error may not trigger foreground fallback | **Medium** | Inference from the absence of an empty-response check in the foreground path (source 6) combined with the council-only `retry_on_empty` (source 7); not empirically tested in this conspect |

**Overall:** High for the native-contract and OMO-mechanism claims (code + schema evidence); Medium-High for the project-specific application, which depends on incident classification from the ticket context.