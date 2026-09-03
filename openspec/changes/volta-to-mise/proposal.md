# Proposal: volta-to-mise

> **Status:** proposed · **Scope:** dev-infra (dev-container toolchain — replace the unverified Volta JS tool manager with the SHA256-verifiable mise tool manager)
> **Escalation:** none — change is within existing module boundaries (per AGENTS.md §2.4, dev-infra changes do not require @architector). No `.sdd/` module doc is created; this change references `.sdd/README.md` only.
> **Predecessor ticket:** `docs/dev-infra-audit/tickets/archive/DIA-030.md` (CLOSED 2026-08-03 with owner directive to migrate).

## Motivation

`Dockerfile.dev` and `tools/opencode-docker/Dockerfile` both install **Volta v2.0.2** (2024-12-05) as the JS tool manager. DIA-030 flagged this install as _unverified_: Volta publishes **no official checksums** for the binary tarballs this image downloads (`volta.manifest` lists binary names only; the GitHub release has `digest: null` on every asset; the 2025-06-03 auto-digest feature does not retroactively cover pre-rollout uploads). Per the project's audit rule "never guess a hash", the install was left unverified and DIA-030 stayed in MONITOR.

Since the DIA-030 closure (2026-08-03), the upstream situation has escalated from "no checksums" to "unmaintained":

1. **Volta is officially unmaintained.** The upstream README now carries a banner recommending migration to `mise` (jdx/mise). See Volta issue #2080.
2. **v2.0.2 (2024-12-05) remains the latest release.** No new releases have been cut in >7 months. The project is on life support.
3. **Checksums are not coming.** The upstream has explicitly deprioritized digest publication in favor of recommending migration.

Continuing to ship an unverified, unmaintained tool manager in the dev image violates the project's SEC-DOCKER-001 invariant (every pinned installer is SHA256-verified). The right response is not to add checksums around Volta — Volta is not going to publish them, and wrapping an unmaintained project in third-party verification does not fix the maintenance risk. The right response is to replace Volta with a maintained, checksum-publishing alternative that serves the same job.

`mise` (jdx/mise) is the upstream-recommended successor. It is actively maintained (daily releases), publishes SHA256 checksums for every release artifact on GitHub Releases, supports a single-file `.mise.toml` tool pin that can replace the `volta` blocks in both `package.json` files (root + `apps/author-studio`), and runs as a static binary — same shape as the existing snip/uv/tini install pattern.

## Scope

### In scope

1. **Replace the Volta install block in `Dockerfile.dev` with a SHA256-verified mise install block** (seam S1). `MISE_VERSION` is an ARG; the tarball is downloaded + verified against the upstream-published SHA256 before extraction — same shape as the node/uv/snip blocks.
2. **Replace the Volta install block in `tools/opencode-docker/Dockerfile` with the same SHA256-verified mise install block** (seam S1).
3. **Remove both `volta` blocks from `package.json`** (root + `apps/author-studio`). The `.mise.toml` at the repo root is the single source of tool pins.
4. **Create `.mise.toml` at the repo root** with `[tools]` only (no `env`, no `plugins`, no `settings` — per interview Q8). Pins `node` and `pnpm` to the versions Volta currently declared.
5. **Add `make check-tools`** (seam S2) — a host-runnable target that invokes `mise install` + `mise trust` as needed and verifies the pinned tools resolve. bats unit test coverage for the wrapper script.
6. **Set `MISE_TRUSTED_CONFIG_PATHS` ENV** in `Dockerfile.dev` (seam S2) so the non-root `dev` user at runtime can read the mounted `/workspace/.mise.toml` without per-session prompts.
7. **Add smoke-test runtime probes for mise** (seam S3) in `scripts/test-docker-smoke.sh`: asserts `mise --version`, asserts `mise install` resolves the `.mise.toml` pins inside the running container, asserts `MISE_TRUSTED_CONFIG_PATHS` is set.
8. **Update the runtime-dependency whitelist** in `tools/opencode-docker/scripts/collect-runtime-deps.sh` (rename `volta*` entries → `mise`).
9. **Documentation updates** (onboarding.md, docker-dev.md, inventory.md, NEXT-RUN.md) pointing at DIA-030's closure and the new mise-based workflow.
10. **`.mise.toml` header comment** noting that the `node`/`pnpm` versions declared there are derived from the Dockerfile.dev ARGs at spec-author time (one-time manual sync — see design.md §7 for the rationale and the verify-at-implementation flag for whether mise can auto-sync from ENV).

### Out of scope

- **Installing mise on the host** — mise runs inside the dev container only. Host tooling is unchanged.
- **Migrating any other tool to mise** — only `node` and `pnpm` (the two tools Volta currently declared) move into `.mise.toml`. Python (uv), Rust (rustup), Bun (standalone), OpenCode (standalone), snip, OpenSpec, tini stay where they are.
- **Using mise's `env`, `plugins`, or `settings` sections** — intentionally deferred. `.mise.toml` is `[tools]` only (interview Q8).
- **Changing the `package.json` `engines` field** — that's a separate concern; out of scope.
- **CI integration** — the project has no `.github/` and no CI (per inventory.md §12). This change does not add CI.
- **`.sdd/` module doc creation** — no system architecture decision is made; this is a bounded dev-infra swap. The DIA-030 archive record remains the design-authority reference.
- **Bumping node/pnpm versions** — this change preserves the existing pinned versions. Version bumps belong in a separate change.

## Design authority (.sdd/) reference

**No `.sdd/` module doc governs this change.** The system architecture authority (`architecture.md`) describes the application's boundaries (editor, workers, contracts, cloud), not the dev-container toolchain. The dev-container toolchain is documented in:

- `docs/dev-infra-audit/inventory.md` §7 (Docker)
- `docs/dev-infra-audit/tickets/archive/DIA-030.md` (the unverified-installs ticket, now CLOSED with the migration directive)
- `.sdd/README.md` (three-layer model — this change lives in L3 `openspec/changes/`, not L1 `.sdd/`)

Per AGENTS.md §2.4, dev-infra changes within existing boundaries use the spec chain directly without architectural escalation. No `@architector` dispatch is required.

**Traceability:** every design decision below references DIA-030 as the originating audit finding and the locked decisions from the interview (Q1–Q8, AC1–AC14).

## Success criteria

1. **SEC-DOCKER-001 restored.** Every pinned installer in `Dockerfile.dev` is SHA256-verified. `mise --version` runs in the container. No `volta` binary or `volta` reference remains in any Dockerfile or `package.json`.
2. **Single source of truth for tool pins.** `.mise.toml` at the repo root declares `node` and `pnpm` with the same versions Volta used to declare. The two `volta` blocks in `package.json` files are gone.
3. **Host-runnable tool integrity check.** `make check-tools` succeeds on a fresh checkout (after `make build`), verifying that the pinned tools resolve.
4. **Smoke test coverage.** `make test-infra` asserts that mise is present, trusted, and functional inside the running dev container.
5. **Runtime whitelist correctness.** `tools/opencode-docker/scripts/collect-runtime-deps.sh` lists `mise` instead of `volta*` entries; the hardened opencode-docker image launches successfully.
6. **Documentation accuracy.** `docs/onboarding.md`, `docs/docker-dev.md`, and `docs/dev-infra-audit/inventory.md` reflect the new toolchain. `NEXT-RUN.md` records the migration.
7. **Rollback is trivial.** `git revert` of the merge commit + `make build && make test-infra` restores the previous state. No data migration, no persistent-state change.

## Non-goals

- **Automated sync between `Dockerfile.dev` ARGs and `.mise.toml`** — the sync is a one-time manual step at spec-author time, documented in the `.mise.toml` header comment. A future change may add a script that enforces parity; this change does not.
- **Adopting mise's `env`/`plugins`/`settings` features** — deferred to a future change if needed.
- **Host-side mise installation** — this change is scoped to the dev container.
- **CI gate for `check-tools`** — there is no CI (inventory.md §12).

## Stakeholders

| Stakeholder                       | Interest                                                                                                                  |
| --------------------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| Dev-container user                | `pnpm install`, `node`, `pnpm` commands continue to work; `make check-tools` is now available as a parity check.          |
| Security posture (SEC-DOCKER-001) | Every pinned installer is now SHA256-verified; no unmaintained tool manager in the image.                                 |
| Maintainer (DIA audit)            | DIA-030 closure is complete; the MONITOR→CLOSED directive is fulfilled.                                                   |
| opencode-docker image             | The hardened runtime image no longer pulls in the unmaintained Volta binaries; `mise` replaces `volta*` in the whitelist. |

## Testing Decisions

Per `openspec/config.yaml` rules: this section states what makes a good test for this change, which modules will be tested, and the prior art in the codebase.

### What makes a good test here

- **Bash/bats is the right tool.** The artifacts under test are shell scripts (`scripts/check-tools.sh`), Dockerfile RUN blocks, ENV declarations, and smoke-test probes — not TypeScript or Python. The existing prior art is `scripts/__tests__/*.bats` (8 suites covering `dev-entrypoint.sh`, `dev-stack.sh`, `gen-jsconfig.sh`, `lint-python-files.sh`, `verify-pre-{commit,push}.sh`, `verify-python.sh`, `context7-docs.mjs`, `validate-skills.sh`).
- **Docker is mocked in unit tests, real in smoke.** Consistent with the existing split: `make test-shell` runs bats with Docker mocked via `test-helper.bash`'s `mock_docker`; `make test-infra` runs `scripts/test-docker-smoke.sh` against a real compose stack. The new `check-tools` tests follow the `test-shell` pattern; the new mise probes follow the smoke-test pattern.
- **Tests assert observable behavior, not implementation details.** Tests assert that `mise --version` succeeds, that `.mise.toml` parses, that `MISE_TRUSTED_CONFIG_PATHS` is set in the container — not that a specific line exists in a Dockerfile.

### Modules under test

1. `scripts/check-tools.sh` (new) — bats unit tests in `scripts/__tests__/check-tools.bats`.
2. `scripts/test-docker-smoke.sh` (extended) — adds mise probes; exercised via `make test-infra`.
3. `Dockerfile.dev` (modified) — exercised via `make test-infra` (build + smoke).
4. `.mise.toml` (new) — parsed by `mise install` during smoke test; also checked by `check-tools.sh`.
5. `tools/opencode-docker/scripts/collect-runtime-deps.sh` (modified) — exercised via opencode-docker image build (out-of-repo CI concern; at minimum, a `bash -n` syntax check in `bats-wrapper.sh`).

### Prior art

- `scripts/__tests__/dev-entrypoint.bats` (10 tests, unshare-isolated) — pattern for namespace isolation where needed.
- `scripts/__tests__/dev-stack.bats` (5 tests, mock_docker) — pattern for mocking Docker.
- `scripts/test-docker-smoke.sh` lines 85–122 — existing runtime-presence probes (node, python3, openspec, language servers); the new mise probes follow this exact shape.
- `Dockerfile.dev` lines 80–88 (node install) + lines 130–136 (uv install) — the SHA256-verified tarball pattern the mise install block mirrors.
