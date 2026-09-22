# DIA-260827-6mhp - Docs overstate pnpm test as all tests

---

id: DIA-260827-6mhp
title: "Docs overstate pnpm test as all tests"
area: docs
severity: Low
status: CLOSED
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: DIA-260827-wfcx
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-27
source: baseline
date: 2026-08-27
created: 2026-08-27
updated: 2026-09-09

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

docs/onboarding.md:43-50 and 290-299 call pnpm test "all tests". It runs only four workspace test tasks, omitting shell/config/Python/plugin/embedded OMO suites.

Reaudit (DIA-260827-wfcx, 2026-08-31) confirms: docs/onboarding.md:43-50,290-299 calls pnpm test 'all tests'. Impact: a developer sees exit 0 while OMO/plugins are red and Python does not run. Correct fix: rename the command 'workspace JS tests' and document one canonical aggregate gate.

## Verification

Rename to "workspace JS tests"; document one canonical all-suite command.

## Fix

Applied in docs/onboarding.md only (docs-only, no code changes):

1. Line 49 (quickstart block): `pnpm test  # runs all tests` renamed to
   `pnpm test  # runs workspace JS tests`.
2. Line 296 (Root Commands table): `Run all tests (via turbo)` renamed to
   `Run workspace JS tests (via turbo)` (table re-padded for new column width).
3. Lines 303-307: added one scope note. `pnpm test` covers only the workspace
   JS suites (vitest via turbo: author-studio, data-contracts, editor-engine,
   phonetics-core); it does NOT cover shell/config, Python, plugins, or
   embedded OMO. Full gate (one line):
   `pnpm test && make test-infra && make test-config && make test-omo`.
4. Package Status table: 3 stale `Not yet` cells updated to `vitest` for
   data-contracts, phonetics-core, and author-studio, matching the four real
   `"test": "vitest run"` suites in package.json so the table no longer
   contradicts the scope note.

## Re-verify

- `grep -n "all tests" docs/onboarding.md`: zero matches (exit 1). Remaining
  "all" claims (`pnpm dev` all apps, `pnpm lint` all code) are out of scope.
- `grep -n "workspace JS tests"`: lines 49 and 296. Full gate line at 307,
  ASCII-clean.
- Fix-loop re-review cycle 1/2: Critical + Major findings both
  verified-closed. GO.
