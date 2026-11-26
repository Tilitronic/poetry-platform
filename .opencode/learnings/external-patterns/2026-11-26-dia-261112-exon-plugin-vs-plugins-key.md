# OpenCode plugin vs plugins key on the V2 tree (2026-11-26)

Date: 2026-11-26
Ticket: DIA-261112-exon 'opencode-version-migration-breaking-change-inventory-blockers-and-remove-or-adapt-rating'
Source: ai-specialist gate lane findings (evidence 2026-11-26), registered before the config edit per AGENTS.md section 2.5 step 1.

## The rename

- OpenCode 2.x canonical top-level config key is `plugins` (plural).
- `plugin` (singular) is a `deprecated: true` V1 alias. 2.3.2 still accepts it
  SILENTLY: no error, no warning.
- 1.x hosts (1.18.32) know ONLY `plugin`. A `plugins` key is ignored there, so
  plugins silently do not load.

## Client config (tui.json)

- 2.3.2 does not read `.opencode/tui.json` at all. V2 terminal config is one
  global `~/.config/opencode/cli.json` with key `plugins`; project-local client
  config is not migrated. Leave tui.json untouched in this slice (removal is
  task 8.5).

## OMO

- OMO 3.0.7 merges both spellings on read, so it imposes no key constraint.

## Validator coupling

- `scripts/validate-observer-dedupe.sh:80` reads `cfg.plugin` directly. After a
  rename to `plugins` it reads `[]` and prints a vacuous ok. Fix: read
  `cfg.plugins ?? cfg.plugin` and map V2 object entries through `.package`.
- `scripts/__tests__/batch-d-infra.test.mjs:641` has the same
  `opencodeConfig.plugin` vacuous read; use the same dual-form fallback.

## Failure modes

- 2.3.2 + singular: silent acceptance (works, but deprecated).
- 1.x + plural: silent non-loading (no plugins at all).
- Validator with one spelling only: vacuous green after the other spelling.

## Timing rule

- Use `plugins` only in the V2-only tree. Running a V1 1.18.32 container
  against a plural-key tree silently loads no plugins; V1 work stays on
  `omo-slim-changes`.

## Sources

- `knowledge/res-261112-1ima-opencode-version-migration/sources/config-schema.json`
  - `plugins` at ~456-469; deprecated `plugin` at ~732-755.
- `knowledge/res-261112-1ima-opencode-version-migration/sources/docs-migrate-v1.md`
  - `plugin` -> `plugins` rename at ~460-472.
- `docs/opencode-v2-migration-audit-register.md:27` (AUD-M1 unlisted
  plugin->plugins) and `:35` (AUD-m3 vacuous dedupe reader).
