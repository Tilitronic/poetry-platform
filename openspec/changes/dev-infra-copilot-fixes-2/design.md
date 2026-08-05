# Design: dev-infra-copilot-fixes-2

> **Proposal:** `openspec/changes/dev-infra-copilot-fixes-2/proposal.md`
> **Companion to:** `openspec/changes/dev-infra-copilot-fixes/` (PR #2's first Copilot-fixes change)
> **Scope:** implementation design only — no system architecture decisions, no `.sdd/` escalation required. The change is within existing module boundaries; the scripts/ edits route through AGENTS.md §2.4 (`@reviewer`). Item C (SKILL.md:346) is flagged §10 N/A per owner ruling Q1.2 (see proposal §10 flag).

## Approach

This change stays entirely within existing module boundaries. It does not introduce any new module, does not alter any data flow described in `architecture.md` (root), and does not affect the DIA redispatch cycle or any other governed protocol. The `.sdd/` directory contains only `.sdd/dia-redispatch-cycle/architecture.md` + `README.md` — no module doc governs `scripts/verify-pre-{push,commit}.sh` or `.opencode/skills/book-rag/`. Per AGENTS.md §3, the absence of a governing `.sdd/` is a documentation gap, but one this change does not fill: the fixes are local, bounded, and the parity requirement between the two scripts is enforced by the identical shape of the quoting fix at line 36 of each and by the symmetric test additions (one new `@test` per script).

Existing patterns followed:

- **Hermetic bats + `FAKE_DOCKER_LOG` seam:** the new space-in-path tests use the existing `mock_docker` helper from `scripts/__tests__/test-helper.bash`, matching the existing `verify-pre-commit.bats:30` and `verify-pre-push.bats:36-38` convention.
- **Escaped-quoting idiom:** `bash -lc "cd \"${WORKSPACE}\" && ${cmd}"` is the standard POSIX/bash pattern for forwarding a variable through a double-quoted outer string into an inner login shell. No project-specific precedent needed — the idiom is self-documenting.
- **Byte-for-byte script parity:** the two verify-pre-\*.sh scripts are edited identically at line 36 (same fix, same shape, same rationale), so a future reader comparing the two files sees no divergence in the quoting strategy.

## Files changed

| File                                          | Change                                                                                                                                                                                                                                                                                                                                                                                                                                                                 | Exact location                                                                                      |
| --------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------- |
| `scripts/verify-pre-push.sh`                  | Line 36 escaped-quoting fix. Current: `bash -lc "cd $WORKSPACE && $cmd"`. New: `bash -lc "cd \"${WORKSPACE}\" && ${cmd}"`. The inner `cd` target is wrapped in escaped double quotes so the inner login shell receives the full (possibly space-containing) path as a single argument. `${WORKSPACE}` and `${cmd}` use `${...}` braces for defensive expansion consistency.                                                                                            | Line 36 (the `else` branch of `run_workspace`, the `docker compose exec -T dev bash -lc ...` call). |
| `scripts/verify-pre-commit.sh`                | Identical escaped-quoting fix at line 36. Byte-for-byte parity with `verify-pre-push.sh:36`.                                                                                                                                                                                                                                                                                                                                                                           | Line 36 (the `else` branch of `run_workspace`, the `docker compose exec -T dev bash -lc ...` call). |
| `scripts/__tests__/verify-pre-push.bats`      | (a) Update the existing `for` loop assertion at lines 36-38 — the `assert_file_contains "$FAKE_DOCKER_LOG" "$step"` shape remains correct (the step name `verify:format` / `verify:js` etc. is unchanged), but the test's intent should be re-verified against the new quoting. (b) Add one new `@test` that sets `POETRY_WORKSPACE="$BATS_TEST_TMPDIR/ws with spaces"` and asserts `$FAKE_DOCKER_LOG` contains the space-containing path with inner quotes preserved. | Lines 36-38 (update verification); new `@test` block appended to end of file.                       |
| `scripts/__tests__/verify-pre-commit.bats`    | (a) Update line 30 assertion: `assert_file_contains "$FAKE_DOCKER_LOG" "cd /workspace && npx lint-staged --allow-empty"` → `assert_file_contains "$FAKE_DOCKER_LOG" "cd \"/workspace\" && npx lint-staged --allow-empty"`. (b) Add one new `@test` with space-containing `POETRY_WORKSPACE`, asserting the delegated log preserves the space.                                                                                                                          | Line 30 (update); new `@test` block appended to end of file.                                        |
| `.opencode/skills/book-rag/SKILL.md` (item C) | 1-line Markdown heading correction at line 346. The "Any OS — use absolute path" bullet is reworded so it no longer contradicts the "Linux / macOS ... relative path" bullet at line 350. The coder has discretion on the exact wording within the confirmed constraint: the two bullets must not contradict each other on the absolute-vs-relative question.                                                                                                          | Line 346 (single-line edit).                                                                        |

## Implementation details

### The escaped-quoting fix (line 36 of both scripts)

Current (both scripts, identical at line 36):

```bash
docker compose -f "$ROOT/docker-compose.yml" exec -T dev bash -lc "cd $WORKSPACE && $cmd"
```

The problem: `$WORKSPACE` is expanded by the **outer** shell before the string is passed to `bash -lc`. If `WORKSPACE="/home/dev/My Projects/poetry-platform"`, the outer shell produces:

```bash
bash -lc "cd /home/dev/My Projects/poetry-platform && pnpm verify:format"
```

The inner login shell then executes `cd /home/dev/My Projects/poetry-platform && ...` — and `cd` receives `/home/dev/My` as its argument (the first unquoted word), which fails with `cd: no such file or directory: /home/dev/My`.

New:

```bash
docker compose -f "$ROOT/docker-compose.yml" exec -T dev bash -lc "cd \"${WORKSPACE}\" && ${cmd}"
```

The fix:

- `\"${WORKSPACE}\"` — escaped double quotes around `${WORKSPACE}`. The outer shell expands `${WORKSPACE}` to the path, but the escaped `\"` become literal `"` characters in the string passed to `bash -lc`. The inner login shell then sees `cd "/home/dev/My Projects/poetry-platform" && ...` — the full path is a single quoted argument to `cd`.
- `${cmd}` — wrapped in `${...}` braces for defensive expansion consistency (the existing `$cmd` works but `${cmd}` is more explicit and matches the `${WORKSPACE}` style).

**Why this specific escape sequence (Q2.4 rationale):**

- **Single quotes inside double quotes don't work here** — `'cd '"'$WORKSPACE'"' && ...'` is syntactically valid but harder to read and maintain. The escaped-double-quote form is the standard idiom.
- **`cd "$WORKSPACE"` without escaping** — does not work because the outer double quotes would terminate at the inner `"`, producing a syntax error.
- **`cd \$WORKSPACE` (backslash escape)** — works but is fragile: the backslash is consumed by the outer shell, and the inner shell sees `$WORKSPACE` unquoted — back to the original defect.
- **`cd \"${WORKSPACE}\"`** — the chosen form. Explicit, readable, standard idiom, preserves the inner quotes through the outer shell's expansion.

### Error-handling contract (Q5 — no changes)

The existing error-handling contract is preserved unchanged:

- `set -euo pipefail` at the top of each script (lines 13) means any non-zero exit from `cd` (e.g., invalid path) or `$cmd` propagates immediately.
- The script exits with the non-zero status from the failing command — no custom error message, no custom stderr formatting.
- Native stderr is the error channel: `docker compose exec` surfaces the inner shell's stderr to the host's stderr.
- The pre-push hook (verify-pre-push.sh) has an additional layer: if the dev container is not running, it warns and exits 0 (never blocks a push). If the container IS running and a verification step fails, it exits non-zero (blocks the push).
- The pre-commit hook (verify-pre-commit.sh) fails by default if the dev container is not running (exit 1 with a clear message — D1 in the bats file header comments).

This change does NOT add new diagnostics, new error messages, or new error-handling paths (Q5, Q6 — "no changes" ruling). The fix only ensures the `cd` command receives the correct path argument; failure modes are unchanged.

### Item C — SKILL.md:346 heading correction

Current (line 346):

````markdown
- **Any OS — use absolute path:** Always use the **absolute path**:
  ```bash
  python3 .opencode/scripts/query_rag.py "#csc OOP"
  ```
````

````

Followed by (line 350):

```markdown
- **Linux / macOS:** Use `python3` and the relative path from the skill base:
  ```bash
  python3 ../../scripts/query_rag.py "#csc OOP"
````

```

The contradiction: line 346 says "Any OS — use absolute path" but line 350 says "Linux / macOS ... relative path". Both cannot be correct.

The fix (coder discretion within confirmed constraint): reword line 346 so the two bullets are consistent. Possible forms:

- **Option A:** change line 346's heading to "Any OS — the script path is relative to the skill base" (aligns with line 350's "relative path" instruction).
- **Option B:** change line 346 to clarify it's about the `python3` invocation path (which is relative) vs. some other absolute path (e.g., the knowledge-bases.yaml cache path).
- **Option C:** merge the two bullets into one coherent instruction.

The coder picks the option that best preserves the original intent (whatever that intent was — the coder may need to inspect the surrounding context at lines 330-360 to determine whether the original author meant "absolute path to the skill base" or "absolute path to the knowledge-bases.yaml cache"). The confirmed constraint is: **the two bullets must not contradict each other on the absolute-vs-relative question**.

## Seams

> Per `openspec/config.yaml`: "Include a Seams section listing the pre-agreed public boundaries where tests will live. Prefer existing seams; propose new ones only at the highest level necessary."

| Seam                                                           | What it is                                                                                                                | Test location                                                | Test type                                                                                                      |
| -------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------- |
| **Escaped-quoting in `run_workspace` (verify-pre-push.sh:36)** | The delegated `bash -lc` argument must pass the full space-containing `$WORKSPACE` to the inner shell as a single `cd` argument | `scripts/__tests__/verify-pre-push.bats` (existing seam)     | Behavioral test via `FAKE_DOCKER_LOG` — assert the logged command contains the space-containing path with inner quotes preserved |
| **Escaped-quoting in `run_workspace` (verify-pre-commit.sh:36)** | Parity with verify-pre-push.sh:36                                                                                         | `scripts/__tests__/verify-pre-commit.bats` (existing seam)   | Same shape of behavioral test via `FAKE_DOCKER_LOG`                                                            |
| **Existing line-30 assertion (verify-pre-commit.bats:30)**     | The delegated-log text shape must match the new quoting                                                                 | `scripts/__tests__/verify-pre-commit.bats:30` (existing assertion — update) | `assert_file_contains "$FAKE_DOCKER_LOG" "cd \"/workspace\" && npx lint-staged --allow-empty"` (updated assertion) |
| **SKILL.md:346 heading correction (item C)**                   | The "Any OS" bullet must not contradict the "Linux / macOS" bullet on absolute-vs-relative                                 | No automated test — structural review by `@reviewer`         | Visual review (Standards axis of two-axis review)                                                              |

### New seams vs. existing seams

- **Space-in-path behavioral test:** extends the existing `verify-pre-push.bats` and `verify-pre-commit.bats` seams via the existing `mock_docker` / `FAKE_DOCKER_LOG` helper from `test-helper.bash`. No new seam.
- **Line-30 assertion update:** modifies an existing assertion in `verify-pre-commit.bats:30` to match the new production-code shape. No new seam.
- **SKILL.md:346 correction:** no automated test — the fix is a 1-line Markdown prose correction. Structural review by `@reviewer` is the appropriate gate.

### Testability env seams

No new env overrides needed for this change. The existing `FAKE_DOCKER_LOG` (set by `mock_docker` in `test-helper.bash`) is reused by the new space-in-path tests. The new tests set `POETRY_WORKSPACE="$BATS_TEST_TMPDIR/ws with spaces"` — this is a new env value but not a new env seam (the `WORKSPACE="${POETRY_WORKSPACE:-/workspace}"` default at line 18 of both scripts already supports the override).

## Design constraints and trade-offs

### Why escaped double quotes (not single quotes, not backslash escape)

See Implementation details § The escaped-quoting fix above. The chosen form `\"${WORKSPACE}\"` is the standard POSIX/bash idiom for this exact scenario (forwarding a variable through a double-quoted outer string into an inner shell). Alternatives were considered and rejected (see Q2.4 rationale in the proposal and the Implementation details above).

### Why the same fix in both scripts (not just one)

The two scripts are near-identical copies with one behavioral difference (pre-push warns and passes when the container is down; pre-commit fails by default — D1). The `run_workspace` function is byte-for-byte identical in both (lines 30-38 of each). The defect is at line 36 of each. Fixing only one would leave the other broken and create a parity violation that a future reader would have to rediscover. The owner ruled Q1.3 ("one change") — the two scripts are edited identically so the fix is a single conceptual change expressed in two files.

### Why update the existing line-30 assertion (not just add new tests)

The existing assertion `assert_file_contains "$FAKE_DOCKER_LOG" "cd /workspace && npx lint-staged --allow-empty"` asserts the **unquoted** shape. After the fix, the logged command is `cd \"/workspace\" && npx lint-staged --allow-empty` (with inner quotes). The existing assertion would fail against the new production code. Updating it is a mandatory companion — without the update, the existing test suite breaks. This is the ":30 mandatory companion" referred to in Q7.

### Why one new `@test` per script (not one combined test)

The two scripts are tested in separate bats files (`verify-pre-push.bats` and `verify-pre-commit.bats`). A combined test would require either (a) a new bats file that tests both scripts (breaking the existing 1:1 mapping between bats file and script), or (b) adding the space-path assertion to an existing test in each file (which conflates the space-path concern with the existing delegation concern). One new `@test` per file keeps the concerns separated: the existing delegation tests verify the default path; the new space-path tests verify the space-containing path. Each test has a single reason to fail.

### Why `bash -n` syntax check (not a bats test for syntax)

`bash -n` is the standard shell-lint tool — it parses the script without executing it and reports syntax errors. Adding a bats test that runs `bash -n` on the modified scripts would be over-engineering for a 2-file change. The coder runs `bash -n scripts/verify-pre-push.sh scripts/verify-pre-commit.sh` as part of the verification gate (see tasks.md). If the syntax is invalid, `bash -n` exits non-zero and the coder sees the error immediately. No bats test is needed.

### Why no `.sdd/` document for this change

The change is a surgical bug fix (escaped quoting) in two existing scripts. It does not introduce a new module, does not alter any data flow, and does not make any cross-cutting technology decision. Per AGENTS.md §2.1, `@architector` is dispatched only when "a new module boundary, technology decision, or cross-cutting concern is needed". None of those apply here. The absence of a `.sdd/scripts-verify-hooks/architecture.md` is a documentation gap (flagged in the proposal), but one this change does not fill. The parity requirement between the two scripts is enforced by the identical shape of the fix and the symmetric test additions.

### Why item C is §10 N/A (not routed through @ai-specialist)

See proposal §10 flag. The edit is a 1-line Markdown prose correction with no config-semantic impact. The overhead of routing through the AI Devtools Modernization Workflow (Phase 1 @ai-specialist research → Phase 2 review → Phase 3 design → Phase 5 validation → Phase 6 register) is disproportionate to the change's scope. The owner ruled Q1.2 (§10 N/A with rationale).
```
