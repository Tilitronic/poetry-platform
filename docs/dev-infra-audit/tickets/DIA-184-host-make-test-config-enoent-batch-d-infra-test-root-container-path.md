# DIA-184 - host make test-config exit 2: batch-d-infra.test.mjs TEST_ROOT defaults to container path /workspace

<!-- Filed 2026-08-15 (ticket-filing lane, agent: coder, session
     ses_ffd82bed7ffeyOGA03b2t3D4Hg). DOCUMENTATION-ONLY: defect filed from
     evidence gathered during this session's reconciliation work (cod-7
     ses_ffde3ced9ffe5Yx7IcgsJEvBLa + confirmed in later gate runs cod-8
     DIA-156 / cod-9 DIA-155). Fix is queued for the next session. ASCII-only
     per DIA-079. -->

---

id: DIA-184
title: "host make test-config exit 2: batch-d-infra.test.mjs TEST_ROOT defaults to container path /workspace"
area: tests-infra
severity: Medium
status: VERIFIED
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-15
source: test-lane
date: 2026-08-15
created: 2026-08-15
updated: 2026-08-15
resolved: 2026-08-15

# --- Session Attribution (v2 schema, optional) ---

session_id: "ses_ffd82bed7ffeyOGA03b2t3D4Hg"
lane_id: "tf-1"
agent: "coder"
model: ""
parent_session_id: "ses_ffe359d8bffegJun06OC9Wg749"
attempts: 0
lease_expires_at: "" # ISO-8601; set on DISPATCHED, cleared on COMPLETE
files_touched: ["docs/dev-infra-audit/tickets/DIA-184-host-make-test-config-enoent-batch-d-infra-test-root-container-path.md", "scripts/__tests__/batch-d-infra.test.mjs"]
artifacts: []
evidence: ["cod-7 reconciliation report (ses_ffde3ced9ffe5Yx7IcgsJEvBLa): host make test-config exit 2 ENOENT /workspace", "cod-8 DIA-156 gate runs: host exit 2 ENOENT /workspace", "cod-9 DIA-155 gate runs: host exit 2 ENOENT /workspace", "container `docker compose exec dev make test-config` exit 0 (49/49)"]

---

## Description

`scripts/__tests__/batch-d-infra.test.mjs` (tracked; landed in the DIA-153
lease lane's 45-commit push, DIA-134 closure lineage) hardcodes its TEST_ROOT
default to the CONTAINER mount path `/workspace`:

    scripts/__tests__/batch-d-infra.test.mjs:44
    const TEST_ROOT = process.env.TEST_ROOT || '/workspace';

On the HOST, running `make test-config` exits 2 with ENOENT `/workspace`
because no such directory exists outside the dev container. Observed 3 times
this session: cod-7 reconciliation, cod-8 (DIA-156 gates), cod-9 (DIA-155
gates). The pre-push hook runs test-config IN-CONTAINER so the git gate
passes; only host-side direct runs false-fail. Current handoff records the
pair: `test_config_host: 2` vs `test_config_container: 0`.

Why it matters: the documented host gate (`make test-config`, AGENTS.md
section 6) false-fails for any developer running it directly on the host.
This is a REAL defect, not speculative - the default resolves to a
container-only path (DIA-086-style scope note: the file genuinely defaults to
a path that cannot exist on the host).

## Verification

On the HOST (outside the dev container), from the repo root:

    make test-config

Expected (bug): exit 2, ENOENT `/workspace` from batch-d-infra.test.mjs.
Proves the defect exists on host-side direct runs.

Sane reference (not the bug): inside the container:

    docker compose exec dev make test-config

Expected: exit 0 (49/49) - the suite passes when TEST_ROOT resolves to the
real container mount.

## Fix

Implemented 2026-08-15 (fix lane, worktree .slim/worktrees/dia-184, branch omos/dia-184).

**Root cause:** `scripts/__tests__/batch-d-infra.test.mjs` hardcoded all three
path defaults (TEST_ROOT, ESBUILD_BIN, OMO_NODE_MODULES) to the CONTAINER
mount path `/workspace`, which does not exist on the host. Host-side
`make test-config` therefore exit 2 with ENOENT /workspace.

**Fix (host-aware defaults, env override still wins):**

- **TEST_ROOT** now defaults to the repo root of the tree the suite is checked
  out in, derived from `import.meta.url` (the suite is tracked at
  `<tree>/scripts/__tests__/batch-d-infra.test.mjs`, so the tree root is two
  levels above the file). Cwd-independent: correct in-container (/workspace)
  and on the host for both the main tree and worktrees. `process.env.TEST_ROOT`
  still wins when set.
- **ESBUILD_BIN / OMO_NODE_MODULES** get the same treatment via a `findUp`
  helper: walk up from TEST_ROOT to the nearest ancestor that holds the path
  (worktrees have no node_modules of their own - the main tree supplies them).
  Falls back to the TEST_ROOT-relative path at the filesystem root, matching
  the old semantics. Env overrides still win.
- **S6 test section added** pinning the resolution logic: repoRootOf unit
  tests (container / main-tree / worktree layouts) + findUp behavior (walk-up,
  miss-fallback, direct-hit). The helpers stay module-scope so the fix logic
  itself is asserted directly, not just the end state.

**Files changed:** `scripts/__tests__/batch-d-infra.test.mjs` (the fix itself)
plus this ticket file (Fix/Re-verify sections filled + frontmatter updated per
ledger convention).

## Re-verify

Re-verified 2026-08-15 after the fix (fix lane, worktree .slim/worktrees/dia-184):

- **HOST** (outside dev container, worktree repo root): `make test-config`
  exit **0** (was exit 2 ENOENT /workspace). batch-d-infra suite line:
  `node scripts/__tests__/batch-d-infra.test.mjs` -> 56 tests, 56 pass,
  0 fail, exit 0 (incl. new S6 DIA-184 section).
- **CONTAINER** (no regression): `docker compose exec dev make test-config`
  exit **0** (49/49, pre-fix main-tree suite). New suite run in-container
  directly (`node /workspace/.slim/worktrees/dia-184/scripts/__tests__/batch-d-infra.test.mjs`)
  exit **0** (56/56).
- `git status` shows only the intended change: `scripts/__tests__/batch-d-infra.test.mjs`
  (+ this ticket's Fix/Re-verify update).

Re-review cycle 1/2 (rev-3): all prior findings verified-closed; OBS-1 (stale
"exported" wording in this Fix narrative, now module-scope) fixed 2026-08-15.

Status: VERIFIED.
