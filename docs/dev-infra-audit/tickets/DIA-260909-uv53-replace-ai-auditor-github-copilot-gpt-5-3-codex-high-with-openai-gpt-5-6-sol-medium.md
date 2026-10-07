# DIA-260909-uv53 - replace ai-auditor GitHub Copilot GPT-5.3 Codex High with OpenAI GPT-5.6 Sol Medium

---

id: DIA-260909-uv53
title: "replace ai-auditor GitHub Copilot GPT-5.3 Codex High with OpenAI GPT-5.6 Sol Medium"
area: config
severity: Medium
status: CLOSED
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-09-09
source: inventory
date: 2026-09-09
created: 2026-09-09
updated: 2026-09-10

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
evidence:

- ai-auditor re-review ses_f75d7474dffenOqH5Z4DEoUqo1: F5 verified-closed, F6 verified-closed, advisory GO
- test-config EXIT=0 post-fix, 61 PASS 0 FAIL
- developer restart + /models smoke openai/gpt-5.6-sol confirmed

---

## Description

<To be filled at creation time: what is wrong / what to build, with exact
files and line references where known.>

## Verification

- [x] make test-config EXIT=0 (coder ses_f787786f8ffeCeB3nfnQP1AONe; re-confirmed post-changelog EXIT=0 at register step)
- [x] ai-auditor independent review: GO-with-notes (ses_f7876869cffeIpqSNVB9U2YjIW)
- [x] CHANGELOG entry appended via scripts/changelog-add EXIT=0 (validate + render auto-ran, 1 passed 0 failed, 134 entries)
- [x] CLOSED: developer restart of OpenCode + /models smoke for openai/gpt-5.6-sol confirmed (see Closure section)

## Fix

Implemented in .opencode/oh-my-opencode-slim.jsonc ai-auditor block L840-846:

```diff
-          "github-copilot/gpt-5.3-codex",
+          "openai/gpt-5.6-sol",
            "github-copilot/gemini-3.1-pro-preview",
            "opencode/big-pickle"
-        "variant": "high",
+        "variant": "medium",
```

Fallbacks (gemini-3.1-pro-preview, big-pickle), skills (teaching), mcps
(websearch) unchanged. Gate learnings:
.opencode/learnings/external-patterns/2026-09-09-dia-260909-uv53-ai-auditor-sol-medium.md.

## Re-verify

- test-config EXIT=0 confirmed after fix and again after changelog append.
- ai-auditor review GO-with-notes; sole process gap: Step 5 restart +
  /models smoke not yet evidenced. Ticket stays OPEN pending developer
  restart + smoke resolving openai/gpt-5.6-sol with no fallback events.

## Follow-up (2026-09-10) - registry metadata fix, ai-specialist ses_f75dfc2f2ffeEkAsQjqVOjsbEs

- Verdict: GO-CONDITIONAL. jsonc ai-auditor block L840-846 already
  openai/gpt-5.6-sol variant medium - NOT re-edited per gate.
- Registry fix only: knowledge/model-registry.yaml Sol quota_notes
  corrected to direct OpenAI pricing short-context $4.00/$20.00 per 1M,
  over-272K long-context $8.00/$30.00 per 1M (2x in, 1.5x out);
  note added: gpt-5.6 is model alias, -medium is OMO variant not model ID.
- Evidence: developers.openai.com gpt-5.6-sol model page + pricing page,
  opencode.ai providers + models docs, GitHub Copilot supported-models +
  pricing docs. Gate learnings updated:
  .opencode/learnings/external-patterns/2026-09-09-dia-260909-uv53-ai-auditor-sol-medium.md
  (follow-up gate section).

## Restart / smoke checklist (developer, CONFIRMED)

- [x] Full OpenCode restart (preset reload, no hot-swap)
- [x] /models smoke: openai/gpt-5.6-sol resolves, non-empty response
- [x] No fallback events (gemini/big-pickle not hit), no 429/401

## F5-F6 fix loop (2026-09-10, ai-auditor ses_f75dbba1cfferxghSJ57kGQk8I)

- F5: make test-config re-run AFTER registry follow-up fix EXIT=0,
  61 PASS lines, 0 FAIL (decision-variants 337 passed 0 failed,
  grilling-gate 337 passed, plugin-structure all structural gates PASS).
  JSONC ai-auditor block untouched.
- CHANGELOG entry 136 verification field updated from manual to:
  test-config EXIT=0 post-registry-fix evidence (validate 1 passed
  0 failed, rendered 136 entries).

## Closure (2026-09-10, ai-auditor re-review ses_f75d7474dffenOqH5Z4DEoUqo1)

- Gate: ai-specialist GO-CONDITIONAL (ses_f75dfc2f2ffeEkAsQjqVOjsbEs) -
  jsonc block already correct, registry-only fix applied.
- Coder persist + F5-F6 fix: registry pricing corrected ($4/$20 short,
  $8/$30 over-272K, alias/variant note); learnings Outcome updated.
- test-config EXIT=0 post-fix, 61 PASS lines, 0 FAIL.
- CHANGELOG: 136 entries, entry 136 verification carries test-config evidence.
- Auditor re-review: F5 verified-closed, F6 verified-closed, advisory GO.
- Developer confirmed: OpenCode restart done + /models smoke for
  openai/gpt-5.6-sol (resolves, non-empty response, no fallback events).
- Ticket CLOSED via scripts/tickets close (see close status below).
