# DIA-260927-k8nh - test-suite speedups: compose exec, parallel validators, turbo inputs, parallel pip

---

id: DIA-260927-k8nh
title: "test-suite speedups: compose exec, parallel validators, turbo inputs, parallel pip"
area: tests-infra
severity: Low
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: DIA-260926-ch1d
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-09-27
source: inventory
date: 2026-09-27
created: 2026-09-27
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
evidence: []

---

## Description

**Status: pure umbrella (all four items split to child tickets). This ticket stays OPEN until all children close.**

Origin: read-only test-suite recon under DIA-260926-ch1d (lane ses_f1ea8e1b2ffe0gZKORW1VGf23E; prior audit knowledge/archive/ana021-test-suite-audit/). Four low-risk test-pipeline wins. The dominant test cost in this repo is `make test-shell` (bats, ~24.6 s serial, the last step of the ~32 s pre-push chain) - these four items are the cheap, low-risk wins; bats parallelization is explicitly out of scope.

1. test-python: collapse the per-package `compose exec` calls (install + pytest for each of 3 packages) into a SINGLE exec with a bash loop. File: Makefile:191-196. [ESTIMATE] ~1.8 s saved (2x ~900 ms exec overhead). Risk: low (shell quoting gets trickier).
2. test-config: run the ~20 sequential read-only validators in parallel (background jobs + `wait`, or `xargs -P`). File: Makefile:235-268. [ESTIMATE] ~1.0 s saved (1.6 s -> ~0.4 s). Risk: low (validators are pure read-only, no shared state or output deps).
3. turbo: add "package.json" to the `test` task inputs. File: turbo.json:27 (current inputs: ["src/**", "vitest.config.ts", "tsconfig*.json"]). This is a CORRECTNESS fix, not a speedup: a dependency or test-script change that does not touch src/ or the configs can currently replay a stale green turbo cache. Risk: low.
4. test-python: parallelize the 3x `uv pip install`. File: Makefile:191-196. [ESTIMATE] ~2 s saved. Risk: low.

Non-goals (explicitly out of scope): bats `-j` parallelization (flaky-test risk from shared setup_file/teardown_file and temp-dir collisions), pytest-xdist, vitest pool tuning, vitest.workspace.ts unification, turbo --filter/--since (turbo caching already covers the no-change case).

## Verification

- [ ] `make test-config` exit 0; record before/after wall time.
- [ ] `make test-shell` green in-container (3 SKIPS tagged "selected container engine unavailable" are expected).
- [ ] `make test-python` green in-container.
- [ ] `make test-infra` green on the HOST (requires a live container engine).
- [ ] Item 3 specifically: touch a package.json and confirm turbo RERUNS the test task instead of replaying the cache.

## Split

This ticket is now a **pure umbrella** -- all four items have been split into separate tracer-bullet tickets:

| Child ticket    | Purpose                                                             |
| --------------- | ------------------------------------------------------------------- |
| DIA-260927-0zii | Collapse per-package compose exec into a single exec                |
| DIA-260927-shgj | Run read-only validators in parallel                                |
| DIA-260927-hwl9 | Add package.json to turbo test inputs (stale-green correctness fix) |
| DIA-260927-h5xs | Parallelize the 3x uv pip install (blocked by DIA-260927-0zii)      |

This ticket stays OPEN until all four children close.

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
