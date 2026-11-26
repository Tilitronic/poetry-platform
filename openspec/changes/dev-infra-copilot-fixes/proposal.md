# Proposal: dev-infra-copilot-fixes

> **Status:** proposed · **Scope:** dev-infra (scripts/, Dockerfile, entrypoints, secrets/) + AI-tooling config (.opencode/commands/, .config/opencode/skills/, .opencode/memory/)
> **Escalation:** none — both commit chains stay within existing module boundaries. Commit A routes through AGENTS.md §2.4 (dev-infra → @reviewer); Commit B routes through AGENTS.md §10 (AI Devtools Modernization Workflow → @ai-specialist). The PR description must acknowledge both review chains so reviewers see the routing explicitly.
> **Source:** GitHub Copilot review comments on PR #2 (Tilitronic/poetry-platform). All 8 findings owner-confirmed via Socratic interview; every decision below traces to a confirmed answer (Q1–Q7, E1, E4).

## Motivation

PR #2 (the current dev-infrastructure hardening PR) received 8 GitHub Copilot review comments spanning two orthogonal concerns: dev-infra correctness issues in scripts and the opencode-docker `Dockerfile`, and AI-tooling configuration issues in `.opencode/` and `.config/opencode/`. Each finding has been reviewed by the project owner and confirmed as a genuine defect worth fixing in a single follow-up PR on the same branch (`further-dev-infrastructure-development`).

The fixes fall cleanly into two commits along the routing boundary already defined by AGENTS.md:

1. **Commit A — dev-infra fixes (§2.4 → `@reviewer`):** misleading user output, missing fail-fast defaults in arch-dispatch `case` statements, and zero-byte secret handling that contradicts `secrets/README.md`.
2. **Commit B — AI-tooling config fixes (§10 → `@ai-specialist`):** hardcoded `/home/qualt` paths in telemetry commands, a committed runtime cache file that should be gitignored, and a duplicated failure entry in `failures.md`.

The scope is intentionally narrow: every fix is local, bounded, and independently revertable. Nothing here changes runtime behavior of application code, alters turbo invocation, introduces new modules, or modifies architecture. No `.sdd/` document governs any of the affected paths.

## Scope

### In scope (exactly 8 fixes — no more, no less)

**Commit A — dev-infra (§2.4 → `@reviewer`):**

1. **#1 — `scripts/dev-stack.sh:44-47` (misleading output).**
   Currently echoes `"starting all app services (turbo run dev)..."` and advertises URLs for `author-studio`, `api-server`, and `publishing`. `docs/docker-dev.md:14-18` confirms turbo **only** starts `author-studio`; `api-server` is FastAPI/uvicorn started manually and `publishing-platform` has no `dev` script. Fix: rewrite the output to name only `author-studio`, mention that `api-server` and `publishing` must be started separately, and omit the fabricated URLs. No doc-path citation in user-facing output (E4). No behavior change to the `turbo` invocation.

2. **#4 — `tools/opencode-docker/Dockerfile:33,57,65,75` (missing `*)` fail-fast branches).**
   Four arch-dispatch `case` statements (`NODE_ARCH`, `MISE_ARCH`, `SNIP_ARCH`, `UV_ARCH`) lack a default branch. An unsupported `TARGETARCH` produces an empty `$*_ARCH` variable and a malformed download URL — silent build corruption. Fix: add a `*)` branch to **all four** (consistency sweep; Copilot flagged MISE only, but the defect is identical in all four). Each branch prints `ERROR: unsupported TARGETARCH='${TARGETARCH}'. Supported: amd64, arm64.` to stderr and exits 1. Build-time fail-fast (Docker propagates non-zero `RUN` exit). (Q1b, Q2c)

3. **#6 — `dev-entrypoint.sh:26` (zero-byte secret loading).**
   Currently: `if [ -f "$file" ]; then ... export ...` loads any existing file, including zero-byte ones. This contradicts `secrets/README.md:28-38` which documents "an empty placeholder does not fail startup" and "a file must be non-empty to actually be loaded". A zero-byte secret currently exports an empty env var, which can mask a developer-provided env var (e.g., `CONTEXT7_API_KEY=test` set in a shell gets overwritten to empty by the entrypoint). Fix: add a strict zero-byte check `[ ! -s "$file" ]` _before_ the export — if the file is empty or zero-byte, print `[dev-entrypoint] [skip] secret '<name>': file empty or zero-byte, not wiring` to stderr and `exit 0` from that iteration (degraded boot, never crash). Whitespace-only files still load (E1 — strict zero-byte check, not trim-and-test).

4. **#7 — `scripts/dev-secrets-profile.sh:17-24` (parity with entrypoint).**
   Same fix as #6, applied to the interactive-shell profile loader so both secret-loading paths behave identically. Skip empty + `[dev-secrets-profile] [skip] secret '<name>': file empty or zero-byte, not wiring` to stderr, exit 0 from that iteration.

5. **`secrets/README.md` sync note (companion to #6 + #7).**
   Add a short note (in the same commit as #6/#7) making the skip behavior explicit in user-facing docs: "empty/zero-byte secret files are SKIPPED, not wired; dev env boots degraded". Aligns docs with the new code. (Companion to #6/#7 — must ship in the same commit as the code changes.)

6. **New bats test for fix #4 (Dockerfile arch fail-fast).**
   Add a hermetic bats test (e.g., `scripts/__tests__/opencode-docker-arch-failfast.bats` or append to the existing `scripts/__tests__/opencode-docker.bats`) asserting that all 4 arch `case` statements in `tools/opencode-docker/Dockerfile` contain a `*)` fail-fast branch. Test strategy = static grep (Q7): the test greps the Dockerfile for each `*_ARCH=$(case` block and asserts the presence of a `*)` arm in each. No throwaway `docker build` test — that would be non-hermetic and slow. (Q7)

**Commit B — AI-tooling config (§10 → `@ai-specialist`):**

7. **#2 — `.opencode/commands/telemetry-report.md:8` (hardcoded path).**
   The `bun run "/home/qualt/.../report.ts"` line hardcodes a user-specific absolute path. Fix: replace `/home/qualt` with `${HOME:?...}` guard that hard-exits with a clear message if `HOME` is unset, and use `$HOME` expansion for the path. No `/home/qualt` literal anywhere in the file. (Q2b, Q5)

8. **#3 — `.opencode/commands/telemetry-inspect.md:9` (hardcoded path).**
   Same fix as #2, same `${HOME:?...}` guard pattern.

9. **#5 — `.config/opencode/skills/book-rag/knowledge-bases.yaml` (committed runtime cache).**
   This file is a runtime cache produced by the `book-rag` skill (cached_at / ttl / test_kb entries). The consumer script `query_rag.py` referenced by `.opencode/skills/book-rag/SKILL.md:38` lives at `.opencode/scripts/query_rag.py` and regenerates this file on demand (cache-path logic at lines 109–117: `_CACHE_DIR`/`_CACHE_FILENAME`). The committed content contains environment-specific timestamps (`cached_at`/`ttl_seconds`) and test data (`test_kb`) — churn that belongs in `.gitignore`, not version control. Fix: DELETE the committed file. Add a path-scoped root `.gitignore` entry with a comment: `# Generated RAG index cache (book-rag skill); regenerate via book-rag skill` followed by `.config/opencode/skills/book-rag/knowledge-bases.yaml`. (Q1c, Q2d)
   **Out of scope:** refactoring the `book-rag` skill or changing the cache-regeneration behavior of `query_rag.py`.

10. **#8 — `.opencode/memory/failures.md:11-12` (duplicated bullet).**
    The "MCP header-name mismatch risk" failure entry appears twice: line 11 (no indent, `- Failure mode: ...`) and line 12 (one-space indent + continuation ` - Failure mode: ...` — identical content). Line 13 carries the Resolution. Fix: keep exactly one entry (the properly-indented line 12 form is not the issue — both are duplicates; collapse to a single bullet) plus the Resolution line. No other changes to `failures.md`.

### Out of scope (explicitly deferred — interview-confirmed)

- Refactoring the `book-rag` skill or changing the cache-regeneration behavior of `query_rag.py` (Q1c).
- Compose `environment:` changes (there is no third secret loader in this scope).
- Rewriting the 9-ahead local commits on the branch (append-only; PR is a single new commit pair on top).
- Anything beyond the 8 listed fixes.
- Architecture changes (no new module boundary, no cross-cutting technology decision).
- Any `.sdd/` document authoring (no governing architecture exists for scripts/ or .opencode/ — see Design authority section below; flagged as a gap, not invented here).

## Design authority (.sdd/) reference

**No `.sdd/` document governs the paths touched by this change.** The project's `.sdd/` directory contains only `.sdd/dia-redispatch-cycle/architecture.md` (DIA cycle protocol) and `.sdd/README.md`. None of the following have an `.sdd/` entry:

- `scripts/` (dev-infra shell scripts)
- `tools/opencode-docker/Dockerfile` (opencode-docker has its own module-local `AGENTS.md` but no `.sdd/`)
- `dev-entrypoint.sh`, `scripts/dev-secrets-profile.sh` (secrets loaders)
- `.opencode/commands/`, `.config/opencode/skills/`, `.opencode/memory/` (AI-tooling config)

Per AGENTS.md §2.4 (dev-infra) and §10 (AI-tooling), changes within existing boundaries route directly through the spec chain without architectural escalation. This change is entirely within existing boundaries — no new module is introduced, no cross-cutting technology decision is made, and `architecture.md` (root) is unaffected.

**⚠️ Gap flagged:** the secrets-loading code path (`dev-entrypoint.sh` + `dev-secrets-profile.sh`) is a de-facto module with two parallel implementations that must stay in sync (whitelist, empty-handling, log format). Per the project's design-authority rules (§3), the absence of a `.sdd/secrets-loaders/architecture.md` is a documentation gap. This change does NOT invent one — the owner may choose to dispatch `@architector` in a follow-up if the dual-loader pattern warrants formalization. For now, the parity requirement between the two scripts is enforced by this change's own tests and by the companion `secrets/README.md` note.

**Relevant existing patterns this change follows:**

- **Hermetic bats tests:** `scripts/__tests__/dev-entrypoint.bats` uses `unshare -r -m` + tmpfs for namespace-isolated secret loading tests (test-helper.bash). The new Dockerfile arch test is even simpler (static grep of the Dockerfile itself — no container runtime needed).
- **Static-grep pattern for Dockerfile assertions:** `scripts/__tests__/opencode-docker.bats` already contains Dockerfile-shape assertions via grep.
- **Stderr logging for degraded boot:** `dev-entrypoint.sh:26` already emits to stderr on Docker-daemon absence; the new `[skip]` messages follow the same pattern.
- **`${HOME:?...}` idiom:** standard POSIX/bash parameter expansion with `:?` for hard-exit on unset or empty variables. Adopted here for the telemetry commands — no specific project precedent required, as the idiom is self-documenting.
- **`.gitignore` for generated artifacts:** `knowledge/*/sources/` is already gitignored; the new `knowledge-bases.yaml` entry follows the same "generated runtime artifact, not source" pattern.

## Rollback plan

Every artifact is independently revertable. The two commits are atomic on the routing boundary, so either can be reverted alone if a review chain rejects it:

| Artifact                                                                                       | Revert                                                |
| ---------------------------------------------------------------------------------------------- | ----------------------------------------------------- |
| `scripts/dev-stack.sh` (lines 44-47)                                                           | `git checkout` prior output block                     |
| `tools/opencode-docker/Dockerfile` (4 `*)` branches)                                           | `git checkout` prior `case` statements                |
| `scripts/__tests__/opencode-docker-arch-failfast.bats` (or appended to `opencode-docker.bats`) | Delete file (or `git checkout` if appended)           |
| `dev-entrypoint.sh` (empty-secret skip)                                                        | `git checkout` prior secret-loading block             |
| `scripts/dev-secrets-profile.sh` (empty-secret skip)                                           | `git checkout` prior secret-loading block             |
| `secrets/README.md` (sync note)                                                                | `git checkout` prior docs                             |
| `.opencode/commands/telemetry-report.md`                                                       | `git checkout` prior hardcoded paths                  |
| `.opencode/commands/telemetry-inspect.md`                                                      | `git checkout` prior hardcoded paths                  |
| `.config/opencode/skills/book-rag/knowledge-bases.yaml` (delete)                               | `git checkout` prior file + remove `.gitignore` entry |
| `.gitignore` (new entry)                                                                       | Remove the entry                                      |
| `.opencode/memory/failures.md` (dedup)                                                         | `git checkout` prior duplicated form                  |

No existing production code is modified. No data migrations. No runtime behavior change beyond the listed fixes. Rollback is `git checkout` or file deletion, with no side effects on running services.

## Testing Decisions

> Per `openspec/config.yaml`: "Include a Testing Decisions section that states what makes a good test for this change, which modules will be tested, and the prior art in the codebase."

### What makes a good test here

This change is almost entirely dev-infra hardening and configuration cleanup — the defects are either (a) misleading output, (b) missing fail-fast defaults, (c) incorrect empty-file handling, (d) hardcoded paths, (e) committed runtime artifacts, or (f) documentation duplication. Good tests for these defects are **structural assertions** (does the code contain the expected fail-fast branch?), **behavioral assertions in hermetic shells** (does the entrypoint skip empty files and emit the right `[skip]` message?), and **static shape checks** (does the telemetry command contain `${HOME:?` instead of `/home/qualt`?). We do NOT test by running the actual Docker build, booting the actual dev container, or invoking the real telemetry package — those are slow, non-hermetic, and orthogonal to the fixes.

### Test layers (gates)

1. **`make test-shell`** (bats — 90/90 existing + new tests for this change).
   The new test(s):
   - **Arch fail-fast bats test** (fix #4): static grep over `tools/opencode-docker/Dockerfile` asserting each of the four `*_ARCH=$(case` blocks contains a `*)` arm. Appended to `scripts/__tests__/opencode-docker.bats` (existing seam, matches prior Dockerfile-shape assertions there). One or four assertions — one per `*_ARCH` variable name — so a future regression that drops a single `*)` fails specifically.
   - **Empty-secret skip bats test** (fixes #6 + #7): extends `scripts/__tests__/dev-entrypoint.bats` with a test that writes a zero-byte file for a whitelisted secret, runs the entrypoint in a namespace, and asserts the env var is unset AND stderr contains `[dev-entrypoint] [skip] secret '<name>': file empty or zero-byte, not wiring`. Companion test for `dev-secrets-profile.sh` either in the same file or in a new `dev-secrets-profile.bats` — following the existing namespace-isolation pattern in `test-helper.bash`.

2. **`make test-infra`** (full dev stack build + smoke probes).
   The Dockerfile changes (fix #4) are verified **structurally** by the bats test, not by a full rebuild. The `make test-infra` gate still runs as the final integration check — any syntactic regression in the Dockerfile will surface there. Manual build verification (Q7) is the developer's responsibility for the happy path (amd64/arm64 still download correct artifacts); the bats test covers the **unhappy path** (unsupported arch → fail-fast).

3. **`make test-config`** (opencode config schema validation).
   Validates that `.opencode/commands/telemetry-report.md`, `.opencode/commands/telemetry-inspect.md`, and `.opencode/memory/failures.md` remain valid after the fix #2/#3/#8 edits. Catches any YAML-frontmatter or markdown schema regression introduced by the `${HOME:?}` substitution or the bullet dedup.

4. **`pnpm verify:js` + `pnpm verify:js-tests`** (TypeScript lint + unit tests).
   Not directly exercised by these fixes (no TS files touched), but the gate must still pass to confirm the change does not disturb the monorepo. Exit-code-0 required.

### Two-chain review matrix

The routing boundary is the critical test-process decision:

| Commit                                                                            | Routing        | Reviewer                                                                               | Gate                                                                                      |
| --------------------------------------------------------------------------------- | -------------- | -------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| A (dev-infra: scripts, Dockerfile, entrypoints, secrets/README.md, arch bats)     | AGENTS.md §2.4 | `@reviewer` (two-axis: Standards + Spec fidelity)                                      | `make test-shell` + `make test-infra` + coder handoff with verification evidence          |
| B (AI-tooling: telemetry commands, book-rag cache, failures.md dedup, .gitignore) | AGENTS.md §10  | `@ai-specialist` (independent review against best practices + AIHero patterns — §10.5) | `make test-config` + schema/JSONC validity + functional smoke test after OpenCode restart |

The PR description must acknowledge both chains so reviewers self-select. Each commit can be reviewed and merged independently if one chain raises concerns the other does not.

### What we explicitly do NOT test

- A real `docker build` of the opencode-docker Dockerfile for every supported `TARGETARCH` (slow, requires multi-arch build infra; manual verify per Q7).
- Boot-time behavior of the entrypoint in the actual dev container (the hermetic bats test covers the logic; the container boot is covered by `make test-infra` smoke probes).
- `query_rag.py` runtime behavior or the `book-rag` skill's cache-regeneration flow (out of scope — this change only removes the committed cache artifact and gitignores it).
- The telemetry scripts actually execute successfully when invoked (we test the path substitution is correct, not that the telemetry package works; its correctness is upstream's responsibility).
- Visual or functional testing of the dev-stack output messaging (manual developer check — the assertion is "the output matches what `docs/docker-dev.md` says turbo actually starts").

### Prior art in the codebase

- **Hermetic bats + namespace isolation:** `scripts/__tests__/dev-entrypoint.bats` (the canonical pattern; `test-helper.bash`'s `run_entrypoint_ns`). The new empty-secret tests reuse this seam directly.
- **Static grep over Dockerfile:** `scripts/__tests__/opencode-docker.bats` already contains Dockerfile-shape assertions; the arch-fail-fast test is a natural extension.
- **`${HOME:?...}` guard pattern:** standard POSIX/bash parameter expansion. The telemetry commands adopt this idiom for hard-fail on unset `HOME`.
- **`.gitignore` for generated artifacts:** `knowledge/*/sources/` is already ignored; the `knowledge-bases.yaml` entry follows the established pattern.
- **Fail-fast `case` defaults in the Dockerfile:** not yet present (that is the defect); the fix brings the four statements in line with the project's general "fail loud on unsupported input" stance seen in `dev-entrypoint.sh`'s Docker-daemon check and `dev-stack.sh`'s early-exit on Docker absence.

### Test risk and mitigation

**Risk:** the arch-fail-fast bats test uses static grep, which can produce false positives if the Dockerfile is reformatted (e.g., the `*)` arm ends up on the same line as the previous arm's terminator). **Mitigation:** the test greps for the literal string `*)` inside each `case` block's text span (extracted by line-range), not just anywhere in the file. If the Dockerfile is reformatted, the test is updated in the same change.

**Risk:** the empty-secret skip test relies on the namespace-isolated runner `run_entrypoint_ns`. If the test-helper changes, the new test may silently lose coverage. **Mitigation:** the new test lives in the same bats file as the existing secret-loading tests and uses the same `run_entrypoint_ns` helper — any future break to the helper breaks existing tests too, so it is self-protecting.

**Risk:** the `${HOME:?...}` guard in telemetry commands causes an immediate hard exit if `HOME` is unset. On the rare developer machine where `HOME` is not set, the command stops working instead of failing silently with a bad path. **Mitigation:** this is the desired behavior (Q5) — a hard, informative exit is strictly better than a silent wrong-path error. The `:?` parameter expansion emits `HOME: unset` (or similar) to stderr before exiting.
