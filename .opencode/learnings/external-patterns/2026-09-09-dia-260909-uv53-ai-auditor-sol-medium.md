# ai-auditor Sol medium gate findings - DIA-260909-uv53 (2026-09-09)

Ticket: DIA-260909-uv53
Date: 2026-09-09
Gate: ai-specialist, AGENTS.md 2.5 step 1, docs only, no config edit.
Source: ai--1 / ses_f787c469cffe3N9O39kwh1uCIS
Scope: read-only verification. No edits to .opencode/oh-my-opencode-slim.jsonc or any config.

## Gate verdict

GO conditional on post-restart model-picker smoke test.

The proposed ai-auditor retarget (Sol primary, variant medium, fallbacks kept)
is approved to proceed to coder implementation. The condition is a live
post-restart smoke check that the model picker resolves the new primary
(openai/gpt-5.6-sol) without fallback events before Phase 6 review closes
the ticket.

## Current vs proposed snippet

File: .opencode/oh-my-opencode-slim.jsonc, ai-auditor block L840-853.

Current (verified 2026-09-09, read-only):

```jsonc
"ai-auditor": {
  "model": [
    "github-copilot/gpt-5.3-codex",
    "github-copilot/gemini-3.1-pro-preview",
    "opencode/big-pickle"
  ],
  "variant": "high",
  "skills": [
    "teaching"
  ],
  "mcps": [
    "websearch"
  ]
},
```

Proposed (for coder lane, NOT applied in this gate):

```jsonc
"ai-auditor": {
  "model": [
    "openai/gpt-5.6-sol",
    "github-copilot/gemini-3.1-pro-preview",
    "opencode/big-pickle"
  ],
  "variant": "medium",
  "skills": [
    "teaching"
  ],
  "mcps": [
    "websearch"
  ]
},
```

Delta: primary github-copilot/gpt-5.3-codex -> openai/gpt-5.6-sol;
variant high -> medium. Gemini + big-pickle fallback order unchanged.
Skills (teaching) and mcps (websearch) unchanged.

## Evidence

- OpenAI gpt-5.6-sol model page: documents Sol as agentic coding model with
  medium reasoning effort as the default operating point.
  URL: https://openai.com/index/introducing-gpt-5-6-sol (see also platform
  model card for gpt-5.6-sol reasoning-effort guidance).
- opencode.ai model catalog: openai/gpt-5.6-sol listed as available model ID.
  URL: https://opencode.ai/docs/providers/openai (catalog entry).
- opencode docs/models: reasoning variant (low/medium/high) selects the
  effort level passed to the provider; medium is the cost/latency balance.
  URL: https://opencode.ai/docs/models
- opencode docs/agents: per-agent model list is tried in order; first entry
  is primary, later entries are fallbacks.
  URL: https://opencode.ai/docs/agents
- Existing Terra precedent in this repo (same preset family pattern):
  .opencode/oh-my-opencode-slim.jsonc L731-732 (openspec-plan),
  L765-768 (reviewer), L826-831 (ai-specialist) - primary-first with
  qwen/flash fallbacks kept. Sol change follows the same shape.
- Prior gate record: 2026-09-09-dia-260909-18f4-terra-routing-gate-findings.md
  (Terra Variant A gated rollout precedent).

## Risks

1. Cost: Sol priced approx $4 input / $20 output per 1M tokens, plus provider
   surcharge above ~272K context. Long audit sessions can get expensive.
   Mitigation: medium (not high) variant; keep audit scope bounded.
2. Family overlap: Terra and Sol are the same flagship reasoning family, so
   routing both reviewer/analyzer (Terra) and ai-auditor (Sol) to it
   concentrates provider risk. Mitigation: gemini fallback kept in second
   position, so a Sol 429/quota event degrades instead of failing the lane.
3. Registry gap: knowledge/model-registry.yaml L80-90 has no Sol entry
   (Terra entry was added under DIA-133; Sol was not). Coder must add a Sol
   entry or the drift check will flag the new model ID.
4. Fallback variant semantics: the OMO fallback chain has no per-fallback
   variants - the single "variant": "medium" applies to whichever model
   answers, including gemini and big-pickle fallbacks. Accepted: medium is
   a safe middle for all three; no per-model tuning available.

## Next gates (in order)

1. Coder: apply the snippet delta (primary + variant only), add Sol registry
   entry per DIA-133, keep fallbacks/skills/mcps untouched.
2. test-config: make test-config must pass (agent-names, decision-variants,
   changelog, drift/registry checks).
3. Restart: full OpenCode restart so the preset reloads (no hot-swap).
4. /models smoke: post-restart model-picker smoke test - resolve
   openai/gpt-5.6-sol, confirm non-empty response, no fallback events,
   no 429/401. This is the GO condition from this gate.
5. Phase 6 review: ai-auditor independent review of the implemented change
   per AGENTS.md 2.5 step 6, then CHANGELOG entry.

## Follow-up gate - registry metadata fix (2026-09-10, ai-specialist ses_f75dfc2f2ffeEkAsQjqVOjsbEs)

Verdict: GO-CONDITIONAL. .opencode/oh-my-opencode-slim.jsonc:840-846
already openai/gpt-5.6-sol variant medium - DO NOT re-edit that block.
Registry-only fix: knowledge/model-registry.yaml:92-102 Sol quota_notes
corrected from stale ">272K-tier $4/$20" to direct OpenAI pricing.

Sources:

- OpenAI gpt-5.6-sol model page: Sol agentic coding model, medium default.
  URL: https://developers.openai.com/api/docs/models/gpt-5.6-sol
- OpenAI migration guide / model card: gpt-5.6 alias, reasoning-effort
  guidance (medium default operating point).
  URL: https://developers.openai.com/api/docs/models
- OpenAI pricing page: gpt-5.6-sol short-context $4.00 in / $20.00 out
  per 1M; long-context (prompts >272K input tokens) $8.00 in / $30.00
  out per 1M (2x input, 1.5x output for full request).
  URL: https://developers.openai.com/api/docs/pricing
- opencode.ai providers: openai provider via AI SDK / Models.dev, /connect
  then /models picker.
  URL: https://opencode.ai/docs/providers/
- opencode.ai models: reasoning variants none/minimal/low/medium/high/
  xhigh select effort passed to provider; medium is cost/latency balance.
  URL: https://opencode.ai/docs/models
- GitHub Copilot supported models + pricing context: prior ai-auditor
  primary github-copilot/gpt-5.3-codex replaced; gemini-3.1-pro-preview
  kept as second-position fallback.
  URLs: https://docs.github.com/copilot/concepts/model-config/supported-models
  and https://docs.github.com/copilot/how-tos/model-config/use-policy-for-extra-models

Corrections applied:

- quota_notes now reads direct OpenAI short-context pricing plus
  over-272K long-context tier (was: stale single-tier note).
- Note added: gpt-5.6 is a model alias; -medium is an OMO variant
  (reasoning effort), not part of the model ID.

## Outcome (2026-09-09 register + 2026-09-10 follow-up, ai-auditor ses_f75dbba1cfferxghSJ57kGQk8I F5-F6)

- IMPLEMENTED: coder applied the snippet delta
  (.opencode/oh-my-opencode-slim.jsonc ai-auditor L840-846, primary
  github-copilot/gpt-5.3-codex -> openai/gpt-5.6-sol, variant high ->
  medium). make test-config EXIT=0 (coder ses_f787786f8ffeCeB3nfnQP1AONe,
  re-confirmed post-changelog EXIT=0).
- REVIEWED: ai-auditor independent review GO-with-notes
  (ses_f7876869cffeIpqSNVB9U2YjIW).
- REGISTERED: CHANGELOG entry appended via scripts/changelog-add EXIT=0
  (validate 1 passed 0 failed, rendered 134 entries); ticket Fix +
  Verification + Re-verify blocks updated.
- FOLLOW-UP CORRECTION (2026-09-10, ai-specialist ses_f75dfc2f2ffeEkAsQjqVOjsbEs):
  knowledge/model-registry.yaml Sol quota_notes fixed from stale
  ">272K-tier $4/$20" to direct OpenAI pricing - short-context $4.00 in /
  $20.00 out per 1M, over-272K long-context $8.00 in / $30.00 out per 1M
  (2x input, 1.5x output for full request); note added that gpt-5.6 is a
  model alias and -medium is an OMO reasoning-effort variant, not part of
  the model ID. JSONC ai-auditor block untouched (already correct).
- POST-FIX VALIDATION (2026-09-10, F5): make test-config re-run AFTER the
  registry fix EXIT=0, 61 PASS lines, 0 FAIL (decision-variants 337
  passed, grilling-gate 337 passed, plugin-structure all gates PASS).
  CHANGELOG entry 136 verification field updated from manual to this
  test-config evidence.
- CLOSED 2026-09-10: developer OpenCode restart done + /models smoke for
  openai/gpt-5.6-sol (resolves, non-empty response, no fallback events)
  per ticket Closure evidence. Auditor re-review advisory GO
  (ses_f75d7474dffenOqH5Z4DEoUqo1). No pending items.
