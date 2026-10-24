# DIA-260928-f3c4 - tooling: pending-gate-clear cannot clear a plugin-written conspect flag (writer/reader schema mismatch)

---

id: DIA-260928-f3c4
title: "tooling: pending-gate-clear cannot clear a plugin-written conspect flag (writer/reader schema mismatch)"
area: scripts
severity: Medium
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-09-28
source: inventory
date: 2026-09-28
created: 2026-09-28
updated: 2026-09-28

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

## Problem

The delegation plugin writes `.opencode/session/conspect-pending.json` with ONLY
`session_id`, `agent`, `detected_at`, `flag`. `scripts/pending-gate-clear`
requires a `.res` // `.res_id` // `.res_dir` key (around line 84) and refuses
otherwise BY DESIGN ("If absent -> refuse, never guess"). Consequence: no
plugin-written conspect flag can ever be cleared through the sanctioned
command.

## Evidence (2026-09-28)

- Writer: `.opencode/plugins/delegation-observer.ts` around line 2967 (four
  keys only).
- Reader: refuses with
  `refused: missing res directory (no res/res_id/res_dir key in flag JSON)`
  exit 1.
- Instance: the stale flag from 2026-09-25 (session
  `ses_f256279feffe1PHc6M6LG67mYq`) whose pipeline is FULLY verified -
  `knowledge/res-260925-09iu-lean-ctx` holds 9 non-empty source archives, an
  18804-byte conspect, and a `shelf.conspects` entry for that res id - so it
  is a false-positive gate that no tool can clear, and hand-deleting the flag
  is forbidden.

## Impact

The mechanical conspect gate either leaks a stale flag forever (agents keep
re-checking it across sessions) or forces the forbidden hand-delete; the
"verified clear" guarantee (DIA-260825-fjnc) is unreachable for
plugin-written flags.

## Options

- (a) the writer persists the res id in the flag (it knows the research id at
  write time);
- (b) the clear script resolves the res id from `session_id` via
  registry/messages.jsonl instead of refusing;
- (c) a schema change at write time plus legacy-shape tolerance that looks
  artifacts up by session id.

## Acceptance criteria

- For a plugin-written flag whose artifacts verify (sources/, conspect file,
  shelf entry), the sanctioned clear command SUCCEEDS and reports a verified
  clear;
- when artifacts do NOT verify it still refuses and names what is missing;
- no hand-deletion route is ever required.

## Relations

- conspect gate DIA-260819-qibv
- verified-clear tooling DIA-260825-fjnc
- the artifact under the stale flag is `res-260925-09iu-lean-ctx`
  (campaign DIA-260925-td9h)

## Re-verify

> To be filled at re-verify time.
