# Proposal: dia-067-docker-trafilatura

> **Status:** proposed · **Scope:** dev-infra (`Dockerfile.dev`, `scripts/test-docker-smoke.sh`). No application code touched.
> **Escalation:** none — change stays within existing module boundaries (Docker tooling layer). Per AGENTS.md §2.4 (dev-infra within existing boundaries → spec chain + `@reviewer`), no `@architector` dispatch is required.
> **Source ticket:** `docs/dev-infra-audit/tickets/DIA-067.md` (agents inside docker dev environment cannot invoke `trafilatura`). Strategy decision: ana001 analysis report (`knowledge/ana001-docker-trafilatura-strategy/ana001-docker-trafilatura-strategy-report.md`), developer-approved Option C (uv tool install, 9.0/10).

## Why

The `@conspecter` Phase A source-capture pipeline requires the `trafilatura` CLI to archive URLs into markdown. Inside the dev container, `trafilatura` is absent (`command not found`). The host workaround (`/tmp/opencode/venv/bin/trafilatura` v2.2.0 via PEP668 get-pip.py bootstrap) does not bridge into the container where agents execute. This blocks the res003 persistence pipeline (research-pipeline skill → conspecter Phase A → Phase B conspect → memory-shelf registration) under `knowledge/res003-tool-enumeration/`.

**Why now:** DIA-067 was discovered 2026-08-08 when conspecter (con-1, ses_02110793fffeKFqhWUcZSiXLYI) twice attempted Phase A — all 11 source files created EMPTY (0 bytes). The ana001 container-strategy analysis has been completed and developer-approved. The implementation is a 2-line Dockerfile change + 1 smoke-test probe, following the established playwright/crawl4ai precedent exactly.

## What Changes

1. **`Dockerfile.dev`** — add trafilatura as a uv tool install between the existing uv installation (line 147) and the Rust toolchain (line 149):

   ```dockerfile
   # After uv installation (line 147) and before Rust toolchain (line 149)
   ARG TRAFILATURA_VERSION=2.2.0
   RUN uv tool install trafilatura==${TRAFILATURA_VERSION} && \
       trafilatura --version
   ```

   - **Option C (uv tool install):** installs to `~/.local/bin` (isolated from system Python, no `--break-system-packages` needed). uv tools are on PATH automatically for the dev user. Version pinned via `ARG` for deterministic builds and explicit reviewability.
   - **Fallback Option A (bake into image):** if `uv tool install` fails (dependency conflict, missing system library), fall back to `uv pip install --system --break-system-packages trafilatura==${TRAFILATURA_VERSION}` — the existing playwright/crawl4ai pattern at line 186.

2. **`scripts/test-docker-smoke.sh`** — add a trafilatura presence probe (follows the `openspec --version` and `playwright --version` probe patterns):
   ```bash
   echo "-> verifying trafilatura (DIA-067: source-capture for @conspecter)..."
   traf_ver="$(docker compose exec -T dev trafilatura --version 2>&1)"
   if [[ "$traf_ver" != *"2.2.0"* ]]; then
     echo "error: trafilatura --version is '$traf_ver', expected 2.2.0" >&2
     exit 1
   fi
   echo "ok: trafilatura ${traf_ver}"
   ```

## Scope (interview-confirmed)

### In scope

- **Dockerfile.dev trafilatura install** via `uv tool install` (Option C, ana001 report §Recommendation).
- **Version pinning** via `ARG TRAFILATURA_VERSION=2.2.0` (matches the project's ARG-pin pattern: `UV_VERSION`, `RUST_VERSION`, `MISE_VERSION`, `SNIP_VERSION`, etc.).
- **Smoke-test probe** in `test-docker-smoke.sh` asserting `trafilatura --version` contains `2.2.0` (follows the `openspec --version` probe pattern at line 121-126).
- **Fallback documentation** in design.md noting Option A as the recovery path if Option C fails at build time.

### Out of scope (explicitly deferred — interview-confirmed)

- **Host-side trafilatura install.** OUT of scope per DIA-067 ticket §Verification step 3 (`which trafilatura` host-side — expected absent). The host workaround remains for host-side scripts that need trafilatura outside the container; this change closes the container gap only.
- **Changes to `dev-entrypoint.sh`.** OUT of scope — Option C requires no entrypoint changes (uv tools install to `~/.local/bin`, already on PATH for the dev user).
- **Changes to `docker-compose.yml`.** OUT of scope — no new containers, no new volumes, no new secrets. The one-container architecture (docker-compose.yml:3-6) is preserved.
- **Changes to `@conspecter` invocation pattern.** OUT of scope — trafilatura becomes available on PATH, so `trafilatura -u "<URL>" --output-format markdown` works without wrapper scripts.
- **`make test-infra` structural changes.** OUT of scope — the smoke-test probe is additive within the existing `test-docker-smoke.sh` flow; `make test-infra` already builds the image and runs the smoke test, so no Makefile changes are needed.
- **Any `.sdd/` module doc authoring.** See Design authority section below.
- **Anything beyond the Dockerfile change + smoke-test probe.**

## Design authority (.sdd/) reference

**No `.sdd/` module doc governs this change.** The `.sdd/` directory contains only `.sdd/dia-redispatch-cycle/architecture.md` (DIA cycle protocol) and `.sdd/README.md`. Neither `Dockerfile.dev` nor `scripts/test-docker-smoke.sh` have an `.sdd/` entry.

This is the same precedent as `openspec/changes/dia-066-tool-coverage-audit/proposal.md` §Design authority, `openspec/changes/dev-infra-config-validators/proposal.md` §Design authority, and `openspec/changes/volta-to-mise/proposal.md` §Design authority: bounded dev-infra within existing boundaries does not require architectural escalation. Per AGENTS.md §3, the absence of a governing `.sdd/` is a documentation gap, but one this change does not fill.

**Relevant existing patterns this change follows:**

- **uv for Python tooling** — Dockerfile.dev:186 uses `uv pip install --system --break-system-packages playwright crawl4ai`. uv is the established Python tool manager. Option C (`uv tool install`) aligns perfectly and is cleaner (no `--break-system-packages`).
- **ARG-pinned versions** — `UV_VERSION=0.11.29`, `RUST_VERSION=1.83.0`, `MISE_VERSION=2026.8.0`, `SNIP_VERSION=0.22.0`, etc. `TRAFILATURA_VERSION=2.2.0` follows the same pattern.
- **Build-time provisioning** — Dockerfile.dev installs all tools at build time. No tool is installed at run time. Option C aligns (zero per-run latency).
- **Smoke-test probe pattern** — `docker compose exec -T dev <tool> --version` + version-string assertion + `echo "ok: <tool> ${ver}"`. Exact same shape as the openspec (line 121-126), playwright (line 102), and language-server (line 202-207) probes.
- **One dev workstation container** — docker-compose.yml:3-6. Option C adds a tool to the existing container; Option D (separate container) was rejected by ana001 for violating this principle.

## Testing Decisions

**What makes a good test for this change:**

1. **Build-time verification:** the Dockerfile's `RUN uv tool install trafilatura==${TRAFILATURA_VERSION} && trafilatura --version` step itself is the first test — if the install fails, the build fails (fail-fast at the earliest possible point).
2. **Runtime smoke-test probe:** `test-docker-smoke.sh` asserts `trafilatura --version` returns `2.2.0` inside the running container. This catches the case where the build succeeds but the binary is not on PATH for the dev user (e.g., `~/.local/bin` not in PATH).
3. **No unit tests needed:** this is a tool-install change, not a code change. There is no business logic to unit-test. The bats test suite (`scripts/__tests__/`) does not test Dockerfile contents — that is the smoke test's role.

**Modules tested:**

- `Dockerfile.dev` — the `uv tool install` step (via Docker build + smoke-test probe).
- `scripts/test-docker-smoke.sh` — the trafilatura probe (verified by running `make test-infra`).

**Prior art:**

- `scripts/test-docker-smoke.sh` lines 118-128 — the openspec version probe (exact same shape: `docker compose exec -T dev <tool> --version` + version-string assertion).
- `scripts/test-docker-smoke.sh` lines 99-116 — the playwright/crawl4ai probe (same tool-install verification pattern).

**Test seams (confirmed with developer before any test is written):**

- **Seam 1: Smoke-test probe.** The probe runs `docker compose exec -T dev trafilatura --version` and asserts the output contains `2.2.0`. If the install succeeded but the binary is not on PATH, the probe fails with a clear error message pointing to the Dockerfile.

## Success criteria

1. **`docker compose build dev` succeeds** with the new `uv tool install trafilatura==2.2.0` step. The build log shows `trafilatura --version` output (version 2.2.0).
2. **`docker compose exec -T dev trafilatura --version` returns `2.2.0`** (or contains `2.2.0`). The binary is on PATH for the non-root `dev` user.
3. **`make test-infra` exits 0** — the smoke-test probe passes as part of the standard test-infra flow.
4. **`@conspecter` Phase A works end-to-end** — re-dispatch conspecter for the 11 source URLs; all `sources/*.md` files > 0 bytes.
5. **No changes to `dev-entrypoint.sh`, `docker-compose.yml`, or `@conspecter` invocation pattern** — the tool is simply available on PATH.
6. **Host-side `which trafilatura` remains absent** (DIA-067 ticket §Verification step 3 — documents the gap is closed inside the container, not on the host).

## Rollback plan

The change is low-risk and fully reversible:

1. **Remove the Dockerfile lines:** delete the `ARG TRAFILATURA_VERSION=2.2.0` and `RUN uv tool install ...` block from Dockerfile.dev.
2. **Remove the smoke-test probe:** delete the trafilatura probe block from `scripts/test-docker-smoke.sh`.
3. **Rebuild the image:** `docker compose build dev` (without the trafilatura step).

No application code is touched. No config files are modified. No entrypoint or compose changes. Rollback is a single `git revert`.

**Fallback (Option A):** if `uv tool install` fails at build time (dependency conflict, missing system library), replace the `uv tool install` line with `uv pip install --system --break-system-packages trafilatura==${TRAFILATURA_VERSION}` (the playwright/crawl4ai pattern). Same `ARG`, same probe, same rollback shape. Recovery cost: change one Dockerfile line, rebuild.

## References

- **Source ticket:** `docs/dev-infra-audit/tickets/DIA-067.md`
- **Strategy analysis:** `knowledge/ana001-docker-trafilatura-strategy/ana001-docker-trafilatura-strategy-report.md` (Option C recommended, 9.0/10; Option A fallback, 8.7/10)
- **Immediate prior art (Dockerfile pattern):** `Dockerfile.dev` lines 174-189 (playwright/crawl4ai install via uv pip)
- **Immediate prior art (smoke-test pattern):** `scripts/test-docker-smoke.sh` lines 118-128 (openspec version probe)
- **OpenSpec change pattern:** `openspec/changes/dia-066-tool-coverage-audit/` (same shape: dev-infra, `skip_specs: true`, single-module)
- **Conspecter invocation evidence:** `ses_02110793fffeKFqhWUcZSiXLYI` (con-1, Phase A ×2 attempts, 11 source files EMPTY 0B)
