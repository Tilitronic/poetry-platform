## Context

See `proposal.md` for motivation and `specs/workspace-preset-selection/spec.md` for the behavior contract. The embedded OMO preset manager currently keeps a runtime preset in module state and best-effort rewrites a global user configuration value. Its command is documented as live switching, although its implementation tells the developer to restart. The launcher currently enters OpenCode through the container entrypoint without a preset-resolution step.

This design stays in the existing OpenCode configuration and launcher boundary governed by `.sdd/opencode-config/architecture.md`. Host launcher shell remains bash-3-compatible where it is touched, per `.sdd/dev-infra/architecture.md` ADR 8. No new module, service, dependency, or preset registry is introduced.

## Goals / Non-Goals

**Goals:**

- Resolve a deterministic, project-scoped preset before agent setup.
- Persist selections safely across processes and workspaces.
- Give every public control surface exact validation and truthful outcomes.

**Non-Goals:**

- Changing preset definitions or their model routing.
- Live model switching, an interactive picker, aliases, case-insensitive names, or environment-variable persistence.
- Migration of moved or recloned workspaces.

## Decisions

1. **Canonical path is the sole key.** The selection helper obtains the workspace `realpath` and uses that string as the map key. This meets the developer-approved symlink behavior without coupling independent clones through Git identity. Repository/remote lookup is excluded.

2. **One durable map, not per-project configuration rewrites.** A local user-data store maps canonical paths to exact preset names. The helper locks, parses, validates, atomically replaces, and re-reads the map before acknowledging a write. This preserves unrelated workspace choices and removes the existing best-effort global `preset` write. Alternatives rejected: rewriting `.opencode/oh-my-opencode-slim.jsonc` (changes shared project definitions) and an unverified best-effort write (can falsely claim success).

3. **Resolve at the launcher boundary before agent construction.** The launch path obtains the effective preset from `PRESET`, then the persistent map, then no preset. It validates names from the effective configuration's `presets` keys. It supplies the resolved choice to OpenCode before plugin/agent setup and prints the name or no-preset state plus source. Invalid explicit or stored data stops the launch before setup; absence is not an error. This distinguishes first launch from configuration corruption and prevents unintentional expensive routing.

4. **Selectors only schedule the next launch.** `/preset NAME` and `make preset NAME=NAME` call the same selection helper. They require exactly one name, change no in-process runtime preset or TUI model state, and report the canonical key and next-launch effect only after verified persistence. No-argument calls report stored selection or `none` and usage.

5. **`PRESET` is a non-persistent highest-priority override.** `make opencode PRESET=NAME` passes the value through the existing launcher path. It is exact-match validated, does not modify the store, and overrides a valid stored value for that invocation only.

## Approach

Extend the embedded OMO configuration/command integration with a focused selection-store and resolution seam, replacing the runtime manager's global best-effort persistence and live-switch presentation. Update the root Makefile and the container launch path to route `preset` and `PRESET` through the same resolver before `dev-entrypoint.sh opencode`. Update the preset-switching documentation to describe next-launch behavior.

The effective preset registry remains `.opencode/oh-my-opencode-slim.jsonc`; no config schema is changed. Existing runtime-preset state is not used to select or mutate current-session models. The selection helper is the only owner of storage format, lock lifecycle, atomic update, and verification.

## Seams

The developer has confirmed these public test seams:

1. **Selector command seam:** `/preset NAME` accepts/rejects input, persists only verified exact selections, and leaves current-session model state unchanged.
2. **Make selector seam:** `make preset NAME=NAME` exposes the same selection behavior from a terminal.
3. **Startup resolution seam:** `make opencode PRESET=NAME` and normal launch resolve precedence before agent setup and print source.
4. **Selection-store seam:** isolated user-config directory tests exercise canonical keys, lock/read/atomic-write/re-read verification, and independent workspace entries.
5. **Fail-closed launch seam:** invalid override, malformed data, and stale stored names abort before agent setup with actionable diagnostic details.

## Test Strategy

Use isolated user-config directories and two temporary canonical workspaces. Test successful `/preset` and Make selection, a new-process read, symlink sharing, clone/path separation, one-run override precedence, and no current-session model change. Test unknown, non-exact, stale, corrupt, and malformed selections fail before agent setup with name/key/available-name diagnostics. Inject lock, parse, write, and verification failures; assert no `Saved` output and preservation of unrelated entries. Assert every startup output includes effective preset/no-preset and source.

The existing Bun tests for `preset-manager` and launcher Bats tests are the closest seams. Tests must be written at the seams above before production changes; no internal state-only test substitutes for a launch assertion.

## Risks / Trade-offs

- [A moved workspace loses its selection] -> Intentional Q4 behavior; selection is re-established explicitly.
- [Concurrent selectors contend for the store] -> Exclusive lock plus re-read verification prevents false acknowledgement and lost unrelated entries.
- [A removed preset blocks a launch] -> Intentional fail-closed behavior; diagnostics identify the name, canonical key, and available replacements.
- [Container and host paths differ] -> Define and test the canonical workspace identity at the launch boundary, using the path visible to the process that owns the selection store.

## Migration Plan

1. Ship the selector integration without changing any existing preset definitions.
2. Existing global preset behavior is not imported as a workspace selection; absent workspace entries resolve to no preset.
3. On rollback, remove the selector integration and ignore the selection store. Retain stored selections and leave project preset definitions unchanged.

## Open Questions

None.
