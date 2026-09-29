# DIA-260927-vmpa - dev-infra: tee the full make test-infra output (stdout and stderr) to a gitignored orchestrator-readable log at .opencode/session/test-infra.log

---

id: DIA-260927-vmpa
title: "dev-infra: tee the full make test-infra output (stdout and stderr) to a gitignored orchestrator-readable log at .opencode/session/test-infra.log"
area: scripts
severity: Low
status: CLOSED
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-09-27
source: inventory
date: 2026-09-27
created: 2026-09-27
updated: 2026-09-29

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

The orchestrator could not see the full `make test-infra` output: a chat
paste truncated it, hiding the Xvfb and plugin-suite failures that only a
complete read surfaced. What landed: `make test-infra` now tees complete
stdout+stderr into the gitignored, orchestrator-readable
`.opencode/session/test-infra.log`, appends the run's real exit code as a
final `==> test-infra exit code: N` trailer line, and returns that same
code unchanged.

Commits:

- 4a177a2f feat(makefile): tee test-infra stdout+stderr to the gitignored session log, exit code preserved
- f65b857f fix(dev-infra): extract the log wrapper to a bash-pinned helper so a pipefail-less /bin/sh cannot mask the exit code; add wrapper tests

Files:

- Makefile - the test-infra recipe now delegates to the wrapper
- scripts/test-infra-log.sh - new helper (truncate, fd/tee juggle, trailer line, bash pin)
- `scripts/__tests__/test-infra-log.bats` - new, 4 tests
- `scripts/__tests__/batch-d-infra.test.mjs` - S8 wiring assertions on the recipe-to-helper seam

## Verification

- [x] The log exists, is gitignored (`.gitignore:72` covers `.opencode/session/`), and the green host run's real exit code was recorded at `.opencode/session/test-infra.log:1919` (`==> test-infra exit code: 0`), cited as primary evidence in the closed tickets DIA-260827-wawy and DIA-260926-ch1d. Caveat for readers: the file today carries a `[stale]` marker, because a `make -n` probe executed the recipe and poisoned the evidence; the next real `make test-infra` rewrites it truthfully.
- [x] A pipefail-less /bin/sh cannot mask a failed run: the wrapper is bash-pinned (bash shebang, `bash scripts/test-infra-log.sh` call site in the recipe, `[ -n "${BASH_VERSION:-}" ]` guard), so `sh wrapper` exits 2 with "bash required" and a failing inner command yields wrapper exit 7 plus trailer `==> test-infra exit code: 7`.
- [x] Wrapper behaviour is covered by tests: `scripts/__tests__/test-infra-log.bats` (4 tests: success, failure exit-code carry, per-run truncation, non-bash guard) all pass in a full `make test-shell` run (exit 0), and `scripts/__tests__/batch-d-infra.test.mjs` S8 pins the recipe-to-helper seam (6 assertions; node run: 63 pass, 0 fail).
- [x] The log is truncated per run (`: >"$log"` in the wrapper, asserted by the truncation bats test and an S8 assertion) - the reviewer CLEARED the suspicion that the log appends across runs.
- [x] Finding (c) stdout/stderr interleaving nondeterministic: closed by DEVELOPER DISPOSITION (accepted as-is 2026-09-27, no code change) - the log is complete and reproducible ordering is not needed.
- [x] Finding (e) failure attribution changed on the console: closed by DEVELOPER DISPOSITION (accepted as-is 2026-09-27, no code change) - the wrapper target is the honest reporting point.

## Fix

Review findings from the section 2.4 two-axis review of 4a177a2f, one line each:

- (a) CRITICAL - the recipe ran `set -o pipefail` under /bin/sh with no SHELL override, so on a host whose /bin/sh lacks pipefail the trailer could record tee's 0 over a FAILED run: FIXED - wrapper is bash with an explicit shebang, a `[ -n "${BASH_VERSION:-}" ]` guard, a call-site `bash scripts/test-infra-log.sh`, and a bats test asserting `sh wrapper` exits 2 with "bash required".
- (b) MAJOR - the new behaviour was untested and AGENTS.md section 2.4 requires tests alongside dev-infra changes: FIXED - `scripts/__tests__/test-infra-log.bats` covers success, failure exit-code carry, per-run truncation and the non-bash guard; `batch-d-infra.test.mjs` S8 pins the recipe-to-helper seam.
- (c) MINOR - two `tee -a` writers append to the same file, so stdout/stderr interleaving in the log is nondeterministic (complete, not reproducible): ACCEPTED AS-IS by the developer on 2026-09-27 - the log is complete and reproducible ordering is not needed; no code change.
- (d) SUGGESTION - fd 3 leaked into the inner tee and two comments asserted unguaranteed behaviour: FIXED - inner tee gets `3>&-`; the pipefail and `--no-print-directory` comments corrected.
- (e) BRING TO THE DEVELOPER - the console is not byte-identical in two ways: one was requested (the `==> test-infra exit code:` trailer on the console), the other was not - a prerequisite failure now surfaces as `make: *** [Makefile:...: test-infra] Error 2` instead of `... test-shell] Error N`, i.e. the failure ATTRIBUTION changed: ACCEPTED AS-IS by the developer on 2026-09-27 - the wrapper target is the honest reporting point; no code change.

Disposition note: (c) and (e) were dispositioned ACCEPTED-AS-IS by the
developer on 2026-09-27 and are recorded here as the durable record of that
decision - both are closed WITHOUT a code change. (a), (b) and (d) are
closed by the fixes in f65b857f. The reviewer also CLEARED the suspicion
that the log appends across runs: the wrapper truncates it per run
(`: >"$log"`).

## Re-verify

> To be filled at re-verify time.
