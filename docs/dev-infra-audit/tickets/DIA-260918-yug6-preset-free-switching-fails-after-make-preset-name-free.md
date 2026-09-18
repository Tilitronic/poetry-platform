# DIA-260918-yug6 - preset free switching fails after make preset NAME=free

---

id: DIA-260918-yug6
title: "preset free switching fails after make preset NAME=free"
area: scripts
severity: Medium
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-09-18
source: inventory
date: 2026-09-18
created: 2026-09-18
updated: 2026-09-18

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

<To be filled at creation time: what is wrong / what to build, with exact
files and line references where known.>

## Verification

<Acceptance criteria as checkboxes - how to prove the ticket is done.>

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.

## Architector Design (arc-1 ses_f4b8bbe5dffek2VbfdOxeAx7sH)

Verbatim architector design summary (DIA-174 R2 persistence, no implementation in this lane):

- Project-local store: .opencode/state/workspace-preset.json, schema v2.
- Single resolver with five tiers: (1) PRESET env, (2) bridge deprecated,
  (3) project store, (4) config preset, (5) none.
- Remove silent none fallback at lines 159-161.
- Walk-up to .opencode or .git for project root resolution.
- Makefile forwards only PRESET override.
- Implementer note (rev-1 F6, supersedes the line above): Makefile forwards
  stored-plus-bridge selections via OPENCODE_WORKSPACE_PRESET and
  override-plus-declared selections via PRESET. Reason: the project-local
  store file is shared by host and container, so either env key reaches the
  same bytes; keeping the bridge key during transition avoids breaking
  in-flight launches that still export it.
- ADRs 1-6 recorded in architector design session arc-1.
- File list: workspace-preset.ts, loader.ts, workspace-preset-cli.ts,
  preset-manager.ts, doctor.ts, Makefile, gitignore, jsonc, docs.
- Rollback: git revert plus repin OMO version.
- Test strategy: make test-omo plus R-5 container matrix covering five launch paths.

References:

- Analyzer artifact: knowledge/ana-260918-6ac2-preset-free-switching/ana-260918-6ac2-preset-free-switching-report.md
- Learnings: .opencode/learnings/external-patterns/2026-09-18-preset-workspace-bridge.md
