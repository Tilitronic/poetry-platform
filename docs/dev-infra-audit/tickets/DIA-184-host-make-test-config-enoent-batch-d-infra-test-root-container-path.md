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
status: OPEN
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

# --- Session Attribution (v2 schema, optional) ---

session_id: "ses_ffd82bed7ffeyOGA03b2t3D4Hg"
lane_id: "tf-1"
agent: "coder"
model: ""
parent_session_id: "ses_ffe359d8bffegJun06OC9Wg749"
attempts: 0
lease_expires_at: "" # ISO-8601; set on DISPATCHED, cleared on COMPLETE
files_touched: ["docs/dev-infra-audit/tickets/DIA-184-host-make-test-config-enoent-batch-d-infra-test-root-container-path.md"]
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

<What changed — fill at fix time. Leave blank with this note until then.>

> To be filled at fix time.

Suggested direction (owned by the next session): TEST_ROOT should be
host-aware - detect cwd/repo root, or accept a TEST_ROOT env override with a
sane default (e.g. repo-root resolution instead of the hardcoded
/workspace). Note ESBUILD_BIN and OMO_NODE_MODULES at lines 45-46 have the
same /workspace default pattern and likely need the same treatment. The exact
fix, tests, and gate re-verification are queued for the next session.

## Re-verify

<Result of re-running Verification after the fix — fill at re-verify time.
Must include the actual gate output/exit code that proves VERIFIED.>

> To be filled at re-verify time.
