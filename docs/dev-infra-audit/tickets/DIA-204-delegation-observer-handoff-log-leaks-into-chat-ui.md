# DIA-204 - delegation-observer handoff-archived log line leaks into OpenCode chat UI (console.warn surfaces in conversation stream)

<!-- FILED 2026-08-16 (docs lane, coder agent). Developer-reported via
     screenshot (observer lane analysis). Next free number after DIA-203
     (max+1 per COORDINATION.md number-allocation protocol). -->

---

id: DIA-204
title: "delegation-observer handoff-archived log line leaks into OpenCode chat UI (console.warn surfaces in conversation stream)"
area: opencode-config
severity: Medium
status: OPEN
blocked_by: [] # no blockers
parent_epic: ""

# DIA-104 grilling-gate markers (ai--7 validated design): fill at creation time

# with the defaults below (absent = legacy/skipped, grandfather precedent).

gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered:
source: developer-report
date: 2026-08-16
created: 2026-08-16
updated: 2026-08-16

# --- Session Attribution (v2 schema, optional) ---

session_id: "ses_ff556cf05ffe55oXNmk41IV1Gq" # session that observed the defect (screenshot)
lane_id: "docs"
agent: "coder"
model: "opencode-go/deepseek-v4-flash"
parent_session_id: "ses_ff556cf05ffe55oXNmk41IV1Gq" # orchestrator session that observed the defect
attempts: 0
lease_expires_at: ""
files_touched: [docs/dev-infra-audit/tickets/DIA-204-delegation-observer-handoff-log-leaks-into-chat-ui.md, docs/dev-infra-audit/tickets/README.md]
artifacts: []
evidence: [.opencode/images/ses_ff556cf05ffe55oXNmk41IV1Gq/clipboard-1da748a9.png]

---

## Description

Developer-reported 2026-08-16 (screenshot
`.opencode/images/ses_ff556cf05ffe55oXNmk41IV1Gq/clipboard-1da748a9.png`,
analyzed by the observer lane): the OpenCode chat interface (dark theme,
orchestrator session, DeepSeek V4 Flash) renders a plain-text log line
directly in the main conversation stream:

    [delegation-observer] handoff archived: ses_ff556cf05ffe55oXNmk41IV1Gq prior slot -> archive/ses_ff556cf05ffe55oXNmk41IV1Gq.2026-08-16T15-48-27.938Z.json

Source: the delegation-observer plugin (internal telemetry about handoff
archival). Severity: real bug - internal plugin telemetry surfaces in the
user-facing chat stream instead of a debug/telemetry channel. Not a crash;
pollutes the conversation UI with implementation-level output.

ROOT CAUSE (read-only recon, docs lane):

- Emitting call: `.opencode/plugins/delegation-observer.ts:1155-1157`
  (inside `atomicWriteHandoff`, step 1 - archive prior slot):

      console.warn(
        `[delegation-observer] handoff archived: ${sessionId} prior slot -> archive/${archiveName}`
      )

- Channel: `console.warn` (stderr). OpenCode captures plugin console output
  and surfaces it in the TUI chat stream / notification area, so ANY
  console.warn from the plugin is user-visible. This is the leak.
- Trigger: the line fires on EVERY handoff archival - i.e. whenever
  `log_decision(handoff)` writes a terminal handoff for a session that
  already has a prior slot (session end / handoff rewrite). Routine
  telemetry, not a warning condition.
- Scope: systemic, not just this line. delegation-observer.ts has 17+
  console.warn call sites (lines 759, 865, 1016, 1155, 1162, 1219, 1343,
  1364, 1630, 1900, 1937, 1980, 2004, 2160, 2181, 2215, 2544) - the whole
  plugin logs via console.warn, so every one of them can surface in the
  chat UI. The handoff-archived line is the most visible because it fires
  on every session end; the others are mostly error paths (rarer).
- Precedent: DIA-193 already demoted the skip-if-inflight console.warn to
  the TUI-safe SDK logger `ctx.client.app.log` (info, then debug). The
  plugin already uses ctx.client.app.log at lines 1689, 2152, 2207, 2550,
  2628, 2651. The same pattern applies here.
- Test impact: `.opencode/plugins/__tests__/parallel-handoff.test.mjs`
  captures console.warn (lines 139-152) and asserts on "handoff archived"
  at line 253 (absent on first write) and line 317 (present on overwrite).
  A fix that demotes the line to app.log must update the harness capture
  and those assertions (DIA-193 precedent).

## Verification

1. Reproduce the leak (pre-fix): in an orchestrator session, invoke
   `log_decision(handoff, terminal status, prognosis)` twice for the same
   session_id (or end a session whose slot already exists) so the prior
   slot is archived; confirm the `[delegation-observer] handoff archived`
   line appears in the OpenCode chat stream.
2. Post-fix: repeat step 1 and confirm NO `[delegation-observer] handoff
archived` line appears in the chat stream; the event must be visible
   only via the TUI-safe SDK logger (ctx.client.app.log, debug/info level)
   - check the plugin app log output.
3. Channel audit: grep delegation-observer.ts for `console.warn` - after
   the fix, the handoff-archived line must NOT be among them, and the
   remaining console.warn call sites should be reviewed for the same leak
   (scope decision: fix just this line vs. sweep the plugin).
4. Tests: bun parallel-handoff harness (the S1 archive-on-overwrite test
   must assert the app.log message, not console.warn capture); make
   test-config exit 0 (56 tests incl. batch-d-infra which bundles the real
   plugin); make test-shell exit 0.
5. Restart smoke (section 2.5 Phase 5): restart OpenCode, run a fresh
   orchestrator session to session end, confirm the chat stream stays
   clean.

## Fix

> To be filled at fix time.

Fix direction (for design): demote the handoff-archived console.warn at
delegation-observer.ts:1155-1157 to `ctx.client.app.log` (level debug or
info, service delegation-observer) - the DIA-193 pattern. Update
parallel-handoff.test.mjs to capture/assert the app.log message instead of
console.warn. Decide scope: minimum (this line only) vs. sweep (audit all
17+ console.warn call sites for the same leak).

## Routing

AGENTS.md section 2.5 (opencode-config / plugin change):

1. Gate: @ai-specialist (read-only research) - or coder fallback if the
   endpoint is down.
2. User reviews and decides (practice-protected).
3. Design: @architector if non-trivial (a single-line demote likely skips
   this step).
4. Implement: @coder applies the approved design.
5. Validate: make test-config + restart smoke.
6. Independent review: @ai-auditor.
7. Register: CHANGELOG YAML-ledger append + learnings outcome.

## Re-verify

> To be filled at re-verify time.
