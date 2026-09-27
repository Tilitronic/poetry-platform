# DIA-260926-ch1d - host test-shell failures: check-compose-config + validate-skills

---

id: DIA-260926-ch1d
title: "host test-shell failures: check-compose-config + validate-skills"
area: scripts
severity: Medium
status: CLOSED
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-09-26
source: inventory
date: 2026-09-26
created: 2026-09-26
updated: 2026-09-27

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

- knowledge/ana-260927-8yqj-host-test-shell-compose-config-failure/ana-260927-8yqj-host-test-shell-compose-config-failure-report.md
- .opencode/session/test-infra.log:1919 (==> test-infra exit code: 0)

---

## Description

Host `make test-infra` (which chains the `test-shell` target, Makefile:149) fails with 2 test failures. In-container `make test-shell` is green; the host path is red.

1. scripts/**tests**/check-compose-config.bats:179 - "compose config validation fails -> non-zero exit": expected exit 1, got 0. Area of this session's compose-config test work (commits 3322d57e superseded, 6a2896a3 "exercise the host path hermetically instead of skipping in-container").
2. scripts/**tests**/validate-skills.bats:561 - "compat: valid declarations across all four classes exit 0": expected exit 0, got 1. Cause line: skill 'compat-valid': requires_bash '4.0' cannot be satisfied, bash version unknown (host-side bash version detection gap).

Also observed (warning, not a failure): vendored bats drift - scripts/**tests**/vendor/bats-core at v1.11.0 vs bats-wrapper.sh pin v1.14.0 (DIA-121 drift check).

Impact: blocks the DIA-260827-wawy close-out (its condition is a green host `make test-infra`).

## Verification

- [x] `make test-shell` green on the host (0 failures).
- [x] `make test-infra` green on the host.

## Fix

F1 - check-compose-config.bats host-only failure. Root cause: a host-exported COMPOSE_ENGINE=podman is honoured by scripts/container-engine.sh in the override branch near lines 46-50, which skips the PATH probe and bypasses the test's fake docker, so the real host engine validated a valid config and returned 0. Pre-existing, introduced at 1a168d77. Fix commits: cebf6f31 (pin COMPOSE_ENGINE=docker in the failing test) and 5935b8f1 (drop the unreachable invalid-compose fixture, suite-level `unset COMPOSE_ENGINE`, version-agnostic comment). Status: FIXED and HOST-CONFIRMED.

F2 - validate-skills.bats:561 host-only failure. Root cause: the Fedora host runs a uk_UA locale, so `bash --version` prints the localized word for version and the English-word regex in scripts/validate-skills.sh never matched, yielding "bash version unknown". The earlier SIGPIPE/pipefail theory was FALSIFIED by the reviewer (host bash is 5.3.9, not 3.2). Fix commits: 64d40b49 (LC_ALL=C on the bash --version probe - locale-independent for every locale) and 652eacc4 (locale regression test). The SIGPIPE work in a9f4e20d + 04cc0b7e is retained as a real latent-bug guard, NOT as the F2 fix. Status: FIXED and HOST-CONFIRMED (the Fedora host `make test-shell` now reports 0 failures).

## Re-verify

> To be filled at re-verify time.
