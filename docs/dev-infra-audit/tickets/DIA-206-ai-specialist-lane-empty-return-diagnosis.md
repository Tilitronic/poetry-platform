# DIA-206 - ai-specialist lane systemic empty-return failure

<!-- Copy this template to a new file `DIA-<NNN>-<human-slug>.md` (bare
     `DIA-<NNN>.md` names are deprecated per DIA-110) and replace placeholders.
     Keep the YAML frontmatter block intact. Statuses VALIDATE and E2E (added
     2026-08-04, ticket-vocabulary drift fix) are audit-phase statuses - used
     while the gate-matrix validation / Docker+browser end-to-end runs are
     pending or in progress; they transition to fix-lane states via Fix ->
     Re-verify. -->
<!-- GRANDFATHERED: DIA-001 through DIA-049 use v1 schema (no session fields).
     Session-attribution fields are OPTIONAL for all tickets. New tickets SHOULD
     populate them; existing tickets are not retroactively updated. -->

---

id: DIA-206
title: "ai-specialist lane systemic empty-return failure"
area: opencode-config
severity: Major
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: "" # optional DIA-NNN parent epic ticket (DIA-125 keep-local extension; scripts/tickets emits this field always)

# DIA-104 grilling-gate markers (ai--7 validated design): fill at creation time

# with the defaults below (absent = legacy/skipped, grandfather precedent).

gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: fix-lane
source: fix-lane
date: 2026-08-17
created: 2026-08-17
updated: 2026-08-17

# --- Session Attribution (v2 schema, optional - GRANDFATHERED for DIA-001..049) ---

session_id: "ses_ff1484b67ffemi5N1IjJ7t3bj8" # OpenCode session ID that owned this ticket
lane_id: "ai--3" # e.g. cod-1, ai--3
agent: "ai-specialist" # agent name (coder, reviewer, etc.)
model: "" # model ID used
parent_session_id: "ses_ff0fa6381ffeuBEQAQ7LO1yhR1" # orchestrator's session ID (populated via get-my-session-id tool)
attempts: 5 # how many delegations attempted (total empty-return incidents observed)
lease_expires_at: "" # ISO-8601; set on DISPATCHED, cleared on COMPLETE
files_touched: [] # list of file paths modified
artifacts: [] # list of artifact references (commits, test outputs)
evidence:

- ".opencode/session/partial-results/ses_ff0d1c373ffeSU5j05iI6xhEkC.json (P1 schema per DIA-099; coder empty-return 2026-08-17)"
- ".opencode/session/partial-results/ses_ff0c44443ffeafSwm0X2Q6OqXW.json (P1 schema per DIA-099; researcher empty-return 2026-08-17)"

---

## Description

The ai-specialist lane returned EMPTY results 3 times in a row (3x empty
session-return) during session ses_ff1484b67ffemi5N1IjJ7t3bj8 (2026-08-17),
while working in the DIA-194 CHANGELOG conversion context. Each delegation
completed without producing any usable output, so the orchestrator routed the
ai-specialist work to a @coder substitute instead (the workaround that
unblocked the session). Partial results from the 3 failed ai-specialist
sessions were preserved in `.opencode/session/partial-results/` (P1 schema per
DIA-099). A lesson was recorded: L20260817-006 in
`.opencode/memory/lessons.md` ("Designated lane failing EMPTY 3x
(session-return failure): route the research to a substitute lane instead of
looping").

2026-08-17 update: 5 total empty returns observed in the 2026-08-17 window
across deepseek-v4-flash AND qwen3.7-plus lanes (ai-specialist x3, coder x1,
researcher x1) - the pattern is systemic across lanes, NOT ai-specialist-
specific. This strengthens the systemic provider/endpoint hypothesis (see
Verification step 2 for the two additional incidents).

Why it matters: ai-specialist is the MANDATORY Phase-1 gate for ALL
section-2.5 AI-devtools config work per AGENTS.md section 2.5 (the
AI Devtools Modernization Workflow). A lane that silently returns empty blocks
the entire modernization workflow: the orchestrator cannot get the required
read-only research findings, and every config change (including deferred
tickets DIA-183 and the DIA-194 CHANGELOG conversion) stalls at the gate. The
3x repetition indicates a systemic lane failure rather than a one-off
transient, so a diagnosis ticket is warranted per the session summary's
recommendation.

## Verification

How to reproduce/confirm the defect:

1. Dispatch ai-specialist on a minimal test task (e.g. "read
   `.opencode/opencode.jsonc` and report the agent block keys") and observe
   whether the lane returns an empty result.
2. Inspect `.opencode/session/partial-results/` for the 3 preserved
   partial-result JSON files from the failed ai-specialist sessions (P1 schema
   per DIA-099; files are named `<session-id>.json`). NOTE (2026-08-17): two
   MORE empty-return incidents were discovered in the same window, showing the
   pattern is NOT ai-specialist-specific but systemic across lanes:
   a) cod-2 ses_ff0d1c373ffeSU5j05iI6xhEkC (coder lane, DIA-206 evidence-
   gather) - read files then returned EMPTY; partial preserved at
   `.opencode/session/partial-results/ses_ff0d1c373ffeSU5j05iI6xhEkC.json`
   (D1 signal: session_complete + no task_success).
   b) res-1 ses_ff0c44443ffeafSwm0X2Q6OqXW (researcher lane, res030) -
   archived 4 of 5 sources then returned EMPTY; partial preserved at
   `.opencode/session/partial-results/ses_ff0c44443ffeafSwm0X2Q6OqXW.json`
   (D1 signal); resumed successfully by cod-3 resume lane (DIA-099 Variant
   A2, verify-first, completed the research).
3. Check `.opencode/session/registry.jsonl` for the 3 failed sessions' rows
   and classify their detection signals per DIA-099: D1 (session_complete +
   no task_success + no file edits + short duration, ~80% SILENT_FAILURE
   candidate), D2 (session_failed with MAXIMUM STEPS, ~95% CRASH/STEP_CAP),
   D5 (stall_detected with no terminal, ~90% STALLED). Note: registry
   signatures alone cannot discriminate silent failure from a reporting
   artifact - ground-truth verification (re-dispatch and observe) is
   mandatory.
4. Confirm the lesson entry L20260817-006 exists in
   `.opencode/memory/lessons.md`.

## Fix

<What changed - fill at fix time. Leave blank with this note until then.>

> To be filled at fix time.

## Re-verify

<Result of re-running Verification after the fix - fill at re-verify time.
Must include the actual gate output/exit code that proves VERIFIED.>

> To be filled at re-verify time.
