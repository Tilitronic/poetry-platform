# Design: volta-to-mise

> **Proposal:** `openspec/changes/volta-to-mise/proposal.md`
> **Predecessor ticket:** `docs/dev-infra-audit/tickets/archive/DIA-030.md`
> **Scope:** dev-infra toolchain swap. No system-architecture decision; no `.sdd/` module doc created.

## Context

### Design-authority reference

No `.sdd/` module doc governs this change. The traceability chain is:

- **DIA-030** (archived ticket) — the originating audit finding: unverified Volta installs. CLOSED 2026-08-03 with the owner directive: migrate to mise.
- **`.sdd/README.md`** (three-layer model) — this change lives in L3 `openspec/changes/`, not L1 `.sdd/`.
- **`docs/dev-infra-audit/inventory.md` §7** — the existing Docker/toolchain inventory that this change mutates.
- **`architecture.md`** — authoritative for the application. The dev-container toolchain is _not_ described there; it is described in the inventory and in this change's proposal/design.

Per AGENTS.md §2.4, dev-infra changes within existing boundaries use the spec chain directly. No `@architector` dispatch.

### The dual-path contract

mise can be consumed in two ways, and this change uses BOTH:

1. **mise declares** — `.mise.toml` at the repo root pins `node` and `pnpm` versions. This is the _source of truth_ for what versions are requested.
2. **Tarball installs** — `Dockerfile.dev` (and `tools/opencode-docker/Dockerfile`) download the mise binary itself via SHA256-verified tarball. This is the _trust chain_ for the binary.

Both paths consume the **same `.mise.toml` pin**. The Dockerfile install block makes `mise` available; the `.mise.toml` makes `mise install` reproducible. Neither is useful without the other.

### The manual-sync contract

The `.mise.toml` file pins `node = "24.18.0"` and `pnpm = "10.33.0"`. The Dockerfile ARG block pins `NODE_VERSION=24.18.0` and `PNPM_VERSION=10.33.0`. Today these two values are **manually synced at spec-author time** (a one-time step performed by the author of this change). The `.mise.toml` carries a header comment noting this:

```toml
# .mise.toml — Tool versions pinned for the poetry-platform dev environment.
#
# The node/pnpm versions here are derived from Dockerfile.dev ARGs at spec-author
# time (2026-08-03: node 24.18.0, pnpm 10.33.0). There is no automated sync
# between the two sources of truth; a future change may add a script that
# enforces parity. Until then, bumping either version requires updating BOTH:
#   - The ARG in Dockerfile.dev + tools/opencode-docker/Dockerfile
#   - The [tools] entry below
```

This is a deliberate deferral (out-of-scope per proposal §In-scope #10), not an oversight. The header comment makes the contract visible.

### Verify-at-implementation flags

Two unknowns MUST be resolved during implementation, not during spec-authoring. They are flagged here so the implementer does not silently paper over them:

**Flag (a): mise behavior when a pinned tool is not mise-installed.**
If a developer runs `node --version` on a host where mise has been installed but `mise install` has not yet been run (so the mise-managed node shim does not exist yet), what happens? Two possible behaviors:

- (i) mise's shim returns a clear error ("tool not installed; run mise install").
- (ii) mise falls through to whatever `node` is on PATH outside mise.

The spec does not assume either. The implementer MUST verify the behavior against the actual mise version chosen (see flag b) and document the observed behavior in the `check-tools.sh` wrapper's `--verify` output. If behavior (ii) holds, the `check-tools.sh` script needs an explicit `mise which node` probe to assert the shim is active, not just a `node --version` probe.

**RESOLVED (2026-08-03, against the actual mise v2026.8.0 binary):**

- `mise current <tool>` prints the `.mise.toml` pin **even when the tool is not mise-installed** — it only reads the config, so it is a _declaration_ probe, not an _activation_ probe.
- `mise which <tool>` exits 1 with `ERROR node is not a mise bin. Perhaps you need to install it first.` when the tool is not mise-installed — this is behavior (i)-style (a clear error, no silent fallthrough), and it is the shim-active probe.
- `mise install` resolves the pins (downloads node/pnpm, verifies upstream checksums, exit 0) and works non-interactively without a trust prompt in a fresh directory.
- Conclusion: `check-tools.sh` probes **both** `mise which <tool>` (activation) and a version parity comparison (`mise current <tool>` vs `<tool> --version` vs the pin) — a `node --version`-only probe would be insufficient.

**Flag (b): mise release SHA256 format.**
mise publishes SHA256 checksums on GitHub Releases, but the exact filename pattern and per-asset coverage need verification against the live release the implementer chooses. The MISE_VERSION ARG value and its corresponding SHA256 MUST be CONCRETE in the implementation — not invented. The implementer fetches the latest stable release at implementation time via:

```bash
# Fetch the latest stable mise release tag:
curl -fsSL https://github.com/jdx/mise/releases/latest -w '%{url_effective}\n' -o /dev/null
# Parse the tag (e.g., v2026.8.1) from the redirect URL, then fetch the checksum file:
curl -fsSL "https://github.com/jdx/mise/releases/download/v<MISE_VERSION>/SHA256SUMS"
# or the per-asset <asset>.sha256 pattern — whichever mise publishes for the chosen release.
```

The exact pattern (single `SHA256SUMS` manifest vs. per-asset `.sha256` sidecar) is determined at implementation time and recorded in `design.md` §4's "Install block" sub-section before the Dockerfile is modified. The implementer MUST NOT invent a SHA256 hash. If the chosen release's checksum format differs from the examples below, the install block is adapted to the actual format.

**RESOLVED (2026-08-03):**

- Latest stable release at implementation time: **v2026.8.0** (fetched via the redirect URL above; asset list from `api.github.com/repos/jdx/mise/releases/latest`).
- Checksum format: **single `SHASUMS256.txt` manifest** per release (no per-asset sidecars). Entries look like `<sha256>  ./mise-v<VER>-linux-<arch>.tar.gz` — the filename carries a `./` prefix that the install block must strip when rewriting to `/tmp/mise.tar.gz`.
- Concrete digests (from the v2026.8.0 `SHASUMS256.txt`):
  - linux-x64: `64183603854f319b78658305c545aacae935e0959a3a894b77a0f9416eab047b`
  - linux-arm64: `6d888ba3d0b5d78f676771a84846885b7f685fb4d1533f2927079eb9b75633a8`
- **Tarball layout deviation:** the release tarball does NOT contain a bare `mise` binary at the archive root — it contains a `mise/` prefix directory with the binary at `mise/bin/mise` (plus share/man/README/LICENSE). The design skeleton's `--strip-components=0 mise` would fail; the install block extracts with `tar xzf ... -C /usr/local/bin/ --strip-components=2 mise/bin/mise` (verified against the real tarball).

---

## §1 — Seams

The four pre-agreed public boundaries seams where tests will live. No test is written at an unconfirmed seam.

| Seam   | Boundary                                                                                                      | Test location                                |
| ------ | ------------------------------------------------------------------------------------------------------------- | -------------------------------------------- |
| **S1** | The mise install block in `Dockerfile.dev` and `tools/opencode-docker/Dockerfile` (replaces the Volta block). | `make test-infra` (smoke test probes §4).    |
| **S2** | `scripts/check-tools.sh` wrapper + `make check-tools` Makefile target + `MISE_TRUSTED_CONFIG_PATHS` ENV.      | `scripts/__tests__/check-tools.bats` (unit). |
| **S3** | Runtime probes in `scripts/test-docker-smoke.sh` (mise presence, `.mise.toml` resolution, ENV set).           | `make test-infra` (integration smoke).       |
| **S4** | `.mise.toml` config integrity (parses, pins match Dockerfile ARGs, header comment present).                   | `scripts/__tests__/check-tools.bats` (unit). |

### Why these seams

- **S1 (Dockerfile install block):** The most critical boundary. If the mise install fails or is not SHA256-verified, SEC-DOCKER-001 is violated. Tested indirectly via smoke (the image must build).
- **S2 (check-tools wrapper):** The host-runnable integrity check. Unit-tested with bats (Docker mocked, per the existing `test-shell` pattern).
- **S3 (smoke probes):** The runtime assertion that mise works inside the running container. Tested by `make test-infra`.
- **S4 (config integrity):** Guards the `.mise.toml` pin contract — the versions declared there must match the Dockerfile ARGs (or the header-comment contract must hold). Tested by the bats unit test.

---

## §2 — File-by-file implementation design

### §2.1 — New file: `.mise.toml` (repo root)

Contents:

```toml
# .mise.toml — Tool versions pinned for the poetry-platform dev environment.
#
# The node/pnpm versions here are derived from Dockerfile.dev ARGs at spec-author
# time (2026-08-03: node 24.18.0, pnpm 10.33.0). There is no automated sync
# between the two sources of truth; a future change may add a script that
# enforces parity. Until then, bumping either version requires updating BOTH:
#   - The ARG in Dockerfile.dev + tools/opencode-docker/Dockerfile
#   - The [tools] entry below

[tools]
node = "24.18.0"
pnpm = "10.33.0"
```

**Scope decision (interview Q8):** `[tools]` only. No `[env]`, no `[plugins]`, no `[settings]`. The mise install block in the Dockerfile handles ENV; the `[tools]` section handles tool pins. No other mise feature is adopted in this change.

### §2.2 — Modified file: `package.json` (root)

Remove the `volta` block (lines 66–69):

```diff
-  "volta": {
-    "node": "24.18.0",
-    "pnpm": "10.33.0"
-  }
```

No other changes to `package.json`. The `packageManager`, `engines`, `scripts`, `devDependencies`, `lint-staged` fields stay as-is.

### §2.3 — Modified file: `apps/author-studio/package.json`

Remove the `volta` block (lines 46–49):

```diff
-  "volta": {
-    "node": "24.18.0",
-    "pnpm": "10.33.0"
-  },
```

The `engines` field stays as-is (it is a separate concern, out of scope).

### §2.4 — Modified file: `Dockerfile.dev` (S1 + S2)

**Remove** the existing Volta install block (lines 108–118) and the `ARG VOLTA_VERSION=2.0.2` (line 31):

```diff
- ARG VOLTA_VERSION=2.0.2
```

```diff
- # === Volta — JS tool manager ===
- # SEC-DOCKER-001: checksum verification is BLOCKED here — the volta-cli/volta
- # v2.0.2 release publishes no official digest for the binary tarballs
- # (volta.manifest lists binary names only, no hashes). Per the audit rule
- # "never guess a hash", this install is intentionally left unverified (ticket
- # DIA-030 stays open for volta). Revisit when upstream publishes checksums.
- RUN VOLTA_ARCH=$(case "${TARGETARCH:-$(uname -m)}" in x86_64|amd64) echo "linux" ;; aarch64|arm64) echo "linux-arm" ;; esac) && \
-     curl -fsSL "https://github.com/volta-cli/volta/releases/download/v${VOLTA_VERSION}/volta-${VOLTA_VERSION}-${VOLTA_ARCH}.tar.gz" -o /tmp/volta.tar.gz && \
-     tar xzf /tmp/volta.tar.gz -C /usr/local/bin/ && \
-     rm -f /tmp/volta.tar.gz && \
-     volta --version
```

**Insert** in the same position (after the snip install block, before the uv install block) a new mise install block. The exact SHA256 verification pattern depends on flag (b) from the Context section — the implementer resolves this at implementation time. The skeleton (shape mirrors the existing uv install block):

```dockerfile
# === mise — JS tool manager (replaces Volta; see DIA-030 closure) ===
# SEC-DOCKER-001: the mise release publishes SHA256 checksums alongside each
# tarball. MISE_VERSION + its SHA256 are pinned in concert; the checksum file
# is fetched from the same release and verified before extraction (same shape
# as the uv install below).
ARG MISE_VERSION=2026.8.0
RUN MISE_ARCH=$(case "${TARGETARCH:-$(uname -m)}" in x86_64|amd64) echo "x64" ;; aarch64|arm64) echo "arm64" ;; esac) && \
    curl -fsSL "https://github.com/jdx/mise/releases/download/v${MISE_VERSION}/mise-v${MISE_VERSION}-linux-${MISE_ARCH}.tar.gz" -o /tmp/mise.tar.gz && \
    curl -fsSL "https://github.com/jdx/mise/releases/download/v${MISE_VERSION}/SHASUMS256.txt" -o /tmp/mise.sha256 && \
    grep "mise-v${MISE_VERSION}-linux-${MISE_ARCH}.tar.gz" /tmp/mise.sha256 | sed "s|\./mise-v${MISE_VERSION}-linux-${MISE_ARCH}.tar.gz|/tmp/mise.tar.gz|" | sha256sum -c - && \
    tar xzf /tmp/mise.tar.gz -C /usr/local/bin/ --strip-components=2 mise/bin/mise && \
    rm -f /tmp/mise.tar.gz /tmp/mise.sha256 && \
    mise --version
```

**FLAG_B RESOLUTION (2026-08-03) — the concrete values above replace every `<...>` placeholder:**

- `MISE_VERSION=2026.8.0` — the ARG carries NO leading "v" (repo convention: VOLTA_VERSION=2.0.2, NODE_VERSION=24.18.0 — the download URLs prefix `v`, so `v${MISE_VERSION}` → `v2026.8.0`). Latest stable at implementation time; see Context flag (b) resolution for the fetch evidence. **Empirical correction (2026-08-03):** the initial draft used `MISE_VERSION=v2026.8.0`, which produced `vv2026.8.0` (double-v) in the URL and a 404 — caught by executing the exact RUN block in a scratch `debian:13-slim` container; fixed to the no-v convention above.
- Checksum file: `SHASUMS256.txt` (single manifest; entries `./mise-v<VER>-linux-<arch>.tar.gz`). The `sed` strips the `./` prefix and rewrites the filename to `/tmp/mise.tar.gz` before `sha256sum -c -` — the same grep|sed|sha256sum shape as the tini/snip/uv blocks.
- Extraction: `--strip-components=2 mise/bin/mise` — REQUIRED deviation from the original skeleton's `--strip-components=0 mise`: the release tarball nests the binary at `mise/bin/mise` under a `mise/` prefix dir (verified against the actual v2026.8.0 tarball). No mise shims are installed (the tarball ships only the `mise` binary); `mise install` inside the container manages tool versions at runtime, never PATH shims.

The `<PLACEHOLDER_RESOLVED_VIA_FLAG_B>` tokens are resolved by the implementer at implementation time (see §Context "Verify-at-implementation flags" flag (b)). The spec does not invent a hash.

**Add** the `MISE_TRUSTED_CONFIG_PATHS` ENV declaration (S2) in the ENV block after `PIP_BREAK_SYSTEM_PACKAGES=1`:

```dockerfile
ENV MISE_TRUSTED_CONFIG_PATHS=/workspace
```

This makes the mounted `/workspace/.mise.toml` trusted for the non-root `dev` user without per-session prompts.

**Update** the Dockerfile header comment (line 5) to reflect the new tool list:

```diff
- #   - Node 24, pnpm, bun, uv, Volta, snip
+ #   - Node 24, pnpm, bun, uv, mise, snip
```

### §2.5 — Modified file: `tools/opencode-docker/Dockerfile` (S1)

**Remove** the Volta install block (lines 48–54) and the `ARG VOLTA_VERSION=2.0.2` declaration:

```diff
- # Install Volta 2.0.2 — JS tool manager for automatic Node version switching
- ARG VOLTA_VERSION=2.0.2
- RUN VOLTA_ARCH=$(case "${TARGETARCH:-$(uname -m)}" in x86_64|amd64) echo "linux" ;; aarch64|arm64) echo "linux-arm" ;; esac) && \
-     curl -fsSL "https://github.com/volta-cli/volta/releases/download/v${VOLTA_VERSION}/volta-${VOLTA_VERSION}-${VOLTA_ARCH}.tar.gz" -o /tmp/volta.tar.gz && \
-     tar xzf /tmp/volta.tar.gz -C /usr/local/bin/ && \
-     rm -f /tmp/volta.tar.gz && \
-     volta --version
```

**Insert** the same mise install block as §2.4 (identical shape, same FLAG_B resolution).

### §2.6 — Modified file: `tools/opencode-docker/Dockerfile` (line ~103 — the `collect-runtime-deps.sh` invocation whitelist) (S1)

Rename the `volta*` entries in the runtime dependency whitelist at the `collect-runtime-deps.sh` invocation (line ~103) of `tools/opencode-docker/Dockerfile`. The script itself never had volta entries.

```diff
-       curl wget snip uv volta volta-migrate volta-shim dbus-send openspec
+       curl wget snip uv mise dbus-send openspec
```

`volta-migrate` and `volta-shim` were Volta-specific helpers that mise does not ship. The single `mise` binary covers all of mise's functionality.

### §2.7 — New file: `scripts/check-tools.sh` (S2)

A host-runnable wrapper around `mise install` + `mise trust`. Invoked via `make check-tools`. Responsibilities:

1. Check that `mise` is on PATH (fail with a pointer to `make build` if not — mise ships in the dev container, so running this on the host without mise is an expected error path, not a bug).
2. Run `mise trust /workspace/.mise.toml` (or whatever path the `.mise.toml` is at).
3. Run `mise install` to resolve the `[tools]` pins.
4. Probe each pinned tool via `mise which <tool>` (addresses flag (a): asserts the mise-managed shim is active, not a system PATH tool).
5. Print a summary line per tool: `ok: node <version> (mise-declared, version matches)` or `fail: node shim not active`.

**Flag (a) resolution incorporated (2026-08-03, verified against mise v2026.8.0):** `mise current <tool>` alone cannot prove activation (it prints the pin even when the tool is not mise-installed), so the implemented script additionally compares `mise current <tool>` AND `<tool> --version` against the hardcoded pin (24.18.0 / 10.33.0) — see Context flag (a) RESOLVED. The summary line format is `ok: node 24.18.0 (mise-declared, version matches)`.

The script is tested by bats with Docker mocked (same pattern as `dev-stack.bats`). bats tests cover:

- mise present → script exits 0 with "ok" summary.
- mise absent → script exits non-zero with a clear "run make build first" message.
- `.mise.toml` missing → script exits non-zero with a clear "no .mise.toml at repo root" message.
- `mise which node` returns non-zero → script reports "shim not active" and exits non-zero.

### §2.8 — Modified file: `Makefile`

**Add** the `check-tools` target (S2):

```makefile
check-tools:
	bash scripts/check-tools.sh
```

**Add** `check-tools` to the `.PHONY` declaration line.

The target is deliberately NOT wired into `test-shell` or `test-infra`: `check-tools` is a host-runnable convenience, not a CI gate. It requires mise to be on PATH (which means either the dev container or a host mise install — out of scope for this change).

### §2.9 — Modified file: `scripts/test-docker-smoke.sh` (S3)

**Add** three probes after the existing openspec/make probes (lines 112–122):

```bash
echo "-> verifying mise tool manager (DIA-030 closure)..."
docker compose exec -T dev mise --version >/dev/null
echo "ok: mise present in dev container"
# The mounted /workspace/.mise.toml must resolve under MISE_TRUSTED_CONFIG_PATHS.
docker compose exec -T dev bash -c 'mise install >/dev/null && mise which node >/dev/null'
echo "ok: mise resolved .mise.toml pins"
docker compose exec -T dev bash -c '[ -n "${MISE_TRUSTED_CONFIG_PATHS:-}" ]'
echo "ok: MISE_TRUSTED_CONFIG_PATHS set"
```

### §2.10 — Modified file: `scripts/__tests__/bats-wrapper.sh`

**Add** `scripts/check-tools.sh` to the `bash -n` syntax-check loop (line 20–31):

```diff
  "$ROOT/scripts/lint-python-files.sh" \
+ "$ROOT/scripts/check-tools.sh" \
  "$ROOT/.opencode/scripts/validate-skills.sh" \
```

### §2.11 — New file: `scripts/__tests__/check-tools.bats` (S2 + S4)

bats unit tests for `scripts/check-tools.sh`. Uses `mock_docker` from `test-helper.bash` (mise is on PATH via a test-installed fake). Test cases:

1. mise present + `.mise.toml` present + `mise which node` succeeds → script exits 0 with "ok: node" output.
2. mise absent → script exits non-zero with "run make build first" message.
3. `.mise.toml` missing → script exits non-zero with "no .mise.toml" message.
4. `mise which node` returns non-zero → script reports "shim not active" and exits non-zero.
5. `.mise.toml` header comment present + `[tools]` section present → S4 integrity check passes (this is a structural assertion, not a content assertion — the versions are checked by the smoke test against the running container, not by the bats test).

### §2.12 — Documentation updates

**`docs/onboarding.md`**: replace any Volta reference (none found by grep — Volta is not mentioned in onboarding.md today, but the toolchain narrative at §1 should mention mise alongside the other dev-container tools).

**`docs/docker-dev.md`**: same — add mise to the tool list if a tool list exists; otherwise no change.

**`docs/dev-infra-audit/inventory.md` §7**: replace "volta 2.0.2" with "mise <MISE_VERSION>" in the ARG list and the toolchain narrative.

**`docs/dev-infra-audit/NEXT-RUN.md`**: add a row to the "closed this cycle" table noting the volta→mise migration and pointing at DIA-030 (already closed).

**`docs/dev-infra-audit/tickets/archive/DIA-030.md`**: append a note at the bottom recording that the owner directive (migrate to mise) has been fulfilled by this change. The CLOSED status stays; the note adds traceability.

---

## §3 — Test strategy

Per `openspec/config.yaml` rules, this section states what makes a good test for this change, which modules will be tested, and the prior art.

### What makes a good test here

The artifacts under test are bash scripts, Dockerfile RUN blocks, ENV declarations, and a TOML file. bash/bats is the right tool (same choice as the existing 8 bats suites). Tests assert **observable behavior** (commands succeed, files parse, ENV is set), not implementation details (specific line numbers in a Dockerfile).

### Modules under test

| Module                                                  | Test type          | Gate              |
| ------------------------------------------------------- | ------------------ | ----------------- |
| `scripts/check-tools.sh` (new)                          | bats unit (S2)     | `make test-shell` |
| `scripts/test-docker-smoke.sh` (extended, S3)           | integration smoke  | `make test-infra` |
| `Dockerfile.dev` (modified, S1)                         | integration smoke  | `make test-infra` |
| `.mise.toml` (new, S4)                                  | bats unit (S4)     | `make test-shell` |
| `tools/opencode-docker/Dockerfile` (modified)           | `bash -n` (syntax) | `make test-shell` |
| `tools/opencode-docker/scripts/collect-runtime-deps.sh` | `bash -n` (syntax) | `make test-shell` |

### Acceptance criteria (AC1–AC14)

Each AC is testable by one of the seams above. The task list maps each AC to a specific test.

| AC   | Description                                                                                                                                                                                                                         | Test seam |
| ---- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------- |
| AC1  | `Dockerfile.dev` contains no volta install tokens (VOLTA_VERSION, volta-cli, volta-shim, volta-migrate, volta.tar, volta --version). Historical comments (e.g. 'replaces Volta; DIA-030 closure') are acceptable.                   | S1        |
| AC2  | `tools/opencode-docker/Dockerfile` contains no volta install tokens (VOLTA_VERSION, volta-cli, volta-shim, volta-migrate, volta.tar, volta --version). Historical comments (e.g. 'replaces Volta; DIA-030 closure') are acceptable. | S1        |
| AC3  | `Dockerfile.dev` contains a mise install block with SHA256 verification.                                                                                                                                                            | S1        |
| AC4  | `tools/opencode-docker/Dockerfile` contains the same SHA256-verified mise install block.                                                                                                                                            | S1        |
| AC5  | `MISE_TRUSTED_CONFIG_PATHS=/workspace` is declared as ENV in `Dockerfile.dev`.                                                                                                                                                      | S2        |
| AC6  | `.mise.toml` exists at the repo root with `[tools]` section declaring `node` and `pnpm`.                                                                                                                                            | S4        |
| AC7  | `.mise.toml` contains the spec-author header comment about manual sync.                                                                                                                                                             | S4        |
| AC8  | `package.json` (root) no longer contains a `volta` block.                                                                                                                                                                           | S4        |
| AC9  | `apps/author-studio/package.json` no longer contains a `volta` block.                                                                                                                                                               | S4        |
| AC10 | `scripts/check-tools.sh` exists and is bash-syntax-clean.                                                                                                                                                                           | S2        |
| AC11 | `make check-tools` target exists in the Makefile.                                                                                                                                                                                   | S2        |
| AC12 | `scripts/__tests__/check-tools.bats` exists and passes under `make test-shell`.                                                                                                                                                     | S2        |
| AC13 | `scripts/test-docker-smoke.sh` probes mise presence, `.mise.toml` resolution, and the ENV var.                                                                                                                                      | S3        |
| AC14 | `tools/opencode-docker/Dockerfile` line ~103 lists `mise` instead of `volta*` in the collect-runtime-deps.sh invocation.                                                                                                            | S1        |

---

## §4 — Rollback plan

Rollback is trivial because this change has no persistent-state impact:

1. **`git revert <merge-commit>`** — reverts all file changes.
2. **`make build && make test-infra`** — rebuilds the dev image with the reverted Dockerfile and runs the full smoke suite.
3. **Verify**: the dev container starts, Volta is back in place, the smoke test passes.

No data migration is needed. `.mise.toml` is removed on revert; `package.json` volta blocks are restored. The only thing that needs to exist after rollback is the reverted Dockerfile + the original Volta install block.

**Rollback risk:** very low. The change is a bounded dev-infra swap with no application-code impact and no persistent-state impact.

---

## §5 — Acceptance-criteria-to-test traceability

The AC→seam mapping in §3 is reproduced as a task-list ordering constraint in `tasks.md`. Each task's verification procedure cites the specific AC numbers it closes.
