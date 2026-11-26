# DIA-260927-hwl9 - turbo: add package.json to the test task inputs (stale-green fix)

---

id: DIA-260927-hwl9
title: "turbo: add package.json to the test task inputs (stale-green fix)"
area: tests-infra
severity: Low
status: CLOSED
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: DIA-260927-k8nh
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-09-27
source: fix-lane
date: 2026-09-27
created: 2026-09-27
updated: 2026-10-13

# --- Session Attribution (v2 schema, optional) ---

session_id: ""
lane_id: ""
agent: ""
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: "" # ISO-8601; set on DISPATCHED, cleared on COMPLETE
files_touched:

- 'turbo.json'
- 'scripts/**tests**/batch-d-infra.test.mjs'
  artifacts: []
  evidence:
- 'turbo.json#tasks.test.inputs'
- 'scripts/**tests**/batch-d-infra.test.mjs#package-json-input'

---

## Description

turbo.json:27 test task inputs are `["src/**","vitest.config.ts","tsconfig*.json"]`; a dependency or test-script change that touches neither src/ nor the configs can replay a stale green cache. Add `"package.json"` to the inputs. This is a CORRECTNESS fix, not a speedup. Risk: low. Related: DIA-260831-c3d4 (closed, earlier inputs fix).

## Verification

- [x] Change package.json CONTENT and confirm turbo changes the task hash (mtime touch rejected as non-probative: turbo hashes content, not mtime)

## Fix

Added package.json to the base test task inputs in turbo.json. Added a regression assertion in scripts/`__tests__`/batch-d-infra.test.mjs requiring package.json in test.inputs.

## Re-verify

The focused batch-d-infra suite passed 64/64, and make test-config exited 0. The regression test asserts package.json is in the Turbo input list.

Runtime cache-miss experiment (run 2026-10-22, DIA-261021-51pm item 6e; CONTENT change, mtime touch rejected as non-probative):

- package: @poetry/phonetics-core (packages/phonetics-core), task `pnpm turbo run test --dry=json --filter=@poetry/phonetics-core`
- hash before: `b3837c03a1b746d7`
- probe: added one harmless key `"__cache_probe__": true` to packages/phonetics-core/package.json (content change)
- hash after: `90aa98d8d19cb976` - CHANGED, so package.json content is part of the test task hash (acceptance criterion met)
- restore: `git show HEAD:packages/phonetics-core/package.json > packages/phonetics-core/package.json`; `git diff -- empty` confirmed, re-run hash back to `b3837c03a1b746d7`

The earlier evidence limitation (experiment unrun at closure) is now closed.
