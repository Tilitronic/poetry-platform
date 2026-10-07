# DIA-260918-yug6 - preset free switching fails after make preset NAME=free

---

id: DIA-260918-yug6
title: "preset free switching fails after make preset NAME=free"
area: scripts
severity: Medium
status: DONE
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

<To be filled at creation time: what is wrong / what to build, with exact
files and line references where known.>

## Verification

- [x] Commit bcb6f26a present in git log (durable project-local preset store plus loud degrade plus docs).
- [x] Commit 9cd078fa present in git log (rev-1 fixes: Makefile degrade, save self-heal, preset none, changelog narrow, ASCII).
- [x] Commit e50c1de0 present in git log (changelog narrow diff plus scratch note).
- [x] Architector design persisted verbatim in ticket (Architector Design section below, session arc-1).
- [x] Preset switching bats pass: workspace-preset-selection.bats 10/10 plus preset-single-path.bats 6/6 (2026-09-22, exit 0).
- [x] make test-config exit 0 (2026-09-22, 79 PASS lines, structural gates PASS).
- [ ] Container-matrix R-5 launch-path evidence re-run in this lane (commit e50c1de0 cites test-omo 1409 pass from 2026-09-18; not re-run here).
- [ ] End-to-end `make preset NAME=free` switching re-verified on current tree (superseded: DIA-260918-vsq8 replaced the multi-path launch with single-path `make opencode PRESET=<name>`; see UNTICKED note).

## Fix

Shipped in three commits (all in git log, subjects verified 2026-09-22):

- bcb6f26a "DIA-260918-yug6 durable project-local preset store plus loud degrade plus docs" - project-local store .opencode/state/workspace-preset.json schema v2 replaces the host-global identity-keyed store the container never read; single five-tier resolver (PRESET, deprecated bridge, project store, config preset, none); loader degrades loudly to no preset instead of FATAL init failure; doctor defers to the resolver; lock file removed (tmp+rename+verify); bridge gets a distinct source with explicit Makefile forwarding; preset-switching docs rewritten; muse-balanced active via tier 4 (was silently none).
- 9cd078fa "DIA-260918-yug6 rev-1 fixes: Makefile degrade plus save self-heal plus preset none plus changelog narrow plus ASCII" - Makefile opencode launches bare with Effective line on resolve failure, exit 1 only for missing args; saveWorkspacePreset self-heals corrupt stores; /preset none clears via clearWorkspacePreset; CHANGELOG diff narrowed to the appended entry; Unicode markers replaced with ASCII.
- e50c1de0 "DIA-260918-yug6 changelog narrow diff plus scratch note" - hand-appended single entry scope oh-my-opencode-slim, rendered MD, validate plus render exit 0; carried test-omo 1409 pass plus test-config exit 0 from 2026-09-18.

Design pointer: Architector Design section below (session arc-1, persisted per DIA-174 R2, no implementation in that lane). Implementer note rev-1 F6 inside the design supersedes the Makefile forwarding line (stored-plus-bridge via OPENCODE_WORKSPACE_PRESET, override-plus-declared via PRESET).

Note: later campaign DIA-260918-vsq8 superseded the multi-path launch with single-path `make opencode PRESET=<name>` (only OH_MY_OPENCODE_SLIM_PRESET forwarded). Developer approved closure with residual notes below; status set DONE 2026-09-22.

## Re-verify

Evidence collected 2026-09-22 in backfill lane (no code changes, ticket file only):

- `bats scripts/__tests__/workspace-preset-selection.bats` -> 10/10 ok, exit 0.
- `bats scripts/__tests__/preset-single-path.bats` -> 6/6 ok, exit 0.
- `make test-config` -> exit 0, 79 PASS lines, `validate-plugin-structure.sh: all structural gates PASS`.
- `git show -s` confirms all three subjects: bcb6f26a, 9cd078fa, e50c1de0.
- NOT re-run in this lane: test-omo suite and R-5 container matrix (prior evidence cited in e50c1de0 message only); end-to-end free-switching on current tree (superseded by vsq8 single-path).

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

## Close residual notes (2026-09-22, developer approved)

- (a) Container-matrix re-run not repeated in close lane. Prior evidence from e50c1de0 (2026-09-18) cited as-is.
- (b) End-to-end free-switching on old make preset path untestable. Path superseded by DIA-260918-vsq8 single-path launch.
