# DIA-261023-d3rw - WORKTREE marker collision: the injected envelope worktree field breaks after-hook worktree tracking

---

id: DIA-261023-d3rw
title: "WORKTREE marker collision: the injected envelope worktree field breaks after-hook worktree tracking"
area: opencode-config
severity: Medium
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: DIA-261023-d6b9
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-10-23
source: fix-lane
date: 2026-10-23
created: 2026-10-23
updated: 2026-10-23

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

`extractWorktreeMarker` (`.opencode/plugins/delegation-observer.ts:142-149`)
collects `/WORKTREE:\s*(\S+)/gi` matches and returns a value only when
`markers.length === 1` (`:148`), otherwise `undefined` silently.

The injected envelope contains a `worktree: <path>` field
(`.opencode/plugins/delegation-observer.ts:1940`), and the regex is
case-insensitive, so it matches.

The before-hook extraction at `.opencode/plugins/delegation-observer.ts:1811`
runs before the mutation and is safe. The after-hook re-scan
(`.opencode/plugins/delegation-observer.ts:2767-2778`, extract call at
`:2773`) reads the MUTATED prompt (`:2771`), so a reviewer dispatch that
also carries an authored `WORKTREE:` marker yields two matches, resolves
to `undefined`, and `sessionWorktrees` is never populated for that child -
DIA-220 apoptosis worktree cleanup loses the lane.

Conditional on one unverifiable link: that core passes the same
(post-mutation) args object into `tool.execute.after`. The plugin
documents that assumption at
`.opencode/plugins/delegation-observer.ts:2758-2766`; verifying it needs
core source.

Fix options:

- (a) extract from a captured pre-mutation copy of the authored text;
- (b) rename the envelope field so it cannot collide (for example a
  `lane_path:` field);
- (c) make the extractor prefer the authored marker when two are present.

Origin: layer-4 recon (code-navigator) during DIA-261023-d6b9.

## Verification

- [ ] Post-mutation args identity in `tool.execute.after` confirmed or
      the fix chosen does not depend on it (options (a)/(b) can proceed
      regardless).
- [ ] A reviewer dispatch carrying an authored `WORKTREE:` marker plus an
      injected envelope still populates `sessionWorktrees` for the child
      (regression test added).
- [ ] Plugin test suite exits 0.

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
