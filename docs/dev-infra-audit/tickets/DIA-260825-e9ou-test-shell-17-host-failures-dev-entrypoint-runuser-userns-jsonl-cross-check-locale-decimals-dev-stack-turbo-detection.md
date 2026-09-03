# DIA-260825-e9ou - test-shell: 17 host failures - dev-entrypoint runuser userns, jsonl-cross-check locale decimals, dev-stack turbo detection

---

id: DIA-260825-e9ou
title: "test-shell: 17 host failures - dev-entrypoint runuser userns, jsonl-cross-check locale decimals, dev-stack turbo detection"
area: scripts
severity: Medium
status: CLOSED
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-25
source: inventory
date: 2026-08-25
created: 2026-08-25
updated: 2026-08-25

# --- Session Attribution (v2 schema, optional) ---

session_id: ""
lane_id: ""
agent: ""
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: "" # ISO-8601; set on DISPATCHED, cleared on COMPLETE
files_touched:

- scripts/**tests**/test-helper.bash
- .opencode/scripts/jsonl-cross-check.sh
- scripts/**tests**/ssh-agent-forward.bats
  artifacts: []
  evidence: []

---

## Description

Observed on HOST (mimic@192) running `make test-shell`: 527 tests, 17 failures,
1 skipped. Three independent failure clusters, all host-environment artifacts
rather than logic bugs in the test assertions themselves:

### Cluster 1 - dev-entrypoint.bats (9 failures)

Failure string: "runuser: user dev does not exist or the user entry does not
contain all the required fields".

The `run_entrypoint_ns` tests run under `unshare -r -m` (per the per-test
header comment) to simulate a user namespace, but `scripts/dev-entrypoint.sh`
calls `runuser -u dev` to drop privileges. Inside the freshly-created userns
there is no `dev` passwd entry, so `runuser` exits 1 and every
`run_entrypoint_ns` test fails. The test harness assumes the `dev` user exists
in the mapped namespace, which it does not.

### Cluster 2 - jsonl-cross-check.bats (7 failures)

The tests assert dot-decimal numeric strings such as
"completeness: 100.0% (target >= 99.0%)". The script under test prints
locale-formatted comma decimals ("100,0%") on hosts whose locale uses a comma
as the decimal separator (uk_UA / ru_RU / de_DE). The numeric formatting in the
cross-check script must force `LC_ALL=C` / `LC_NUMERIC=C` so the decimal point
is always a dot regardless of host locale.

### Cluster 3 - dev-stack.bats (1 failure)

Test: "runs pnpm install when turbo binary is missing". The test output reports
"ok: dependencies already installed" instead of exercising the install branch.
The turbo-presence check in `scripts/dev-stack.sh` resolves a `turbo` binary
from outside the test sandbox (host PATH / global install), so the
missing-turbo branch is never reached and the negative-path assertion fails.

## Verification

All gates green at commit 3628fdc (branch DIA-260822-medh-red), full
`make test-shell` target chain run on the host (host has no `make` binary, so
the exact Makefile command sequence was executed directly):

- [x] check-pin-sync: 4 ok / 0 fail (node 24.18.0, pnpm 10.33.0 parity both Dockerfiles)
- [x] check-host-jq: 1 ok / 0 fail (jq 1.7 functional)
- [x] check-host-lsp: 1 ok / 0 fail, 3 warn (rust-analyzer via poetry-dev container; ts/yaml/pyright host warns are documented dev-container-provided tools)
- [x] check-opencode-docker: static integrity passed
- [x] bats-wrapper.sh: 527 ok / 0 fail / 1 skip (pre-existing "real Xvfb on PATH" skip in dev-entrypoint test 7)
- [x] Full suite completes (prior fix attempts aborted at test 299/527 with ENOSPC from the opencode-docker config copy filling the 512M /tmp tmpfs)
- [x] No new Xvfb zombie processes after the dev-entrypoint suite (21 before = 21 after)

## Fix

All three clusters fixed; plus one additional hermeticity fix that was required
to make the suite completable on this host (detailed below).

1. Cluster 1 (dev-entrypoint, 9 failures) - `scripts/__tests__/test-helper.bash`:
   new `install_fake_priv_drop` helper plants no-op `runuser`/`gosu`/`su`
   shims on PATH for the `unshare -r -m` entrypoint tests, so the privilege
   drop succeeds without a `dev` passwd entry inside the user namespace. The
   shims install into `/var/tmp` (not `$BATS_TEST_TMPDIR`) because the xvfb
   variant mounts a tmpfs over /tmp inside the namespace and would hide them.
   The same helper plants a no-op `Xvfb` shim when the host has a real Xvfb:
   the entrypoint's Xvfb block runs BEFORE the privilege drop, so every ns
   test was launching a real Xvfb against host /tmp (zombie processes,
   ~20MB Mesa .so caches per spawn). The shim is conditional so hosts WITHOUT
   Xvfb still exercise the "not installed" branch. The docker mock in
   test-helper also learned to consume `compose exec --user <user>` flags.

2. Cluster 2 (jsonl-cross-check, 7 failures) - `.opencode/scripts/jsonl-cross-check.sh`:
   `export LC_ALL=C` before any output, so `printf '%.1f'` always renders dot
   decimals regardless of host locale.

3. Cluster 3 (dev-stack, 1 failure) - root cause was the docker mock, not
   dev-stack.sh: `docker compose exec -T --user dev dev test -x ...` was
   mis-parsed by the fake (the `--user dev` flags were not consumed), so the
   recorded command never matched `"test -x node_modules/.bin/turbo"` and the
   fake answered exit 0 ("already installed") unconditionally. Fixed by the
   `--user` case in the mock's flag-consumption loop (test-helper.bash).

4. Additional (out of the three named clusters, required for a green run on
   this host): ssh-agent-forward.bats executed the REAL
   tools/opencode-docker wrapper, which copies `$OPENCODE_DOCKER_REPO/config`
   into the per-test HOME on every launch. This repo's config dir carries a
   developer-installed node_modules (~62MB, gitignored, deliberate plugin
   install), so 10 tests copied ~60MB each into the 512M /tmp tmpfs and the
   suite died with ENOSPC around test 8 (aborting the whole bats run at
   299/527). Fix: setup() now points `OPENCODE_DOCKER_REPO` at an empty
   per-test fixture dir, making the wrapper's config copy a no-op and the
   assertions independent of developer-local config state. Follow-up worth a
   separate ticket: the wrapper copying config/node_modules into
   ~/.opencode-docker/config is wasteful in real use too (cp has no exclude;
   would need an rsync-based or whitelist copy).

## Re-verify

> To be filled at re-verify time.
