# Proposal: dev-infra-language-servers

> **Status:** proposed · **Scope:** dev-infra (Dockerfile.dev, .devcontainer, scripts, Makefile, docs/dev-infra, host toolchain)
> **Escalation:** none — change is within existing module boundaries (per AGENTS.md §2.4, dev-infra changes do not require @architector)

## Motivation

The dev container currently ships Node, Python, and Rust toolchains but **no language servers**. Developers editing in VSCode, opencode, or any LSP-capable client get no path resolution for `@poetry/*` workspace packages, no Python cross-file intelligence, and no Rust analysis inside the container. The same gap exists on the **host**: developers editing outside the container (e.g. on a laptop without Docker, or using opencode in host mode) have no LSP binaries available either.

This change closes both gaps in a single coordinated scope:

- **Container scope (T1–T6):** installs the three language servers (TypeScript, Python, Rust) in `Dockerfile.dev`, wires the IDE to use them, and generates a `jsconfig.json` so `@poetry/*` paths resolve cleanly across the monorepo.
- **Host scope (T7–T11):** mirrors the same three LS installs on the host via `scripts/install-host-lsp.sh`, verifies them with `scripts/check-host-lsp.sh`, pins versions in a single source of truth (`scripts/lsp-versions.env`), and wires the host probe as a prerequisite of `make test-shell` so host-tool drift fails loudly before any bats run.

## Scope

### In scope

#### Container scope (T1–T6)

1. **Language server binaries in `Dockerfile.dev`** — `typescript-language-server` + `typescript` (TypeScript LSP), `pyright` (Python), `rust-analyzer` (Rust via `rustup component`). All versions pinned in a central ARG block.
2. **`jsconfig.json` generator** — `scripts/gen-jsconfig.sh` derives `@poetry/*` path mappings from `pnpm-workspace.yaml` + `packages/*/package.json`. Output written to repo root, gitignored.
3. **`pyrightconfig.json`** — committed at repo root, points pyright at the two Python packages (`apps/api-server`, `packages/analytics-pipeline`).
4. **IDE config** — `.vscode/` is tracked in the repo (settings.json + extensions.json committed). `.vscode/settings.json` holds shared workspace settings (already present: `rust-analyzer.check.command: clippy`, `typescript.tsdk`); `.vscode/extensions.json` holds recommended extensions. `.devcontainer/devcontainer.json` auto-installs the LS extensions (`rust-lang.rust-analyzer`, `ms-python.vscode-pylance`) into the container via `customizations.vscode.extensions` — recommendations alone do not auto-install.
5. **Test assertions** — smoke test verifies LS binary presence; bats test validates generator output shape.
6. **Makefile wiring** — new `gen-jsconfig` target wired into `test-infra` so CI catches generator regressions.

#### Host scope (T7–T11) — extension

7. **Single source of LS pins — `scripts/lsp-versions.env`** — a new `KEY=VALUE` file (sourceable by bash, parseable by awk/grep) declaring `TYPESCRIPT_LANGUAGE_SERVER_VERSION=5.3.0`, `PYRIGHT_VERSION=1.1.411`, `RUST_ANALYZER_VERSION=<rustup channel>`. Sourced by `install-host-lsp.sh`, `check-host-lsp.sh`, and the bats test; cross-referenced (not duplicated) by `Dockerfile.dev` ARG block via comment.
8. **Host install script — `scripts/install-host-lsp.sh`** — bash-only (`#!/usr/bin/env bash`, `set -euo pipefail`, bash 4+), idempotent, installs the three LS binaries on the host:
   - `typescript-language-server@<pinned>` and `pyright@<pinned>` via `npm install -g --prefix "$HOME/.local"` (no sudo, no shell-rc mutation; EACCES detection with remediation pointer to `docs/dev-infra/host-lsp-setup.md`).
   - `rust-analyzer` via `rustup component add rust-analyzer` if rustup is present; if rustup is absent and `SKIP_RUST≠1`, emits a stderr warning with https://rustup.rs URL and continues (partial install, exit 0); if `SKIP_RUST=1`, emits a stdout skip line and continues.
   - Per-tool version-check-skip before each install (idempotent).
   - Per-tool output lines: `installed: <tool> <version> (<method>)` or `already installed: <tool> <version> (<method>; skipping)`.
   - Exits 0 on full or partial success; exits 1 only on unrecoverable errors. No logging infra; stdout/stderr only.
9. **Host probe script — `scripts/check-host-lsp.sh`** — bash-only, aggregate probe (all 3 tools probed before any exit), mirrors `check-tools.sh` line shapes:
   - `ok: <tool> <pinned> (host, version matches scripts/lsp-versions.env)`
   - `fail: <tool> — not found on PATH. Run scripts/install-host-lsp.sh (see docs/dev-infra/host-lsp-setup.md)`
   - `fail: <tool> — <actual> on PATH, expected <pinned>. Run scripts/install-host-lsp.sh`
   - `skip: rust-analyzer (SKIP_RUST=1 set; not required for TS/Python LSP work)`
   - Aggregate summary emitted before exit. Exit 0 if all pass (skip neutral); exit 1 if any fail.
10. **Setup guide — `docs/dev-infra/host-lsp-setup.md`** — owner-runnable markdown checklist covering: npm global prefix (`$HOME/.local`) + PATH note, rustup install URL, `SKIP_RUST=1` and `NPM_PREFIX` escape hatches, troubleshooting for the Gate B live-state on hosts without rust-analyzer.
11. **Makefile wiring for host probe** — `check-host-lsp: bash scripts/check-host-lsp.sh`; `test-shell: check-host-lsp test-opencode-docker` + bats-wrapper. Gate B live-state accepted (make test-shell fails on hosts without rust-analyzer until T8 or `SKIP_RUST=1` is exported — documented in `host-lsp-setup.md` §Troubleshooting, not a blocker).
12. **Dockerfile.dev documentary cross-references** — pure comment edits at the ARG block (~:35-38) and npm-packages block (~:97-99) pointing at `scripts/lsp-versions.env` as the single source of truth; NO RUN changes, NO new ARGs, NO version bumps. rust-analyzer needs no cross-ref (RUST_VERSION ARG + rustup install are already self-contained).
13. **bats test — `scripts/__tests__/check-host-lsp.bats`** — 6 core cases, FAKE-mock pattern from `check-tools.bats` (bats NEVER shells real LSP binaries): all-ok / one-missing / version-fail / skip-neutral / multi-fail / env-file-missing. Invariant: every `--version` probe is driven by a FAKE binary planted on PATH; no test spawns a real LS.

### Out of scope

- Configuring rust-analyzer beyond `check.command: clippy` (existing pattern in `.vscode/settings.json`, now committed).
- Runtime verification that language servers produce correct analysis — each LS has its own test suite; we only verify presence and configuration.
- Changes to application code, `tsconfig.json`, `turbo.json`, or any package's `package.json`.
- **`opencode.jsonc` change** — `lsp: true` at line 49 already enables LSP discovery; no custom `lsp` object is added (deferred; see Q1 ruling).
- **Dockerfile.dev behavior change** — the existing `RUN npm install -g` and `rustup component add` steps are untouched; only documentary comments are added in T10/T7–T9.
- **Windows host support** — scripts assume Linux/macPosix hosts with bash 4+. Windows developers use the dev container (T1–T6 covers them).
- **CI host-LSP enforcement** — `make test-shell` runs in CI via the dev container (where the LS binaries are already present via T1). The host probe is a developer-convenience gate, not a new CI surface.
- **New `.sdd/` document for dev-infra** — see `.sdd/` gap flag below.

## Context correction

The initial research stated `.vscode/` is gitignored and therefore `.vscode/settings.json`/`extensions.json` could not be committed. **Correction: `.vscode/` is now tracked in the repo** (removed from `.gitignore`; `settings.json` + `extensions.json` are committed). The design therefore:

- Keeps shared IDE settings in committed `.vscode/settings.json` (`rust-analyzer.check.command: clippy`, `typescript.tsdk`, formatters).
- Keeps recommended extensions in committed `.vscode/extensions.json` (includes `rust-lang.rust-analyzer`, `ms-python.vscode-pylance`).
- Uses `.devcontainer/devcontainer.json` → `customizations.vscode.extensions` only to AUTO-INSTALL extensions inside the container (recommendations are not auto-installed), and `customizations.vscode.settings` for container-specific settings (e.g. terminal profile).

## Design authority (.sdd/) reference

**No `.sdd/` document governs dev-infra.** The project's design authority layer (`architecture.md` + `.sdd/`) describes system architecture (editor, workers, contracts, cloud), not developer tooling. Per AGENTS.md §2.4, dev-infra changes within existing boundaries use the spec chain directly without architectural escalation.

**Documentation gaps flagged (discovered-but-deferred, not blockers):**

1. **No `docs/dev-infra.md`** — there is no catalog of the dev container's contents, purpose, and extension points. This change does not create one (out of scope), but it is a candidate for a follow-up change.
2. **No `.sdd/dev-infra/architecture.md`** — the `.sdd/` layer currently contains only `.sdd/README.md` (the design-authority layer model document). dev-infra is not yet represented as a module in the SDD layer. This change does not author one (out of scope; dev-infra's module boundary is stable, no cross-cutting technology decision is being made here), but the gap is logged as a follow-up candidate for when dev-infra grows its next non-trivial module (e.g., host-tool harmonization beyond LSP).

Neither gap blocks this change: dev-infra is within existing module boundaries per AGENTS.md §2.4, and the scope extension (T7–T11) stays within the same dev-infra module.

## Rollback plan

Every artifact added by this change is independently revertable. Container scope (T1–T6) and host scope (T7–T11) are disjoint — a rollback of one does not force a rollback of the other.

### Container scope (T1–T6)

| Artifact                                                        | Revert                                              |
| --------------------------------------------------------------- | --------------------------------------------------- |
| Dockerfile.dev LS install block                                 | Remove the ARG entries + `RUN` steps; rebuild image |
| `scripts/gen-jsconfig.sh`                                       | Delete file                                         |
| `scripts/__tests__/gen-jsconfig.bats`                           | Delete file                                         |
| `pyrightconfig.json`                                            | Delete file                                         |
| `.devcontainer/devcontainer.json` extensions/settings additions | `git checkout` to prior version                     |
| Makefile `gen-jsconfig` target + `test-infra` dependency        | `git checkout` to prior version                     |
| `.gitignore` jsconfig.json entry                                | Remove line                                         |

### Host scope (T7–T11)

| Artifact                                                    | Revert                                                                                                                                   |
| ----------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| `scripts/lsp-versions.env`                                  | Delete file                                                                                                                              |
| `scripts/install-host-lsp.sh`                               | Delete file; to undo installed binaries: `npm uninstall -g typescript-language-server pyright` + `rustup component remove rust-analyzer` |
| `scripts/check-host-lsp.sh`                                 | Delete file                                                                                                                              |
| `scripts/__tests__/check-host-lsp.bats`                     | Delete file                                                                                                                              |
| `docs/dev-infra/host-lsp-setup.md` + `docs/dev-infra/` dir  | Delete file (and directory if empty)                                                                                                     |
| Makefile `check-host-lsp` target + `test-shell` prereq edit | `git checkout` to prior version                                                                                                          |
| Dockerfile.dev documentary cross-ref comments               | `git checkout` to prior version (pure comments; no behavior change)                                                                      |

All host-scope rollbacks are file deletions or `git checkout` to prior versions. `npm uninstall -g` and `rustup component remove` are independent of the repo; they can be run at the owner's discretion. No existing production code is modified. No data migrations. Rollback has no side effects on running services.

## Testing Decisions

> Per `openspec/config.yaml`: "Include a Testing Decisions section that states what makes a good test for this change, which modules will be tested, and the prior art in the codebase."

### What makes a good test here

This is dev-infra — tests verify **tool presence and configuration shape**, not business logic. A good test is one that fails loudly when a tool goes missing or a configuration drifts silently, and passes quietly otherwise. We do NOT test LS analysis quality (each LS has its own test suite) or IDE integration (not automatable in CI).

### Container-scope test layers (T1–T6)

#### Smoke layer (`scripts/test-docker-smoke.sh`, run by `make test-infra`)

- Asserts each LS binary is on `PATH` in the built container: `typescript-language-server --version`, `pyright --version`, `rust-analyzer --version`.
- Follows the existing smoke test pattern: `docker compose exec -T dev <tool> --version >/dev/null` + `echo "ok: ..."`.
- Catches: missing installs, broken `RUN` steps, PATH misconfigurations.

#### Behavioral layer (`scripts/__tests__/gen-jsconfig.bats`, run by `make test-shell`)

- Asserts the generator produces valid JSON.
- Asserts the output contains path mappings for **specific known** `@poetry/*` packages (e.g., `@poetry/editor-engine`, `@poetry/data-contracts`, `@poetry/phonetics-core`).
- Asserts each path points to an existing `src/index.ts` file (via a `test -f` check or equivalent).
- Asserts `compilerOptions.baseUrl` is `"."`.
- Catches: generator logic regressions, silent empty-path failures, workspace layout drift.

### Host-scope 3-gate acceptance (T7–T11)

The host-scope change splits verification across three gates. Each gate is independently satisfiable; Gate B's rust-analyzer live-state is accepted as non-blocking (see Q7a ruling).

#### Gate A — spec-logic bats (FAKE-mocked, no host install required)

- **Location:** `scripts/__tests__/check-host-lsp.bats`
- **Pattern:** FAKE-mock from `check-tools.bats` — every `--version` probe is driven by a FAKE binary planted on `PATH` by the test; the script under test never shells a real LSP binary.
- **Core cases (6; Q7b — no partial-PATH / env-parse / install-rerun extras):**
  1. **all-ok** — all 3 FAKE tools report pinned versions → exit 0, 3 `ok:` lines, aggregate summary.
  2. **one-missing** — one FAKE tool's `which` fails → exit 1, 1 `fail:` line + 2 `ok:` lines, aggregate summary.
  3. **version-fail** — one FAKE tool reports a wrong version → exit 1, 1 `fail:` line naming the mismatch.
  4. **skip-neutral** — `SKIP_RUST=1` set → `skip:` line for rust-analyzer, exit 0 if others pass.
  5. **multi-fail** — multiple tools fail → aggregate reports all failures, exit 1, single summary line.
  6. **env-file-missing** — `scripts/lsp-versions.env` absent → exit 1 with a what/why/how-to-fix pointer (no bare `exit 1`).
- **Invariant:** bats NEVER shells real LSP binaries. If any test invokes a real `typescript-language-server`, `pyright`, or `rust-analyzer` on the host, the test is broken.
- **Runs under:** `make test-shell` (via bats-wrapper auto-discovery; baseline 110 → 110+N).

#### Gate B — host-integration, owner-run

- **Runs manually:** `bash scripts/check-host-lsp.sh`, `make check-host-lsp`, `make test-shell`.
- **Pass criteria:** `check-host-lsp.sh` exits 0; `make check-host-lsp` exits 0; `make test-shell` passes with the new prereq.
- **Live-state acceptance (Q7a):** rust-analyzer is absent on THIS host → Gate B fails until T8 is implemented OR `SKIP_RUST=1` is exported. This is accepted, not a blocker; documented in `docs/dev-infra/host-lsp-setup.md` §Troubleshooting. `make test-infra` (Docker smoke) and `test-shell` bats remain green.
- **Gate B is the real-host probe seam** — the counterpart to Gate A's FAKE-mock seam.

#### Gate C — T11 functional UX, owner-run manual

- **Runs manually:** go-to-definition / hover / diagnostics on `.ts` / `.rs` / `.py` files in the editor of choice.
- **Verification:** markdown checklist in the change archive (`openspec/changes/dev-infra-language-servers/verification-T11.md`); no automation.
- **Accepts:** any one of VSCode, opencode-in-container, opencode-on-host as the verification client.

### What we explicitly do NOT test

- IDE extension installation (VSCode marketplace availability is not our concern; devcontainer CLI handles this).
- LS responsiveness or analysis correctness (out of scope; each LS is third-party).
- `pyrightconfig.json` shape beyond "pyright can parse it and exit" (basic validity; the file is hand-maintained and reviewed in PRs).
- Rust-analyzer's clippy integration (only presence is asserted; clippy correctness is Rust's problem).
- **Extra bats cases** (partial-PATH / env-parse / install-rerun) — explicitly excluded per Q7b.
- **`opencode.jsonc` LSP configuration** — no test; no change made (deferred).
- **CI host-LSP enforcement** — CI runs in the dev container; host probe runs on owner's machine.

### Prior art in the codebase

- Smoke test binary-presence pattern: existing `scripts/test-docker-smoke.sh` lines 79-82 (node, python3 version checks).
- bats shell-script behavior pattern: existing `scripts/__tests__/dev-entrypoint.bats` (namespace-isolated tests with `test-helper.bash`).
- **bats FAKE-mock pattern (Gate A host scope):** existing `scripts/__tests__/check-tools.bats` — plants `FAKE_MISE_*`, `FAKE_NODE_*`, `FAKE_PNPM_*` binaries on `PATH` via `install_fakes()`, tests drive behavior via env vars. `check-host-lsp.bats` replicates this shape for LSP tools.
- **ok:/fail:/skip: line shape (Gate B host scope):** existing `scripts/check-tools.sh` emits `ok: <tool> <version> (mise-declared, version matches)` / `fail: ...` lines. `check-host-lsp.sh` mirrors this shape (different parenthetical context: `(host, version matches scripts/lsp-versions.env)`).
- bats-wrapper with vendor-on-demand: existing `scripts/__tests__/bats-wrapper.sh` (syntax-checks all scripts, vendors bats-core if missing; auto-discovery of `__tests__/*.bats`; baseline 110 → 110+N).
- Makefile `test-infra` composition: existing `Makefile` line 64 (`test-infra: test-shell test-python` + smoke test).

### Test risk and mitigation

**Risk:** generator silently produces empty path mappings if `pnpm-workspace.yaml` parsing fails (e.g., unexpected YAML shape). **Mitigation:** bats test asserts specific known package names appear in the output; an empty or malformed output fails the test loudly.

**Risk:** smoke test takes longer because three more `docker compose exec` calls. **Mitigation:** each call is a fast `--version` check (<1s); total addition is <5s to a test that already takes minutes.

**Risk (host scope):** Gate B rust-analyzer live-state fails on hosts without rustup. **Mitigation:** `SKIP_RUST=1` escape hatch documented in `host-lsp-setup.md`; rust-analyzer is the only skippable LS (TS/Python are required for core LSP work); the skip is neutral (does not affect exit 0).

**Risk (host scope):** bats test accidentally invokes a real LSP binary. **Mitigation:** FAKE-mock invariant — every test sets `PATH` to a temp dir containing only FAKE binaries; real LSPs are unreachable by construction.
