## Why

Changing an OpenCode preset does not reliably survive a restart for one workspace while preserving choices made in other workspaces. A durable, project-scoped selector is needed so a developer deliberately chooses the routing and cost profile used by the next launch.

## What Changes

- Add project-scoped persisted preset selection, keyed only by the canonical absolute workspace path produced by `realpath`.
- Add `/preset NAME` and `make preset NAME=NAME` to validate and persist a choice for the next launch.
- Add required `make opencode PRESET=NAME` one-run selection with highest precedence.
- Resolve the effective preset before agent setup and print its name and source at startup.
- Fail closed for invalid explicit or stored values; preserve invalid stored data for diagnosis rather than silently falling back.
- Treat no stored selection and no `PRESET` override as the documented default: no preset.

## Capabilities

### New Capabilities

- `workspace-preset-selection`: Persist, resolve, validate, and report a per-workspace OpenCode preset selection without changing the preset definitions.

### Modified Capabilities

None.

## Impact

- Affects the OpenCode launch integration, the Makefile command surface, and local user selection data.
- Preset names remain owned by the effective `.opencode/oh-my-opencode-slim.jsonc` configuration for the launch. The existing global `preset` and `presets` fields are the current registry surface (Tier-1: `.opencode/oh-my-opencode-slim.jsonc:3-6`).
- The selection store must support locking, parse/validation, atomic replacement, and post-write verification while preserving other workspace entries.
- This stays within the existing OpenCode configuration and launcher boundary. It does not create a new module, dependency, public network API, schema/state service, or preset definition.

## Testing Decisions

A good test proves the public selection and startup seams, not internal storage mechanics: a selection made by `/preset NAME` or `make preset NAME=NAME` must survive a new process, remain isolated to its canonical workspace key, and only affect the next launch. Tests must use an isolated user-config directory and prove `PRESET=NAME` precedence, no live current-session model change, exact-name validation, fail-closed stale/unknown values before agent setup, truthful write failure output, and startup reporting of effective preset plus source.

The relevant test modules are the launcher integration and Make command surfaces. Existing configuration tests and the comment-preserving preset script are prior art for validating preset membership before changing configuration (Tier-1: `scripts/promo-preset-apply:153-162,223-237`).

## Rollback Plan

Remove the selector integration and ignore the local workspace-selection data. Do not alter existing project preset definitions or delete stored selection entries; this preserves a reversible rollback and avoids data loss.

## Alternatives considered

- Canonical workspace-path selection: use `realpath` absolute workspace paths as keys, with explicit persisted selection and one-run override - chosen per Q4-Q12; it shares selections through symlinked launches without incorrectly coupling clones or moved workspaces.
- Repository identity selection: key selections by remote or repository name - rejected by developer decision Q4 because different clones and moved repositories must require a fresh choice; it also conflicts with the stated no-remote-fallback rule.
- Status-quo / do nothing: retain only the existing global active preset pointer - rejected because it does not provide durable per-workspace selection (Tier-1: `.opencode/oh-my-opencode-slim.jsonc:3,6`; `scripts/promo-preset-apply:15`).

Chosen option: canonical workspace-path selection - because Q4 requires `realpath` scoping and Tier-1 shows the existing preset registry is global rather than workspace-scoped.
