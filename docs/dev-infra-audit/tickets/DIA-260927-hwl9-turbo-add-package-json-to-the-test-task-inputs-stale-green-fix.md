# DIA-260927-hwl9 - turbo: add package.json to the test task inputs (stale-green fix)

---

id: DIA-260927-hwl9
title: "turbo: add package.json to the test task inputs (stale-green fix)"
area: tests-infra
severity: Low
status: OPEN
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

turbo.json:27 test task inputs are `["src/**","vitest.config.ts","tsconfig*.json"]`; a dependency or test-script change that touches neither src/ nor the configs can replay a stale green cache. Add `"package.json"` to the inputs. This is a CORRECTNESS fix, not a speedup. Risk: low. Related: DIA-260831-c3d4 (closed, earlier inputs fix).

## Verification

- [ ] `touch` a package.json and confirm turbo RERUNS the test task instead of replaying the cache

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
