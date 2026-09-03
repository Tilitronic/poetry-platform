## Why

`.opencode/opencode.jsonc` declares two explicit local plugin paths (lines 603-604):

```
"./.opencode/plugins/delegation-observer.ts",
"./.opencode/plugins/needs-input-observer.ts"
```

These paths are resolved RELATIVE TO the config file's own directory (`.opencode/`), so they expand to dead nested locations `.opencode/.opencode/plugins/...` that do not exist. Meanwhile OpenCode auto-discovery loads the real files at `.opencode/plugins/...` exactly once. The explicit entries are inert — they point at dead targets while auto-discovery does the real work.

A runtime audit confirmed: **no duplicate observer loads**. The defect is dead nested paths, not duplication. Silent dead plugin paths mask configuration drift: the config appears to explicitly load observers, but the explicit entries resolve to nothing.

## What Changes

- Fix the two dead explicit paths in `.opencode/opencode.jsonc` (lines 603-604): change `./.opencode/plugins/...` to `./plugins/...` so they resolve relative to `.opencode/` into the live `.opencode/plugins/...` directory.
- Add one fail-hard validation script `scripts/validate-local-plugins.sh` that checks every local `./` plugin declaration in `opencode.jsonc` resolves relative to `.opencode/` and points to an existing file. Exit 1 on broken path (fail-hard, wired into `make test-config`).
- Wire `scripts/validate-local-plugins.sh` into `make test-config` (alongside existing `validate-*.sh` scripts).

## Capabilities

### New Capabilities

None. This is a config fix + validation script. No spec-level behavior changes.

### Modified Capabilities

None.

## Impact

- **Config:** `.opencode/opencode.jsonc` lines 603-604 — two path strings changed.
- **Scripts:** `scripts/validate-local-plugins.sh` — new file (~30 lines), bash-3 compatible, coreutils + jq only.
- **Makefile:** `test-config` target gains one line: `bash scripts/validate-local-plugins.sh`.
- **Dependencies:** none added (jq already required by other validate scripts).
- **Systems:** no runtime behavior change (auto-discovery already loads the plugins correctly); the fix makes explicit declarations match reality, and the validation script prevents future drift.

## Alternatives considered

- **Broad duplicate/unique-ID assertions** (check that no plugin is loaded twice): rejected — runtime audit confirmed no duplicates exist; the defect is dead paths, not duplication. Adding broad assertions would be speculative scope creep. Evidence: Tier-1 (runtime audit findings, registered in `.opencode/learnings/external-patterns/2026-08-21-observer-plugin-path-resolution.md`).
- **Warn-only validation** (print warning but don't fail): rejected — broken plugin path = plugin not loaded = runtime behavior differs from declared config. This is a hard contract violation, not a warning. All other `validate-*.sh` scripts fail-hard; consistency matters. Evidence: Tier-1 (interview Q3 — developer agreed fail-hard).
- **Separate validation files per plugin** (hardcoded check for delegation-observer and needs-input-observer): rejected — doesn't scale to future local plugins. The generic `./` prefix filter covers any local plugin declaration. Evidence: Tier-1 (interview Q2 — developer agreed generic mechanism).
- **Status-quo / do nothing** (leave dead paths, no validation): rejected — silent drift, misleading config, no regression gate. Evidence: Tier-1 (runtime audit identified the defect; interview Q1 confirmed problem).

Chosen option: fix paths + generic fail-hard validation — because it addresses the actual defect (dead paths, not duplicates), matches the existing validation pattern, and prevents future drift for any local plugin declaration.

## Testing Decisions

**What makes a good test for this change:** the existing `scripts/validate-*.sh` pattern (bash-3 compatible, coreutils + jq, exit 1 on failure) is the right seam. A good test: parse `opencode.jsonc` with `jq`, filter `plugins[]` entries with `./` prefix, resolve each relative to `.opencode/`, check `-f` for each, exit 1 if any missing.

**Which modules will be tested:** the `scripts/validate-local-plugins.sh` script itself. No unit tests for the script (it's a validation gate, not business logic); the gate is tested by running it against the real config (`make test-config`).

**Prior art in the codebase:** `scripts/validate-agent-names.sh`, `scripts/validate-dia-mentions.sh`, `scripts/validate-handoff.sh` — all follow the same pattern (bash-3, coreutils + jq, exit 1 on failure, wired into `make test-config`).
