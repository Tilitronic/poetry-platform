# Proposal: runtime-config-test

> **Status:** proposed
> **Scope:** dev-infra (scripts/, Makefile, bats test scaffolding). No application code touched.
> **Escalation:** none - change stays within existing module boundaries. Per AGENTS.md section 2.4 (dev-infra within existing boundaries -> @reviewer), no @architector dispatch is required.
> **Source tickets:** docs/dev-infra-audit/tickets/DIA-260821-n8sq.md (P1: no runtime config test; merge gate does not catch preset mismatch, plugin duplicates, or version drift before launch).
> **Research basis:** knowledge/res039-opencode-runtime-config-introspection/ (4 archived external sources + 3 verified-local files; corroborates `opencode debug config`, `debug paths`, `debug agent <name>`, `--pure`, `OPENCODE_CONFIG_CONTENT`, `OPENCODE_DISABLE_MODELS_FETCH=1`).

## Why

There is no runtime config test. The merge gate does not catch preset mismatch, plugin duplicates, or version drift before launch. The existing `make test-config` performs static JSONC syntax validation + agent-name cross-ref + handoff schema + many other validators, but does NOT boot OpenCode or validate the effective runtime config in a clean HOME. A config can pass static validation but resolve incorrectly at runtime (e.g., Terra-to-DeepSeek style fallback/override where config says one thing but runtime resolves differently). This change adds a runtime validation layer that real-boots OpenCode in a clean HOME with the project's real config and asserts the effective preset/model/plugins match expectations.

## What Changes

- Add `scripts/test-runtime-config.sh` - bash script that creates a clean HOME (temp dir via `mktemp -d`), symlinks the project's `.opencode/opencode.jsonc` and `.opencode/oh-my-opencode-slim.jsonc` into a temp OPENCODE_CONFIG_DIR, runs `opencode debug config` + `opencode debug agent <name>` + `opencode debug paths`, parses the JSON output, and asserts the effective preset/model/plugins match expectations dynamically extracted from the project config.
- Add `make test-runtime-config` target - standalone target (NOT wired into `make test-config` because it requires the opencode binary which may not be available in all environments). CI must run this target inside the dev container to close the merge-detection P1.
- Add `scripts/__tests__/test-runtime-config.bats` - bats unit tests with 6-case fixture matrix covering all exit codes (0=OK, 1=project config failure, 2=infra/unsupported binary/schema).
- Exit code contract: exit 0 = runtime assertions pass; exit 1 = project config failure (preset mismatch, plugin duplicates, effective config does not match expectations); exit 2 = infra/unsupported binary/schema (opencode not found, debug command unavailable, non-JSON output).
- Dynamic extraction: test reads project config to extract expected active preset, key-agent model, plugin list; then asserts runtime matches. Self-maintaining - if config changes, test adapts automatically.
- Binary availability guard: `command -v opencode` then `opencode debug config` as hard availability check. If unavailable, exit 2 with "unsupported: opencode debug config unavailable or schema changed".
- Cleanup via trap: temp HOME removed on exit.

## Capabilities

### New Capabilities

None. This is dev-infra tooling (bash script + Makefile target + bats tests). No spec-level behavior changes.

### Modified Capabilities

None. No existing capabilities are modified.

**skip_specs: true** - this change is pure dev-infra tooling with no spec-level behavior changes.

## Impact

**Affected code:**

- `scripts/test-runtime-config.sh` (new) - runtime config validator
- `scripts/__tests__/test-runtime-config.bats` (new) - bats unit tests
- `Makefile` (modified) - add `test-runtime-config` target

**Dependencies:**

- Requires `opencode` binary on PATH (host-runnable) or inside dev container (CI)
- Requires `jq` for JSON parsing (already validated by `check-host-jq.sh`)
- Requires Node.js for JSONC tokenization (already validated by `validate-opencode-config.sh`)

**Systems:**

- CI pipeline must run `make test-runtime-config` inside dev container
- Does NOT affect application code, APIs, or user-facing behavior

## Design authority (.sdd/) reference

**Relevant .sdd/ documents:**

- `.sdd/dev-infra/architecture.md` - governs dev-infra scripts, Makefile targets, bats test scaffolding
- `.sdd/opencode-config/architecture.md` - governs OpenCode config validation, JSONC parsing, preset/plugin semantics

**No new architectural decisions required.** This change stays within existing module boundaries (dev-infra scripts + Makefile). Per AGENTS.md section 3, the absence of a governing .sdd/ for `scripts/test-runtime-config.sh` is a documentation gap, but one this change does not fill (precedent: `openspec/changes/dev-infra-config-validators/proposal.md` section Design authority).

## Testing Decisions

**What makes a good test here:**
The artifact under test is a bash script that boots OpenCode in a clean HOME and parses its introspection output. The prior art is `session-analytics.sh` (binary availability guard) and `validate-opencode-config.sh` (Node JSONC tokenizer). Tests assert observable behavior (exit code, output content), not implementation details.

**Modules under test:**

| Module                                             | Test type                   | Gate              |
| -------------------------------------------------- | --------------------------- | ----------------- |
| `scripts/test-runtime-config.sh` (new)             | bats unit                   | `make test-shell` |
| `scripts/__tests__/test-runtime-config.bats` (new) | bats suite                  | `make test-shell` |
| `Makefile` (`test-runtime-config` target)          | wiring regression bats test | `make test-shell` |

**Fixture matrix (6 cases):**

| #   | Case                                                                      | Expected exit | Expected output                                                                        |
| --- | ------------------------------------------------------------------------- | ------------- | -------------------------------------------------------------------------------------- |
| 1   | Valid: opencode available, project config resolves correctly              | 0             | stdout `ok:` lines, final summary                                                      |
| 2   | Preset mismatch: config says preset X, runtime resolves preset Y          | 1             | stderr `FAIL:` line naming the mismatch                                                |
| 3   | Plugin duplicates: effective plugin array has duplicate package names     | 1             | stderr `FAIL:` line naming the duplicate                                               |
| 4   | Model mismatch: config says model A for agent X, runtime resolves model B | 1             | stderr `FAIL:` line naming the mismatch                                                |
| 5   | opencode binary not found                                                 | 2             | stderr `FAIL:` line "unsupported: opencode not found"                                  |
| 6   | `opencode debug config` returns non-JSON or unavailable                   | 2             | stderr `FAIL:` line "unsupported: opencode debug config unavailable or schema changed" |

**Test risk and mitigation:**

- **Risk**: opencode binary not available in test environment. **Mitigation**: bats tests use env override (`OPENCODE_BIN`) to point at a mock script that simulates `opencode debug config` output. Real binary tests run in dev container via CI.
- **Risk**: `opencode debug config` output schema changes across versions. **Mitigation**: exit 2 on schema mismatch (not exit 1), so the test fails loudly but does not falsely accuse the project config.

**Prior art in the codebase:**

- `scripts/session-analytics.sh` - binary availability guard pattern (`command -v opencode` + `opencode db path`)
- `.opencode/scripts/validate-opencode-config.sh` - Node JSONC tokenizer (reused for static layer)
- `scripts/__tests__/validate-agent-names.bats` - env override pattern for fixture trees
- `tools/opencode-docker/README.md` - clean-HOME packaging approach (HOME under temp dir, config via OPENCODE_CONFIG)

## Rollback plan

**Rollback is trivial** because this change has no persistent-state impact:

1. `git revert <merge-commit>` - reverts all file changes
2. `make test-shell` - bats re-runs at pre-existing baseline (93/93 + any other tests added since)
3. `make test-config` - re-runs the config-validation gate (unchanged, since `test-runtime-config` is NOT wired into it)

No data migration is needed. The only things that need to exist after rollback are the original Makefile (without `test-runtime-config` target) and the original bats-wrapper.sh syntax-check loop.

**Rollback risk:** very low. The change is a bounded dev-infra addition (one new script, one new bats suite, one Makefile extension) with no application-code impact and no persistent-state impact.

## Alternatives considered

- **Static-only (no runtime boot)**: parse config files without booting OpenCode - rejected because ticket requires real boot to catch Terra-to-DeepSeek style fallback/override (developer override, Q4)
- **Mode A (synthetic config)**: use OPENCODE_CONFIG_CONTENT with controlled test config - rejected because it does not validate the project's real config (developer rejected, Q5)
- **Mode C (both synthetic + real)**: run synthetic first to prove mechanism, then real config - rejected because synthetic self-test is deferred (developer rejected, Q5)
- **Option A (hardcoded expectations)**: hardcode expected preset/model in test script - rejected because not self-maintaining, requires test update on every config change (developer rejected, Q9)
- **Option C (structural invariants only)**: assert preset non-empty, no duplicates, but not semantic correctness - rejected because does not catch wrong preset active or wrong model assigned (developer rejected, Q9)
- **Wire into `make test-config`**: run on every config validation - rejected because breaks test-config in environments without opencode binary (developer rejected, Q6)
- **Plugin version drift in initial scope**: compare installed vs pinned plugin versions - deferred because requires npm ls / package.json parsing, heavier dependency (developer agreed, Q1)
- **Status-quo / do nothing**: accept that merge gate does not catch runtime config failures - rejected because P1 ticket explicitly requires this validation (DIA-260821-n8sq)

**Chosen option:** Mode B (real project config in clean HOME) with dynamic extraction - because it validates the project's real config, is self-maintaining, and catches preset/model/plugin mismatches without requiring test updates on config changes (evidence: res039 corroborates `opencode debug config` as runtime source of truth; developer rulings Q1-Q9).
