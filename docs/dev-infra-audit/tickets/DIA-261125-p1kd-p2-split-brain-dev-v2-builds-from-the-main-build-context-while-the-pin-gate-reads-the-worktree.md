# DIA-261125-p1kd - P2 split-brain - dev-v2 builds from the main build context while the pin gate reads the worktree

---

id: DIA-261125-p1kd
title: "P2 split-brain - dev-v2 builds from the main build context while the pin gate reads the worktree"
area: docker
severity: Major
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-11-25
source: inventory
date: 2026-11-25
created: 2026-11-25
updated: 2026-11-25

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

The dev-v2 build and the per-service pin gate read different trees, so the
artifact that gets built and the artifact that gets validated are not the same
input set. This is the P2 split-brain.

Divergence:

- `docker-compose.yml` `dev-v2` builds with `context: .`, i.e. the MAIN checkout
  (`/workspace`), so the image is assembled from the main tree.
- the per-service pin gate resolves and reads the V2 WORKTREE path when it
  compares pins, not the main tree.

Consequence: a pin or file that differs between the main tree and the worktree
can pass the gate while the image is built from the other tree (the reverse also
passes). Gate-green therefore does not imply image-correct.

Status: NO FIX HAS BEEN CHOSEN. This ticket records the divergence only. Do not
implement a candidate fix without a developer decision on which side owns the
build (main tree vs worktree) and which side the gate must read.

## Verification

- [ ] Record the build context: the resolved dev-v2 compose config shows
      `context: .` (main tree).
- [ ] Record the gate input: cite the script and line where the pin gate
      resolves the worktree path.
- [ ] Reproduce the split-brain: with a pin that differs between the main tree
      and the worktree, the gate still passes and the image is built from the
      other tree's value.
- [ ] After a fix is chosen: one command proves the gate and the image read the
      same tree for the same pin.

## Fix

dev-v2 no longer sets `working_dir` (it roots at the image WORKDIR /workspace,
like `dev`) and its `pnpm_store_v2` now mounts /workspace/node_modules; the
build context was already the repo root, and `.worktrees/` is now excluded from
it. Pins, profile, image tag, container name/hostname, ports and the state/cache
volumes are unchanged.

Commit: 406f7a3 (DIA-261112-exon).

## Re-verify

### Resolution (mount half)

Mount/run half RESOLVED at 406f7a3: dev-v2 now builds from and runs the
repository root, so V2 runs the migration tree instead of the feature worktree.

### Remaining half - pin gate

Still OPEN: `scripts/check-omo-version-sync.sh` continues to read
`.worktrees/opencode-v2` as the V2 service while that worktree exists, so the
gate's V2 input is no longer dev-v2's actual runtime tree. Follow-up: drop or
repoint that V2 block (developer decision).
