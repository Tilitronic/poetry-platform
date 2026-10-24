## Why

A completed config/plugin audit (2026-08-27) found two latent risks in how the two
observer plugins (delegation-observer.ts, needs-input-observer.ts) are registered and
re-loaded:

(a) Doc/config drift: docs/dev-infra-audit/inventory.md lists explicit
`file:///workspace/.opencode/plugins/delegation-observer.ts` and
`file:///workspace/.opencode/plugins/needs-input-observer.ts` entries in the project
plugin array. The LIVE config registers observers ONCE via auto-discovery of
`.opencode/plugins/` and contains NO such explicit entries. If those documented entries
are ever revived, OpenCode would load each observer twice (explicit file:/// +
auto-discovery) -> duplicate hook handlers, duplicate registry rows, double notifications.

(b) In-process reload double-invocation: when OpenCode re-evaluates a plugin module
without a full process restart (and without invoking dispose), singleton side-effects
re-fire. Only delegation-observer.ts currently has globalThis reload guards (boot
evidence + stall-sweep interval, landed by the already-implemented
plugin-reload-boot-sweep-dedup change). needs-input-observer.ts has ZERO reload guards:
its permission watchdog timers, title-suffix boot retro pass, TUI toast, and ticker
boot-seed all re-run on reload, stacking timers and re-firing notifications.

This change closes both risks: a single registration source of truth enforced by a
make test-config dedupe gate, and globalThis reload guards extended to every singleton
side-effect in needs-input-observer (and any remaining unguarded one in
delegation-observer).

## What Changes

- Establish the invariant: observer plugins are registered EXACTLY ONCE via
  auto-discovery of `.opencode/plugins/`. No config-layer plugin array (project
  opencode.jsonc, oh-my-opencode-slim.jsonc, tui.json, docker config) may contain an
  explicit entry (file:///, ./, or bare name) for a plugin that also lives in
  `.opencode/plugins/`.
- Fix the doc/config drift: correct docs/dev-infra-audit/inventory.md so the documented
  plugin array reflects auto-discovery (remove or annotate the stale file:/// observer
  entries). This removes the trap that invites a future double-load.
- Add scripts/validate-observer-dedupe.sh and wire it into make test-config. The check
  fails if any observer plugin is registered twice: (i) an explicit plugin-array entry
  whose resolved basename matches an auto-discovered observer in `.opencode/plugins/`,
  or (ii) the same basename appears twice within a single plugin array.
- Extend the globalThis guard pattern (already proven in delegation-observer.ts) to ALL
  singleton side-effects in needs-input-observer.ts: permission watchdog timer set,
  title-suffix boot retro pass, TUI toast dedupe set, ticker boot-seed/re-arm. Update
  its dispose hook to clear the new globalThis Symbols.
- Audit delegation-observer.ts for any OTHER unguarded singleton side-effect beyond
  boot/stall-sweep (e.g., routingWriteTimer) and apply the same globalThis guard where
  found unguarded. Boot/stall-sweep are already guarded by
  plugin-reload-boot-sweep-dedup (complementary, not duplicated).
- Add unit tests in
  .opencode/plugins/**tests**/needs-input-observer.reload-dedup.test.mjs asserting each
  guard suppresses on a second factory invocation / module re-evaluation.

## Capabilities

### New Capabilities

None. This is a reliability + config-drift fix within existing plugins and config. No
spec-level behavior changes.

### Modified Capabilities

None.

## Impact

- Config (docs): docs/dev-infra-audit/inventory.md (doc correction only; no runtime
  config change needed because the live config already uses auto-discovery).
- Scripts: scripts/validate-observer-dedupe.sh (new, bash-3 compatible, coreutils + jq
  only).
- Makefile: test-config target gains one line (bash scripts/validate-observer-dedupe.sh).
- Plugins: .opencode/plugins/needs-input-observer.ts (add globalThis guards + dispose
  clears them); .opencode/plugins/delegation-observer.ts (audit + extend guard only if
  an unguarded singleton side-effect is found).
- Tests: .opencode/plugins/**tests**/needs-input-observer.reload-dedup.test.mjs (new).
- Dependencies: none added (jq already required by other validate scripts).
- Systems: registry.jsonl, ticker.json, TUI toasts, terminal titles - dedupe prevents
  duplicate writes/notifications on reload.

## Alternatives considered

- Broad unique-ID / cross-layer duplicate assertion across ALL plugins (not just
  observers): rejected - the risk is specific to observer plugins that are ALSO
  auto-discovered; npm plugins (oh-my-opencode-slim, ponytail, envsitter-guard)
  legitimately appear in multiple config layers (e.g., OMO in both opencode.jsonc and
  tui.json) and are never auto-discovered, so a broad cross-layer check would
  false-positive on OMO. Scoping the check to the auto-discovered observer set is
  false-positive-free. Evidence: Tier-1 (live config inspection - opencode.jsonc plugin
  array L708-719 has only 3 npm entries; observers load via auto-discovery).
- Remove auto-discovery and register observers explicitly once: rejected - auto-discovery
  is the project's chosen single source of truth (DIA-188 / OMO 2.2.15 self-sufficiency);
  explicit registration reintroduces the drift class this change removes. Evidence:
  Tier-1 (live config + AGENTS.md section 2.5).
- Time-based reload dedup (e.g., 30s window): rejected - conflates full process restart
  with in-process reload (proven wrong in plugin-reload-boot-sweep-dedup live 26s smoke
  test). Process-scoped globalThis state is the correct mechanism. Evidence: Tier-1
  (plugin-reload-boot-sweep-dedup design.md D1 alternatives).
- Module-level let for guard state: rejected - module-level state resets on module
  re-evaluation (the exact reload semantics this change must survive). globalThis
  survives re-evaluation. Evidence: Tier-1 (plugin-reload-boot-sweep-dedup design.md D2
  alternatives).
- Status-quo / do nothing: rejected - leaves a live double-load trap (if inventory.md
  entries are revived) and double-fires needs-input-observer side-effects on every
  in-process reload. Evidence: Tier-1 (audit findings, this ticket).

Chosen option: auto-discovery as single source of truth + scoped make test-config dedupe
gate + globalThis guards on all needs-input-observer singleton side-effects - because it
is false-positive-free, distinguishes restart from reload, and closes both latent risks
with the already-proven guard pattern.

## Testing Decisions

**What makes a good test for this change:** the existing validate-\*.sh pattern (bash-3,
coreutils + jq, exit 1 on failure, wired into make test-config) is the right seam for the
dedupe gate. For the plugin guards, the existing bun plugin test harness
(.opencode/plugins/**tests**/) is the right seam - mirror
delegation-observer.reload-dedup.test.mjs.

**Which modules will be tested:** (1) scripts/validate-observer-dedupe.sh exercised
against real configs + a broken fixture (an explicit observer entry added to a temp
config -> exit 1; clean config -> exit 0). (2)
needs-input-observer.reload-dedup.test.mjs asserts each globalThis guard suppresses on
second factory invocation and that dispose clears the Symbols.

**Prior art in the codebase:** scripts/validate-agent-names.sh,
scripts/validate-dia-mentions.sh (validate pattern);
.opencode/plugins/**tests**/delegation-observer.reload-dedup.test.mjs (guard test
pattern, already implemented by plugin-reload-boot-sweep-dedup).
