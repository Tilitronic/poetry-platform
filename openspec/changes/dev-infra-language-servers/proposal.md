# Proposal: dev-infra-language-servers

> **Status:** proposed · **Scope:** dev-infra (Dockerfile.dev, .devcontainer, scripts, Makefile)
> **Escalation:** none — change is within existing module boundaries (per AGENTS.md §2.4, dev-infra changes do not require @architector)

## Motivation

The dev container currently ships Node, Python, and Rust toolchains but **no language servers**. Developers editing in VSCode, opencode, or any LSP-capable client get no path resolution for `@poetry/*` workspace packages, no Python cross-file intelligence, and no Rust analysis inside the container. This change installs the three language servers (TypeScript, Python, Rust), wires the IDE to use them, and generates a `jsconfig.json` so `@poetry/*` paths resolve cleanly across the monorepo.

## Scope

### In scope

1. **Language server binaries in `Dockerfile.dev`** — `typescript-language-server` + `typescript` (TypeScript LSP), `pyright` (Python), `rust-analyzer` (Rust via `rustup component`). All versions pinned in a central ARG block.
2. **`jsconfig.json` generator** — `scripts/gen-jsconfig.sh` derives `@poetry/*` path mappings from `pnpm-workspace.yaml` + `packages/*/package.json`. Output written to repo root, gitignored.
3. **`pyrightconfig.json`** — committed at repo root, points pyright at the two Python packages (`apps/api-server`, `packages/analytics-pipeline`).
4. **IDE config** — `.vscode/` is tracked in the repo (settings.json + extensions.json committed). `.vscode/settings.json` holds shared workspace settings (already present: `rust-analyzer.check.command: clippy`, `typescript.tsdk`); `.vscode/extensions.json` holds recommended extensions. `.devcontainer/devcontainer.json` auto-installs the LS extensions (`rust-lang.rust-analyzer`, `ms-python.vscode-pylance`) into the container via `customizations.vscode.extensions` — recommendations alone do not auto-install.
5. **Test assertions** — smoke test verifies LS binary presence; bats test validates generator output shape.
6. **Makefile wiring** — new `gen-jsconfig` target wired into `test-infra` so CI catches generator regressions.
7. **`.gitignore`** — add `jsconfig.json` to the gitignore.

### Out of scope

- Configuring rust-analyzer beyond `check.command: clippy` (existing pattern in `.vscode/settings.json`, now committed).
- Runtime verification that language servers produce correct analysis — each LS has its own test suite; we only verify presence and configuration.
- Changes to application code, `tsconfig.json`, `turbo.json`, or any package's `package.json`.

## Context correction

The initial research stated `.vscode/` is gitignored and therefore `.vscode/settings.json`/`extensions.json` could not be committed. **Correction: `.vscode/` is now tracked in the repo** (removed from `.gitignore`; `settings.json` + `extensions.json` are committed). The design therefore:

- Keeps shared IDE settings in committed `.vscode/settings.json` (`rust-analyzer.check.command: clippy`, `typescript.tsdk`, formatters).
- Keeps recommended extensions in committed `.vscode/extensions.json` (includes `rust-lang.rust-analyzer`, `ms-python.vscode-pylance`).
- Uses `.devcontainer/devcontainer.json` → `customizations.vscode.extensions` only to AUTO-INSTALL extensions inside the container (recommendations are not auto-installed), and `customizations.vscode.settings` for container-specific settings (e.g. terminal profile).

## Design authority (.sdd/) reference

**No `.sdd/` document governs dev-infra.** The project's design authority layer (`architecture.md` + `.sdd/`) describes system architecture (editor, workers, contracts, cloud), not developer tooling. Per AGENTS.md §2.4, dev-infra changes within existing boundaries use the spec chain directly without architectural escalation.

**Documentation gap flagged:** there is no `docs/dev-infra.md` or equivalent that catalogs the dev container's contents, purpose, and extension points. This change does not create one (out of scope), but it is a candidate for a follow-up change.

## Rollback plan

Every artifact added by this change is independently revertable:

| Artifact                                                        | Revert                                              |
| --------------------------------------------------------------- | --------------------------------------------------- |
| Dockerfile.dev LS install block                                 | Remove the ARG entries + `RUN` steps; rebuild image |
| `scripts/gen-jsconfig.sh`                                       | Delete file                                         |
| `scripts/__tests__/gen-jsconfig.bats`                           | Delete file                                         |
| `pyrightconfig.json`                                            | Delete file                                         |
| `.devcontainer/devcontainer.json` extensions/settings additions | `git checkout` to prior version                     |
| Makefile `gen-jsconfig` target + `test-infra` dependency        | `git checkout` to prior version                     |
| `.gitignore` jsconfig.json entry                                | Remove line                                         |

No existing production code is modified. No data migrations. Rollback is file deletion / git checkout, with no side effects on running services.

## Testing Decisions

> Per `openspec/config.yaml`: "Include a Testing Decisions section that states what makes a good test for this change, which modules will be tested, and the prior art in the codebase."

### What makes a good test here

This is dev-infra — tests verify **tool presence and configuration shape**, not business logic. A good test is one that fails loudly when a tool goes missing or a configuration drifts silently, and passes quietly otherwise. We do NOT test LS analysis quality (each LS has its own test suite) or IDE integration (not automatable in CI).

### Two test layers

1. **Smoke layer** (`scripts/test-docker-smoke.sh`, run by `make test-infra`)
   - Asserts each LS binary is on `PATH` in the built container: `typescript-language-server --version`, `pyright --version`, `rust-analyzer --version`.
   - Follows the existing smoke test pattern: `docker compose exec -T dev <tool> --version >/dev/null` + `echo "ok: ..."`.
   - Catches: missing installs, broken `RUN` steps, PATH misconfigurations.

2. **Behavioral layer** (`scripts/__tests__/gen-jsconfig.bats`, run by `make test-shell`)
   - Asserts the generator produces valid JSON.
   - Asserts the output contains path mappings for **specific known** `@poetry/*` packages (e.g., `@poetry/editor-engine`, `@poetry/data-contracts`, `@poetry/phonetics-core`).
   - Asserts each path points to an existing `src/index.ts` file (via a `test -f` check or equivalent).
   - Asserts `compilerOptions.baseUrl` is `"."`.
   - Catches: generator logic regressions, silent empty-path failures, workspace layout drift.

### What we explicitly do NOT test

- IDE extension installation (VSCode marketplace availability is not our concern; devcontainer CLI handles this).
- LS responsiveness or analysis correctness (out of scope; each LS is third-party).
- `pyrightconfig.json` shape beyond "pyright can parse it and exit" (basic validity; the file is hand-maintained and reviewed in PRs).
- Rust-analyzer's clippy integration (only presence is asserted; clippy correctness is Rust's problem).

### Prior art in the codebase

- Smoke test binary-presence pattern: existing `scripts/test-docker-smoke.sh` lines 79-82 (node, python3 version checks).
- bats shell-script behavior pattern: existing `scripts/__tests__/dev-entrypoint.bats` (namespace-isolated tests with `test-helper.bash`).
- bats-wrapper with vendor-on-demand: existing `scripts/__tests__/bats-wrapper.sh` (syntax-checks all scripts, vendors bats-core if missing).
- Makefile `test-infra` composition: existing `Makefile` line 64 (`test-infra: test-shell test-python` + smoke test).

### Test risk and mitigation

**Risk:** generator silently produces empty path mappings if `pnpm-workspace.yaml` parsing fails (e.g., unexpected YAML shape). **Mitigation:** bats test asserts specific known package names appear in the output; an empty or malformed output fails the test loudly.

**Risk:** smoke test takes longer because three more `docker compose exec` calls. **Mitigation:** each call is a fast `--version` check (<1s); total addition is <5s to a test that already takes minutes.
