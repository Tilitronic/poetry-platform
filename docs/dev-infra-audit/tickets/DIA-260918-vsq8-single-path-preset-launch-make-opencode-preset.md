# DIA-260918-vsq8 - single-path preset launch make opencode PRESET

---

id: DIA-260918-vsq8
title: "single-path preset launch make opencode PRESET"
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

Single-path preset launch: `make opencode PRESET=<name>` is the only
supported way to start the TUI with a preset. The Makefile forwards the
choice as the single env var OH_MY_OPENCODE_SLIM_PRESET (the only preset
env oh-my-opencode-slim 2.2.19 reads) via `docker compose ... -e`. The
legacy `make preset NAME=<name>` target is a deprecated stub (exit 2)
that points at the single path. A stale OPENCODE_WORKSPACE_PRESET bridge
export was dropped so PRESET cannot be shadowed. Unknown PRESET values
fail loudly with the available-preset list before any container starts.

## Verification

- [x] `make presets` lists a non-empty registry including free and muse-balanced (host smoke 2026-09-18, exit 0; bats test 1 re-verified 2026-09-22)
- [x] `make preset NAME=free` prints the deprecation notice, exits 2, writes nothing (host smoke 2026-09-18: make exit 2, STUB_EXIT=2; bats test 2 re-verified 2026-09-22)
- [x] `make opencode PRESET=does-not-exist` prints Unknown preset plus the available list, exits 2, starts no container (host smoke 2026-09-18: EXIT=2; bats test 6 re-verified 2026-09-22)
- [x] Makefile forwards only OH_MY_OPENCODE_SLIM_PRESET; no second preset path remains; stale OPENCODE_WORKSPACE_PRESET export is ignored and bare `make opencode` forwards no override (bats tests 3/4/5, 2026-09-22)
- [x] preset-single-path.bats 6/6 pass, exit 0 (2026-09-22 backfill run)
- [x] make test-config passes, exit 0 (2026-09-22 backfill run)
- [ ] Live TUI check: `make opencode PRESET=free` and PRESET=muse-balanced Effective lines at TUI startup - HUMAN STEP PENDING, to be captured on next interactive launch

## Fix

Backfilled 2026-09-22 from git log (each hash verified present via
`git show -s`), oldest first:

1. 793d40bf - DIA-260918-vsq8 revert fork chain to clean npm track
2. fe29b95d - DIA-260918-vsq8 single-path preset launch make opencode PRESET
3. 8690921c - DIA-260918-vsq8 rev-3 fixes drop bridge plus exit 2 plus stripper plus quote
4. d59e9fc2 - DIA-260918-vsq8 / preset out of scope warning
5. 84b58f4e - DIA-260918-vsq8 audit artifacts plus DIA-260918-yug6 history
6. 8903970f - DIA-260918-vsq8 shelf specs schema fix
7. f2656c61 - DIA-260918-vsq8 forward OH_MY_OPENCODE_SLIM_PRESET the only env 2.2.19 reads

Net effect: Makefile `opencode` target takes PRESET (validated against
`make presets` registry, exit 2 on unknown), forwards exactly one env
var; `preset` target is a stub (exit 2); the OPENCODE_WORKSPACE_PRESET
bridge is gone; `/`-prefixed PRESET input warns out-of-scope.

## Re-verify

Backfill verification run 2026-09-22 (host, ASCII-only):

- `bash scripts/__tests__/bats-wrapper.sh --filter preset-single-path`:
  6/6 ok (tests 1-6 listed above), FILTER_EXIT=0
- Full `test-shell` suite via bats-wrapper (no filter): 724/724 ok,
  WRAPPER_EXIT=0
- `make test-config`: all structural gates PASS, CONFIG_EXIT=0
- `git show -s` confirms all 7 Fix hashes exist with the subjects quoted
- Ticket file ASCII check: `grep -P '[^\x00-\x7F]'` clean
- Ticket status unchanged: OPEN (live TUI check still pending)

## Evidence

Host smoke 2026-09-18 provided by developer, recorded verbatim:

1. git log HEAD d59e9fc plus 8690921 plus fe29b95 plus 793d40b plus e50c1de on branch omo-slim-changes.
2. make presets prints free muse-balanced openai-first-cost-balanced promo-union-alpha exit 0.
3. make preset NAME=free prints deprecation Use make opencode PRESET plus make presets, make exit 2, STUB_EXIT=2.
4. make opencode PRESET=does-not-exist prints Unknown preset plus Available presets list, make exit 2, EXIT=2, no container started.

Remaining live check: make opencode PRESET=free and PRESET=muse-balanced Effective lines at TUI startup, to be captured on next interactive launch.
