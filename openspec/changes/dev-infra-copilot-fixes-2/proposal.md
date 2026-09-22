# Proposal: dev-infra-copilot-fixes-2

> **Status:** proposed · **Scope:** dev-infra (scripts/verify-pre-{push,commit}.sh) + AI-tooling Markdown (.opencode/skills/book-rag/SKILL.md) · **Companion to:** `openspec/changes/dev-infra-copilot-fixes/` (PR #2's first Copilot-fixes change)
> **Escalation:** none — all edits stay within existing module boundaries. The scripts/ edits route through AGENTS.md §2.4 (dev-infra → `@reviewer`). Item C (SKILL.md:346 heading correction) is an `.opencode/` edit but flagged **§10 N/A** per owner ruling Q1.2 (see §10 flag below); it carries no config-semantic change and requires no AI Devtools Modernization Workflow.
> **Source:** GitHub Copilot review comments on PR #2 (Tilitronic/poetry-platform) — specifically comments **#10** and **#11** (unquoted `$WORKSPACE` in the delegated-paths `bash -lc` argument), plus one previously-suppressed observation **C** (SKILL.md:346 heading contradiction) owner-confirmed for inclusion in this follow-up.

## Motivation

PR #2's first Copilot-fixes change (`dev-infra-copilot-fixes`) addressed comments #1–#9. Comments **#10** and **#11** landed after that change was authored and target a distinct, latent defect in the same two husky-hook scripts: `scripts/verify-pre-push.sh` and `scripts/verify-pre-commit.sh`.

The defect: line 36 of each script constructs the delegated command as

```bash
docker compose -f "$ROOT/docker-compose.yml" exec -T dev bash -lc "cd $WORKSPACE && $cmd"
```

The `$WORKSPACE` expansion is **unquoted inside the double-quoted outer string**. When `POETRY_WORKSPACE` contains a whitespace character (e.g., `/home/dev/My Projects/poetry-platform`), the `cd` receives the path pre-split by the inner shell: `cd /home/dev/My` — fatal `cd: no such file or directory`. The same defect is present in **both** scripts at line 36 (verified in Phase 1).

While inspecting these two lines, a previously-suppressed observation **C** was re-surfaced: `.opencode/skills/book-rag/SKILL.md:346` carries a heading-adjacent contradiction — the "Any OS" bullet at line 346 instructs "use absolute path" while the immediately following "Linux / macOS" bullet at line 350 instructs "use relative path". These two bullets cannot simultaneously be correct. The owner ruled in Q1.3 / Phase 3 confirmation to fold this correction into the same change (single 1-line Markdown fix, no config-semantic impact).

## Scope

### In scope (exactly 3 edits + test companions — surgical)

1. **`scripts/verify-pre-push.sh:36`** — escaped-quoting fix for the delegated-paths `bash -lc` argument.
   Current: `bash -lc "cd $WORKSPACE && $cmd"`
   New: `bash -lc "cd \"${WORKSPACE}\" && ${cmd}"`
   The inner `cd` target is wrapped in escaped double quotes so the inner login shell receives the full (possibly space-containing) path as a single argument. `${WORKSPACE}` and `${cmd}` are wrapped in `${...}` braces for defensive expansion consistency. (Q2.1, Q2.2, Q2.3, Q2.4)

2. **`scripts/verify-pre-commit.sh:36`** — identical escaped-quoting fix, byte-for-byte parity with verify-pre-push.sh:36. (Q2.1, Q1.3 — "one change" ruling: the two scripts are edited identically so the fix is a single conceptual change expressed in two files.)

3. **`scripts/__tests__/verify-pre-push.bats`** — companion test updates:
   - **Update the existing line-30 assertion** (`assert_file_contains "$FAKE_DOCKER_LOG" "cd /workspace && npx lint-staged --allow-empty"` is in verify-pre-commit.bats; the verify-pre-push.bats equivalent asserts each step via a `for` loop) — adjusted to match the new escaped-quoting shape `cd \"/workspace\" && ...`. This is the mandatory companion: the existing assertion would otherwise fail because the logged delegated command now contains `\"` around `/workspace`. (Q7 — :30 mandatory companion)
   - **Add one new `@test`** that sets `POETRY_WORKSPACE` to a path containing a space (e.g., `"$BATS_TEST_TMPDIR/ws with spaces"`) and asserts the delegated log contains the full space-containing path (proving the inner shell receives it as a single argument). (Q7 — :30 new @test per script)

4. **`scripts/__tests__/verify-pre-commit.bats`** — same two test updates as verify-pre-push.bats:
   - **Update line 30** (`assert_file_contains "$FAKE_DOCKER_LOG" "cd /workspace && npx lint-staged --allow-empty"`) to the new escaped-quoting shape.
   - **Add one new `@test`** with a space-containing `POETRY_WORKSPACE`. (Q7 — :30 new @test per script)

5. **`.opencode/skills/book-rag/SKILL.md:346`** (item C) — 1-line Markdown heading correction.
   The "Any OS — use absolute path" bullet at line 346 is corrected so it no longer contradicts the "Linux / macOS ... relative path" bullet at line 350. The precise wording of the correction is the coder's call within the confirmed constraint: **the two bullets must not contradict each other on the absolute-vs-relative question**. (Q1.3 — owner ruled include; Phase 3 confirmation — "Fold in item C")

### Out of scope (interview-confirmed deferrals)

- **Empty-guard** on `$WORKSPACE` (e.g., `[ -z "$WORKSPACE" ] && exit 1`) — explicitly deferred per Q3 ("N/A" ruling). The existing default `WORKSPACE="${POETRY_WORKSPACE:-/workspace}"` already makes the variable non-empty in every reachable path; an empty-guard would be dead code.
- **Relative-path rejection** (e.g., rejecting `$WORKSPACE` unless it starts with `/`) — explicitly deferred per Q3. The fix addresses the space-in-path defect; path-shape validation is a separate concern.
- **Line 34** (`(cd "$WORKSPACE" && bash -lc "$cmd")` — the inside-container branch) — already correctly quoted; no defect. Not touched.
- **Diagnostics / error messaging** around a failed `cd` — explicitly deferred per Q6 ("no changes" ruling). The existing `set -euo pipefail` causes a non-zero exit; the error surfaces through native stderr. No additional diagnostics are added.
- **Makefile / `make test-shell` wiring changes** — the existing bats target already picks up the two modified bats files. No Makefile edit is required per Q6.
- **Any `.sdd/` document authoring** — no governing architecture exists for `scripts/verify-pre-*.sh` (see Design authority below); flagged as a gap, not invented here.
- **Any further Copilot comments** beyond #10 and #11 plus observation C.

## §10 flag — item C

Item C edits a file under `.opencode/skills/`. Per AGENTS.md §10, changes to AI tooling (agents, skills, rules, config, plugins, MCPs, permissions) must route through the AI Devtools Modernization Workflow (gate → @ai-specialist → review → design → implement → validate → register).

**This change flags item C as §10 N/A with the following rationale (owner ruling Q1.2):**

- The edit is a **Markdown heading-adjacent prose correction** — a single bullet's wording is adjusted so it no longer contradicts the adjacent bullet. No `SKILL.md` activation trigger, workflow phase, constraint, script reference, or tool-permission is changed.
- No config-semantic change: the skill's runtime behavior (which file it invokes, what arguments, what env vars) is unaffected. `query_rag.py` is not touched; the path-instruction prose is the only edit.
- No OpenCode restart is required — SKILL.md is read at skill-invocation time; the change is inert until the next invocation, at which point it is purely informational.
- The edit is a 1-line Markdown fix in a single file. The overhead of routing through @ai-specialist (Phase 1 research → Phase 2 review → Phase 3 design → Phase 5 validation → Phase 6 register) is disproportionate to the change's scope.

The orchestrator should record this §10 N/A flag in `.opencode/learnings/external-patterns/` if the pattern (Markdown-only prose correction in SKILL.md) is judged to set a reusable precedent; otherwise the flag stands as a one-time owner ruling for this change.

## Design authority (.sdd/) reference

**No `.sdd/` document governs the paths touched by this change.** The project's `.sdd/` directory contains only `.sdd/dia-redispatch-cycle/architecture.md` (DIA cycle protocol) and `.sdd/README.md`. None of the following have an `.sdd/` entry:

- `scripts/verify-pre-push.sh`, `scripts/verify-pre-commit.sh` (husky-hook verification gates)
- `scripts/__tests__/verify-pre-{push,commit}.bats` (hermetic bats tests for the above)
- `.opencode/skills/book-rag/SKILL.md` (AI-tooling skill documentation)

Per AGENTS.md §2.4 (dev-infra) and §3 (design authority), changes within existing boundaries route directly through the spec chain without architectural escalation. This change is entirely within existing boundaries — no new module is introduced, no cross-cutting technology decision is made, and `architecture.md` (root) is unaffected.

**⚠️ Gap flagged (parity with the prior dev-infra-copilot-fixes proposal):** the `scripts/verify-pre-{push,commit}.sh` pair is a de-facto module — two near-identical husky-hook gates that must stay in sync (run_workspace quoting, error contract, default-`$WORKSPACE` semantics). The absence of a `.sdd/scripts-verify-hooks/architecture.md` is a documentation gap. This change does NOT invent one; the parity requirement between the two scripts is enforced by this change's own test symmetry (one new `@test` per script, identical shape) and by the byte-for-byte identical quoting fix at line 36 of each. The owner may choose to dispatch `@architector` in a follow-up if the dual-hook pattern warrants formalization.

## Rollback plan

Every artifact is independently revertable. The change is a single conceptual fix (escaped quoting) applied to two files, plus two companion bats test updates, plus one Markdown heading correction. Each file is revertable via `git checkout` with no side effects on running services, no data migrations, and no runtime behavior change beyond the listed fixes.

| Artifact                                               | Revert                        |
| ------------------------------------------------------ | ----------------------------- |
| `scripts/verify-pre-push.sh` (line 36 quoting)         | `git checkout` prior line 36  |
| `scripts/verify-pre-commit.sh` (line 36 quoting)       | `git checkout` prior line 36  |
| `scripts/__tests__/verify-pre-push.bats` (:30 + new)   | `git checkout` prior file     |
| `scripts/__tests__/verify-pre-commit.bats` (:30 + new) | `git checkout` prior file     |
| `.opencode/skills/book-rag/SKILL.md` (line 346)        | `git checkout` prior line 346 |

No production code is modified. No data migrations. Rollback is `git checkout` per file, with no side effects on running services or committed configuration.

## Testing Decisions

> Per `openspec/config.yaml`: "Include a Testing Decisions section that states what makes a good test for this change, which modules will be tested, and the prior art in the codebase."

### What makes a good test here

This change is a **one-character-class defect** (missing escaped quotes) in a shell-interpolation context. Good tests must:

1. **Prove the defect is fixed** — the delegated `bash -lc` argument must pass the full space-containing `$WORKSPACE` to the inner shell as a single `cd` argument.
2. **Not regress the existing passing cases** — the default `WORKSPACE=/workspace` (no spaces) must continue to delegate correctly.
3. **Stay hermetic** — no real `docker compose exec`, no real container, no real `pnpm`/`npx`. The existing bats mock_docker infrastructure (FAKE_DOCKER_LOG) is the correct seam.

A good test is therefore a **bats assertion against `$FAKE_DOCKER_LOG`** — the fake docker binary records every delegated command it receives, and the test inspects the recorded command shape. This is the existing seam (see prior art below) and is sufficient: if the log contains `cd "/workspace with spaces" && ...` (with inner quotes preserved), the defect is proven fixed.

### Test layers (gates)

1. **`make test-shell`** (bats — **112/112** expected after this change).
   The existing suite is 110/110 (per Phase 1 count; 2 new tests → 112/112).
   - **Update the existing line-30 assertion in `verify-pre-commit.bats`** — the delegated-log text shape changes from `cd /workspace && npx lint-staged --allow-empty` to `cd \"/workspace\" && npx lint-staged --allow-empty`. This is a mandatory companion: without the update the existing test fails against the new production code. (:30 mandatory companion)
   - **Update the equivalent assertion(s) in `verify-pre-push.bats`** — same shape change for each step asserted via the `for` loop at lines 36-38.
   - **New `@test` in `verify-pre-commit.bats`**: set `POETRY_WORKSPACE="$BATS_TEST_TMPDIR/ws with spaces"`, run the script, assert `$FAKE_DOCKER_LOG` contains the space-containing path with inner quotes preserved. (Q7 — :30 new @test)
   - **New `@test` in `verify-pre-push.bats`**: identical shape, identical assertion strategy. (Q7 — :30 new @test)

2. **`bash -n` syntax check** on both modified scripts — static validation that the escaped-quoting fix is syntactically valid bash. Run as part of the coder's verification gate (not a separate bats test — `bash -n` is the standard shell-lint, and adding it as a bats test would be over-engineering for a 2-file change).

3. **`openspec validate dev-infra-copilot-fixes-2`** — routed through a coder lane (the openspec CLI is blocked in @openspec-plan's lane via permission shadowing — catch-all `*` deny shadows `openspec *` allow). Coder lane runs the validation; result feeds back into the implementation task's verification evidence.

### What we explicitly do NOT test

- **A real `docker compose exec` with a space-containing `POETRY_WORKSPACE`** — slow, requires a real container, and the bats mock already exercises the exact code path (the `docker` binary is the fake one that logs to `$FAKE_DOCKER_LOG`).
- **The inside-container branch (line 34)** — already correctly quoted; out of scope per Q6.
- **Empty-guard or relative-path-rejection paths** — explicitly deferred per Q3.
- **The SKILL.md:346 correction** — no automated test; the fix is a 1-line Markdown prose correction. Structural review by `@reviewer` (Standards axis) is the appropriate gate.

### Two-axis review matrix

| Routing                  | Reviewer                                          | Gate                                                                                          |
| ------------------------ | ------------------------------------------------- | --------------------------------------------------------------------------------------------- |
| AGENTS.md §2.4 dev-infra | `@reviewer` (two-axis: Standards + Spec fidelity) | `make test-shell` 112/112 + `bash -n` both scripts + coder handoff with verification evidence |

Item C routes with the same change (no separate §10 review — §10 flagged N/A per owner ruling Q1.2).

### Prior art in the codebase

- **Hermetic bats + `FAKE_DOCKER_LOG` seam:** `scripts/__tests__/test-helper.bash` defines `mock_docker`, which installs a fake `docker` binary on `$PATH` that logs every invocation to `$FAKE_DOCKER_LOG`. Existing tests (`verify-pre-commit.bats:30`, `verify-pre-push.bats:36-38`) already use `assert_file_contains "$FAKE_DOCKER_LOG" ...` to verify the delegated command shape. The new space-containing-path test is a natural extension of this seam.
- **Space-in-path testing pattern:** `scripts/__tests__/verify-pre-commit.bats:56-86` and `verify-pre-push.bats:52-85` already set `POETRY_WORKSPACE="$BATS_TEST_TMPDIR/ws"` for the inside-container tests. The new host-side space-path test mirrors this pattern but asserts against `$FAKE_DOCKER_LOG` instead of `$NPX_LOG`/`$PNPM_LOG`.
- **Escaped-quoting idiom in shell:** `bash -lc "cd \"${VAR}\" && cmd"` is a standard POSIX/bash idiom for forwarding a variable through a double-quoted outer string into an inner login shell. No project-specific precedent needed — the idiom is self-documenting and universally portable.

### Test risk and mitigation

**Risk:** the new space-path test passes even if the fix is incomplete (e.g., only one of the two scripts is fixed). **Mitigation:** the test is added to **both** bats files (verify-pre-push.bats and verify-pre-commit.bats), so each script is independently exercised. A partial fix fails one test and passes the other.

**Risk:** the existing line-30 assertion update accidentally drops coverage (e.g., by weakening the assertion to match both the old and new shape). **Mitigation:** the assertion is tightened, not weakened — it asserts the exact new shape `cd \"/workspace\" && npx lint-staged --allow-empty` (with escaped quotes). A regression that drops the inner quotes would fail the assertion.

**Risk:** `make test-shell` count mismatch (112/112 expected) if the test-helper counts differ. **Mitigation:** the coder's verification evidence must include the exact test count (`N tests, 0 failures`). The expected count of 112 is based on the Phase 1 count of 110 + 2 new tests. If the actual count differs, the coder flags the delta in handoff evidence; the reviewer verifies the delta is explained (e.g., if a concurrent change added tests).
