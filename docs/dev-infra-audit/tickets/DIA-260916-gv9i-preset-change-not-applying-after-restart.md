# DIA-260916-gv9i - preset change not applying after restart

---

id: DIA-260916-gv9i
title: "preset change not applying after restart"
area: scripts
severity: Medium
status: CLOSED
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-09-16
source: inventory
date: 2026-09-16
created: 2026-09-16
updated: 2026-09-17

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
evidence:

- cb6027c
- 836d757
- 9c09190
- 164ec44
- b16eddb
- make test-omo exit 0
- verify-pre-push.sh exit 0

---

## Description

Workspace preset selection was lost across restarts: choosing a preset
applied to the running session only, with no persisted selection for the
next launch. Fix centers on
`.opencode/oh-my-opencode-slim/src/config/workspace-preset.ts`
(file-backed versioned store + resolve), `workspace-preset-cli.ts`
(save|resolve), `make preset` (Makefile), and startup resolution
(PRESET override > bridged/stored > none, fail-closed).

## Verification

- [x] All 5 scoped commits in history (cb6027c, 836d757, 9c09190, 164ec44, b16eddb)
- [x] `make test-omo` exit 0 (1383 pass, 0 fail; tsc clean)
- [x] workspace-preset-selection bats pass (tests 673-681, fail-closed paths)
- [x] `bash scripts/verify-pre-push.sh` exit 0
- [x] CLI read path: `resolve "$(pwd)"` returns stored selection, exit 0
- [ ] OpenCode restart + live smoke (residual: not feasible in lane, developer side)

## Fix

Workspace preset selection was lost across restarts: choosing a preset
applied to the running session only, with no persisted selection for the
next launch (root: no file-backed store; plus the host launcher user
config is not mounted into the dev container, so a bridge was needed).

Landed fix (5 commits, all in history):

- cb6027c feat: file-backed versioned store
  `.opencode/oh-my-opencode-slim/src/config/workspace-preset.ts`
  (read/save/resolve, lock file, atomic write + read-back verify),
  `workspace-preset-cli.ts` (save|resolve), `make preset` (Makefile),
  startup resolution order PRESET override > bridged/stored > none,
  fail-closed on unknown/stale/malformed/lock-failure, plus
  `scripts/__tests__/workspace-preset-selection.bats` and openspec
  `openspec/changes/workspace-preset-selection/`.
- 836d757 fix: review fixes - OPENCODE_WORKSPACE_PRESET private bridge
  (host launcher carries the stored value; still validated against the
  container registry); TS CLI replaces scripts/workspace-preset-selection.py.
- 9c09190 docs: memory-shelf ADR + lessons for workspace-preset-selection.
- 164ec44 fix: sandbox bridge env in tests (bunfig.toml, test-setup.ts)
  - graceful fallback to none for fixture workspaces defining no presets.
- b16eddb fix: retarget bats to promo presets (post 7jek preset rename).

## Re-verify

Re-verified 2026-09-17 in verify-then-close lane (campaign ticket
DIA-260916-gv9i), all legs green:

- git log: cb6027c, 836d757, 9c09190, 164ec44, b16eddb all present.
- make test-omo: exit 0 (1383 pass, 0 fail, 3141 expects; tsc clean).
- bats full suite via scripts/**tests**/bats-wrapper.sh: exit 0,
  0 "not ok" lines; workspace-preset tests 673-681 all ok
  (make preset save, PRESET override precedence, no-preset default,
  unknown/stale/malformed/lock-failure fail-closed, parse-failure closed).
- bash scripts/verify-pre-push.sh: exit 0 ("verification passed").
- Functional read path: `bun run
.opencode/oh-my-opencode-slim/src/config/workspace-preset-cli.ts
resolve "$(pwd)"` -> "promo stored", exit 0; "promo" is a configured
  preset. Fail-closed round-trip confirmed (fixture workspace with no
  presets refuses save / resolves none, per 164ec44 design).
- Residual (explicit): OpenCode restart + live smoke could not run in
  this lane (no container engine for compose); developer restarts on
  their side. Store/bridge/CLI legs above cover the persist path.
