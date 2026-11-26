---
title: deepseek-v4.1-flash naming gate (DIA-260827-bry9)
date: 2026-09-17
ticket: DIA-260827-bry9
source: ai--2 / ses_f50cbc402ffeOszTVkFMwb68AO (read-only, AGENTS.md 2.5 step 1)
verdict: GO with corrected provider prefix
---

## Catalog verdict (2026-09-17)
- deepseek-v4.1-flash is Go-exclusive as of 2026-09-17.
- Present in live zen/go JSON catalog and Go docs model table row.
- Absent from zen/v1 JSON catalog and Zen docs model table.
- Do not bind it under zen; zen binding would be a phantom id.

## Required form
- Use opencode-go/deepseek-v4.1-flash in config model refs.
- Go-docs verbatim rule: config model id is provider_id/model_id.
- Zen-docs counterpart: config model id is provider_id/model_id (same rule, other provider).
- Models-docs citation: provider/model join is the documented reference form.

## Slash explanation
- The slash is a runtime join echo of provider_id + model_id.
- No literal slash is stored as a separate config field.
- Config carries the joined string only; runtime splits it back.

## Corrected bindings
- .opencode/oh-my-opencode-slim.jsonc line 34 -> opencode-go/deepseek-v4.1-flash
- .opencode/oh-my-opencode-slim.jsonc line 153 -> opencode-go/deepseek-v4.1-flash
- .opencode/oh-my-opencode-slim.jsonc line 166 -> opencode-go/deepseek-v4.1-flash
- .opencode/oh-my-opencode-slim.jsonc line 226 -> opencode-go/deepseek-v4.1-flash

## Flags (out of scope for this gate)
- Line 241 bare qwen3.8-flash without provider prefix is out of scope; separate lane.
- knowledge/model-registry.yaml needs a new v4.1 entry; registry work is implementer-side.

## Developer evidence credit
- Developer supplied the live Zen Go models endpoint evidence confirming Go-exclusive listing.

## Outcome
- TODO-pending-implementation: @coder config-work on model bindings is unblocked and pending.
- DONE (commit 98d6fae, test-config 78 PASS/0 FAIL, ai-auditor approve-with-notes, residual risks R1-R5 tracked separately).
