# Tasks: dev-infra-language-servers

> **Proposal:** `openspec/changes/dev-infra-language-servers/proposal.md`
> **Design:** `openspec/changes/dev-infra-language-servers/design.md`
> **Workflow:** per `openspec/config.yaml`, each task is a vertical slice invoked via the `tdd-craftsman` skill. Write the failing test BEFORE production code. Work one slice at a time.

## Dependency graph

```
T1 (LS binaries + smoke) ─────────────────────┐
                                               │
T2 (gen-jsconfig.sh) ──▶ T3 (gen-jsconfig.bats) ──▶ T6 (Makefile + wiring)
                                               │
T4 (pyrightconfig.json) ───────────────────────│
                                               │
T5 (devcontainer extensions) ──────────────────┘
```

**Critical path:** T2 → T3 → T6
**Parallel tracks:** T1, T4, T5 can proceed independently while T2/T3 are in flight.

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

## Implementation order (suggested)

1. **Start with T2** (generator script) — it's on the critical path and has no blockers. Write the script, manually verify output.
2. **Then T3** (bats test) — write the tests RED, then harden T2 until GREEN.
3. **In parallel with T2/T3:** T1 (LS binaries), T4 (pyrightconfig), T5 (devcontainer extensions) can proceed on separate branches or sequentially.
4. **Finally T6** — wires everything together. Only starts after T2, T3, T5 are done.

## Out of scope for these tasks

- Configuring rust-analyzer beyond `check.command: clippy` (e.g., `rust-analyzer.cargo.features`, `rust-analyzer.checkOnSave`).
- Tightening pyright's `typeCheckingMode` from `basic` to `strict`.
- Adding `typescript.tsdk` or other TypeScript-specific settings to devcontainer.json (it already lives in committed `.vscode/settings.json`).
- Documenting the dev container in a `docs/dev-infra.md` (flagged as a follow-up in the proposal).
