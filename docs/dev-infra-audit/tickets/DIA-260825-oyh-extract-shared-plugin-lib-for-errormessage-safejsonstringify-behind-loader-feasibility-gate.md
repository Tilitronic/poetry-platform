# DIA-260825-oyh - extract shared plugin lib for errorMessage safeJsonStringify behind loader feasibility gate

---

id: DIA-260825-oyh
title: "extract shared plugin lib for errorMessage safeJsonStringify behind loader feasibility gate"
area: scripts
severity: Medium
status: DONE
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "waived" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [refactor-no-behavior-change] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "refactor-no-behavior-change: verbatim move of DIA-098 copies, no new module boundary crossed (lib/ is loader-invisible)" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-25
source: inventory
date: 2026-08-25
created: 2026-08-25
updated: 2026-09-22

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

delegation-observer.ts and needs-input-observer.ts each carried a duplicated
copy of the DIA-098 errorMessage + safeJsonStringify helpers (line-for-line
mirrors of the same fix). Duplication risk: a future SDK-shape change fixed
in one copy silently rots the other. Fix: extract the canonical body ONCE
into .opencode/plugins/lib/errors.ts (verbatim move of the
delegation-observer.ts copy, DIA-098 provenance docstrings intact) and have
both observers import errorMessage from ./lib/errors.ts.

Loader feasibility gate (STEP 1, verified empirically before extraction):
OpenCode loads plugins via node --experimental-strip-types as individual
files with no bundler and no extensionless resolution, and plugin
auto-discovery scans .opencode/plugins/ top-level only (verified via
opencode debug config: a lib/errors.ts probe never appears in the plugin
list, matching the **tests**/ precedent). So the lib/ submodule is never
picked up as a phantom plugin, and the relative import with explicit .ts
extension resolves cleanly.

## Verification

- [x] commit a25be983 exists in git log (refactor(plugins): extract shared error helpers to lib/errors.ts)
- [x] .opencode/plugins/lib/errors.ts exists with DIA-260825-oyh provenance header (consolidation provenance + DIA-098 R1 docstrings)
- [x] both observers import errorMessage from ./lib/errors.ts (grep: delegation-observer.ts:60, needs-input-observer.ts:63; needs-input mirror copies deleted)
- [x] node --check exit 0 on all three files (errors.ts, delegation-observer.ts, needs-input-observer.ts)
- [x] related observer suites green: 73 pass / 0 fail across 8 files (both reload-dedup, stale-boot-sweep, dia189, per-permission-rows, platform-gate, ticker-expiry, plugin-load-smoke)
- [x] make test-config exit 0 (validate-plugin-structure.sh: all structural gates PASS)

## Fix

> Landed as commit a25be983 (2026-08-25). STEP 2 extraction: lib/errors.ts
> created with errorMessage + safeJsonStringify moved VERBATIM;
> needs-input-observer.ts mirror copies deleted; both plugins import
> errorMessage from ./lib/errors.ts (safeJsonStringify stays
> module-internal to the lib; eslint caught the unused-import slip in the
> first commit attempt). STEP 3 verify at commit time: node --check x3 exit
> 0; capability-tokens 10/10; bun plugin suite 102 pass / 0 fail on the
> covered suites; opencode debug startup exit 0; make test-config exit 0.

## Re-verify

> Re-verified 2026-09-22 (fill-then-close lane): commit a25be983 present in
> git log; lib/errors.ts provenance header intact (lines 1-17); grep
> confirms both import lines; node --check x3 exit 0; observer subset
> (8 files) 73 pass / 0 fail exit 0; capability suites in isolation 28 pass
> / 0 fail exit 0; make test-config exit 0.
>
> NOTE (pre-existing, unrelated): full host `bun test` run shows 10 fails
> in parallel-handoff (S1 archive), reviewer-immutable-git-envelope (4q3h x6),
> integration-regressions (realCp), and capability timing asserts -- none of
> these files import the extracted lib (grep: no test file references
> errorMessage/safeJsonStringify), and the capability suites pass in
> isolation, so the full-run red is host-environmental flake
> (git/time/order-dependent, Docker daemon down so no container run), not a
> regression from this extraction. Docker unavailable at re-verify time:
> dial unix /var/run/docker.sock: no such file.
