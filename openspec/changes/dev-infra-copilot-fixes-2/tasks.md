# Tasks: dev-infra-copilot-fixes-2

> **Proposal:** `openspec/changes/dev-infra-copilot-fixes-2/proposal.md`
> **Design:** `openspec/changes/dev-infra-copilot-fixes-2/design.md`
> **Companion to:** `openspec/changes/dev-infra-copilot-fixes/` (PR #2's first Copilot-fixes change)
> **Workflow:** per `openspec/config.yaml`, the single task is a vertical slice invoked via the `tdd-craftsman` skill. Write the failing test BEFORE production code. Work one sub-step at a time.
> **Routing:** AGENTS.md §2.4 → `@reviewer` (two-axis: Standards + Spec fidelity). Item C is flagged §10 N/A per owner ruling Q1.2 (see proposal §10 flag) — no separate AI Devtools Modernization Workflow.

## Dependency graph

```
T1 — Surgical escaped-quoting fix + test companions + item C
 │  fixes verify-pre-push.sh:36, verify-pre-commit.sh:36
 │  updates :30 assertion (verify-pre-commit.bats) + equivalent verify-pre-push.bats assertions
 │  adds 2 new @tests (one per script)
 │  fixes SKILL.md:346 heading contradiction (item C)
 │  verification gate: bash -n, make test-shell 112/112, openspec validate (coder lane)
```

**Critical path:** T1 is the only task. The change is surgical and fits in a single context window.

**Rationale for single task:** the change is 2 production-code lines (identical fix at line 36 of two scripts), 2 bats test updates (mandatory companions), 2 new `@test` blocks, and 1 Markdown heading correction. The entire change is a single conceptual fix (escaped quoting for space-in-path) expressed in two scripts, with symmetric test coverage, plus one unrelated 1-line Markdown fix. Splitting into multiple tasks would create artificial boundaries with no independent demoability or verifiability.

---

## T1 — Surgical escaped-quoting fix + test companions + item C

**Blockers:** none
**Vertical slice:** the complete change — both script fixes, both test updates, both new `@test` blocks, the SKILL.md:346 heading correction, and the full verification gate. The slice is "demoable" in the sense that after T1, `make test-shell` passes 112/112, both scripts pass `bash -n`, and the SKILL.md contradiction is resolved.

**Routing:** AGENTS.md §2.4 → `@reviewer` (two-axis: Standards + Spec fidelity)
**Commit message template:** `fix(dev-infra): escape $WORKSPACE in husky hook delegated paths (Copilot #10/#11) + SKILL.md:346 heading fix`

### Sub-steps (implementation order within the single task)

> Per `openspec/config.yaml` apply guidance: "Write the failing test BEFORE any production code" and "Work one slice at a time". The sub-steps below are ordered RED-GREEN: tests are written first (they fail against the unquoted production code), then the production fix makes them pass.

**Sub-step (a): Update the existing line-30 assertion in `verify-pre-commit.bats`**

- Current (line 30): `assert_file_contains "$FAKE_DOCKER_LOG" "cd /workspace && npx lint-staged --allow-empty"`
- New: `assert_file_contains "$FAKE_DOCKER_LOG" "cd \"/workspace\" && npx lint-staged --allow-empty"`
- **Status after this sub-step:** this assertion FAILS against the current production code (which still logs `cd /workspace && ...` without inner quotes). This is the RED state — the mandatory companion test is updated first so the coder sees the failure before applying the fix.
- **Rationale:** the existing assertion must be updated before the production fix, otherwise the coder might forget to update it and the test suite breaks.

**Sub-step (b): Verify the equivalent assertions in `verify-pre-push.bats`**

- The existing `for` loop at lines 36-38 asserts `assert_file_contains "$FAKE_DOCKER_LOG" "$step"` for each step name (`verify:format`, `verify:js`, `verify:js-tests`, `verify:python`). The step name is unchanged by the quoting fix, so these assertions should still pass — but the coder must verify this by running the test after the production fix. If the assertion shape needs updating (e.g., to assert the full delegated command including the escaped quotes), the coder updates it.
- **Status after this sub-step:** no change to the assertions yet; verification deferred until after sub-step (c).

**Sub-step (c): Add new `@test` for space-in-path in `verify-pre-commit.bats`**

- New `@test` block appended to end of file.
- Setup: `export POETRY_WORKSPACE="$BATS_TEST_TMPDIR/ws with spaces"`, `export FAKE_DOCKER_SERVICES="dev"`, `mock_docker` (already in `setup()`).
- Action: `run bash "$SCRIPTS_DIR/verify-pre-commit.sh"`
- Assertions:
  - `assert_status 0`
  - `assert_file_contains "$FAKE_DOCKER_LOG" "cd \"/workspace with spaces\""` (or the equivalent shape — the coder verifies the exact logged text)
- **Status after this sub-step:** this test FAILS against the current production code (which would log `cd /workspace with spaces && ...` without inner quotes, causing the assertion to fail). This is the RED state for the new test.

**Sub-step (d): Add new `@test` for space-in-path in `verify-pre-push.bats`**

- Same shape as sub-step (c), appended to end of `verify-pre-push.bats`.
- **Status after this sub-step:** this test FAILS against the current production code. RED state.

**Sub-step (e): Fix line 36 of `scripts/verify-pre-push.sh`**

- Current (line 36): `docker compose -f "$ROOT/docker-compose.yml" exec -T dev bash -lc "cd $WORKSPACE && $cmd"`
- New: `docker compose -f "$ROOT/docker-compose.yml" exec -T dev bash -lc "cd \"${WORKSPACE}\" && ${cmd}"`
- **Status after this sub-step:** the `verify-pre-push.bats` space-path test (sub-step d) now PASSES. GREEN for that test.

**Sub-step (f): Fix line 36 of `scripts/verify-pre-commit.sh`**

- Identical fix as sub-step (e).
- **Status after this sub-step:** the `verify-pre-commit.bats` space-path test (sub-step c) and the updated line-30 assertion (sub-step a) now PASS. GREEN for all tests.

**Sub-step (g): Fix SKILL.md:346 heading contradiction (item C)**

- File: `.opencode/skills/book-rag/SKILL.md`
- Line 346: reword the "Any OS — use absolute path" bullet so it no longer contradicts the "Linux / macOS ... relative path" bullet at line 350.
- The coder has discretion on the exact wording within the confirmed constraint: **the two bullets must not contradict each other on the absolute-vs-relative question**. The coder should inspect lines 330-360 to determine the original intent before rewording.
- **Status after this sub-step:** no automated test; visual review by `@reviewer` (Standards axis).

**Sub-step (h): Verification gate**

The coder runs the following checks and reports the results in the handoff evidence:

1. **`bash -n scripts/verify-pre-push.sh scripts/verify-pre-commit.sh`** — syntax check. Exit 0 required.
2. **`make test-shell`** — full bats suite. Expected: **112 tests, 0 failures** (110 existing + 2 new). If the actual count differs, the coder flags the delta and explains it (e.g., "111 tests, 0 failures — the test-helper counted 109 existing + 2 new; the delta of 1 is explained by [reason]").
3. **`openspec validate dev-infra-copilot-fixes-2`** — routed through a coder lane (the openspec CLI is blocked in @openspec-plan's lane via permission shadowing). The orchestrator dispatches a coder lane to run this validation; the result feeds back into T1's verification evidence. Exit 0 required.
4. **Visual inspection of the SKILL.md:346 fix** — the coder confirms the two bullets no longer contradict each other.

### Acceptance criteria (user perspective)

- Running `bash scripts/verify-pre-push.sh` or `bash scripts/verify-pre-commit.sh` on a host where `POETRY_WORKSPACE` contains a space (e.g., `POETRY_WORKSPACE="/home/dev/My Projects/poetry-platform"`) successfully delegates to the dev container — the inner `cd` receives the full path as a single argument.
- Running the same scripts with the default `WORKSPACE=/workspace` (no spaces) continues to work as before (no regression).
- `make test-shell` passes 112/112 (110 existing + 2 new space-path tests).
- Both scripts pass `bash -n` syntax check (exit 0).
- `.opencode/skills/book-rag/SKILL.md:346` no longer contradicts line 350 on the absolute-vs-relative path question.
- `openspec validate dev-infra-copilot-fixes-2` passes (coder lane).

### Testing

- **RED-GREEN:** sub-steps (a), (c), (d) write the failing tests first (RED). Sub-steps (e), (f) apply the production fix (GREEN). Sub-step (g) is item C (no automated test). Sub-step (h) is the verification gate.
- **Space-path test strategy:** the new `@test` blocks use the existing `mock_docker` / `FAKE_DOCKER_LOG` seam from `test-helper.bash`. The test sets `POETRY_WORKSPACE="$BATS_TEST_TMPDIR/ws with spaces"`, runs the script, and asserts the logged delegated command contains the space-containing path with inner quotes preserved.
- **Line-30 assertion update:** the existing assertion is updated to match the new production-code shape. This is a mandatory companion — without the update, the existing test suite breaks.

### Verification evidence (coder handoff to @reviewer)

The coder's handoff must include:

- `bash -n scripts/verify-pre-push.sh scripts/verify-pre-commit.sh` exit code (expected: 0).
- `make test-shell` exit code + summary line (expected: `112 tests, 0 failures`). If the count differs, the coder explains the delta.
- `openspec validate dev-infra-copilot-fixes-2` exit code (coder lane — expected: 0).
- Confirmation that line 36 of both scripts contains the escaped-quoting fix (one-line grep output per script, e.g., `grep -n 'bash -lc' scripts/verify-pre-push.sh`).
- Confirmation that SKILL.md:346 no longer contradicts line 350 (coder's visual inspection).

---

## Out of scope for this task

- **Empty-guard on `$WORKSPACE`** — explicitly deferred per Q3 ("N/A" ruling).
- **Relative-path rejection** — explicitly deferred per Q3.
- **Line 34 (inside-container branch)** — already correctly quoted; out of scope per Q6.
- **Diagnostics / error messaging** — explicitly deferred per Q6 ("no changes" ruling).
- **Makefile / `make test-shell` wiring changes** — the existing bats target already picks up the modified bats files; no Makefile edit required per Q6.
- **Any `.sdd/` document authoring** — gap flagged in proposal, not filled here.
- **Any further Copilot comments** beyond #10 and #11 plus observation C.

## Verification gate summary

| Gate                                          | When         | Required                                                            |
| --------------------------------------------- | ------------ | ------------------------------------------------------------------- |
| `bash -n scripts/verify-pre-push.sh`          | Sub-step (h) | Exit 0 (syntax valid)                                               |
| `bash -n scripts/verify-pre-commit.sh`        | Sub-step (h) | Exit 0 (syntax valid)                                               |
| `make test-shell`                             | Sub-step (h) | 112 tests, 0 failures (exit 0)                                      |
| `openspec validate dev-infra-copilot-fixes-2` | Sub-step (h) | Exit 0 (coder lane — openspec CLI blocked in @openspec-plan's lane) |
| Visual: SKILL.md:346 fix                      | Sub-step (h) | Two bullets no longer contradict on absolute-vs-relative            |
| Visual: line 36 of both scripts               | Sub-step (h) | Escaped-quoting fix present (grep confirmation)                     |
