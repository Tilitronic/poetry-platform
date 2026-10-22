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
updated: 2026-10-22

# --- Session Attribution (v2 schema, optional) ---

session_id: ""
lane_id: ""
agent: ""
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: "" # ISO-8601; set on DISPATCHED, cleared on COMPLETE
files_touched: [".opencode/plugins/tsconfig.json", "Makefile", "package.json", "pnpm-lock.yaml", ".opencode/plugins/lib/registry.ts", ".opencode/plugins/__tests__/registry.test.mjs"]
artifacts: []
evidence: ["make test-typecheck exit 0", "plugin suite 570 pass / 1 skip / 0 fail", "make test-config exit 0", "make test-shell exit 0", "first make test-config after the registry change saw one transient failure in the skills validator, attributed to a concurrent session writing ticket files; green on clean re-run"]

---

## Description

<To be filled at creation time: what is wrong / what to build, with exact
files and line references where known.>

## Verification

<Acceptance criteria as checkboxes - how to prove the ticket is done.>

## Fix

`3a6822b1` added `@types/node` at the workspace root, created a tsconfig
scoped to the plugin surface, and added a `test-typecheck` make target -
deliberately NOT made a prerequisite of `test-config` at that point.
Measured effect: tsc previously aborted on TS2688 (no node type library);
a types-cleared probe baseline showed 120 per-file errors (TS2591 31,
TS2304 30, TS2584 23, TS2307 22, TS18048 4, TS7006 3, TS7017 2, TS2322 2,
TS2353 1, TS2345 1, TS2339 1); after the dependency, 3 remained.

`0a4caf7a` fixed those 3 remaining errors, all in the plugin session
registry: the union-keyed projection write, the rotate success return type
that was missing four fields the code already returned, and the
index-failure result whose `reserved_id` was declared required although it
cannot exist on the pre-reservation path. All three were
type-declaration drift, not runtime bugs; no suppression was used.

`421648d2` split the index-failure union member into pre-reservation
(`reserved_id?: never`) and post-reservation (`reserved_id: number`);
added the first regression guard for the post-reservation path; corrected
the projection comment to state the real invariant (the private
allowed-list plus the index signature, with per-key types unchecked
because the source row is unvalidated JSON).

`041206a3` was test-only: it added assertions for the remaining two
post-reservation index returns in the append path (the dirty-index return
and the apply-catch return), each with a tie-back that the persisted row's
sequence equals the reported `reserved_id`; renamed a misleadingly-named
test and moved test setup inside the guarded region.

Note for future readers: the union split does NOT enforce anything at the
write site, because both members share the same discriminant, so the
regression tests are the real guard.

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

- [x] One command typechecks `.opencode/plugins` and it is wired into a make
      target. MET: `make test-typecheck` runs the scoped tsc over the
      plugin surface (commit 3a6822b1).
- [x] Exit 0 means no type errors. MET: it exits 0 today, and it exits
      non-zero on a regression.
- [x] The current sibling baseline is either clean or explicitly and
      narrowly carved out with a recorded reason. MET by cleaning it: the
      3 remaining errors were fixed, and no known-noise list was
      introduced - fixing the baseline rather than carving it out was the
      chosen policy, since the ticket asked for that decision.

## Relations

Discovered while closing audit condition 1 for DIA-260928-nm2u; adjacent to
DIA-137 (tooling-stack decisions) and the AGENTS.md section 2.5 validate
step.

## Re-verify

> To be filled at re-verify time.

## Remaining work

The final wiring step was NOT done: `test-config` does not yet depend on
`test-typecheck`, so a green typecheck is still an ad-hoc run rather than
part of the documented gate chain. The one line in
`docs/dev-infra-audit/NEXT-RUN.md` recording this is deferred until the
concurrent session commits that file.

## Follow-ups (deferred, not blocking)

1. Rotate receipt divergence: the empty-registry early success returns
   `ok: true` with four telemetry fields omitted, while a bats test
   asserts those keys present on the populated path only - so an operator
   pointing rotate at a non-existent registry gets a success receipt
   missing contract keys. Deferred because changing it is a behaviour
   change.
2. `archiveBytes` duplicates `sourceBytes` on the success path (the
   archive is a byte copy of the source), and the diagnostics surface
   already reports the same number under another name.
3. Evidence-scope correction: the "no consumer" claim for the four rotate
   fields was derived from a plugin-scoped grep, but they are a CLI output
   contract asserted in bats. The conclusion (widen the type) was right;
   the supporting evidence was narrower than stated.
4. One transient `test-config` failure was attributed to the concurrent
   session but not diagnosed - no failing assertion text was captured.
   Next occurrence should capture the assertion and the mtime of the file
   it complains about.
5. The dirty-index test's precondition is inferred, not asserted: it
   relies on index construction failing during bootstrap. A one-line
   precondition assertion on the diagnostics "index dirty" flag would
   localize a future failure.
6. The registry test file's seed setup is still hand-built in three places
   inside one describe block; a seed helper would remove the duplication
   and one class of path drift.
