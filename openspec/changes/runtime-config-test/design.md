# Design: runtime-config-test

> **Proposal:** `openspec/changes/runtime-config-test/proposal.md`
> **Source tickets:** `docs/dev-infra-audit/tickets/DIA-260821-n8sq.md` (P1: no runtime config test).
> **Scope:** implementation design only - no system architecture decisions, no `.sdd/` escalation required. The change is within existing module boundaries; routing is AGENTS.md section 2.4 (dev-infra -> @reviewer).

## Context

See proposal.md - Why. The existing `make test-config` performs static JSONC syntax validation + agent-name cross-ref + handoff schema + many other validators, but does NOT boot OpenCode or validate the effective runtime config. The research basis (knowledge/res039-opencode-runtime-config-introspection/) corroborates `opencode debug config` as the runtime source of truth for effective preset/model/plugin state.

**Current state:**

- `make test-config` validates static config (JSONC syntax, agent names, handoff schema, etc.)
- No runtime validation exists
- `opencode debug config` command is documented but not exercised in CI
- Project config lives at `.opencode/opencode.jsonc` + `.opencode/oh-my-opencode-slim.jsonc`

**Constraints:**

- Must not break `make test-config` in environments without opencode binary
- Must validate the project's real config, not a synthetic test config
- Must be self-maintaining (dynamic extraction of expectations from config)
- Must handle binary/schema unavailability gracefully (exit 2, not exit 1)

## Goals / Non-Goals

**Goals:**

- Real-boot OpenCode in clean HOME with project config symlinked
- Validate effective preset/model/plugins match expectations extracted from config
- Catch preset mismatch, plugin duplicates, model assignment errors
- Handle binary/schema unavailability as infra error (exit 2), not config failure (exit 1)
- Self-maintaining: test adapts automatically when config changes

**Non-Goals:**

- Plugin version drift validation (deferred - requires npm ls / package.json parsing)
- Synthetic self-test (Mode A rejected - does not validate project's real config)
- Wiring into `make test-config` (rejected - breaks test-config in environments without opencode)
- Validating global config (`~/.config/opencode/opencode.jsonc`) - out of scope
- Validating config file path drift (opencode.json vs .opencode.json vs .opencode/opencode.jsonc) - out of scope

## Decisions

### Decision 1: Clean HOME mechanism

**Choice:** `mktemp -d` for HOME + project config symlinked into temp OPENCODE_CONFIG_DIR.

**Rationale:** Symlinks are faster and simpler than copying. The test validates config resolution, not file-copy fidelity. Symlinks still catch preset mismatch + plugin duplicates because those come from config content, not file location.

**Alternatives considered:**

- Copy config files instead of symlink - rejected: adds complexity for no coverage gain
- Use OPENCODE_CONFIG_CONTENT (inline JSON) - rejected: does not validate project's real config (Mode A rejected, Q5)

### Decision 2: Parsing strategy

**Choice:** Reuse existing Node JSONC tokenizer from `validate-opencode-config.sh` for static layer. Use `jq` for parsing `opencode debug config` JSON output.

**Rationale:** The Node tokenizer is proven (handles comments, trailing commas, string literals). `jq` is already validated by `check-host-jq.sh` and is the standard tool for JSON parsing in bash scripts.

**Alternatives considered:**

- Python-based JSON parser - rejected: Node tokenizer already exists and is tested
- Inline bash JSON parsing - rejected: fragile, hard to maintain

### Decision 3: Expectations extraction

**Choice:** Dynamic extraction from project config. Test reads `.opencode/oh-my-opencode-slim.jsonc` to extract active preset name, reads preset's routing table to extract expected model for key agent, reads project plugin array to extract expected plugin list.

**Rationale:** Self-maintaining. If config changes, test adapts automatically. Catches "config says X but runtime resolves Y" failures, which is the exact failure mode the ticket describes.

**Alternatives considered:**

- Hardcoded expectations - rejected: not self-maintaining, requires test update on every config change (Option A rejected, Q9)
- Structural invariants only (preset non-empty, no duplicates) - rejected: does not catch wrong preset active or wrong model assigned (Option C rejected, Q9)

### Decision 4: Binary availability guard

**Choice:** `command -v opencode` then `opencode debug config` as hard availability check. If unavailable, exit 2 with "unsupported: opencode debug config unavailable or schema changed".

**Rationale:** Follows the guard pattern from `session-analytics.sh`. Exit 2 on schema mismatch (not exit 1) so the test fails loudly but does not falsely accuse the project config.

**Alternatives considered:**

- Skip availability check, let test fail with cryptic error - rejected: poor developer experience
- Exit 1 on unavailability - rejected: conflates infra error with config failure

### Decision 5: Wiring decision

**Choice:** Standalone `make test-runtime-config` target. NOT wired into `make test-config`.

**Rationale:** `test-runtime-config` requires the opencode binary, which may not be available in all environments (e.g., CI without dev container, developer machines without opencode installed). Wiring it into `test-config` would break `test-config` in those environments. CI must run this target inside the dev container to close the merge-detection P1.

**Alternatives considered:**

- Wire into `make test-config` - rejected: breaks test-config in environments without opencode (Q6)
- Wire into `make test-infra` - rejected: test-infra is heavy (Docker smoke test + pytest); runtime config test is lightweight

### Decision 6: Runtime introspection commands

**Choice:** Use `opencode debug config` + `opencode debug agent <name>` + `opencode debug paths` + `opencode --pure debug config` for isolation proof.

**Rationale:** res039 corroborates these commands as LLM-free introspection primitives. `debug config` prints resolved config after merging user + project + env overrides. `debug agent <name>` prints named agent's full resolved config (model, tools, permissions). `debug paths` prints all data/config/cache directories (proves clean-HOME isolation). `--pure` runs without external plugins (proves plugin isolation).

**Alternatives considered:**

- Parse startup logs - rejected: may not emit diagnostics we need
- Prompt-based probing (echo "what preset are you using?" | opencode) - rejected: fragile, slow, response format may change
- Skip runtime boot entirely - rejected: ticket requires real boot to catch Terra-to-DeepSeek style fallback/override (Q4)

## Risks / Trade-offs

**Risk:** opencode binary not available in test environment.
**Mitigation:** bats tests use env override (`OPENCODE_BIN`) to point at a mock script that simulates `opencode debug config` output. Real binary tests run in dev container via CI. Exit 2 on unavailability (not exit 1).

**Risk:** `opencode debug config` output schema changes across versions.
**Mitigation:** Exit 2 on schema mismatch (not exit 1), so the test fails loudly but does not falsely accuse the project config. Implementation validates against pinned opencode version (res039 caveat).

**Risk:** Config file path is version-dependent (opencode.json vs .opencode.json vs .opencode/opencode.jsonc).
**Mitigation:** Test symlinks project's `.opencode/opencode.jsonc` into temp OPENCODE_CONFIG_DIR. If opencode does not load from OPENCODE_CONFIG_DIR, exit 2 (schema/path drift). This is an explicit error state, not a silent failure.

**Risk:** Dynamic extraction logic is complex (parsing preset routing tables, plugin arrays).
**Mitigation:** Follow existing patterns from `validate-agent-names.sh` (JSONC parsing with inline Node, jq for JSON extraction). bats tests cover all extraction paths.

**Trade-off:** Standalone target (not wired into test-config) means developers must remember to run it manually.
**Acceptance:** CI runs it inside dev container, so merge gate catches failures. Developer convenience is secondary to not breaking test-config in non-container environments.

## Seams

> Per `openspec/config.yaml`: "Include a Seams section listing the pre-agreed public boundaries where tests will live. Prefer existing seams; propose new ones only at the highest level necessary."

| Seam                                                      | What it is                                                               | Test location                                                                                                        | Test type                                                                                     |
| --------------------------------------------------------- | ------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------- |
| **S1 - `scripts/test-runtime-config.sh`**                 | Runtime config validator (clean HOME + real boot + introspection).       | `scripts/__tests__/test-runtime-config.bats` (new suite, `OPENCODE_BIN` env override for mock binary).               | Behavioral: exit code + stderr/stdout content per 6-case fixture matrix.                      |
| **S2 - `Makefile` `test-runtime-config` target**          | Standalone target that invokes the validator.                            | `scripts/__tests__/test-runtime-config-wiring.bats` (new) OR appended to existing file; static grep over `Makefile`. | Structural assertion: `grep`-based (same shape as `opencode-docker.bats` arch-failfast test). |
| **S3 - `bash -n` syntax-check loop in `bats-wrapper.sh`** | New script passes `bash -n` syntax check on every `make test-shell` run. | `scripts/__tests__/bats-wrapper.sh` (modified - added entry).                                                        | Implicit: `bash -n` runs in `make test-shell`; syntax errors fail the build.                  |

### New seams vs. existing seams

- **S1 is a new top-level script but reuses the existing bats harness** (`bats-wrapper.sh`, `test-helper.bash`). No new harness infrastructure needed.
- **S2 is a new bats test** (or append to existing) for the wiring regression. The natural home is either `scripts/__tests__/test-runtime-config-wiring.bats` (new, dedicated file) or appended to an existing Makefile-aware test if one exists. Decision for the coder lane; default to a new file for clarity.
- **S3 extends the existing `bash -n` loop** (no new seam).

### Testability env seams

- **`OPENCODE_BIN` env override** for `test-runtime-config.sh` - points the validator at a mock binary for bats tests. Same shape as `AGENTS_ROOT` in `validate-agent-names.sh`.
- **`REPO_ROOT` env override** (conditional) - if the validator needs to find project config via a path that differs from the bats test's `REPO_ROOT`. Decision for the coder lane - default to `${BASH_SOURCE[0]}` dirname traversal for the project root, matching `validate-opencode-config.sh`'s pattern.

## Implementation approach

### Script structure (`scripts/test-runtime-config.sh`)

1. **Guard phase:**
   - Check `command -v opencode` (or `$OPENCODE_BIN` if set)
   - If not found, exit 2 with "unsupported: opencode not found"
   - Check `command -v jq` (already validated by `check-host-jq.sh`)
   - If not found, exit 2 with "unsupported: jq not found"

2. **Clean HOME setup:**
   - `TEST_HOME="$(mktemp -d)"`
   - `export HOME="$TEST_HOME"`
   - `TEST_CONFIG_DIR="$TEST_HOME/.config/opencode"`
   - `mkdir -p "$TEST_CONFIG_DIR"`
   - Symlink project config: `ln -s "$REPO_ROOT/.opencode/opencode.jsonc" "$TEST_CONFIG_DIR/opencode.jsonc"`
   - Symlink slim config: `ln -s "$REPO_ROOT/.opencode/oh-my-opencode-slim.jsonc" "$TEST_CONFIG_DIR/oh-my-opencode-slim.jsonc"`
   - `export OPENCODE_CONFIG_DIR="$TEST_CONFIG_DIR"`
   - `export OPENCODE_DISABLE_MODELS_FETCH=1` (keep offline/deterministic)
   - `export OPENCODE_DISABLE_AUTOUPDATE=1`
   - Trap cleanup: `trap 'rm -rf "$TEST_HOME"' EXIT`

3. **Dynamic extraction phase:**
   - Parse `.opencode/oh-my-opencode-slim.jsonc` with inline Node (same tokenizer as `validate-opencode-config.sh`)
   - Extract active preset name
   - Extract preset's routing table to find expected model for key agent (e.g., `orchestrator` or `coder`)
   - Extract project plugin array from `.opencode/opencode.jsonc`
   - Store expectations in bash variables

4. **Runtime introspection phase:**
   - Run `opencode debug config` and capture JSON output
   - If command fails or output is not valid JSON, exit 2 with "unsupported: opencode debug config unavailable or schema changed"
   - Parse JSON with `jq`:
     - Extract effective preset name
     - Extract effective plugin array
     - Extract effective model for key agent
   - Run `opencode debug paths` and assert config path matches `$TEST_CONFIG_DIR` (proves clean-HOME isolation)
   - Run `opencode --pure debug config` and assert plugin array is empty (proves plugin isolation)

5. **Assertion phase:**
   - Compare effective preset name to expected preset name
   - If mismatch, exit 1 with "FAIL: preset mismatch: expected X, got Y"
   - Check for duplicate package names in effective plugin array
   - If duplicates found, exit 1 with "FAIL: plugin duplicates: [list]"
   - Compare effective model for key agent to expected model
   - If mismatch, exit 1 with "FAIL: model mismatch for agent X: expected Y, got Z"
   - If all assertions pass, exit 0 with "ok: runtime config validation passed"

### Exit code contract

| Exit code | Trigger                                                                                                                                                      | Category                                                                                           |
| --------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------- |
| 0         | All runtime assertions pass (preset resolves correctly, no plugin duplicates, effective config matches expectations)                                         | OK                                                                                                 |
| 1         | Runtime assertion failure (preset mismatch detected, plugin duplicates found, effective config does not match expectations)                                  | HARD fail (project config is broken)                                                               |
| 2         | Infrastructure error (opencode binary not found, `opencode debug config` command unavailable or returns non-JSON, clean HOME setup failed, jq not available) | INFRA error (test environment is broken or opencode version doesn't support introspection surface) |

### Stream contract

- **stderr:** `FAIL: <message>` lines for HARD failures (exit 1) or INFRA errors (exit 2)
- **stdout:** `ok: <message>` lines for passes; final summary line on exit 0
- **Fail-fast:** YES (unlike other validators that collect-all). Rationale: runtime introspection is sequential (guard -> setup -> extract -> introspect -> assert); early failures make later steps meaningless.
- **Shell defaults:** `set -euo pipefail`

## Verification gate summary

| Gate                                               | When        | Required                                                                                              |
| -------------------------------------------------- | ----------- | ----------------------------------------------------------------------------------------------------- |
| `make test-shell`                                  | After T1/T2 | Pre-existing bats baseline + new `test-runtime-config.bats` + wiring test pass                        |
| `make test-runtime-config` (standalone)            | After T1    | Exit 0 on real project config (preset resolves, no duplicates, effective config matches expectations) |
| `bash scripts/test-runtime-config.sh` (standalone) | After T1    | Exit 0 on real project config                                                                         |
| Wiring regression                                  | After T2    | bats test asserts `Makefile` has `test-runtime-config` target                                         |

## Traceability to confirmed rulings

Every design decision above is locked to a confirmed interview ruling. The mapping:

| Decision                                       | Ruling source                                  |
| ---------------------------------------------- | ---------------------------------------------- |
| Clean HOME via mktemp + symlink                | Q2                                             |
| Reuse Node JSONC tokenizer                     | Q3                                             |
| Dynamic extraction from config                 | Q9                                             |
| Binary availability guard (exit 2)             | Q4 (res039 caveat)                             |
| Standalone target (not wired into test-config) | Q6                                             |
| Use `opencode debug config` + related commands | Q4 (res039 research)                           |
| Mode B (real project config, no synthetic)     | Q5                                             |
| Exit 0/1/2 contract                            | Q6, Q8 (correction: missing res dir is exit 1) |
| No plugin version drift in initial scope       | Q1                                             |

No decision in this design.md is invented beyond the confirmed rulings. If a gap emerges during implementation, the coder lane flags it to the orchestrator rather than deciding silently.
