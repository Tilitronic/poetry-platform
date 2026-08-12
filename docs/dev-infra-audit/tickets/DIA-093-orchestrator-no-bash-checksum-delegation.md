# DIA-093 — Orchestrator boot: "I have no bash tool" - DIA-061 checksum not delegated to coder lane

<!-- Campaign c-20260809-residual-closure, session 6. Filed by the first bash
     lane (coder) post-restart, per the developer directive 2026-08-11: the
     orchestrator MUST delegate bash-requiring tasks to coder; resolve once and
     for all for future sessions. Related tickets: DIA-091 (no-bash recurring
     symptom), DIA-061 (handoff checksum mechanism), DIA-075 (checksum
     mismatch class), DIA-063 (batch-approval boot gate / ticket-creation gate).
     Status: OPEN, in-progress (fixes A+E+F implemented + validated 2026-08-11;
     ai-auditor conditional-pass; follow-ups F-1/F-2/F-4 closed; S10-P6
     registration COMPLETE). Restart pending - config live next boot. -->

---

id: DIA-093
title: "Orchestrator boot: 'I have no bash tool' - DIA-061 checksum not delegated to coder lane"
area: opencode-config
severity: Major
status: OPEN
blocked_by: [] # cross-referenced in Description: DIA-091, DIA-061, DIA-075, DIA-063
discovered: 2026-08-11
source: developer-directive
date: 2026-08-11
created: 2026-08-11
updated: 2026-08-11

# --- Session Attribution (v2 schema, optional) ---

session_id: "ses_0100c357effew8ZdYABe1mfRCp"
lane_id: "coder"
agent: "coder"
model: "deepseek-v4-flash"
parent_session_id: ""
attempts: 0
lease_expires_at: ""
files_touched: ["docs/dev-infra-audit/tickets/DIA-093-orchestrator-no-bash-checksum-delegation.md", "docs/dev-infra-audit/tickets/README.md"]
artifacts: []
evidence: ["DIA-091 (no-bash recurring symptom)", "DIA-061 (handoff checksum stays null)", "session 5 developer waiver (DIA-091 pattern)", "session 6 waiver-vs-delegate question repeated", "coder lane computed DIA-061 checksum 2026-08-11: 3125e45855dcb8bac07179e59b87a99600baaf7b4b28c3ea8638c35005ebb311"]

---

## Description

**Summary:** at the start of every session the orchestrator claims it has no
bash tool, so the mandatory DIA-061 handoff checksum stays null in
`.opencode/session/current-handoff.json`. Session 5 used a developer waiver
(DIA-091 pattern); session 6 repeated the waiver-vs-delegate question instead
of auto-delegating to a coder lane. The batch-approval boot gate forbids
delegation before approval, creating a deadlock at the exact step that needs a
bash lane.

**Status:** OPEN, in-progress - fixes A+E+F IMPLEMENTED + VALIDATED (Phase 4
COMPLETE + Phase 5 validation 2026-08-11, `make test-config` exit 0);
root-cause analysis complete (5-Whys); ai-auditor conditional-pass received,
follow-ups F-1/F-2/F-4 closed; S10-P6 registration COMPLETE 2026-08-11;
restart pending (config live next boot).

**Context from this session (evidence the fix works):** the first bash lane
post-restart (this coder lane) computed the DIA-061 canonical checksum of
`.opencode/session/current-handoff.json` on 2026-08-11:
`3125e45855dcb8bac07179e59b87a99600baaf7b4b28c3ea8638c35005ebb311`.
The mechanism the orchestrator claims it cannot perform is trivially
delegable to a bash lane.

### Problem

- At the start of every session the orchestrator claims it has no bash tool,
  so the mandatory DIA-061 handoff checksum stays null.
- Session 5 used a developer waiver (DIA-091 pattern); session 6 repeated the
  waiver-vs-delegate question instead of auto-delegating to a coder lane.
- The batch-approval boot gate forbids delegation before approval, creating a
  deadlock at the exact step that needs a bash lane.

### Developer directive (2026-08-11)

The orchestrator MUST delegate such tasks to coder; resolve once and for all
for future sessions.

### Related tickets

- **DIA-091** — orchestrator no-bash recurring symptom (waiver pattern).
- **DIA-061** — handoff checksum mechanism (stays null because no bash lane
  computes it).
- **DIA-075** — checksum-mismatch class (snip jq wrapper; adjacent failure
  mode of the same checksum mechanism).
- **DIA-063** — batch-approval boot gate / ticket-creation gate (gate forbids
  delegation before approval, deadlocking this step).
- **DIA-092** - snip@1.6.1 plugin removal (root cause of the DIA-075/DIA-078
  bash-lane mechanical lock; its removal unblocked all bash lanes. This
  ticket tracks the standing checksum-delegation rules, which are
  independent scope and remain OPEN. Cross-reference only: 092 is the
  root-cause fix for the snip lock class, not for the delegation rules).

## Verification

- Phase 5 validation (2026-08-11): `make test-config` exit 0.
- `current-handoff.json` checksum field set to
  `3125e45855dcb8bac07179e59b87a99600baaf7b4b28c3ea8638c35005ebb311`; canonical
  command re-run after the write still yields the same hash (only `.prognosis` is
  hashed, so setting the field does not change the hash).
- Restart PENDING: config takes effect next boot (no restart performed per
  instruction).

## Fix

Implemented per developer directive 2026-08-11 as fixes A+E+F (design from
analyzer root-cause analysis, session 6):

- **Root cause (5-Whys):** opencode.jsonc:74 bash deny (orchestrator has no bash
  tool by design) -> stale prompt text (orchestrator prompts still demanded a
  direct bash checksum pipeline) -> boot-gate deadlock (orchestrator_append.md:221
  forbids delegation before approval, so the checksum step could never run) ->
  exit gap (NEXT-RUN.md 7.2 wrote `checksum: null` with no delegated compute path).
- **FIX A (boot gate):** orchestrator_append.md + NEXT-RUN.md section 7.3 -
  missing/invalid checksum no longer blocks presentation; lane-0 coder delegation
  computes the DIA-061 checksum immediately after batch approval (no waiver menu).
- **FIX E (exit protocol):** orchestrator_append.md + NEXT-RUN.md section 7.2 - a
  coder lane computes the checksum before the handoff write; `checksum: null` only
  on crisis/crash exits, with resume_instructions flagging lane-0 requirement.
- **FIX F (stale prompt removal):** 3 orchestrator prompts (opencode-go / cebula /
  free presets in .opencode/oh-my-opencode-slim.jsonc) - stale checksum-pipeline
  text replaced with delegated DIA-061 wording.

**Clarification (2026-08-12, DIA-120 fix):** the handoff file
(`.opencode/session/current-handoff.json`) MUST be written solely via
`log_decision(event_type: 'handoff', ..., prognosis: JSON.stringify(prognosisObject))`
— the delegation-observer plugin's atomic write computes and stores the `checksum`
field automatically. Manual write/edit tools MUST NOT be used for handoff files
(no `checksum: null` placeholders, no post-write checksum-field edits — the DIA-093
"write the lane-returned checksum into the field" instruction is superseded and
conflicts with plugin-written handoffs, DIA-120 secondary finding 2). Lane-0 checksum
delegation is VERIFICATION-ONLY: the coder lane recomputes the DIA-061 canonical SHA256
and compares it against the stored value (re-read at comparison time, DIA-120 secondary
finding 1) — the lane never writes the file.

## Implementation status

- Filed 2026-08-11 (session 6, first bash lane post-restart).
- Root-cause analysis complete: analyzer lane 5-Whys (opencode.jsonc:74 bash deny;
  stale prompt text; boot-gate deadlock orchestrator_append.md:221; exit gap
  NEXT-RUN.md 7.2).
- **Phase 4 COMPLETE 2026-08-11 (fixes A+E+F applied).** Files edited:
  - `.opencode/oh-my-opencode-slim.jsonc` (FIX F - 3 orchestrator prompts)
  - `.opencode/oh-my-opencode-slim/orchestrator_append.md` (FIX A boot gate +
    FIX E exit protocol)
  - `docs/dev-infra-audit/NEXT-RUN.md` (FIX A section 7.3 + FIX E section 7.2)
  - `docs/dev-infra-audit/tickets/DIA-093-orchestrator-no-bash-checksum-delegation.md`
    (this ticket)
  - `.opencode/session/current-handoff.json` (checksum field set)
- **Phase 5 validation:** `make test-config` exit 0; restart PENDING - config
  live next boot (no restart performed by instruction).
- **ai-auditor review:** conditional-pass received 2026-08-11; follow-ups
  F-1/F-2/F-4 closed.
- **Phase 6 (S10-P6 registration):** COMPLETE 2026-08-11 - CHANGELOG entry
  added in `.opencode/CHANGELOG.md` + learnings registered in
  `.opencode/learnings/external-patterns/2026-08-11-dia093-checksum-delegation-fix.md`.

## Re-verify

- PENDING restart: on next boot confirm lane-0 checksum delegation runs
  automatically (no waiver menu), missing checksum does not block presentation,
  and `checksum: null` is never written except crisis/crash exits.
