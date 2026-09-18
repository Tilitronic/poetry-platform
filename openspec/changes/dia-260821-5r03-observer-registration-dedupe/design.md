## Context

Observer plugins (delegation-observer.ts, needs-input-observer.ts) live in
`.opencode/plugins/`. OpenCode auto-discovers and loads every `*.ts` there exactly once -
this is the project's single registration source of truth (DIA-188 / OMO 2.2.15
self-sufficiency). The live project `opencode.jsonc` plugin array (L708-719) contains only
three npm entries: `oh-my-opencode-slim@2.2.15`, `@dietrichgebert/ponytail`,
`envsitter-guard@0.0.4`. No explicit observer entries exist today.

Two latent risks remain (audit 2026-08-27):

1. `docs/dev-infra-audit/inventory.md` (L60) documents explicit `file:///...` observer
   entries that are ABSENT from the live config. Reviving them would double-load each
   observer (explicit + auto-discovery).
2. On in-process reload (module re-evaluation without dispose), singleton side-effects
   re-fire. delegation-observer.ts already guards its boot evidence
   (`BOOT_EMITTED_KEY`) and stall-sweep interval (`STALL_SWEEP_KEY`) via globalThis
   Symbols (plugin-reload-boot-sweep-dedup, already implemented). needs-input-observer.ts
   has NO such guards.

Governing module doc: `.sdd/opencode-config/architecture.md` (opencode-config boundary;
ADRs on batch pattern D, singleton-batch exemption, instance separation). This change
operates within that boundary - it does not introduce a new module.

Constraints:

- Bash-3 compatible validators (no `[[ ]]`, no associative arrays).
- No new dependencies (coreutils + jq only).
- ASCII-only input/output (DIA-079).
- Fail-hard on duplicate registration (exit 1, wired into make test-config).
- Plugin guards must survive module re-evaluation, not just factory re-invocation.

See proposal.md for motivation and scope.

## Goals / Non-Goals

**Goals:**

- Enforce single-source-of-truth: observers registered exactly once via auto-discovery;
  no explicit entry for an auto-discovered observer in any config layer.
- Remove the doc/config drift trap in inventory.md.
- Add a false-positive-free make test-config dedupe gate.
- Add globalThis reload guards to every singleton side-effect in needs-input-observer.ts
  (permission watchdog timers, title-suffix boot retro pass, TUI toast dedupe, ticker
  boot-seed/re-arm) + clear them in dispose.
- Audit delegation-observer.ts for any remaining unguarded singleton side-effect and guard
  it.

**Non-Goals:**

- Changing auto-discovery behavior (it works correctly).
- Cross-layer duplicate detection of npm plugins (OMO legitimately appears in
  opencode.jsonc + tui.json; not auto-discovered, so out of scope).
- Runtime plugin-loading validation (the gate checks registration identity, not load
  success).
- Re-implementing delegation-observer boot/stall-sweep guards (already done by
  plugin-reload-boot-sweep-dedup).

## Decisions

### D1: Auto-discovery is the single registration source of truth

**Choice:** Observers load only via auto-discovery of `.opencode/plugins/*.ts`. The
dedupe validator treats the set of basenames in `.opencode/plugins/*.ts` as the canonical
observer registry. Any explicit plugin-array entry whose resolved basename is in that set
is a duplicate.

**Rationale:** auto-discovery is already the live mechanism; making it the enforced
invariant removes the drift class. Explicit entries for auto-discovered plugins are always
redundant (and dangerous if revived).

**Alternatives considered:** remove auto-discovery and register observers explicitly once
(rejected - reintroduces the drift class this change removes); broad cross-layer unique-ID
check (rejected - false-positives on OMO). See proposal.md Alternatives.

### D2: Scoped dedupe validator (false-positive-free)

**Choice:** `scripts/validate-observer-dedupe.sh` enumerates auto-discovered observer
basenames from `.opencode/plugins/*.ts`. For each config layer (`opencode.jsonc`,
`oh-my-opencode-slim.jsonc`, `tui.json`, `tools/opencode-docker/config/opencode.json`), it
parses the plugin array, resolves each entry to a canonical basename (strip `file:///`,
`./`, `@scope/`, version `@x.y.z`, `.ts`/`.js`), and fails if (i) that basename is in the
auto-discovered observer set, or (ii) the same basename appears twice within one array.

**Rationale:** scoping to the auto-discovered observer set means npm plugins
(oh-my-opencode-slim, ponytail, envsitter-guard) are never flagged - they are not in
`.opencode/plugins/`, so they can never be explicit+auto-discovery duplicates. OMO
appearing in both `opencode.jsonc` and `tui.json` is not flagged because OMO is not
auto-discovered (no false positive). Within-array duplicates of npm plugins don't exist.
The check is therefore false-positive-free while still catching the real risk (an explicit
observer entry, or a within-array observer duplicate).

**Alternatives considered:** broad cross-layer unique-ID assertion (rejected - false
positives on OMO); see proposal.md.

### D3: globalThis guard pattern for needs-input-observer singleton side-effects

**Choice:** mirror delegation-observer.ts. Add module-scope Symbol keys and globalThis-
backed stores:

- `NEEDS_INPUT_PERM_TIMERS_KEY = Symbol.for("needs-input-observer.permissionTimers")` -
  store the `pendingPermissionTimers` Map (or a guard flag) on globalThis so a reload
  clears/reuses prior timers instead of stacking.
- `NEEDS_INPUT_TITLE_BOOT_KEY = Symbol.for("needs-input-observer.titleSuffixBootDone")` -
  guard the boot retro pass (rename existing sessions/ptys) so it runs once per process;
  reload skips it.
- `NEEDS_INPUT_TOAST_KEY = Symbol.for("needs-input-observer.notifiedAsks")` - a Set of
  `session_id+reason` already toasted, so a reload does not re-toast a pending ask.
- `NEEDS_INPUT_TICKER_BOOT_KEY = Symbol.for("needs-input-observer.tickerBootSeeded")` -
  guard the ticker boot-seed + watchdog re-arm so reload does not double-seed.

Before each side-effect, check the globalThis flag; if set, skip. After running, set the
flag. A full process restart clears globalThis, so a new process re-runs the side-effect
(correct). `dispose` clears all four Symbols (mirror delegation-observer dispose).

**Rationale:** globalThis survives module re-evaluation (the reload semantics); process-
scoped state distinguishes in-process reload (suppress) from full restart (run). This is
the exact pattern already proven in delegation-observer.ts (`BOOT_EMITTED_KEY` /
`STALL_SWEEP_KEY`).

**Alternatives considered:** module-level `let` (rejected - resets on re-eval); time-based
dedup (rejected - conflates restart/reload); see proposal.md.

### D4: delegation-observer completeness audit

**Choice:** audit delegation-observer.ts for any singleton side-effect beyond boot/stall-
sweep that lacks a globalThis guard (candidate: `routingWriteTimer` at L1841, a per-instance
setTimeout cleared only in dispose). If found unguarded on reload, apply the same
globalThis guard. Boot/stall-sweep are already guarded (plugin-reload-boot-sweep-dedup) -
this task does NOT re-implement them.

**Rationale:** the audit flagged "notifications/hooks unguarded in BOTH plugins".
delegation-observer's boot/stall are done; this closes any remaining gap without
duplicating prior work.

**Alternatives considered:** re-implement boot/stall guards here (rejected - duplicate of an
already-implemented change).

### D5: No delta spec

**Choice:** `skip_specs: true`. No capability change; behavior of observers is unchanged
(dedupe is internal reliability).

**Rationale:** specs describe externally visible behavior; this change prevents duplicate
internal side-effects, not a behavior change.

## Seams

**Test seams:**

- `scripts/validate-observer-dedupe.sh` - the dedupe gate itself. Exercised by
  `make test-config` and by a broken-fixture test (add an explicit observer entry to a temp
  config -> exit 1).
- `.opencode/plugins/__tests__/needs-input-observer.reload-dedup.test.mjs` - bun harness
  asserting each globalThis guard suppresses on second factory invocation and dispose clears
  the Symbols. Mirror `delegation-observer.reload-dedup.test.mjs`.

**Public boundaries:**

- `make test-config` target (the dedupe gate's public boundary).
- The plugin factory + dispose hook (guard seams inside needs-input-observer.ts).

**No new production module boundaries:** all changes are internal to existing plugins + one
new validator script.

## Risks / Trade-offs

**Risk:** globalThis flag persists across module re-evaluations but resets on process
restart.
-> **Mitigation:** intended - in-process reload suppresses duplicate side-effects; full
restart re-runs them (correct; boot markers reflect latest state).

**Risk:** the dedupe validator assumes jq is available.
-> **Mitigation:** jq is already required by other validate scripts; dev environment
guarantees it.

**Risk:** validator checks registration identity, not runtime load success (a path may
exist but the plugin fails to load).
-> **Mitigation:** runtime load is caught by OpenCode startup logs + functional smoke; out
of scope for make test-config.

**Risk:** a future observer plugin added to `.opencode/plugins/` but also explicitly listed
would be caught only by this validator (not by path-existence checks).
-> **Mitigation:** this is exactly the gap the validator closes; the scoped observer-set
check catches it.

**Trade-off:** the validator does not check npm package-name duplicates across layers.
Acceptable - npm resolution fails at install time, not config-validation time; the risk
class this ticket addresses is observer double-load via explicit+auto-discovery.

## Migration Plan

**Deployment:** corrective (inventory.md doc fix) + additive (validator script) + internal
plugin guards. No migration needed; auto-discovery continues to load observers.

**Rollback:** revert the commit. Guards and validator removed; auto-discovery unchanged.

**Config chain verification:**

1. `make test-config` passes (including new `validate-observer-dedupe.sh`).
2. bun plugin test suite passes (`needs-input-observer.reload-dedup.test.mjs`).
3. Restart OpenCode + functional smoke (observers load once; needs-input flow fires single
   toast/ticker on a simulated reload-free path).
4. `@ai-auditor` review of the config + plugin change.
5. `CHANGELOG.yaml` append + validate + render.

**Open Questions:** none.
