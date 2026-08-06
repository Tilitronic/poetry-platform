# Tasks: dev-infra-language-servers

> **Proposal:** `openspec/changes/dev-infra-language-servers/proposal.md`
> **Design:** `openspec/changes/dev-infra-language-servers/design.md`
> **Workflow:** per `openspec/config.yaml`, each task is a vertical slice invoked via the `tdd-craftsman` skill. Write the failing test BEFORE production code. Work one slice at a time.

## Dependency graph

```
┌────────────── CONTAINER SCOPE (T1–T6) ──────────────┐
│                                                       │
│ T1 (LS binaries + smoke) ─────────────────────┐      │
│                                                │      │
│ T2 (gen-jsconfig.sh) ──▶ T3 (gen-jsconfig.bats) ──▶ T6 (Makefile + wiring)
│                                                │      │
│ T4 (pyrightconfig.json) ───────────────────────│      │
│                                                │      │
│ T5 (devcontainer extensions) ──────────────────┘      │
└───────────────────────────────────────────────────────┘

┌────────────── HOST SCOPE (T7–T11) ───────────────┐
│                                                    │
│ T7 (TS LS host install + lsp-versions.env) ──┐    │
│                                               │    │
│ T8 (rust-analyzer host install) ──────────────┼──▶ T10 (check-host-lsp.sh + bats + Makefile + docs + Dockerfile comments) ──▶ T11 (manual UX verification)
│                                               │    │
│ T9 (pyright host install) ────────────────────┘    │
└────────────────────────────────────────────────────┘

Two scopes are DISJOINT (no edges cross between them) except:
  - T10 touches Dockerfile.dev (documentary comments only); T1 also touches
    Dockerfile.dev. Coordinate: T10's comment edits must come AFTER T1's RUN
    steps are in place so comments point at the right lines.
```

**Critical paths:**

- Container scope: T2 → T3 → T6
- Host scope: {T7, T8, T9 parallel} → T10 → T11

**Parallel tracks:**

- Container scope: T1, T4, T5 can proceed independently while T2/T3 are in flight.
- Host scope: T7, T8, T9 can proceed in parallel (each is a vertical slice of `install-host-lsp.sh` adding one LS + its pin in `lsp-versions.env`). They share files (the install script + env file), so implementers MUST coordinate via small, non-overlapping slices — one LS per slice, one commit per slice. Do NOT batch multiple LS into a single task.

---

## T1 — Language server binaries in the dev container

**Blockers:** none
**Vertical slice:** one complete LS stack from version pinning to smoke-tested presence.

### What changes

1. `Dockerfile.dev`:
   - Extend the ARG block (lines 21-32) with three new entries:
     - `TYPESCRIPT_LS_VERSION` (e.g., `4.3.0` — current latest of `typescript-language-server`)
     - `TYPESCRIPT_VERSION` (e.g., `5.8.2` — match or exceed the version hoisted by pnpm)
     - `PYRIGHT_VERSION` (e.g., `1.1.401` — current latest)
   - Extend the "Global npm packages" RUN step (lines 68-71) to install `typescript-language-server@${TYPESCRIPT_LS_VERSION} typescript@${TYPESCRIPT_VERSION} pyright@${PYRIGHT_VERSION}`.
   - Extend the Rust toolchain RUN step (lines 104-107) with `rustup component add rust-analyzer` after the existing `rustup target add wasm32-unknown-unknown`.
2. `scripts/test-docker-smoke.sh`:
   - Append to the "verifying runtimes" block (after line 82): three new `docker compose exec -T dev <ls> --version >/dev/null` + `echo "ok: ..."` assertions for `typescript-language-server`, `pyright`, `rust-analyzer`.

### Acceptance criteria (user perspective)

- After `docker compose build dev`, opening a shell in the container and running `typescript-language-server --version`, `pyright --version`, and `rust-analyzer --version` each prints a version string and exits 0.
- `make test-infra` passes end-to-end, including the new binary-presence assertions in the smoke test.
- No existing smoke test assertions are removed or weakened.

### Testing

- The smoke test assertions ARE the test for this task. No separate unit test needed — we verify the binary is on PATH and runs.

---

## T2 — `jsconfig.json` generator script

**Blockers:** none
**Vertical slice:** a self-contained bash script that produces valid jsconfig.json from the workspace layout.

### What changes

1. `scripts/gen-jsconfig.sh` (new file, executable):
   - Reads `pnpm-workspace.yaml` at repo root to get workspace globs (e.g., `apps/*`, `packages/*`).
   - Expands each glob, reads `package.json` from each matched directory, extracts the `"name"` field (scoped as `@poetry/<pkg>`).
   - For each package, verifies `src/index.ts` exists (per the existing convention that `main`/`types` point to TS sources directly).
   - Emits a `jsconfig.json` to stdout (caller redirects to file) with:
     ```json
     {
       "compilerOptions": {
         "baseUrl": ".",
         "paths": {
           "@poetry/editor-engine": ["packages/editor-engine/src/index.ts"],
           "@poetry/data-contracts": ["packages/data-contracts/src/index.ts"],
           ...
         }
       }
     }
     ```
   - Uses `jq` (already installed in the container) for JSON construction to avoid hand-rolled string building.
   - Exit 0 on success; non-zero with a clear stderr message on: missing `pnpm-workspace.yaml`, missing `package.json` in a matched directory, missing `src/index.ts`, malformed JSON anywhere.
   - Deterministic: same workspace layout always produces identical output (sorted keys).

### Acceptance criteria (user perspective)

- Running `bash scripts/gen-jsconfig.sh > jsconfig.json` at repo root produces a file that is valid JSON, contains `compilerOptions.baseUrl: "."`, and has a `compilerOptions.paths` entry for every current `@poetry/*` workspace package.
- Each path entry points to a file that actually exists on disk (`packages/<pkg>/src/index.ts`).
- Running the script twice produces byte-identical output (deterministic).
- If a package directory is missing `src/index.ts`, the script exits non-zero with a message naming the offending package.

### Testing

- Behavioral test is in T3 (bats). For this task, manual verification of the output shape is sufficient until T3 automates it.

---

## T3 — bats test for the generator

**Blockers:** T2
**Vertical slice:** automated validation that the generator's output shape is correct and stable.

### What changes

1. `scripts/__tests__/gen-jsconfig.bats` (new file):
   - Follows the conventions in `scripts/__tests__/dev-entrypoint.bats` (load `test-helper` if needed; use `run` + `assert_status` + `assert_output_contains` or equivalent).
   - Tests (at minimum):
     - **Valid JSON:** running the script produces output that `jq` can parse.
     - **baseUrl correct:** `compilerOptions.baseUrl` is `"."`.
     - **Known packages present:** output contains path entries for specific known packages (e.g., `@poetry/editor-engine`, `@poetry/data-contracts`, `@poetry/phonetics-core`, `@poetry/analytics-pipeline`).
     - **Path validity:** each path in the output points to an existing file (via `test -f`).
     - **Determinism:** running the script twice produces byte-identical output.
   - Does NOT use namespace isolation (unlike dev-entrypoint.bats) because the generator reads the real repo layout; test fixtures are unnecessary when the real repo is a valid input.
2. `scripts/__tests__/bats-wrapper.sh`:
   - Add `scripts/gen-jsconfig.sh` to the `bash -n` syntax-check loop (lines 20-26).

### Acceptance criteria (user perspective)

- `make test-shell` passes, including the new `gen-jsconfig.bats` tests.
- If a new `@poetry/*` package is added to the workspace (without `src/index.ts`), the bats test fails — catching the drift.
- If the generator's output shape changes (e.g., `baseUrl` is accidentally removed), the bats test fails.

### Testing

- This task IS the test for T2's generator. RED-GREEN: write the bats tests first (they fail because T2 may not yet handle all edge cases), then harden T2 until they pass.

---

## T4 — `pyrightconfig.json` at repo root

**Blockers:** none
**Vertical slice:** a single committed config file that tells pyright where Python sources live.

### What changes

1. `pyrightconfig.json` (new file at repo root):
   - Points pyright at both Python packages:
     ```json
     {
       "include": ["apps/api-server", "packages/analytics-pipeline"],
       "exclude": ["**/node_modules", "**/__pycache__", "**/.venv"],
       "pythonVersion": "3.11",
       "typeCheckingMode": "basic"
     }
     ```
   - `pythonVersion` matches the Python version in `Dockerfile.dev` (python3 from Debian 13 = 3.13; adjust if needed).
   - `typeCheckingMode: "basic"` is permissive enough to not fail on existing code; can be tightened in a follow-up.

### Acceptance criteria (user perspective)

- Running `pyright` from the repo root exits 0 (or with only pre-existing type errors, not config errors).
- pyright finds Python sources in both `apps/api-server` and `packages/analytics-pipeline`.
- The config is valid JSON (verifiable via `jq . pyrightconfig.json`).

### Testing

- Implicit: pyright's own startup validates the config. If the config is malformed, pyright exits non-zero with a clear error.
- No separate test needed beyond "pyright runs."

---

## T5 — Devcontainer extensions auto-install + tracked `.vscode/`

**Blockers:** none
**Vertical slice:** IDE integration so VSCode uses the installed LS binaries.

### What changes

1. `.devcontainer/devcontainer.json`:
   - Extend `customizations.vscode.extensions` array with:
     - `"rust-lang.rust-analyzer"`
     - `"ms-python.vscode-pylance"`
   - These auto-install the LS extensions inside the container (`.vscode/extensions.json` recommendations alone are NOT installed automatically).
   - Keep `customizations.vscode.settings` limited to container-specific settings (`terminal.integrated.defaultProfile.linux: bash`). The shared `rust-analyzer.check.command: clippy` setting already lives in committed `.vscode/settings.json` — do NOT duplicate it in the devcontainer.
2. `.vscode/` (tracked, committed):
   - `.vscode/extensions.json` — already recommends `rust-lang.rust-analyzer` + `ms-python.vscode-pylance`; confirm they are present.
   - `.vscode/settings.json` — already sets `rust-analyzer.check.command: clippy` and `typescript.tsdk`; confirm unchanged.
3. `.gitignore` — ensure `.vscode/` is NOT ignored (removed from the IDE/Editor section) so both files are committed.

### Acceptance criteria (user perspective)

- `.devcontainer/devcontainer.json` is valid JSON.
- The extensions array contains `rust-lang.rust-analyzer` and `ms-python.vscode-pylance` alongside the existing extensions.
- `.vscode/` is tracked in git (`git ls-files .vscode` shows settings.json + extensions.json).
- `.gitignore` does NOT ignore `.vscode/`.
- Recreating the devcontainer installs the two new extensions automatically inside the container.

### Testing

- JSON validity is caught by any JSON parser (including the devcontainer CLI's own validation on rebuild).
- `git ls-files .vscode` returns both files; `git check-ignore .vscode/settings.json` exits non-zero (not ignored).
- No separate automated test needed; this is a declarative config change verified by the devcontainer CLI.

---

## T6 — Makefile, `.gitignore`, and `postCreateCommand` wiring

**Blockers:** T2, T3, T5
**Vertical slice:** end-to-end wiring so the generator runs automatically and CI catches drift.

### What changes

1. `Makefile`:
   - Add `gen-jsconfig` target:
     ```makefile
     gen-jsconfig:
     \tbash scripts/gen-jsconfig.sh > jsconfig.json
     ```
   - Extend `test-infra` dependencies to run `gen-jsconfig` FIRST (so test-shell's bats tests have a fresh jsconfig.json to validate):
     ```makefile
     test-infra: gen-jsconfig test-shell test-python
     \tbash scripts/test-docker-smoke.sh
     ```
   - Add `gen-jsconfig` to the `.PHONY` declaration.
2. `.gitignore`:
   - Add a new section or extend the existing "IDE / Editor" section:
     ```
     # === Generated by scripts/gen-jsconfig.sh ===
     jsconfig.json
     ```
3. `.devcontainer/devcontainer.json`:
   - Change `postCreateCommand` from string to array form to chain both steps:
     ```json
     "postCreateCommand": ["bash", "-c", "pnpm install && bash scripts/gen-jsconfig.sh > jsconfig.json"]
     ```

### Acceptance criteria (user perspective)

- `make gen-jsconfig` produces a `jsconfig.json` at repo root with the correct content.
- `make test-infra` runs end-to-end: generates jsconfig.json, runs bats tests (which validate the generated file), runs Python tests, runs the Docker smoke test (which verifies LS binary presence).
- After creating a fresh devcontainer, `jsconfig.json` exists at `/workspace/jsconfig.json` without manual intervention.
- `git status` does NOT show `jsconfig.json` as untracked (it's gitignored).
- If the generator's output shape is broken, `make test-infra` fails at the bats step (T3's tests catch it).

### Testing

- The wiring IS the test: if `make test-infra` passes, the wiring is correct. No separate test needed.

---

## Host-scope tasks (T7–T11)

> Added in the Phase 3 scope extension (host-global LS availability). These tasks are independent of T1–T6 (the container scope) except for the Dockerfile.dev documentary comments in T10, which must be sequenced AFTER T1's RUN steps are in place.

---

## T7 — Host install: `typescript-language-server` + `scripts/lsp-versions.env`

**Blockers:** none
**Vertical slice:** introduce the version-pin source of truth and install the first host LS (TypeScript). After this task, `scripts/install-host-lsp.sh` can install `typescript-language-server@5.3.0` on a host with npm, and the pinned version is declared in a sourceable env file.

### What changes

1. `scripts/lsp-versions.env` (new file, sourceable `KEY=VALUE`):
   - Header comment: `# Language server version pins (single source of truth).`
   - Header comment: `# Sourced by: scripts/install-host-lsp.sh, scripts/check-host-lsp.sh, scripts/__tests__/check-host-lsp.bats.`
   - Header comment: `# Keep in sync with Dockerfile.dev ARG block (documentary cross-ref; no automation — see design.md).`
   - First entry: `TYPESCRIPT_LANGUAGE_SERVER_VERSION=5.3.0`
   - Placeholder entries for the other two LS (added by T8/T9): `# PYRIGHT_VERSION=...` and `# RUST_ANALYZER_VERSION=...` as comments; the actual keys appear in T8/T9.
   - Bash-friendly syntax (no YAML, no quoting surprises): `KEY=value`, one per line, `#` comments allowed.
2. `scripts/install-host-lsp.sh` (new file, executable, bash 4+, `set -euo pipefail`):
   - Shebang: `#!/usr/bin/env bash`.
   - Sources `scripts/lsp-versions.env` relative to its own directory (so it works when invoked from any cwd): `source "$(dirname "${BASH_SOURCE[0]}")/lsp-versions.env"`.
   - Exits 1 with a what/why/how-to-fix pointer if the env file is missing or the required key is undefined.
   - TypeScript LS install function:
     - Resolve `NPM_PREFIX="${NPM_PREFIX:-$HOME/.local}"`.
     - Check existing install: if `typescript-language-server --version` reports `${TYPESCRIPT_LANGUAGE_SERVER_VERSION}`, emit `already installed: typescript-language-server ${TYPESCRIPT_LANGUAGE_SERVER_VERSION} (npm -g --prefix ${NPM_PREFIX}; skipping)` and skip.
     - Otherwise: `npm install -g --prefix "${NPM_PREFIX}" "typescript-language-server@${TYPESCRIPT_LANGUAGE_SERVER_VERSION}"`.
     - EACCES detection: if npm exits non-zero with `EACCES` in stderr, emit `error: npm install failed with EACCES. See docs/dev-infra/host-lsp-setup.md for remediation (do NOT use sudo).` to stderr and exit 1.
     - On success: emit `installed: typescript-language-server ${TYPESCRIPT_LANGUAGE_SERVER_VERSION} (npm -g --prefix ${NPM_PREFIX})`.
   - Rust-analyzer and pyright sections: **not yet implemented** (added by T8 and T9). The script exits 0 after the TS install.
3. `scripts/__tests__/check-host-lsp.bats` (new file — skeleton only, T7 adds just enough to prove the env-file-missing case):
   - `@test "check-host-lsp: env file missing -> exit 1 with what/why/how-to-fix pointer"` — runs the script in a temp tree without `lsp-versions.env`, asserts exit 1 and asserts output contains the remediation pointer.
   - Subsequent tasks (T8/T9/T10) add more cases; the T7 skeleton establishes the FAKE-mock infrastructure (`install_fakes()` from `check-tools.bats`, adapted for LSP tools).

### Acceptance criteria (user perspective)

- `bash scripts/install-host-lsp.sh` installs `typescript-language-server@5.3.0` into `$HOME/.local` on a host with npm (idempotent: re-running emits `already installed: ...` and skips).
- `scripts/lsp-versions.env` exists, is sourceable, and declares `TYPESCRIPT_LANGUAGE_SERVER_VERSION=5.3.0`.
- `typescript-language-server --version` prints `5.3.0` and exits 0.
- Running the install script without `lsp-versions.env` present exits 1 with a clear remediation pointer (no bare `exit 1`).
- The new bats case (`env-file-missing`) passes under `make test-shell`.

### Testing

- The `env-file-missing` bats case is the RED-GREEN anchor for this slice. Write the test first (it fails because the script doesn't yet exist), then implement the script until it passes.
- Real-install verification is Gate B (owner-run); the bats case only covers the env-file-missing branch.

---

## T8 — Host install: `rust-analyzer` (rustup-conditional, `SKIP_RUST=1`)

**Blockers:** none (parallel with T7 and T9 per Q4 ruling; each of T7/T8/T9 is an independent vertical slice. In practice, implementations share `install-host-lsp.sh` + `lsp-versions.env` — coordinate via one LS per slice, one commit per slice, no cross-slice edits; reconcile at merge time. See §Implementation order below.)
**Vertical slice:** extend the install script with the rust-analyzer branch. After this task, the install script handles the rustup-conditional logic (present → install, absent w/ SKIP_RUST≠1 → warn + continue, SKIP_RUST=1 → skip + continue). The rust-analyzer pin is declared in `lsp-versions.env`.

### What changes

1. `scripts/lsp-versions.env`:
   - Add `RUST_ANALYZER_VERSION=<rustup channel>` (e.g., `RUST_ANALYZER_VERSION=stable` or a pinned channel). The exact value is resolved at implementation time against the current rustup stable channel; the key name is fixed.
2. `scripts/install-host-lsp.sh`:
   - Add rust-analyzer install function:
     - `SKIP_RUST="${SKIP_RUST:-0}"` escape hatch.
     - If `SKIP_RUST=1`: emit `skip: rust-analyzer (SKIP_RUST=1)` to stdout, return 0.
     - If `rustup` is on PATH: `rustup component add rust-analyzer`. On success emit `installed: rust-analyzer <version> (rustup component add)`. Idempotent: if `rust-analyzer --version` already reports the expected version, emit `already installed: rust-analyzer <version> (rustup; skipping)`.
     - If `rustup` is NOT on PATH AND `SKIP_RUST≠1`: emit to stderr `warning: rustup not found; rust-analyzer not installed. Install from https://rustup.rs or set SKIP_RUST=1 to suppress.` and return 0 (partial install acceptable). The script continues, exits 0 overall.
     - Note: the probe (`rust-analyzer --version`) works regardless of install method (rustup or apt) — the install path is rustup-only, but the probe path is install-method-agnostic.
3. `scripts/__tests__/check-host-lsp.bats`:
   - Add `@test "check-host-lsp: SKIP_RUST=1 -> skip line, exit 0 if others pass"` — plants FAKE binaries for TS LS and pyright on PATH, sets `SKIP_RUST=1`, does NOT plant a FAKE rust-analyzer, runs the **probe script** (not the install script; install is destructive, tested via Gate B). Asserts the `skip: rust-analyzer (SKIP_RUST=1 set; not required for TS/Python LSP work)` line appears and exit is 0.
   - Note: this test exercises the probe script's SKIP_RUST handling, not the install script's. The install script's SKIP_RUST branch is tested in Gate B (owner-run).

### Acceptance criteria (user perspective)

- On a host with rustup: `bash scripts/install-host-lsp.sh` installs rust-analyzer via `rustup component add rust-analyzer`, emits `installed: rust-analyzer <version> (rustup component add)`.
- On a host without rustup (SKIP_RUST≠1): emits the stderr warning with https://rustup.rs URL, continues, exits 0 (partial install). The TS LS install from T7 is unaffected.
- On a host with `SKIP_RUST=1`: emits `skip: rust-analyzer (SKIP_RUST=1)`, exits 0.
- `scripts/lsp-versions.env` declares `RUST_ANALYZER_VERSION=...`.
- The SKIP_RUST bats case passes under `make test-shell`.

### Testing

- The SKIP_RUST bats case is the RED-GREEN anchor for this slice's probe-side logic. Write the test first (it fails because the probe script doesn't yet respect SKIP_RUST — T10 adds that, but the test is written now to document the expected contract).
- If T10's probe is not yet implemented, the test is added as a pending/skip case with a TODO comment referencing T10. The implementation is completed in T10.

---

## T9 — Host install: `pyright`

**Blockers:** none (parallel with T7 and T8 per Q4 ruling; same coordination note as T8 applies.)
**Vertical slice:** extend the install script with the pyright branch. After this task, `install-host-lsp.sh` installs all three LS binaries (TypeScript, Rust, Python) and `lsp-versions.env` declares all three pins.

### What changes

1. `scripts/lsp-versions.env`:
   - Add `PYRIGHT_VERSION=1.1.411`.
2. `scripts/install-host-lsp.sh`:
   - Add pyright install function, mirroring the TS LS shape:
     - Check existing install: if `pyright --version` reports `${PYRIGHT_VERSION}`, emit `already installed: pyright ${PYRIGHT_VERSION} (npm -g --prefix ${NPM_PREFIX}; skipping)` and skip.
     - Otherwise: `npm install -g --prefix "${NPM_PREFIX}" "pyright@${PYRIGHT_VERSION}"`.
     - EACCES detection: same remediation pointer as TS LS.
     - On success: emit `installed: pyright ${PYRIGHT_VERSION} (npm -g --prefix ${NPM_PREFIX})`.
   - Final exit 0 after all three installs (or partial if rust-analyzer was skipped).
3. `scripts/__tests__/check-host-lsp.bats`:
   - No new case added in T9 (the probe is tested in T10; T9 is install-only). The install script's pyright branch is tested in Gate B (owner-run) — same rationale as T8's rustup-conditional branch.

### Acceptance criteria (user perspective)

- `bash scripts/install-host-lsp.sh` installs `pyright@1.1.411` into `$HOME/.local` on a host with npm (idempotent: re-running emits `already installed: ...` and skips).
- `scripts/lsp-versions.env` declares `PYRIGHT_VERSION=1.1.411`.
- `pyright --version` prints `1.1.411` and exits 0.
- Re-running `bash scripts/install-host-lsp.sh` emits three `already installed:` lines and exits 0 (full idempotency).
- The install script's exit code is 0 for full install, 0 for partial install (rust-analyzer skipped via SKIP_RUST=1 or rustup-absent), and 1 only for unrecoverable errors (EACCES, env-file-missing, npm-not-found).

### Testing

- Gate B (owner-run) is the install script's test for T9. The probe script's pyright-handling is tested in T10.

---

## T10 — Host probe `check-host-lsp.sh` + bats test + Makefile wiring + docs + Dockerfile comments

**Blockers:** T7, T8, T9 (the probe sources `lsp-versions.env` and probes the installed binaries; the env file must declare all three pins, the install script must be in place for Gate B to pass)
**Vertical slice:** the probe script, its FAKE-mock bats test (6 core cases), the Makefile `check-host-lsp` target wired into `test-shell`, the setup guide, and the Dockerfile.dev documentary cross-ref comments. This is the integration task for the host scope.

### What changes

1. `scripts/check-host-lsp.sh` (new file, executable, bash 4+, `set -euo pipefail`):
   - Shebang: `#!/usr/bin/env bash`.
   - Sources `scripts/lsp-versions.env`; exits 1 with a what/why/how-to-fix pointer if missing.
   - Resolves `SKIP_RUST="${SKIP_RUST:-0}"`.
   - Aggregate probe function (all 3 tools probed, failures aggregated, single exit):
     - For each tool (`typescript-language-server`, `pyright`, `rust-analyzer`):
       - If tool is not on PATH (`! command -v <tool>`): emit `fail: <tool> — not found on PATH. Run scripts/install-host-lsp.sh (see docs/dev-infra/host-lsp-setup.md)` to stderr, mark failure.
       - Else if `<tool> --version` does not match the pinned version: emit `fail: <tool> — <actual> on PATH, expected <pinned>. Run scripts/install-host-lsp.sh` to stderr, mark failure.
       - Else: emit `ok: <tool> <pinned> (host, version matches scripts/lsp-versions.env)`.
     - Special case for rust-analyzer when `SKIP_RUST=1`: emit `skip: rust-analyzer (SKIP_RUST=1 set; not required for TS/Python LSP work)`, do NOT mark failure.
   - Emit aggregate summary line before exit (e.g., `summary: 3 ok, 0 fail, 0 skip` or `summary: 2 ok, 1 fail, 0 skip — see above`).
   - Exit 0 if no failures (skip neutral); exit 1 if any failure. Every exit-1 is preceded by the summary + per-failure remediation pointers.
2. `scripts/__tests__/check-host-lsp.bats` (extends the T7 skeleton):
   - Add 5 more cases (total 6, per Q7b — no extras):
     1. `all-ok` — all 3 FAKE tools report pinned versions → exit 0, 3 `ok:` lines, aggregate summary.
     2. `one-missing` — one FAKE tool's `which` fails → exit 1, 1 `fail:` line + 2 `ok:` lines, aggregate summary.
     3. `version-fail` — one FAKE tool reports a wrong version → exit 1, 1 `fail:` line naming the mismatch.
     4. `skip-neutral` — `SKIP_RUST=1` set → `skip:` line for rust-analyzer, exit 0 if others pass.
     5. `multi-fail` — multiple tools fail → aggregate reports all failures, exit 1, single summary line.
     6. `env-file-missing` — `scripts/lsp-versions.env` absent → exit 1 with what/why/how-to-fix pointer (added in T7; retained here for the count).
   - **Invariant:** every case plants FAKE binaries on `PATH` via `install_fakes()` (mirrors `check-tools.bats`); bats NEVER shells real LSP binaries.
   - Test the **probe script** (`check-host-lsp.sh`), not the install script — install is destructive, probe is not.
3. `scripts/__tests__/bats-wrapper.sh`:
   - Add `scripts/install-host-lsp.sh` and `scripts/check-host-lsp.sh` to the `bash -n` syntax-check loop (lines 20-36).
4. `Makefile`:
   - Add `check-host-lsp` to `.PHONY` declaration (line 25).
   - Add `check-host-lsp` target:
     ```makefile
     # Host-runnable LSP integrity check (scripts/check-host-lsp.sh). Verifies the
     # three LS binaries (TS/Python/Rust) are on PATH at the pinned versions from
     # scripts/lsp-versions.env. Wired into test-shell so `make test-shell` fails
     # fast on host-tool drift — Gate B of the host-scope 3-gate acceptance
     # (proposal.md). rust-analyzer is skippable via SKIP_RUST=1 (see
     # docs/dev-infra/host-lsp-setup.md).
     check-host-lsp:
     \tbash scripts/check-host-lsp.sh
     ```
   - Edit `test-shell` prereq (line 82): from `test-shell: test-opencode-docker` to `test-shell: check-host-lsp test-opencode-docker`.
5. `docs/dev-infra/host-lsp-setup.md` (new file + `docs/dev-infra/` directory):
   - Markdown checklist, owner-runnable:
     - **Prerequisites:** bash 4+, npm on PATH, (optional) rustup on PATH for rust-analyzer.
     - **Step 1:** `bash scripts/install-host-lsp.sh` — run the install script.
     - **Step 2:** add `$HOME/.local/bin` to PATH (document shell-specific instructions for bash/zsh/fish; do NOT edit the user's shell rc automatically).
     - **Step 3:** verify with `bash scripts/check-host-lsp.sh` or `make check-host-lsp`.
     - **Escape hatches:** `SKIP_RUST=1` (skip rust-analyzer), `NPM_PREFIX=/path` (non-standard npm global prefix).
     - **Troubleshooting:**
       - Gate B live-state: if rust-analyzer is absent on THIS host and T8 is not yet implemented, `make test-shell` fails. Export `SKIP_RUST=1` to suppress.
       - EACCES during npm install: do NOT use sudo; adjust `$HOME/.local` ownership or set `NPM_PREFIX`.
       - rustup not found: install from https://rustup.rs, or use `SKIP_RUST=1` to skip.
     - **T11 verification checklist** (linked): go-to-def / hover / diagnostics on `.ts` / `.rs` / `.py` files; record results in `openspec/changes/dev-infra-language-servers/verification-T11.md`.
6. `Dockerfile.dev`:
   - Pure documentary comment edits (NO RUN changes, NO new ARGs, NO version bumps):
     - At ARG block (~:35-38, above the existing `TYPESCRIPT_LS_VERSION` / `TYPESCRIPT_VERSION` / `PYRIGHT_VERSION` lines): add comment `# keep in sync with scripts/lsp-versions.env — the single source of truth for host + container LS versions; T7-T10`.
     - At npm-packages block (~:97-99, above the existing `RUN npm install -g ...` line): add comment `# versions are pinned in scripts/lsp-versions.env (host) and mirrored in the ARG block above (container); see T7-T10`.
   - rust-analyzer needs no cross-ref comment (RUST_VERSION ARG + rustup install are self-contained).

### Acceptance criteria (user perspective)

- `bash scripts/check-host-lsp.sh` (on a host with all three LS installed at the pinned versions) exits 0 with three `ok:` lines and an aggregate summary.
- `make check-host-lsp` exits 0 under the same conditions.
- `make test-shell` runs `check-host-lsp` first (as a prereq), then runs bats (which now includes `check-host-lsp.bats` with 6 cases). If the host probe fails, `make test-shell` fails BEFORE bats runs.
- `make test-shell` on THIS host (which lacks rust-analyzer) fails at the `check-host-lsp` step. Documented in `docs/dev-infra/host-lsp-setup.md` §Troubleshooting; `SKIP_RUST=1` suppresses.
- Gate A bats: all 6 cases pass under `make test-shell`. Invariant holds: no test shells a real LSP binary.
- Dockerfile.dev RUN steps are UNCHANGED (diff shows only comments added at lines ~35 and ~97).
- `docs/dev-infra/host-lsp-setup.md` exists and is linked from the T11 verification checklist.

### Testing

- The 6-case bats suite IS the test for the probe script. RED-GREEN: write the tests first (they fail because the probe script doesn't yet exist), then implement the probe until they pass.
- Install script is tested via Gate B (owner-run) — see T7/T8/T9 acceptance criteria.
- Dockerfile.dev comments are tested implicitly: if the comment points at a line that moves in a future change, the drift is visible in PR review (no automation — deliberate choice, see design.md §Design constraints).

---

## T11 — Manual functional UX verification

**Blockers:** T10
**Vertical slice:** owner runs the full LSP stack in their editor of choice and records go-to-definition / hover / diagnostics on `.ts` / `.rs` / `.py` files. Markdown checklist in the change archive; no automation.

### What changes

1. `openspec/changes/dev-infra-language-servers/verification-T11.md` (new file):
   - Markdown checklist:
     - [ ] TS: open a file in `packages/editor-engine/src/`, hover over a symbol imported from `@poetry/data-contracts` — go-to-def works.
     - [ ] TS: hover over a local symbol shows type information.
     - [ ] TS: diagnostics panel shows no spurious "cannot find module" errors for `@poetry/*` imports.
     - [ ] Python: open a file in `apps/api-server/`, hover over a symbol imported from `packages/analytics-pipeline` — go-to-def works.
     - [ ] Python: diagnostics panel shows no spurious import errors.
     - [ ] Rust: open a file in `packages/stress-lang-core/`, hover over a symbol — type information appears.
     - [ ] Rust: diagnostics panel shows no spurious errors (or only pre-existing ones unrelated to LSP).
     - [ ] Verification client: record which client was used (VSCode / opencode-in-container / opencode-on-host).
     - [ ] Date + developer initials.
2. Owner runs the checklist; checks off items; commits the file to the change archive (or leaves it as an untracked record of completion — at owner's discretion).

### Acceptance criteria (user perspective)

- The checklist exists in the change archive.
- At least one verification client has been exercised; at least the TS + Python sections are checked off (Rust is skippable via `SKIP_RUST=1`).
- Any failures are recorded as comments in the checklist (not silently skipped).

### Testing

- No automation by design (Q7c ruling). The checklist is the test.

---

## Implementation order (suggested)

### Container scope (T1–T6)

1. **Start with T2** (generator script) — it's on the critical path and has no blockers. Write the script, manually verify output.
2. **Then T3** (bats test) — write the tests RED, then harden T2 until GREEN.
3. **In parallel with T2/T3:** T1 (LS binaries), T4 (pyrightconfig), T5 (devcontainer extensions) can proceed on separate branches or sequentially.
4. **Finally T6** — wires everything together. Only starts after T2, T3, T5 are done.

### Host scope (T7–T11)

1. **T7, T8, T9 are parallel by task definition** (Q4 ruling: T7→T10, T8→T10, T9→T10, T10→T11 — no edges between T7/T8/T9). Each is a vertical slice of `install-host-lsp.sh` adding one LS + its pin in `lsp-versions.env`.
2. **Implementation coordination:** T7/T8/T9 share files (`install-host-lsp.sh` + `lsp-versions.env`). If implemented sequentially, T7 goes first (creates the env file with all three pin KEYS declared as placeholders, plus the TS install function). T8/T9 each add one install function + fill in their pin. If implemented on parallel branches, reconcile at merge time (the env file's keys are additive; the install script's per-LS functions are non-overlapping).
3. **T10 after T7/T8/T9** — the probe + integration task. Depends on all three install slices being complete because the probe sources the env file (which now declares all three pins) and the bats test covers the full 6-case matrix.
4. **T11 last** — manual UX verification after all automation is in place.

### Cross-scope coordination

- **T10's Dockerfile.dev comment edits** must come AFTER T1's RUN steps are in place, so the comments point at the correct line numbers. Either: (a) T10 follows T1 in the same PR, or (b) T10's comments are written against the expected post-T1 line numbers and reconciled at merge time. Document in the PR description.
- **T1–T6 and T7–T11 are otherwise independent.** They can be implemented on parallel branches and merged in either order, but the Dockerfile.dev coordination point means the branch that touches Dockerfile.dev last wins for line numbers.

## Out of scope for these tasks

- Configuring rust-analyzer beyond `check.command: clippy` (e.g., `rust-analyzer.cargo.features`, `rust-analyzer.checkOnSave`).
- Tightening pyright's `typeCheckingMode` from `basic` to `strict`.
- Adding `typescript.tsdk` or other TypeScript-specific settings to devcontainer.json (it already lives in committed `.vscode/settings.json`).
- Documenting the dev container in a `docs/dev-infra.md` (flagged as a follow-up in the proposal).
- **`opencode.jsonc` LSP configuration** — no custom `lsp` object added; `lsp: true` at line 49 suffices (Q4 ruling).
- **Windows host support** — out of scope; Windows developers use the dev container.
- **CI host-LSP enforcement** — CI runs in the dev container; host probe is a developer-convenience gate.
- **New `.sdd/` document** — dev-infra is within existing module boundaries; the `.sdd/` gap is logged in proposal.md, not authored here.
- **Extra bats cases** (partial-PATH / env-parse / install-rerun) — explicitly excluded per Q7b.
- **Dockerfile.dev behavior change** — only documentary comments; no RUN/ARG modifications.
