# Tasks: volta-to-mise

> **Proposal:** `openspec/changes/volta-to-mise/proposal.md`
> **Design:** `openspec/changes/volta-to-mise/design.md`
> **Predecessor ticket:** `docs/dev-infra-audit/tickets/archive/DIA-030.md`
> **Workflow:** per `openspec/config.yaml`, each task is a vertical slice. For each task, invoke the `tdd-craftsman` skill. Write the failing test BEFORE any production code.

## Dependency graph

```
T1 (.mise.toml + volta block removals + check-tools script + bats)
 │
 ├──▶ T2 (Dockerfile.dev mise install block + MISE_TRUSTED_CONFIG_PATHS ENV + smoke probes)
 │     │
 │     └──▶ T3 (tools/opencode-docker Dockerfile swap + whitelist rename)
 │           │
 │           └──▶ T5 (full validation gate)
 │
 └──▶ T4 (documentation updates)
       │
       └──▶ T5 (full validation gate)
```

**Critical path:** T1 → T2 → T3 → T5
**Parallel track:** T4 (docs) runs in parallel with T2/T3 — it depends only on T1 (the new `.mise.toml` must exist before docs can reference it).

**Rationale for ordering:**

- **T1 is the foundation.** It creates `.mise.toml`, removes the two `volta` blocks from `package.json` files, and introduces `scripts/check-tools.sh` with bats coverage. T2/T3/T4 all reference artifacts produced by T1.
- **T2 follows T1** because the Dockerfile install block consumes `.mise.toml` (the file T1 creates) and the smoke probes assert the ENV T2 sets.
- **T3 follows T2** because the `tools/opencode-docker/Dockerfile` mise install block is the _same shape_ as T2's — the implementer copies the resolved FLAG_B pattern from T2 rather than re-resolving it. The whitelist rename in the `collect-runtime-deps.sh` invocation (`tools/opencode-docker/Dockerfile` line ~103) is a one-line change that rides along with the Dockerfile swap.
- **T4 follows T1** but can run in parallel with T2/T3 because docs are text-only and do not block any test.
- **T5 is the validation gate.** It depends on all of T1–T4 because it runs the full test suite. It is the last slice because it requires all prior slices to be green.

---

## Pre-implementation resolution (MANDATORY)

**Before T1 starts, the implementer MUST resolve the two verify-at-implementation flags from design.md §Context:**

- **Flag (a):** Run `mise install` on a scratch environment (or read the mise docs for the chosen version) and determine what happens when `node --version` is invoked but mise's node shim is not yet active. Record the observed behavior in design.md §2.7's `check-tools.sh` wrapper description. This determines whether `check-tools.sh` needs an explicit `mise which node` probe or can rely on `node --version` alone.

- **Flag (b):** Fetch the latest stable mise release and determine the exact SHA256 verification pattern mise publishes:

  ```bash
  # Step 1: fetch the latest stable release tag
  curl -fsSL https://github.com/jdx/mise/releases/latest -w '%{url_effective}\n' -o /dev/null
  # Step 2: parse the tag (e.g., v2026.8.1)
  # Step 3: list the release assets
  curl -fsSL "https://api.github.com/repos/jdx/mise/releases/latest" | jq -r '.assets[].name'
  # Step 4: identify the SHA256 pattern — single SHA256SUMS manifest vs. per-asset .sha256 sidecar
  ```

  Record the chosen `MISE_VERSION` and its `SHA256` in design.md §2.4 before writing the Dockerfile install block. **Do NOT invent a hash.** If the chosen release's checksum format differs from the existing uv/snip patterns, adapt the install block accordingly.

**The MISE_VERSION ARG value is a TODO until flag (b) is resolved.** The design.md and tasks.md use the placeholder `<IMPLEMENTER_RESOLVES_VIA_FLAG_B>` for this value.

---

## T1 — `.mise.toml` + volta block removals + `check-tools.sh` + bats

**Blockers:** none
**Vertical slice:** create the new tool-pin source of truth (`.mise.toml`), remove the two `volta` blocks from `package.json` files, introduce `scripts/check-tools.sh` with bats coverage.

### What changes

1. **`.mise.toml`** (new file, repo root) — contents per design.md §2.1. `[tools]` section only, with header comment about manual sync.
2. **`package.json`** (root, modified) — remove the `volta` block (lines 66–69) per design.md §2.2.
3. **`apps/author-studio/package.json`** (modified) — remove the `volta` block (lines 46–49) per design.md §2.3.
4. **`scripts/check-tools.sh`** (new file, executable) — host-runnable wrapper per design.md §2.7. Implements the four steps: PATH check → `mise trust` → `mise install` → `mise which <tool>` probe per pinned tool (flag-a resolution).
5. **`scripts/__tests__/check-tools.bats`** (new file) — bats unit tests per design.md §2.11. Five test cases covering: mise present (happy path), mise absent (clean error), `.mise.toml` missing (clean error), `mise which node` fails (clean error), `.mise.toml` header-comment + `[tools]` structural integrity (S4).
6. **`scripts/__tests__/bats-wrapper.sh`** (modified) — add `scripts/check-tools.sh` to the `bash -n` syntax-check loop per design.md §2.10.
7. **`Makefile`** (modified) — add `check-tools` target per design.md §2.8.

### Acceptance criteria closed

- **AC6:** `.mise.toml` exists with `[tools]` declaring `node` and `pnpm`.
- **AC7:** `.mise.toml` header comment about manual sync present.
- **AC8:** root `package.json` no longer contains a `volta` block.
- **AC9:** `apps/author-studio/package.json` no longer contains a `volta` block.
- **AC10:** `scripts/check-tools.sh` exists and is bash-syntax-clean.
- **AC11:** `make check-tools` target exists in the Makefile.
- **AC12:** `scripts/__tests__/check-tools.bats` exists and passes under `make test-shell`.

### Verification procedure

1. `make test-shell` — bats runs; all 5 new tests pass; `bash -n scripts/check-tools.sh` passes.
2. `cat .mise.toml` — visual check: `[tools]` section present, header comment present, `node = "24.18.0"`, `pnpm = "10.33.0"`.
3. `grep -c volta package.json apps/author-studio/package.json` — both return 0 (no `volta` references).

### Testing

- bats unit tests: 5 cases per design.md §2.11.
- No Docker involvement (mocked PATH via a fake mise on PATH in the test).
- S4 integrity assertions embedded in the 5th test case.

---

## T2 — `Dockerfile.dev` mise install block + `MISE_TRUSTED_CONFIG_PATHS` ENV + smoke probes

**Blockers:** T1
**Vertical slice:** replace the Volta install block in `Dockerfile.dev` with a SHA256-verified mise install block (using the FLAG_B pattern resolved pre-implementation); add `MISE_TRUSTED_CONFIG_PATHS=/workspace` ENV; add three smoke probes in `scripts/test-docker-smoke.sh`.

### What changes

1. **`Dockerfile.dev`** (modified):
   - Remove `ARG VOLTA_VERSION=2.0.2` (line 31).
   - Remove the entire Volta install block (lines 108–118).
   - Insert the mise install block in the same position per design.md §2.4, with the concrete `MISE_VERSION` + SHA256 resolved via flag (b). The install block MUST include `sha256sum -c -` verification — same shape as the uv install block.
   - Add `ENV MISE_TRUSTED_CONFIG_PATHS=/workspace` in the ENV block (S2).
   - Update the header comment (line 5) to list `mise` instead of `Volta`.
2. **`scripts/test-docker-smoke.sh`** (modified):
   - Insert three probes after the existing openspec/make probes (lines 112–122) per design.md §2.9:
     1. `mise --version` presence probe.
     2. `mise install && mise which node` probe (asserts `.mise.toml` resolves under `MISE_TRUSTED_CONFIG_PATHS`).
     3. `MISE_TRUSTED_CONFIG_PATHS` ENV-set probe.

### Acceptance criteria closed

- **AC1:** `Dockerfile.dev` contains no volta install tokens (VOLTA_VERSION, volta-cli, volta-shim, volta-migrate, volta.tar, volta --version). Historical comments (e.g. 'replaces Volta; DIA-030 closure') are acceptable.
- **AC3:** `Dockerfile.dev` contains a mise install block with SHA256 verification.
- **AC5:** `MISE_TRUSTED_CONFIG_PATHS=/workspace` declared as ENV in `Dockerfile.dev`.
- **AC13:** `scripts/test-docker-smoke.sh` probes mise presence, `.mise.toml` resolution, and the ENV var.

### Verification procedure

1. `grep -c -iE 'volta-cli|VOLTA_VERSION|volta-shim|volta-migrate|volta\.tar|volta --version' Dockerfile.dev` — returns 0 (tokens-only per AC1; the sanctioned "replaces Volta" header comment is excluded).
2. `grep -c MISE_VERSION Dockerfile.dev` — returns ≥1 (the ARG declaration).
3. `grep -c sha256sum Dockerfile.dev` — the mise install block contains `sha256sum -c -`.
4. `grep -c MISE_TRUSTED_CONFIG_PATHS Dockerfile.dev` — returns ≥1.
5. `make build` — image builds successfully (requires Docker daemon).
6. `make test-infra` — smoke test runs; the three new probes pass.

### Testing

- Smoke-test probes are integration tests (require running Docker daemon).
- The mise install block is verified indirectly by the smoke test (if the image builds and `mise --version` runs, the install block worked).
- The SHA256 verification is verified at image build time: if the hash does not match, the `docker compose build` fails.

---

## T3 — `tools/opencode-docker` Dockerfile swap + whitelist rename

**Blockers:** T2
**Vertical slice:** apply the same mise install block pattern to `tools/opencode-docker/Dockerfile` (the hardened runtime image); rename the `volta*` entries in the `collect-runtime-deps.sh` invocation whitelist (`tools/opencode-docker/Dockerfile` line ~103). The script itself never had volta entries.

### What changes

1. **`tools/opencode-docker/Dockerfile`** (modified):
   - Remove `ARG VOLTA_VERSION=2.0.2` (line 49) and the Volta install block (lines 48–54).
   - Insert the same mise install block as T2 (the FLAG_B pattern is already resolved; the implementer copies from `Dockerfile.dev`).
2. **`tools/opencode-docker/Dockerfile`** (modified, line ~103 — the `collect-runtime-deps.sh` invocation): rename `volta volta-migrate volta-shim` → `mise` in the runtime dependency whitelist per design.md §2.6. The script itself (`collect-runtime-deps.sh`) never had volta entries.

### Acceptance criteria closed

- **AC2:** `tools/opencode-docker/Dockerfile` contains no volta install tokens (VOLTA_VERSION, volta-cli, volta-shim, volta-migrate, volta.tar, volta --version). Historical comments (e.g. 'replaces Volta; DIA-030 closure') are acceptable.
- **AC4:** `tools/opencode-docker/Dockerfile` contains a SHA256-verified mise install block.
- **AC14:** `tools/opencode-docker/Dockerfile` line ~103 lists `mise` instead of `volta*` in the collect-runtime-deps.sh invocation.

### Verification procedure

1. `grep -c -iE 'volta-cli|VOLTA_VERSION|volta-shim|volta-migrate|volta\.tar|volta --version' tools/opencode-docker/Dockerfile` — returns 0 (tokens-only per AC2; the sanctioned "replaces Volta" header comment is excluded).
2. `sed -n '103p' tools/opencode-docker/Dockerfile | grep -c volta` — returns 0 (the collect-runtime-deps.sh whitelist lists no volta).
3. `grep -c mise tools/opencode-docker/Dockerfile` — returns ≥1 (ARG + install block).
4. `sed -n '103p' tools/opencode-docker/Dockerfile | grep -q mise` — exits 0 (the collect-runtime-deps.sh whitelist lists mise).
5. `bash -n tools/opencode-docker/scripts/collect-runtime-deps.sh` — syntax-clean (caught by `make test-shell` via `bats-wrapper.sh`).

### Testing

- `bash -n` syntax check runs in `make test-shell`.
- The actual opencode-docker image build is out of scope for this change's test gates (no CI); smoke verification is manual (`make -C tools/opencode-docker build` if the implementer has podman).

---

## T4 — Documentation updates

**Blockers:** T1
**Vertical slice:** update all documentation that references Volta to reference mise instead.

### What changes

1. **`docs/onboarding.md`** (modified): mention mise alongside the other dev-container tools if the toolchain narrative lists them (interview finding: Volta was not explicitly mentioned in onboarding.md today, but the tool list should reflect the current state).
2. **`docs/docker-dev.md`** (modified): same treatment — replace any Volta reference with mise.
3. **`docs/dev-infra-audit/inventory.md`** §7 (modified): replace "volta 2.0.2" with "mise <MISE_VERSION>" in the ARG list and the toolchain narrative per design.md §2.12.
4. **`docs/dev-infra-audit/NEXT-RUN.md`** (modified): add a row to the "closed this cycle" table noting the volta→mise migration; point at the DIA-030 archive record.
5. **`docs/dev-infra-audit/tickets/archive/DIA-030.md`** (modified): append a note at the bottom recording that the owner directive (migrate to mise) has been fulfilled by this change. The CLOSED status stays.

### Acceptance criteria closed

- All five documentation files reflect the new toolchain.
- No stale Volta references remain in `docs/`.

### Verification procedure

1. `grep -r -i volta docs/` — returns no matches (except the DIA-030 archive record, which documents the _history_, not the current state).
2. `grep -c mise docs/dev-infra-audit/inventory.md` — returns ≥1 (the new toolchain entry).
3. Manual review of `NEXT-RUN.md` — the new row is present.

### Testing

- No automated tests for documentation changes. Verification is by grep + manual review.

---

## T5 — Full validation gate

**Blockers:** T2, T3, T4
**Vertical slice:** run every gate the project has to confirm the change is green end-to-end. This is the final integration slice.

### What changes

No files are modified in T5 — this task is pure verification.

### Acceptance criteria closed (the full set)

- **AC1–AC14** (all) — re-verified end-to-end.

### Verification procedure

Run in this order (each command MUST exit 0):

1. **`make test-config`** — validates OpenCode JSONC config syntax + interview-enforcement + skill frontmatter. Not affected by this change, but a baseline check.
2. **`make test-shell`** — bats unit tests including the new `check-tools.bats` (5 tests) + the existing 8 suites. `bash -n` over all scripts including `scripts/check-tools.sh` and `tools/opencode-docker/scripts/collect-runtime-deps.sh`.
3. **`openspec validate volta-to-mise`** — validates the OpenSpec change artifacts (proposal.md, design.md, tasks.md) against the `spec-driven` schema.
4. **`pnpm verify`** — runs format, lint, typecheck, JS tests, Python tests. Not affected by this change (no application code changed), but a baseline check.
5. **`make test-infra`** — full Docker smoke test. Asserts the dev image builds, the compose stack starts, and all probes (including the three new mise probes) pass.

> **Deferral record (owner-approved 2026-08-03):** gate 5 `make test-infra` (full compose smoke — 7.85GB rebuild, live 18h stack) is DEFERRED to the next natural rebuild window. Substituted verification performed at implementation: `docker build --check` (EXIT=0) on both Dockerfiles + exact mise RUN block executed in a scratch debian:13-slim container (EXIT=0). Re-review cycle 1/2 accepted the deferral; run `make test-infra` before merge/deploy of this change set.

### Rollback check

If any of the five gates above fails:

1. Inspect the failure.
2. Fix in place if the failure is clearly a mistake in the change (missing file, typo, wrong path).
3. If the failure reveals an unstated assumption (e.g., mise behaves differently than expected under flag-a), update design.md with the new finding and re-run the affected task.
4. If the failure is a regression in an unrelated gate (e.g., `pnpm verify` fails on an unrelated typecheck error), do not fix in this change — open a new ticket and proceed.

After all five gates pass, the change is ready for `@reviewer`.

---

## Summary of file changes

| File                                              | Action | Task                       |
| ------------------------------------------------- | ------ | -------------------------- |
| `.mise.toml`                                      | create | T1                         |
| `package.json`                                    | modify | T1                         |
| `apps/author-studio/package.json`                 | modify | T1                         |
| `scripts/check-tools.sh`                          | create | T1                         |
| `scripts/__tests__/check-tools.bats`              | create | T1                         |
| `scripts/__tests__/bats-wrapper.sh`               | modify | T1                         |
| `Makefile`                                        | modify | T1                         |
| `Dockerfile.dev`                                  | modify | T2                         |
| `scripts/test-docker-smoke.sh`                    | modify | T2                         |
| `tools/opencode-docker/Dockerfile`                | modify | T3                         |
| `docs/onboarding.md`                              | modify | T4                         |
| `docs/docker-dev.md`                              | modify | T4                         |
| `docs/dev-infra-audit/inventory.md`               | modify | T4                         |
| `docs/dev-infra-audit/NEXT-RUN.md`                | modify | T4                         |
| `docs/dev-infra-audit/tickets/archive/DIA-030.md` | modify | T4                         |
| `openspec/changes/volta-to-mise/.openspec.yaml`   | create | T0 (pre-existing scaffold) |
| `openspec/changes/volta-to-mise/proposal.md`      | create | T0 (pre-existing scaffold) |
| `openspec/changes/volta-to-mise/design.md`        | create | T0 (pre-existing scaffold) |
| `openspec/changes/volta-to-mise/tasks.md`         | create | T0 (pre-existing scaffold) |
