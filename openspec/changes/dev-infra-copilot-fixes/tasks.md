# Tasks: dev-infra-copilot-fixes

> **Proposal:** `openspec/changes/dev-infra-copilot-fixes/proposal.md`
> **Design:** `openspec/changes/dev-infra-copilot-fixes/design.md`
> **Workflow:** per `openspec/config.yaml`, each task is a vertical slice invoked via the `tdd-craftsman` skill. Write the failing test BEFORE production code. Work one slice at a time.
> **Routing:** the two tasks map 1:1 to the two commits. Task 1 routes through AGENTS.md §2.4 (`@reviewer`); Task 2 routes through AGENTS.md §10 (`@ai-specialist`). Each task's handoff must include verification evidence (exit codes + summary lines) per AGENTS.md §2.3.

## Dependency graph

```
T1 — Commit A: dev-infra fixes (§2.4 → @reviewer)
 │  fixes #1, #4, #6, #7 + secrets/README.md + arch-failfast bats + empty-secret bats
 │
 │  (independent — no dependency on T2)
 │
T2 — Commit B: AI-tooling config fixes (§10 → @ai-specialist)
    fixes #2, #3, #5, #8 + .gitignore entry + failures.md dedup
```

**Critical path:** T1 and T2 are independent and can be implemented in either order or in parallel. They will be merged as two separate commits on the same PR, in the order T1 → T2 (dev-infra first, AI-tooling second — matches the ordering of the Copilot review comments).

**Rationale for independence:** the two tasks touch disjoint files. T1 touches `scripts/`, `tools/opencode-docker/Dockerfile`, `dev-entrypoint.sh`, `scripts/dev-secrets-profile.sh`, `secrets/README.md`, and bats test files. T2 touches `.opencode/commands/`, `.config/opencode/skills/`, root `.gitignore`, and `.opencode/memory/failures.md`. There is no shared state, no shared interface, no sequential dependency.

---

## T1 — Commit A: dev-infra fixes (§2.4 → `@reviewer`)

**Blockers:** none
**Vertical slice:** all four dev-infra fixes + companion docs update + two new bats tests. The slice is "demoable" in the sense that after T1, the full dev-infra test gate (`make test-shell` + `make test-infra`) passes and the dev-stack output is accurate.

**Routing:** AGENTS.md §2.4 → `@reviewer` (two-axis: Standards + Spec fidelity)
**Commit message template:** `fix(dev-infra): address Copilot review comments #1, #4, #6, #7 on PR #2`

### What changes

1. **`scripts/dev-stack.sh` (fix #1) — output correction.**
   Replace lines 44-47 with accurate messaging that names only `author-studio` as turbo-managed, notes `api-server` and `publishing-platform` are started separately, and drops the fabricated URLs. Reference `docs/docker-dev.md` in the human-readable note, not as a doc-path citation in the URLs (E4). No behavior change to `docker compose exec -it dev pnpm dev`.

2. **`tools/opencode-docker/Dockerfile` (fix #4) — four `*)` fail-fast branches.**
   Add `*) echo "ERROR: unsupported TARGETARCH='${TARGETARCH}'. Supported: amd64, arm64." >&2; exit 1 ;;` to each of the four `*_ARCH=$(case ...)` blocks at lines 33, 57, 65, 75. Placement: immediately after the last concrete arm, before `esac)`. Identical text across all four blocks.

3. **`dev-entrypoint.sh` (fix #6) — empty-secret skip.**
   Insert `[ ! -s "$file" ]` check after `[ -f "$file" ]`, before the export. On empty file: print `[dev-entrypoint] [skip] secret '<name>': file empty or zero-byte, not wiring` to stderr, `continue` the loop. Strict zero-byte check (E1 — whitespace-only files still load).

4. **`scripts/dev-secrets-profile.sh` (fix #7) — parity with entrypoint.**
   Insert the same `[ ! -s "$secret" ]` check inside the `for secret in /run/secrets/*` loop body, before the `case` dispatch. Print `[dev-secrets-profile] [skip] secret '<name>': file empty or zero-byte, not wiring` to stderr, `continue`. Same strict zero-byte semantics as entrypoint.

5. **`secrets/README.md` — sync note.**
   Add a short note (in the "Empty placeholder files are the valid initialization state" section, after line 38) making the skip behavior explicit: "empty/zero-byte secret files are SKIPPED, not wired; dev env boots degraded". Must ship in the same commit as #6 and #7.

6. **`scripts/__tests__/opencode-docker.bats` — arch-failfast test (fix #4 companion).**
   Append a new `@test` block asserting that each of the four `*_ARCH=$(case` blocks in `tools/opencode-docker/Dockerfile` contains a `*)` arm. Static grep over the Dockerfile text. One assertion per variable name (`NODE_ARCH`, `MISE_ARCH`, `SNIP_ARCH`, `UV_ARCH`) so a regression dropping a single branch fails specifically.

7. **`scripts/__tests__/dev-entrypoint.bats` — empty-secret skip test (fix #6 companion).**
   Append a new `@test` block: create a zero-byte whitelisted secret file in the tmpfs secrets dir, run the entrypoint via `run_entrypoint_ns`, assert the env var is unset AND stderr contains the `[dev-entrypoint] [skip]` message.

8. **(Conditional) `scripts/__tests__/dev-secrets-profile.bats` — parity test (fix #7 companion).**
   If the existing `test-helper.bash` supports running the profile script in a namespace, append to `dev-entrypoint.bats`. Otherwise create a new `dev-secrets-profile.bats` file. Decision: the implementation task makes this call based on `test-helper.bash` capabilities; default to appending to `dev-entrypoint.bats`.

### Acceptance criteria (user perspective)

- Running `bash scripts/dev-stack.sh` prints output that names only `author-studio` as turbo-managed and clearly states api-server/publishing are started separately.
- Building the opencode-docker Dockerfile with an unsupported `TARGETARCH` (e.g., `riscv64`) fails at build time with the explicit `ERROR: unsupported TARGETARCH=...` message.
- Building the Dockerfile with `TARGETARCH=amd64` or `arm64` still succeeds (happy path preserved — verify manually, Q7).
- Starting the dev container with a zero-byte whitelisted secret file: the env var is NOT set, stderr shows `[dev-entrypoint] [skip] secret '<name>': file empty or zero-byte, not wiring`, and the container boots successfully (degraded, not crashed).
- An interactive `docker compose exec dev bash` shell with a zero-byte whitelisted secret file shows the same `[dev-secrets-profile] [skip]` message in the profile load log and the env var is unset.
- `make test-shell` passes with all 90/90 existing bats tests + the new arch-failfast test + the new empty-secret skip tests.
- `make test-infra` passes (full dev stack build + smoke probes).
- `secrets/README.md` clearly documents the skip behavior.

### Testing

- RED-GREEN: write the new bats tests first (they fail because T1 may not yet handle all edge cases), then implement T1 until they pass.
- The arch-failfast test is a pure structural assertion (grep over a static file) — it can be written first and will stay RED until the Dockerfile is updated.
- The empty-secret skip test uses the existing `run_entrypoint_ns` helper — no new test infrastructure needed.

### Verification evidence (coder handoff to @reviewer)

The coder's handoff must include:

- `make test-shell` exit code + summary line (e.g., `92 tests, 0 failures`).
- `make test-infra` exit code + summary lines.
- Confirmation that the four Dockerfile `*)` branches are present (one-line grep output).
- Confirmation that the dev-stack output no longer mentions `api-server` or `publishing` as turbo-managed.

---

## T2 — Commit B: AI-tooling config fixes (§10 → `@ai-specialist`)

**Blockers:** none (independent of T1; ordered after T1 in the PR for logical grouping)
**Vertical slice:** all four AI-tooling config fixes + root `.gitignore` entry + runtime cache deletion. The slice is "demoable" in the sense that after T2, `make test-config` passes, no `/home/qualt` literal remains in the telemetry commands, and the committed runtime cache is gone with a gitignore guard against re-committing.

**Routing:** AGENTS.md §10 → `@ai-specialist` (independent review against best practices + AIHero patterns; §10.5 independent reviewer role)
**Commit message template:** `fix(ai-config): address Copilot review comments #2, #3, #5, #8 on PR #2`

### What changes

1. **`.opencode/commands/telemetry-report.md` (fix #2) — `${HOME:?...}` guard.**
   Replace the hardcoded `/home/qualt/.cache/opencode/packages/opencode-telemetry@0.1.19/...` paths with `${HOME:?HOME is not set; cannot locate opencode-telemetry package}/.cache/opencode/packages/opencode-telemetry@0.1.19/...` in both the `bun run` and `node` fallback paths. No `/home/qualt` literal remains anywhere in the file.

2. **`.opencode/commands/telemetry-inspect.md` (fix #3) — `${HOME:?...}` guard.**
   Same substitution as `telemetry-report.md`. `$ARGUMENTS` preserved at the end of each path.

3. **`.config/opencode/skills/book-rag/knowledge-bases.yaml` — deletion.**
   Delete the file. It is a committed runtime cache (environment-specific timestamps `cached_at`/`ttl_seconds` + test data `test_kb`) regenerated on demand by `.opencode/scripts/query_rag.py` (the consumer referenced at `.opencode/skills/book-rag/SKILL.md:38`). Version-controlling this cache produces noise diffs.

4. **Root `.gitignore` — path-scoped entry.**
   Add a new section near the existing `knowledge/*/sources/` ignore:

   ```gitignore
   # === Generated RAG / skill caches ===
   # Generated RAG index cache (book-rag skill); regenerate via book-rag skill
   .config/opencode/skills/book-rag/knowledge-bases.yaml
   ```

5. **`.opencode/memory/failures.md` (fix #8) — dedup.**
   Remove the duplicated "MCP header-name mismatch risk" bullet. Lines 11-13 currently have the bullet twice (line 11 no-indent, line 12 one-space-indent); line 13 carries the Resolution. Keep one bullet (the line 11 form) followed by the Resolution. No other changes to `failures.md`.

### Acceptance criteria (user perspective)

- `.opencode/commands/telemetry-report.md` and `.opencode/commands/telemetry-inspect.md` contain no `/home/qualt` literal. Both use `${HOME:?...}` guards.
- Running the telemetry commands on a machine where `HOME` is unset produces a clear `HOME: HOME is not set; ...` error on stderr and exits non-zero (Q5).
- Running the telemetry commands on a normal machine (HOME set) succeeds as before (the path resolves correctly).
- `.config/opencode/skills/book-rag/knowledge-bases.yaml` does not exist in the repo after T2.
- `git check-ignore .config/opencode/skills/book-rag/knowledge-bases.yaml` exits 0 (the file is gitignored; a future `book-rag skill` run will not re-commit the cache).
- `.opencode/memory/failures.md` has exactly one "MCP header-name mismatch risk" bullet + its Resolution (not two).
- `make test-config` passes (schema validation of opencode config).
- `query_rag.py` itself is NOT modified in this PR — refactoring the `book-rag` skill or the cache-regeneration flow is out of scope.

### Testing

- No new automated test for T2 — the fixes are one-line substitutions, file deletion, and a gitignore entry. Structural review by `@ai-specialist` is the appropriate gate (this is AI-tooling config, not production code).
- The `${HOME:?...}` substitution can be manually verified by inspecting the file content.
- The gitignore entry can be verified with `git check-ignore`.
- The `failures.md` dedup is a visual review — grep for "MCP header-name mismatch" should return exactly one match (plus the Resolution line).

### Verification evidence (coder handoff to @ai-specialist)

The coder's handoff must include:

- `make test-config` exit code + summary.
- `grep -c '/home/qualt' .opencode/commands/telemetry-report.md .opencode/commands/telemetry-inspect.md` output: both should be `0`.
- Confirmation that `.config/opencode/skills/book-rag/knowledge-bases.yaml` is deleted.
- `git check-ignore .config/opencode/skills/book-rag/knowledge-bases.yaml` exit code (should be 0).
- `grep -c 'MCP header-name mismatch' .opencode/memory/failures.md` output: should be `1` (one bullet remains).

---

## Implementation order (suggested)

1. **Start with T1** (dev-infra fixes) — no blockers, more complex (4 fixes + 2 tests + 1 doc update), routes through `@reviewer`. Write the bats tests RED, then implement until GREEN.
2. **Then T2** (AI-tooling config fixes) — no blockers, simpler (one-line substitutions + file deletion + gitignore + dedup), routes through `@ai-specialist`. Quick to implement.
3. **Final PR description** must acknowledge both review chains explicitly so `@reviewer` and `@ai-specialist` self-select. The PR description should also note the out-of-scope boundary (refactoring the `book-rag` skill / `query_rag.py` cache-regeneration flow) so reviewers know it's deferred intentionally.

## Out of scope for these tasks

- Refactoring the `book-rag` skill or changing the cache-regeneration behavior of `query_rag.py` (Q1c — follow-up after this PR).
- Compose `environment:` changes (no third secret loader in this scope).
- Rewriting the 9-ahead local commits (append-only; this PR adds two new commits on top).
- Any `.sdd/` document authoring (gap flagged in proposal, not filled here).
- Real `docker build` multi-arch testing (manual verify per Q7; bats covers the unhappy path structurally).
- Visual testing of dev-stack output (manual; the assertion is "matches docs/docker-dev.md").
- Any change beyond the 8 confirmed Copilot review fixes.

## Verification gate summary

| Gate                                       | When                     | Required                                          |
| ------------------------------------------ | ------------------------ | ------------------------------------------------- |
| `make test-shell`                          | After T1                 | All 90/90 existing + 2 new tests pass (exit 0)    |
| `make test-infra`                          | After T1                 | Full dev stack build + smoke probes pass (exit 0) |
| `make test-config`                         | After T2                 | opencode config schema validation passes (exit 0) |
| `pnpm verify:js`                           | After T1+T2 (final gate) | TypeScript lint passes (exit 0)                   |
| `pnpm verify:js-tests`                     | After T1+T2 (final gate) | TS unit tests pass (exit 0)                       |
| Manual: dev-stack output                   | After T1                 | Output matches `docs/docker-dev.md` (visual)      |
| Manual: Dockerfile amd64/arm64 build       | After T1                 | Happy-path builds still succeed (Q7)              |
| Manual: telemetry commands with HOME set   | After T2                 | Commands run successfully                         |
| Manual: telemetry commands with HOME unset | After T2                 | Hard exit with clear message (Q5)                 |
