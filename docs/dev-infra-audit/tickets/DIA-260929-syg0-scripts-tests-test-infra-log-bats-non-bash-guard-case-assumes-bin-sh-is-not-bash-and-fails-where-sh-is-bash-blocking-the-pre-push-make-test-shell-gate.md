# DIA-260929-syg0 - scripts/**tests**/test-infra-log.bats: non-bash guard case assumes /bin/sh is not bash and fails where sh is bash, blocking the pre-push make test-shell gate

---

id: DIA-260929-syg0
title: "scripts/**tests**/test-infra-log.bats: non-bash guard case assumes /bin/sh is not bash and fails where sh is bash, blocking the pre-push make test-shell gate"
area: scripts
severity: Medium
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-09-29
source: inventory
date: 2026-09-29
created: 2026-09-29
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

- Symptom: the "wrapper: fails loud through a non-bash shell" case in
  `scripts/__tests__/test-infra-log.bats` failed with 0 not 2 on hosts where
  `/bin/sh` IS bash, blocking the husky pre-push hook (`make test-shell`).
- Mechanism: the case ran `sh "$WRAPPER"` and asserted exit 2 plus the
  "bash required" message. That assertion holds only where `/bin/sh` is NOT
  bash: where sh IS bash, `sh script` runs bash in POSIX mode, `BASH_VERSION`
  IS set, and the wrapper's guard at `scripts/test-infra-log.sh:24`
  (`[ -n "${BASH_VERSION:-}" ] || { ...; exit 2; }`) correctly does not fire -
  so the wrapper ran to completion and the case observed exit 0.
- The failure is environment-specific, not a product defect: the wrapper
  guard itself is CORRECT and was left untouched. The guard exists so a
  pipefail-less non-bash `/bin/sh` cannot mask a failed `make test-infra`
  run; on a host whose sh is bash the guarded path is simply unreachable,
  which is exactly what the guard intends.
- Required behaviour: the case must exercise a genuinely non-bash shell
  where one exists, skip (never falsely pass) where none exists, and keep
  asserting exit 2 + "bash required" unchanged.

## Verification

- [x] The case exercises a non-bash interpreter on hosts that provide one,
      and still asserts exit 2 plus "bash required". Evidenced by the
      single-file bats run below (dash branch taken, 4 ok / 0 not ok).
- [x] Where no non-bash shell exists, the case skips with an explicit reason
      (never a false green) instead of failing. Satisfied by the skip branch
      in the case (reason string above, Fix section); its proving run is
      DEFERRED - see S-C below.
- [x] EVIDENCED - single bats file run: `bats
scripts/__tests__/test-infra-log.bats` exits 0 with 4 ok / 0 not ok, the
      guard branch taken = dash (dash present at /usr/bin/dash, busybox absent,
      /bin/sh is dash here - SH_IS_NOT_BASH), i.e. the dash branch ran, no skip.
- [x] EVIDENCED - full shell gate: `make test-shell` exits 0 with 724 ok /
      0 not ok.
- [x] EVIDENCED - the wrapper guard is unchanged: `scripts/test-infra-log.sh`
      is not among the files this ticket touched.

## Fix

- File touched: `scripts/__tests__/test-infra-log.bats` (the single guard
  case only; `scripts/test-infra-log.sh` untouched).
- What changed and why: the case no longer assumes `sh` is a non-bash shell.
  It now (1) prefers `dash` when `command -v dash` succeeds - a real non-bash
  shell, so the guard path is genuinely exercised; (2) otherwise, if `sh`
  reports `BASH_VERSION`, `skip`s with an explicit reason ("/bin/sh is bash
  here and dash is unavailable; the non-bash guard path is unreachable") so
  the case is never a false green on hosts with no non-bash shell; (3)
  otherwise falls back to `sh`, which is already a non-bash shell there. The
  run line became `run $nonbash "$WRAPPER" ...`; the assertions (status 2,
  "bash required") are unchanged.
- commit: see git log for this ticket id

## Deferred (accepted, not fixed in this commit, re-review da8f30cc cycle 1)

- S-B (Standards, Minor): the pre-commit prettier pass rewrote the dunder path
  `scripts/__tests__/test-infra-log.bats` to `scripts/**tests**/...` in this
  ticket's H1, its frontmatter `title`, and the tickets README index row.
  Tooling is unaffected (slugify/fm_field/YAML fine); the human-readable
  title names a path that does not exist. Repo-wide prettier behaviour, not
  novel to this ticket - fix belongs in a dedicated change (backticks around
  the path in H1 plus escaping the title value, or a prettier-ignore), not
  here.
- S-C (Spec, Minor): the new skip branch has no proving run - the supplied
  evidence covers only the dash branch ("no skip"). A host with no dash and
  bash-as-`sh` takes the skip path, so the guard's only behavioural coverage
  is absent on exactly the host class that reported the original failure.
  Follow-up: add a hermetic case that forces the no-dash path (shadow PATH
  with a fake `sh` exporting BASH_VERSION) and asserts a reported skip, or
  record a real run on a bash-as-`sh` host.

## Re-verify

> To be filled at re-verify time.
