# DIA-261022-zjci - handoff writer error channel: coreAtomicWrite throws on an invalid session id while every other failure returns ok:false

---

id: DIA-261022-zjci
title: "handoff writer error channel: coreAtomicWrite throws on an invalid session id while every other failure returns ok:false"
area: opencode-config
severity: Medium
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-10-22
source: inventory
date: 2026-10-22
created: 2026-10-22
updated: 2026-10-22

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

`.opencode/plugins/lib/handoff.ts:110-112` - `coreAtomicWrite` throws
`new Error("[handoff] invalid session id")` when `sessionId` fails
`SAFE_SESSION_ID` (`/^[A-Za-z0-9_-]+$/`, line 67), while EVERY other failure
in the same function returns result-as-data:

- write path: `{ ok: false, archived_prior, error }` (catch at 152-159)
- pointer path: `{ ok: true, archived_prior, error }` (catch at 178-185)

The public contract is the `{ ok, archived_prior, error? }` return shape
(public factory return types at 197 and 208; DIA-085 best-effort comment at
102). The invalid-session-id throw is a second, undocumented error channel.
Both production callers (`delegation-observer.ts:926` apoptosis path and
`:3668` log_decision path) currently shield themselves with try/catch, but a
new caller relying on the ok-flag contract alone would let the throw escape.

Decision needed: convert the invalid-session-id throw to
`{ ok: false, archived_prior: null, error }`, or keep throws as a documented
programmer-error channel with mandatory try/catch at every caller?

Recommended option: convert to
`{ ok: false, archived_prior: null, error: "[handoff] invalid session id" }`.
A runtime-derived session id is environmental input, not a caller literal,
and the ok-gated active.json logic at `delegation-observer.ts:3718`
(`slotLanded = writeResult !== null && writeResult.ok === true`) then sees an
explicit ok:false instead of riding the exception path. Keep the content-type
throws (198-199, 214-215) and the reserved-path-collision throw (125) -
those ARE caller-programmer errors - and document the split in the function
header.

Alternative: keep all throws and document the try/catch requirement at the
public API.

## Verification

- [ ] Error channel decision applied and documented in the function header
- [ ] If converted: an ok:false result (no throw) on an invalid session id, with a test pinning it
- [ ] make test-shell and bun parallel-handoff suites stay green

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
> Absorbed scope (audit DIA-261022-5n2v): DIA-261022-m6l8 - the two unawaited app.log promises at this same handoff seam; .catch(() => {}) is already the neighbouring convention, so no separate ticket.
