# Tasks: runtime-config-test

> **Proposal:** `openspec/changes/runtime-config-test/proposal.md`
> **Design:** `openspec/changes/runtime-config-test/design.md`
> **Source tickets:** `docs/dev-infra-audit/tickets/DIA-260821-n8sq.md` (P1: no runtime config test).
> **Workflow:** per `openspec/config.yaml`, each task is a vertical slice invoked via the `tdd-craftsman` skill. Write the failing test BEFORE production code. Work one slice at a time.
> **Routing:** AGENTS.md section 2.4 (dev-infra within existing boundaries -> @reviewer, two-axis: Standards + Spec fidelity). No section 10 AI-tooling routing - neither validator modifies opencode config; both only READ it.

## Dependency graph

```
T1 (test-runtime-config.sh + bats)
 │
 └──▶ T2 (Makefile wiring + bash -n loop + wiring regression)
```

**Critical path:** T1 -> T2.
**Rationale for ordering:**

- **T1 is first** because it implements the core validator + tests. T2 wires it into the Makefile and adds it to the syntax-check loop.
- **T2 depends on T1** because it wires the script from T1 into the Makefile. The wiring is not meaningful until the script exists.

---

## T1 - `scripts/test-runtime-config.sh` + `scripts/__tests__/test-runtime-config.bats`

**Blockers:** none
**Vertical slice:** the runtime config validator + its 6-case bats fixture matrix. After T1, running `bash scripts/test-runtime-config.sh` from the repo root produces the expected exit code on the real project config (exit 0 with preset resolves correctly, no plugin duplicates, effective config matches expectations).

### What changes

1. **`scripts/test-runtime-config.sh`** (new file, executable, `set -euo pipefail`). Behavior per design.md:
   - Guard phase: check `command -v opencode` (or `$OPENCODE_BIN` if set), check `command -v jq`. Exit 2 if not found.
   - Clean HOME setup: `mktemp -d` for HOME, symlink project config into temp OPENCODE_CONFIG_DIR, set env vars (`OPENCODE_CONFIG_DIR`, `OPENCODE_DISABLE_MODELS_FETCH=1`, `OPENCODE_DISABLE_AUTOUPDATE=1`), trap cleanup.
   - Dynamic extraction phase: parse `.opencode/oh-my-opencode-slim.jsonc` with inline Node (same tokenizer as `validate-opencode-config.sh`), extract active preset name, extract preset's routing table to find expected model for key agent, extract project plugin array from `.opencode/opencode.jsonc`.
   - Runtime introspection phase: run `opencode debug config`, parse JSON with `jq`, extract effective preset/plugins/model. Run `opencode debug paths` and assert config path matches temp dir. Run `opencode --pure debug config` and assert plugin array is empty.
   - Assertion phase: compare effective vs expected preset/plugins/model. Exit 1 on mismatch, exit 0 on success.
   - `OPENCODE_BIN` env override for bats meta-tests (points at mock binary).

2. **`scripts/__tests__/test-runtime-config.bats`** (new file). 6-case fixture matrix per proposal section Testing Decisions:
   1. Valid: opencode available, project config resolves correctly -> exit 0.
   2. Preset mismatch: config says preset X, runtime resolves preset Y -> exit 1.
   3. Plugin duplicates: effective plugin array has duplicate package names -> exit 1.
   4. Model mismatch: config says model A for agent X, runtime resolves model B -> exit 1.
   5. opencode binary not found -> exit 2.
   6. `opencode debug config` returns non-JSON or unavailable -> exit 2.
      Each test uses `OPENCODE_BIN` (and related env overrides) to point the validator at a mock binary that simulates `opencode debug config` output. Uses `assert_status`, `assert_output_contains` from `test-helper.bash`.

3. **(Conditional) `scripts/__tests__/test-helper.bash` extensions.** If the existing assertion vocabulary is insufficient for the fixture predicates, add helpers. Decision for the coder lane - the existing `assert_file_contains` (substring-only via `grep -qF`) is likely sufficient.

### Acceptance criteria (user perspective)

- `bash scripts/test-runtime-config.sh` from repo root exits 0 on the real project config (preset resolves correctly, no plugin duplicates, effective config matches expectations extracted from config).
- `bash scripts/test-runtime-config.sh` from repo root prints `ok:` lines to stdout, one per assertion.
- `bash scripts/test-runtime-config.sh` from repo root prints final summary line on exit 0.
- All 6 bats fixture tests pass under `make test-shell`.
- The script passes `bash -n` syntax check (verified by `bats-wrapper.sh`).
- opencode binary not found -> exit 2 with "unsupported: opencode not found".
- `opencode debug config` returns non-JSON -> exit 2 with "unsupported: opencode debug config unavailable or schema changed".
- Preset mismatch -> exit 1 with "FAIL: preset mismatch: expected X, got Y".
- Plugin duplicates -> exit 1 with "FAIL: plugin duplicates: [list]".
- Model mismatch -> exit 1 with "FAIL: model mismatch for agent X: expected Y, got Z".

### Verification procedure

1. `bash scripts/test-runtime-config.sh` - exit 0 expected on real project config.
2. `make test-shell` - all bats tests pass (pre-existing baseline + 6 new cases).
3. `bash -n scripts/test-runtime-config.sh` - exit 0.

### Testing

- RED-GREEN: write the 6 bats tests first (they fail because the validator script does not yet exist), then implement the validator until they pass.
- The 6 fixture tests cover all exit-code paths (0 / 1 / 2), the guard phase, and the assertion phase.
- bats uses env override (`OPENCODE_BIN` etc.) to isolate fixture trees - real opencode binary never invoked during tests.

---

## T2 - Makefile wiring + `bash -n` loop + wiring regression

**Blockers:** T1 (script must exist before it can be wired in).
**Vertical slice:** wire the validator into `make test-runtime-config`, add it to the `bats-wrapper.sh` syntax-check loop, add a wiring regression bats test. After T2, `make test-runtime-config` invokes the validator.

### What changes

1. **`Makefile`** (modified). Add new standalone target `test-runtime-config`:

   ```makefile
   test-runtime-config:
       bash scripts/test-runtime-config.sh
   ```

   The spec pins the invariant - `make test-runtime-config` must invoke `test-runtime-config.sh`. The exact shape (prereq vs recipe-line) is a coder-lane detail per design.md. The coder's handoff must document which shape was chosen and why.
   - **Invariants (locked regardless of shape):**
     - The script is invoked with no arguments from the Makefile.
     - `make test-runtime-config` from repo root exits 0 on the real project config (since the validator should pass on the current config).
     - NOT wired into `make test-config` (developer decision, Q6).

2. **`scripts/__tests__/bats-wrapper.sh`** (modified). Add `scripts/test-runtime-config.sh` to the `bash -n` syntax-check loop (lines 30-40). Same shape as the existing entries for `validate-opencode-config.sh`.

3. **`scripts/__tests__/test-runtime-config-wiring.bats`** (new file) OR append to an existing wiring-aware test file. Wiring regression test:
   - Static grep over `Makefile` asserting the `test-runtime-config` target body references `test-runtime-config.sh`.
   - One `@test` block with 1 assertion.
   - Decision: new file preferred (clearer seam, matches the "dedicated wiring test" pattern used elsewhere in the codebase).

### Acceptance criteria (user perspective)

- `make test-runtime-config` from repo root exits 0.
- `make test-runtime-config` invokes `test-runtime-config.sh` (verified by wiring regression test).
- `bash -n scripts/test-runtime-config.sh` runs in `make test-shell` (via `bats-wrapper.sh`).
- The wiring regression bats test passes.
- The validator is also make-callable: `bash scripts/test-runtime-config.sh` from repo root produces the same exit code as via Make.

### Verification procedure

1. `make test-runtime-config` - exit 0 expected. Output should show `test-runtime-config.sh` being invoked.
2. `make test-shell` - all bats tests pass (pre-existing baseline + 6 new for T1 + 1 new wiring regression).
3. `grep -c 'test-runtime-config.sh' Makefile` - returns >=1.
4. `bash scripts/test-runtime-config.sh` - exit 0 (standalone call).

### Testing

- The wiring regression test is a pure structural assertion (static grep over the Makefile, no execution) - same shape as the arch-failfast test in `opencode-docker.bats`.
- No new Docker/build integration is needed. The wiring test is hermetic.

---

## Summary of file changes

| File                                                | Action | Task             |
| --------------------------------------------------- | ------ | ---------------- |
| `scripts/test-runtime-config.sh`                    | create | T1               |
| `scripts/__tests__/test-runtime-config.bats`        | create | T1               |
| `scripts/__tests__/test-helper.bash`                | modify | T1 (conditional) |
| `Makefile`                                          | modify | T2               |
| `scripts/__tests__/bats-wrapper.sh`                 | modify | T2               |
| `scripts/__tests__/test-runtime-config-wiring.bats` | create | T2               |

## Implementation order (suggested)

1. **T1** (test-runtime-config.sh + bats) - the core validator. Write the 6 bats tests RED first, then implement the validator GREEN. ~60 min.
2. **T2** (Makefile wiring + wiring regression) - the integration slice. ~15 min.
3. **Final PR verification:** run `make test-runtime-config` + `make test-shell` end-to-end; expect all bats tests pass.

## Out of scope for these tasks

- Plugin version drift validation - deferred (Q1).
- Wiring into `make test-config` - rejected (Q6).
- Global config validation - out of scope (Q2).
- Synthetic self-test (Mode A) - rejected (Q5).
- `.sdd/` module doc authoring - out of scope (precedent allows).
- Any change beyond the 2 tasks listed.

## Verification gate summary

| Gate                                               | When        | Required                                                                                               |
| -------------------------------------------------- | ----------- | ------------------------------------------------------------------------------------------------------ |
| `make test-shell`                                  | After T1/T2 | Pre-existing bats baseline + 6 T1 + 1 T2 wiring regression pass.                                       |
| `make test-runtime-config`                         | After T2    | Exit 0 on real project config (preset resolves, no duplicates, effective config matches expectations). |
| `bash scripts/test-runtime-config.sh` (standalone) | After T1    | Exit 0 on real project config.                                                                         |
| Wiring regression                                  | After T2    | bats test asserts `Makefile` has `test-runtime-config` target.                                         |

## Coder handoff contract

Per AGENTS.md section 2.3 and section 2.3.1, the coder's handoff to @reviewer must include verification evidence (exit codes + summary lines) for each task. For this change specifically:

- **T1 handoff:** `make test-shell` exit code + summary line (e.g., `99 tests, 0 failures`); `bash scripts/test-runtime-config.sh` exit code + summary output.
- **T2 handoff:** `make test-runtime-config` exit code + output (should show validator being invoked, exit 0); `grep -c 'test-runtime-config.sh' Makefile` output (returns >=1); `make test-shell` exit code + summary line showing all tests pass.
