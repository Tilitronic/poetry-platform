## Context

`.opencode/opencode.jsonc` declares plugins in a top-level `plugins` array (lines 592-605). Most entries are npm package names (`oh-my-opencode-slim@2.2.15`, `@dietrichgebert/ponytail`, `envsitter-guard@0.0.4`). Two entries are local file paths with `./` prefix:

```
"./.opencode/plugins/delegation-observer.ts",
"./.opencode/plugins/needs-input-observer.ts"
```

OpenCode resolves local plugin paths RELATIVE TO the config file's directory (`.opencode/`). So `./.opencode/plugins/...` expands to `.opencode/.opencode/plugins/...` — a dead nested path. The real files live at `.opencode/plugins/...` (relative to project root), which is `.opencode/plugins/...` relative to the config dir — i.e., `./plugins/...` in the config.

A runtime audit confirmed: **no duplicate observer loads**. Auto-discovery loads the real files exactly once. The explicit entries are inert.

Constraints:

- Bash-3 compatible (no `[[ ]]`, no associative arrays, no mapfile/namerefs/compgen).
- No new dependencies (coreutils + jq only; jq already required by other validate scripts).
- ASCII-only input and output (DIA-079).
- Fail-hard on broken path (exit 1, wired into `make test-config`).

See proposal.md for motivation and scope.

## Goals / Non-Goals

**Goals:**

- Fix the two dead explicit paths in `.opencode/opencode.jsonc` (lines 603-604): change `./.opencode/plugins/...` to `./plugins/...`.
- Add `scripts/validate-local-plugins.sh` that checks every local `./` plugin declaration resolves relative to `.opencode/` and points to an existing file. Exit 1 on broken path.
- Wire `scripts/validate-local-plugins.sh` into `make test-config`.
- Config chain verification: `make test-config` passes, restart OpenCode + functional smoke test (plugins load with new paths), `@ai-auditor` review, `CHANGELOG.yaml` append + validate + render.

**Non-Goals:**

- Broad duplicate/unique-ID assertions (runtime audit confirmed no duplicates; the defect is dead paths, not duplication).
- Runtime plugin-loading validation (out of scope for `make test-config`; the validation script checks path existence, not runtime behavior).
- Changes to auto-discovery behavior (auto-discovery works correctly; the fix is to explicit declarations).
- Migration of other config entries (only the two observer plugin paths are broken).

## Decisions

### Decision 1: Fix paths to `./plugins/...`

**Choice:** Change `.opencode/opencode.jsonc` lines 603-604 from `./.opencode/plugins/...` to `./plugins/...`.

**Rationale:** OpenCode resolves local plugin paths relative to the config file's directory (`.opencode/`). So `./plugins/...` resolves to `.opencode/plugins/...` — the live directory. This makes explicit declarations match reality.

**Alternatives considered:**

- Absolute paths (`/workspace/.opencode/plugins/...`): rejected — not portable, breaks if project moves.
- Remove explicit entries (rely on auto-discovery): rejected — explicit declarations are a safety surface; removing them loses the intent to load these plugins even if auto-discovery changes.

### Decision 2: Generic `./` prefix filter in validation script

**Choice:** `scripts/validate-local-plugins.sh` parses `opencode.jsonc` with `jq`, filters `plugins[]` entries with `./` prefix, resolves each relative to `.opencode/`, checks `-f` for each, exits 1 if any missing.

**Rationale:** Generic filter covers any future local plugin declaration, not just the two current ones. Hardcoded checks for specific plugins don't scale.

**Alternatives considered:**

- Hardcoded check for delegation-observer and needs-input-observer: rejected — doesn't scale.
- Runtime plugin-loading validation: rejected — out of scope for `make test-config`; path existence is the right seam.

### Decision 3: Fail-hard behavior (exit 1)

**Choice:** Exit 1 on broken path, wired into `make test-config`.

**Rationale:** Broken plugin path = plugin not loaded = runtime behavior differs from declared config. This is a hard contract violation, not a warning. All other `validate-*.sh` scripts fail-hard; consistency matters.

**Alternatives considered:**

- Warn-only (print warning, don't fail): rejected — silent drift, no regression gate.

### Decision 4: No delta spec

**Choice:** No delta spec under `specs/`. This is a config fix + validation script, not a capability change.

**Rationale:** No spec-level behavior changes. The change is additive (validation script) and corrective (path fix). No capability is modified.

**Alternatives considered:**

- Delta spec for "plugin path resolution": rejected — YAGNI, no capability change.

## Seams

**Test seam:** `scripts/validate-local-plugins.sh` — the validation script itself. No unit tests; the gate is tested by running it against the real config (`make test-config`).

**Public boundary:** the `make test-config` target is the public boundary. The internal implementation of `validate-local-plugins.sh` is not a public boundary.

## Risks / Trade-offs

**Risk:** The validation script assumes `jq` is available. If `jq` is missing, the script fails.
→ **Mitigation:** `jq` is already required by other validate scripts (`validate-agent-names.sh`, `validate-dia-mentions.sh`). The project's dev environment guarantees `jq` is installed. No new dependency.

**Risk:** The validation script checks path existence, not runtime plugin loading. A path may exist but the plugin may fail to load (syntax error, missing dependency).
→ **Mitigation:** Runtime plugin loading is out of scope for `make test-config`. The validation script catches the common defect (dead paths); runtime failures are caught by OpenCode startup logs and functional smoke tests.

**Trade-off:** The validation script does not check npm package names (only local `./` paths). A broken npm package name would not be caught.
→ **Acceptable:** npm package resolution is handled by the package manager (pnpm/Bun); broken package names fail at install time, not at config validation time. The validation script focuses on the defect class that caused this ticket (dead local paths).

## Migration Plan

**Deployment:** the change is corrective (path fix) + additive (validation script). No migration needed. The existing config continues to work (auto-discovery loads the plugins); the fix makes explicit declarations match reality.

**Rollback:** revert the commit. The paths return to dead nested paths, the validation script is removed. Auto-discovery continues to load the plugins correctly.

**Config chain verification:**

1. `make test-config` passes (including new `validate-local-plugins.sh`).
2. Restart OpenCode + functional smoke test (plugins load with new paths; verify via `opencode debug config` or startup logs).
3. `@ai-auditor` review (independent review of config change against best practices + AIHero patterns).
4. `CHANGELOG.yaml` append entry, validate via `scripts/validate-changelog.sh`, regenerate MD via `scripts/changelog-render`.

**Open Questions:** none.
