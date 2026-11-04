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

Make the sanctioned `scripts/pending-gate-clear conspect-pending` command able
to clear a flag the plugin wrote without a res id, so a fully-verified conspect
pipeline is no longer blocked behind a forbidden hand-delete.

## Verification

- [ ] On the live stale flag (session `ses_f256279feffe1PHc6M6LG67mYq`,
      artifact `knowledge/res-260925-09iu-lean-ctx`),
      `bash scripts/pending-gate-clear conspect-pending` exits 0 and prints
      `ok: cleared conspect-pending`.
- [ ] A flag whose res id cannot be resolved still refuses (exit 1) and names
      what is missing - the reader's "never guess" rule survives.
- [ ] A flag whose artifacts do NOT verify (missing sources/, missing conspect
      file, missing shelf entry) still refuses and names the missing artifact.
- [ ] Hand-deleting `.opencode/session/conspect-pending.json` is never required
      on any path.
- [ ] `bats scripts/__tests__/pending-gate-clear.bats` passes with new cases
      covering: legacy no-res flag resolvable, legacy no-res flag unresolvable,
      plugin-written flag WITH `res_id` (the post-`f18f3d19` shape).

## Fix

Smallest concrete change: option (b) from `## Options`, i.e. reader-side legacy
tolerance in `scripts/pending-gate-clear` (option (a) already landed - see
`## Problem` update).

1. `scripts/pending-gate-clear:84` - when `.res // .res_id // .res_dir` is
   empty, do NOT immediately refuse: take the flag's `session_id` and look for a
   UNIQUE `knowledge/<res-id>/` reference attributable to that session in
   `.opencode/session/registry.jsonl` and `.opencode/session/messages.jsonl`
   (today's real row: `messages.jsonl:129154` carries
   `content_ref: knowledge/res-260925-09iu-lean-ctx/res-260925-09iu-lean-ctx-conspect.md`
   with `task_ref: conspect-synthesis-res-260925-09iu-lean-ctx`).
2. Exactly one candidate -> reuse the existing artifact verification unchanged
   (sources/, named conspect file, shelf entry). Zero or more than one
   candidate -> refuse with the current message (never guess).
3. `scripts/__tests__/pending-gate-clear.bats` - add the three cases listed in
   `## Verification`.

Acceptance behaviour: the documented stale flag clears through the sanctioned
command; every unresolvable or artifact-incomplete flag still refuses and names
what is missing; no hand-delete path.

## Problem

The delegation plugin writes `.opencode/session/conspect-pending.json` with ONLY
`session_id`, `agent`, `detected_at`, `flag`. `scripts/pending-gate-clear`
requires a `.res` // `.res_id` // `.res_dir` key (around line 84) and refuses
otherwise BY DESIGN ("If absent -> refuse, never guess"). Consequence: no
plugin-written conspect flag can ever be cleared through the sanctioned
command.

### Update 2026-11-04 (writer half shipped, legacy half still stuck)

- Writer half: FIXED in `f18f3d19` (2026-10-23, "DIA-261022-5n2v: land the
  rollback-free simplification set"). `.opencode/plugins/delegation-observer.ts:2908-2920`
  now extracts `res_id` from the result body (`payload.res_id = resIdMatch[1]`)
  and carries it on the flag; the comment names this ticket explicitly.
- Reader half: UNCHANGED. `scripts/pending-gate-clear:84` still reads only
  `.res // .res_id // .res_dir`, and `:88` still reports
  `missing "res directory (no res/res_id/res_dir key in flag JSON)"`.
- Live probe (2026-11-04, non-destructive: run against a COPY with
  `SESSION_DIR=/workspace/.scratch/rhez-probe`):

      refused: missing res directory (no res/res_id/res_dir key in flag JSON)
      EXIT=1

  and the real `.opencode/session/conspect-pending.json` still holds the
  pre-fix 4-key payload (`session_id: ses_f256279feffe1PHc6M6LG67mYq`,
  `detected_at: 2026-09-25T22:20:18.763Z`, no `res_id`), so the documented
  instance remains un-clearable by any sanctioned command.

- Residual scope: flags written on or after 2026-10-23 carry `res_id` and clear
  normally; every flag written before that date (including the one under this
  ticket) needs the reader-side legacy branch above.

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

Sanctioned clear on the documented instance (this is the acceptance test):

    bash scripts/pending-gate-clear conspect-pending
    # expect: ok: cleared conspect-pending   (exit 0)
    test ! -f .opencode/session/conspect-pending.json && echo CLEARED

Negative paths (refusal must survive):

    # flag with no session_id-attributable res -> refuse, exit 1
    mkdir -p .scratch/f3c4 && printf '%s\n' '{"session_id":"ses_none","agent":"researcher","detected_at":"2026-11-04T00:00:00Z","flag":"PERSISTENCE_RECOMMENDED: true"}' > .scratch/f3c4/conspect-pending.json
    SESSION_DIR=/workspace/.scratch/f3c4 bash scripts/pending-gate-clear conspect-pending; echo "EXIT=$?"
    # resolvable but artifact-incomplete -> refuse naming the missing artifact
    printf '%s\n' '{"session_id":"ses_x","res_id":"res-does-not-exist","flag":"PERSISTENCE_RECOMMENDED: true"}' > .scratch/f3c4/conspect-pending.json
    SESSION_DIR=/workspace/.scratch/f3c4 bash scripts/pending-gate-clear conspect-pending; echo "EXIT=$?"

Suite:

    bats scripts/__tests__/pending-gate-clear.bats
    grep -n "res_id" .opencode/plugins/delegation-observer.ts | head   # writer half still present (f18f3d19)
