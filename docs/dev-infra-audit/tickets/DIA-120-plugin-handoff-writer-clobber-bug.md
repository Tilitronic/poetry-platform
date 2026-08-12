# DIA-120 - delegation-observer handoff-writer clobbers valid handoff on in-flight log_decision - false checksum mismatch escalation

<!-- Filed from a read-only investigation (2026-08-12) into a DIA-061 handoff
     checksum "mismatch" escalation at the S18 batch-approval boot gate. Root
     cause found: the delegation-observer plugin handoff-writer fires on ANY
     log_decision with event_type 'handoff' and a non-empty prognosis string,
     including non-terminal status events (resolution_status 'in-flight').
     During the S18 boot gate the orchestrator's boot-gate detection log
     (event_type 'handoff', resolution_status 'in-flight', content_ref
     'handoff-detected', prose prognosis) triggered the plugin to OVERWRITE
     the valid S17 handoff file with a fallback wrapper, destroying the real
     prognosis and causing a false-positive checksum mismatch escalation that
     required a restore lane. Planning ticket only - no implementation
     performed (fix deferred to section-10 chain). -->

---

id: DIA-120
title: "delegation-observer handoff-writer clobbers valid handoff on in-flight log_decision - false checksum mismatch escalation"
area: opencode-config
severity: Medium
status: OPEN
blocked_by: [] # no blockers
discovered: 2026-08-12
source: session-observation (S18 boot gate, 2026-08-12)
date: 2026-08-12
created: 2026-08-12
updated: 2026-08-12

# --- Session Attribution (v2 schema, optional) ---

session_id: "ses_009e325f8ffe0OCZ9nJNBwt2je"
lane_id: ""
agent: "code-executor"
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: ""
files_touched: ["docs/dev-infra-audit/tickets/DIA-120-plugin-handoff-writer-clobber-bug.md"]
artifacts: []
evidence: ["stored checksum 20c66c0b... (canonical of ORIGINAL S17 handoff)", "computed checksum 0b9f0ddc... (canonical of plugin-written fallback wrapper)", "plugin overwrote current-handoff.json at 12:50:45Z", "S17 exit flow manual checksum 4b1dd181... vs plugin-computed 20c66c0b... (DIA-093 redundancy)"]

---

## Description

### Bug mechanism

The delegation-observer plugin source lives at
`.opencode/plugins/delegation-observer.ts` (not `.opencode/plugin/`). Its
`log_decision` tool handler writes the handoff file
`.opencode/session/current-handoff.json` whenever ALL of the following hold:

- `event_type === "handoff"`
- `prognosis` is a non-empty string

There is NO filter on `resolution_status`. The trigger (lines 1475-1479, as of
2026-08-12) therefore also fires for non-terminal status events such as
`resolution_status 'in-flight'`. When it fires, the handler maps the status via
`statusMap` (`done` -> `done`, `escalated` -> `failed`, `pending-owner` ->
`manual-halt`) and ANY other status, including `in-flight`, falls through to
the default `"manual-halt"` (lines 1485-1491), then calls `atomicWriteHandoff`
(lines 1493-1500) which atomically replaces the existing handoff file
(temp file -> fsync -> rename -> fsync dir, lines 634-654).

Additionally, when the prognosis is plain prose (not JSON-stringified), the
defensive `parsePrognosis` fallback (lines 1456-1470) wraps it in a synthetic
`{ session_summary: { note }, fixes_applied: [], open_tickets: [],
verification_request: [], resume_instructions: "" }` object - the "fallback
wrapper" - so the real S17 prognosis content is destroyed on overwrite.

### Trigger story (S18 boot gate, 2026-08-12)

During the S18 boot gate, the orchestrator's boot-gate detection log used
`log_decision` with `event_type 'handoff'`, `resolution_status 'in-flight'`,
`content_ref 'handoff-detected'`, and a prose prognosis. The plugin's
handoff-writer fired (per the mechanism above), OVERWROTE the valid S17
handoff file at 12:50:45Z with a fallback wrapper, and destroyed the real
prognosis. The subsequent DIA-061 checksum verification then compared the
stored checksum of the original S17 handoff against a fresh computation over
the clobbered file, produced a mismatch, escalated as a false-positive
checksum-mismatch, and required a restore lane to recover the S17 handoff.

### Evidence

- `stored 20c66c0b...` was the CORRECT canonical checksum of the ORIGINAL S17
  handoff (the plugin's own `computeChecksum` of the S17 prognosis).
- The plugin overwrote `current-handoff.json` at 12:50:45Z with a fallback
  wrapper whose canonical checksum was `0b9f0ddc...` (the false
  "computed" value reported in the mismatch escalation).
- Every file version was internally self-consistent at write time: the
  original S17 file's stored checksum matched its own prognosis, and the
  fallback wrapper's stored checksum matched its own (synthetic) prognosis.
  This is NOT tampering - it is a writer that fired when it should not have.

### Secondary findings

1. **Boot-gate stale-comparison flaw.** The boot gate compared lane-0's fresh
   computation against the checksum value memorized from the boot read, not
   re-reading the file's checksum field at comparison time. This is what
   turned a clobbered file into a false "mismatch" escalation: the stored
   value belonged to the pre-clobber file. Fix direction: re-read the file at
   comparison time; include `stored=` in the lane-0 brief.
2. **DIA-093 exit-flow redundancy.** The S17 exit flow wrote the handoff
   manually (`checksum: null`, placeholder future timestamp) and then ran a
   lane-compute + edit dance to fill the checksum. This is redundant with the
   plugin's automatic checksum computation on `log_decision(handoff, ...,
prognosis)` and produced a divergent value (`4b1dd181...` manual vs the
   plugin's `20c66c0b...`). DIA-093's "write the lane-returned checksum into
   the field" instruction conflicts with plugin-written handoffs and should be
   clarified (see Fix).

**Reference files:** `.opencode/plugins/delegation-observer.ts` (handoff-writer
trigger lines 1475-1479, `statusMap` lines 1485-1491, `parsePrognosis` fallback
lines 1456-1470, `atomicWriteHandoff` lines 634-654, `computeChecksum` lines
610-625); `.opencode/session/current-handoff.json` (gitignored runtime
artifact); `docs/dev-infra-audit/tickets/DIA-093-orchestrator-no-bash-checksum-delegation.md`;
`docs/dev-infra-audit/tickets/DIA-061.md`; `.opencode/oh-my-opencode-slim/orchestrator_append.md`
(boot-gate checksum comparison step).

## Verification

- Reproduce the defect: dispatch `log_decision` with `event_type 'handoff'`,
  `resolution_status 'in-flight'`, and a non-empty `prognosis`; confirm
  `.opencode/session/current-handoff.json` gets overwritten (status becomes
  `manual-halt` via the `statusMap` default) and a previously valid handoff is
  clobbered.
- Confirm which events SHOULD write: terminal resolution_status values
  (`done` / `escalated` / `pending-owner`) are the only handoff events that
  should trigger the handoff-writer; `in-flight` (and other non-terminal
  statuses) must be treated as non-writing.
- Confirm the parse-fallback path: pass a plain-text (non-JSON) prognosis and
  confirm the written file contains the synthetic fallback wrapper rather than
  the real prognosis.
- After fix:
  1. An `in-flight` handoff log does NOT touch the handoff file (pre-existing
     valid handoff survives byte-identical).
  2. Terminal-status handoff logs still write atomically with a canonical
     checksum.
  3. Boot-gate verification re-reads the file at comparison time and reports
     `stored=` in the lane-0 brief.

## Fix

> To be filled at fix time via section-10 chain.

Recommended fix direction (recorded now for the section-10 chain; NOT
implemented in this docs-only lane):

- Narrow the handoff-writer trigger in
  `.opencode/plugins/delegation-observer.ts` to terminal `resolution_status`
  values (`done` / `escalated` / `pending-owner`) or require an explicit
  `write_handoff: true` flag; treat in-flight/progress handoff events as
  non-writing.
- Fix the boot-gate comparison to re-read the file's checksum field at
  comparison time (include `stored=` in the lane-0 brief).
- Clarify DIA-093: the handoff should be written solely via
  `log_decision(handoff, ..., prognosis)` as the plugin does; manual
  write/edit tools should not be used for handoff files.

## Re-verify

> To be filled at re-verify time.
