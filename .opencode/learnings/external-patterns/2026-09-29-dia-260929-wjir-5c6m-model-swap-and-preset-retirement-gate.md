# 2026-09-29 - DIA-260929-wjir / DIA-260929-5c6m section-2.5 gate findings

Scope: combined config change to .opencode/oh-my-opencode-slim.jsonc +
knowledge/model-registry.yaml + scripts/promo-preset-apply + 3 test files.

## Findings

1. Presets in oh-my-opencode-slim.jsonc: promo-union-alpha (L20),
   mimo-balanced (L263, active pointer L3), free (L507),
   openai-first-cost-balanced (L738). Only the jsonc is a config file in the
   change set; the other surfaced files are non-config (registry, script, tests).

2. Swap targets confirmed:
   - architector mimo-balanced L283-284 ["opencode-go/kimi-k3",
     "opencode-go/mimo-v2.6-flash"], variant high L286.
   - ai-auditor mimo-balanced L414-415 ["opencode-go/kimi-k3",
     "opencode-go/deepseek-v4-flash"], variant medium L417.
   - analyzer mimo-balanced L354-355 ["opencode-go/qwen3.8-flash",
     "opencode-go/deepseek-v4-flash"], variant high L357.
   - grok-4.7 appears nowhere in-repo except the ticket title/README; it is a
     real Go model (model id grok-4.7, endpoint /v1/responses, @ai-sdk/openai;
     opencode.ai/docs/go, fetched 2026-09-29).

3. Analyzer variant is already "high" (L357) - model-array-only change confirmed.

4. R6 preset scope: only promo-union-alpha and mimo-balanced reference
   kimi-k3/qwen3.8-flash/deepseek-v4.1-flash. openai-first-cost-balanced is
   documented strict-OpenAI-only at oh-my-opencode-slim.jsonc:736-737,
   .opencode/memory/adr.md:2138-2160 (ADR 2138), and jsonc:14.
   Recommendation: Reading B (lane-scoped, active preset only); reject the
   occurrence-scoped read (over-reaches into reviewer/designer/analyzer-escalated
   and into promo-union-alpha, which 5c6m deletes).

5. "free" is load-bearing: scripts/promo-preset-apply:212-218 uses
   find_preset_block(raw,"free") as the insert anchor and returns 2 without it.
   Because the config key is promo-union-alpha, find_preset_block(text,"promo")
   (L113) never matches, so the insert path is the only path the generator can
   take today. promo-review/SKILL.md:134-135 documents "re-run it" (the insert
   logic is not in the skill, contrary to the earlier claim); SKILL.md:55 also
   names the stale "promo" preset.

6. Three test files hardcode the free preset key:
   preset-model-guard.dia260918-t5.test.mjs:81/84/96;
   preset-single-path.bats:28/31/55/60;
   workspace-preset-selection.bats:17/20/28/30.

7. No preset key named "promo" exists in the tree; the generator targets
   "promo". Cross-ref DIA-260918-mm2u (OPEN) confirms the stale target and the
   overcapture concern. promo-registry.json:5,10,24 still carry value "promo".

8. options.thinking (jsonc:296-301) on the @ai-sdk/openai responses transport for
   Grok 4.7: runtime accept/ignore/error UNVERIFIED - needs a live probe. Same
   shape already ships on the OpenAI transport at jsonc:779 (openai-first
   architector), so no novel shape is introduced.

9. Hazards: both campaign tickets have placeholder-only bodies (no scope, no
   acceptance criteria); stale comments at jsonc:14, check-orchestrator-prompt-drift.sh:56-60,
   check-orchestrator-prompt-drift.bats:9-11, model-registry.yaml:23/99/152-162;
   model-registry.yaml has no grok-4.7 entry and must gain one (live Go pricing
   $2.00/$6.00 <=200K, $4.00/$12.00 >200K, $15 bucket, 845 req/mo).

## Sources

- .opencode/oh-my-opencode-slim.jsonc (L3, 14, 20, 263, 283-286, 296-301,
  354-357, 414-417, 507, 736-738, 779)
- knowledge/model-registry.yaml (L16-26, 92-102, 116-126, 152-162)
- scripts/promo-preset-apply (L113, 173, 212-218)
- .opencode/skills/promo-review/SKILL.md (L55, 134-135)
- .opencode/plugins/__tests__/preset-model-guard.dia260918-t5.test.mjs (L81,84,96)
- scripts/__tests__/preset-single-path.bats (L28,31,55,60)
- scripts/__tests__/workspace-preset-selection.bats (L17,20,28,30)
- scripts/__tests__/check-orchestrator-prompt-drift.bats (L9-11); scripts/check-orchestrator-prompt-drift.sh (L56-61)
- docs/dev-infra-audit/tickets/DIA-260918-mm2u-...md (L39-47)
- docs/dev-infra-audit/tickets/DIA-260929-wjir-...md (title); DIA-260929-5c6m-...md (title)
- .opencode/memory/adr.md (L2138-2160)
- knowledge/ana-260929-inpt-ai-specialist-versus-ai-auditor/...-report.md (sec 4, 6)
- https://opencode.ai/docs/go/ (fetched 2026-09-29)
- https://models.dev/model/opencode-go/grok-4.7 (fetched 2026-09-29; xai/grok-4.7 listed)

Outcome: PENDING

## In-session gate rerun (2026-09-29)

In-session rerun of the section 2.5 Phase 1 gate for DIA-260929-wjir + DIA-260929-5c6m (working tree applied, uncommitted). Verified against the current tree. Preset inventory is now exactly two, mimo-balanced (jsonc:15, active pointer :3) and openai-first-cost-balanced (jsonc:261): the deleted promo-union-alpha and free presets are gone and are positively rejected (preset-single-path.bats:40-45; workspace-preset-selection.bats:29-34). The four prior corrections are SUPPORTED: (1) grok-4.7 is registered at knowledge/model-registry.yaml:164-174 and referenced at jsonc:35/:166 - the old "absent from the registry" claim is obsolete, and the live probe (.scratch/models-probe-wjir.txt:762-862: 500K ctx, $2/$6 <=200K, $4/$12 >200K, reasoning+toolcall) reproduces the entry; (2) the free-anchor citation (:212-218 with the "promo" target at :113) cannot resolve in the now 50-line no-op scripts/promo-preset-apply (L1-50) but is carried verbatim by the governing tickets (DIA-260929-5c6m:46-48; DIA-260918-mm2u:40); (3) the record's line numbers are stale and the current anchors are jsonc architector :34-38, analyzer :105-109, ai-auditor :164-169, openai-first architector options :302; (4) the "R6 preset scope" framing is a category error - R6 is either DIA-087's inline-override removal (learnings/2026-08-11-dia087-agent-model-variant-audit.md:20) or DIA-260901-s4ij's DO-NOT-TOUCH list (learnings/2026-09-01-hy3-deepseek-v4-flash-preset-swap.md:27), while the actual scope reading is the ticket's own LANE-SCOPED decision (DIA-260929-wjir:76-80); occurrence-scope is moot for openai-first-cost-balanced (zero occurrences, jsonc:261-326). No contradiction found among jsonc, model-registry.yaml, scripts/promo-preset-apply, and the three touched tests; VERDICT GO-WITH-CONDITIONS. Conditions: (C1) Phase 5 restart+smoke and Phase 6 independent ai-auditor review before commit - this rerun clears only the Phase 1 routing gate; (C2) ai-auditor failover independence: jsonc:167 keeps the fallback on the ai-specialist family (opencode-go/deepseek-v4-flash) while registry:173 claims separation "retained" and adr.md:2487-2490/:2503-2505 required a third-family fallback or a recorded carve-out - record the carve-out or switch the fallback; (C3) confirm make test-config exits 0 (captured log is all-green: drift gate ok at .scratch/test-config-wjir.log:533, plugin-structure PASS at :1274, no FAIL). Also confirm at restart the grok-4.7 architector options.thinking shape (jsonc:48-53) is accepted on the ai-sdk/openai transport (bounded: identical shape ships at jsonc:302). Residuals routed out of scope: promo-registry.json:5/:10/:24/:73-87 still point at "promo"/union-alpha (tracked by DIA-260918-rbqk, DIA-260918-mm2u) and adr.md:2142 still names the pointer "promo" (tracked by DIA-260918-ubxv). No opencode-best-practices.md rule is violated.

Verdict: GO-WITH-CONDITIONS
Outcome: PENDING
