# DIA-260928-gpcc - tooling: no typecheck target covers .opencode/plugins and missing @types/node makes the repo-convention per-file tsc fail on untouched plugin files

---

id: DIA-260928-gpcc
title: "tooling: no typecheck target covers .opencode/plugins and missing @types/node makes the repo-convention per-file tsc fail on untouched plugin files"
area: scripts
severity: Medium
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-09-28
source: inventory
date: 2026-09-28
created: 2026-09-28
updated: 2026-09-28

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

<To be filled at creation time: what is wrong / what to build, with exact
files and line references where known.>

## Verification

<Acceptance criteria as checkboxes - how to prove the ticket is done.>

## Fix

## The gap

`pnpm typecheck` runs turbo over `apps/` and `packages/` only, and `make
test-config` runs `bun test` for the plugins, which transpiles without
type-checking. So plugin TS changes ship with no type-level gate.

## Evidence (captured 2026-09-28)

The repo-convention per-file invocation

```
npx tsc --noEmit --strict --skipLibCheck --target ESNext --module preserve --moduleResolution bundler <file>
```

exits 2 on BOTH changed files AND on untouched siblings:

- `lib/stall-sweep.ts` - 1 error, TS2580 (`process` missing `@types/node`)
- `delegation-observer.ts` - 66 errors, same error classes

while `.opencode/CHANGELOG.yaml` records the same command exiting 0 for
`delegation-observer.ts` on 2026-08-07. This is therefore an environment
regression since that date, not a defect of any one change.

## Why it matters

- A ticket or review citing `tsc` exit 0 for plugin code is currently
  unverifiable.
- Type errors in plugin TS ship silently.
- Reviewers cannot distinguish new type errors from baseline noise.

## Options to evaluate

- Add a make target that runs the per-file/per-project tsc over
  `.opencode/plugins` with `allowImportingTsExtensions` (matching the root
  tsconfig).
- Add a plugin-level tsconfig.
- Add `@types/node` as a devDependency.
- Wire the result into `make test-config` so the gate exists rather than
  relying on an ad-hoc command.
- Decide the baseline-noise policy: a known-noise list is a hollow gate -
  prefer fixing the baseline so exit 0 means clean.

## Acceptance criteria

- [ ] One command typechecks `.opencode/plugins` and it is wired into a make
      target.
- [ ] Exit 0 means no type errors.
- [ ] The current sibling baseline is either clean or explicitly and
      narrowly carved out with a recorded reason.

## Relations

Discovered while closing audit condition 1 for DIA-260928-nm2u; adjacent to
DIA-137 (tooling-stack decisions) and the AGENTS.md section 2.5 validate
step.

## Re-verify

> To be filled at re-verify time.
