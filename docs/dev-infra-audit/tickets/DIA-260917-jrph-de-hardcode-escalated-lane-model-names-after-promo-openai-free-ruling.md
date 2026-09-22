# DIA-260917-jrph - de-hardcode escalated lane model names after promo openai-free ruling

---

id: DIA-260917-jrph
title: "de-hardcode escalated lane model names after promo openai-free ruling"
area: scripts
severity: Medium
status: DONE
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-09-17
source: inventory
date: 2026-09-17
created: 2026-09-17
updated: 2026-09-22

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

Escalated lane agent prompts hardcoded model names (analyzer-escalated:
GPT-5.6 Luna / opencode-go/gpt-5.6-luna; coder-escalated: GPT-5.6 Terra High /
openai/gpt-5.6-terra at high reasoning). After the promo openai-free ruling
these names must not be baked into the lane prompts; model selection belongs
to runtime config, not prompt text. Files:
.opencode/agents/analyzer-escalated.md, .opencode/agents/coder-escalated.md.

## Verification

- [x] Fix commit d9c20993 present in git log with subject
      "fix(agents): DIA-260917-jrph de-hardcode escalated lane model names"
      (verified 2026-09-22 via git log --all grep).
- [x] Commit touches only the two escalated lane prompts (git show --stat:
      2 files changed, 4 insertions, 4 deletions).
- [x] Frontmatter description lines no longer name models; Role paragraphs
      read "Stronger-model ... lane dispatched ONLY by the orchestrator" with no
      model identifier (verified via git show d9c20993 diff).
- [x] make test-config passes: 78 PASS, 0 FAIL, exit 0 (2026-09-22).
- [x] Escalated-lane subsets pass: routing-order-gate.test.mjs 36/36
      (covers coder-escalated), batch-d-infra.test.mjs 57/57 (covers
      analyzer-escalated edit scope), both exit 0 (2026-09-22).
- [ ] Residual hardcoded model mention cleared:
      .opencode/agents/analyzer-escalated.md line 23 still reads "GPT-5.6 Luna
      usage is budgeted" (observed 2026-09-22; out of scope for this backfill
      lane, needs owner decision: reword or keep as budget-policy text).

## Fix

> Commit d9c20993 (2026-09-17, "fix(agents): DIA-260917-jrph de-hardcode
> escalated lane model names"). Changed 2 files, 4 insertions, 4 deletions:
>
> - .opencode/agents/analyzer-escalated.md: frontmatter description dropped
>   "(GPT-5.6 Luna)"; Role paragraph dropped "(opencode-go/gpt-5.6-luna)".
> - .opencode/agents/coder-escalated.md: frontmatter description dropped
>   "(GPT-5.6 Terra High)"; Role paragraph dropped
>   "(openai/gpt-5.6-terra at high reasoning)".
>   No runtime or config change; prompt text only.

## Re-verify

> 2026-09-22 landing verification (backfill lane, code already fixed at
> d9c20993):
>
> - make test-config: exit 0, 78 PASS lines, 0 FAIL lines.
> - node --test scripts/**tests**/routing-order-gate.test.mjs: exit 0,
>   36 pass / 0 fail (includes coder-escalated detection case).
> - node --test scripts/**tests**/batch-d-infra.test.mjs: exit 0,
>   57 pass / 0 fail (includes analyzer-escalated edit-scope case).
>   Residual noted: analyzer-escalated.md line 23 still mentions "GPT-5.6
>   Luna"; left unticked above pending owner decision. Status stays OPEN per
>   lane scope.

## Close

> 2026-09-22 bounded close lane (developer approved closure after line-23
> fix): backfill commit c1ad782 in log (d9c20993 confirmed, test-config
> 78 PASS, routing-order 36/36, batch-d 57/57) and fix commit deda3db in
> log (analyzer-escalated.md line 23 reworded model-neutral, grep clean
> for gpt-5.6/luna/terra in both escalated prompts, test-config exit 0).
> Status set DONE.
