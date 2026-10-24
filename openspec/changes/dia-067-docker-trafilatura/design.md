# Design: dia-067-docker-trafilatura

> **Status:** proposed · **Schema:** spec-driven · **skip_specs:** true
> **Dependencies:** proposal.md (✓ complete)
> **Unlocks:** tasks.md

## Context

See proposal.md — §Why and §What Changes for motivation and scope. This design document explains **HOW** to implement the trafilatura Docker tooling, grounded in the ana001 analysis report and the DIA-067 ticket verification plan.

**Current state:** `trafilatura` is absent from the dev container. Agents (specifically `@conspecter` Phase A) cannot invoke it. The host workaround (`/tmp/opencode/venv/bin/trafilatura` v2.2.0) does not bridge into the container.

**Constraints:**

- The tool must be available on PATH for the non-root `dev` user (UID 1000, created at Dockerfile.dev:196-205).
- The install must happen at build time (zero per-run latency — Pattern 1 from ana001 §Systems Thinking).
- The version must be pinned via ARG (deterministic builds — Pattern 4).
- The install must not require `--break-system-packages` if possible (cleaner than the playwright/crawl4ai pattern — Option C advantage over Option A).
- The change must not break `make test-infra` or require structural changes to the Makefile.

## Goals / Non-Goals

**Goals:**

1. **trafilatura available in the dev container** — `docker compose exec -T dev trafilatura --version` returns 2.2.0.
2. **Deterministic version pinning** — `ARG TRAFILATURA_VERSION=2.2.0` in Dockerfile.dev, matching the project's ARG-pin pattern.
3. **Zero per-run latency** — installed at build time, not at container start.
4. **Smoke-test verification** — `test-docker-smoke.sh` asserts trafilatura presence + version.
5. **Clean install (no `--break-system-packages`)** — uv tools install to `~/.local/bin`, isolated from system Python.

**Non-Goals:**

- **Host-side trafilatura install.** OUT of scope (proposal.md §Out of scope). The host workaround remains for host-side scripts.
- **Changes to `dev-entrypoint.sh` or `docker-compose.yml`.** OUT of scope — Option C requires no entrypoint or compose changes.
- **Changes to `@conspecter` invocation pattern.** OUT of scope — trafilatura becomes available on PATH transparently.

## Decisions

### Decision 1: Option C — uv tool install (primary strategy)

**Choice:** `uv tool install trafilatura==${TRAFILATURA_VERSION}` in Dockerfile.dev after uv installation (line 147) and before Rust toolchain (line 149).

**Rationale:**

- **Highest weighted score (9.0/10)** in the ana001 multi-criteria decision analysis — best balance of reproducibility, latency, PEP668 handling, and version pinning.
- **Cleaner than Option A** — no `--break-system-packages` needed (uv tools are isolated to `~/.local/bin`).
- **Aligns with all 5 established patterns** — build-time provisioning, uv for Python tooling, PEP668 handling, one-container architecture, test-infra gates (ana001 §Systems Thinking).
- **Minimal operational change** — `dev-entrypoint.sh` unchanged, `@conspecter` invocation unchanged (`trafilatura -u "<URL>" --output-format markdown`).
- **Version pinning via ARG** — `TRAFILATURA_VERSION=2.2.0` makes updates explicit and reviewable (same pattern as `UV_VERSION`, `RUST_VERSION`, `MISE_VERSION`, `SNIP_VERSION`).
- **Disk size efficient** — ~30-50MB (smaller than system-wide install per ana001 §Option C Pros).

**Alternatives considered (ana001 §Decision Matrix):**

- **Option A (bake into image via `uv pip install --system --break-system-packages`):** 8.7/10 — strong alternative, identical reproducibility, but uses `--break-system-packages` (less clean). Reserved as fallback.
- **Option B (venv per run):** 6.5/10 — rejected due to per-run latency, non-determinism, deviation from build-time provisioning pattern.
- **Option D (separate container):** 5.8/10 — rejected due to operational complexity, architecture violation (one-container principle), test-infra breakage.
- **Option E (mise Python plugin):** 7.0/10 — rejected due to maturity concerns and unnecessary complexity (uv already established).
- **Option F (apt package):** 8.0/10 — not recommended unless verified available in Debian 13 repos (likely PyPI-only).

### Decision 2: Dockerfile placement — between uv install (line 147) and Rust toolchain (line 149)

**Choice:** Insert the `ARG TRAFILATURA_VERSION=2.2.0` and `RUN uv tool install ...` block at line 148 (after `uv --version` at line 147, before `# === Rust toolchain` comment at line 149).

**Rationale:**

- **uv must be installed first** — `uv tool install` requires the `uv` binary on PATH. The uv install completes at line 147 (`uv --version`).
- **Before Rust toolchain** — logical grouping: Python tooling (uv, trafilatura) before Rust tooling. The Rust toolchain (lines 149-172) is a separate concern.
- **Before non-root user creation (line 196)** — `uv tool install` runs as root during build, installs to `/root/.local/bin` by default. BUT: uv tools install to the invoking user's `~/.local/bin`. Since the Dockerfile runs as root until `USER ${USER_UID}:${USER_GID}` at line 227, the tool installs to `/root/.local/bin` — which is NOT on the dev user's PATH.

**CRITICAL ISSUE (discovered during design):** uv tools install to `~/.local/bin` of the invoking user. In the Dockerfile, `uv tool install` runs as root → installs to `/root/.local/bin`. The non-root `dev` user (UID 1000) has `HOME=/home/dev` (line 207), so `/root/.local/bin` is NOT on the dev user's PATH.

**Resolution options:**

1. **Install as the dev user** — defer the `uv tool install` to after the `USER ${USER_UID}:${USER_GID}` switch (after line 227). But this means the install runs at container start, not build time — violates Pattern 1 (build-time provisioning).
2. **Install as root, copy to dev user's home** — `uv tool install` as root, then `cp -r /root/.local /home/dev/` + `chown -R dev:dev /home/dev/.local`. Adds complexity but preserves build-time install.
3. **Set UV_TOOL_DIR env var** — uv respects `UV_TOOL_DIR` (or `XDG_BIN_HOME`). Set `ENV UV_TOOL_BIN_DIR=/usr/local/bin` before the install, so uv tools install to a system-wide location on PATH. Cleanest option.
4. **Use `uv pip install --system` (Option A fallback)** — installs to system Python site-packages, on PATH for all users. Uses `--break-system-packages` but avoids the user-scope issue entirely.

**Developer decision required:** Option 3 (set `UV_TOOL_BIN_DIR=/usr/local/bin`) is recommended as the cleanest resolution. If the developer prefers Option 4, fall back to the `uv pip install --system --break-system-packages` pattern (playwright/crawl4ai precedent). This is flagged as an **OPEN QUESTION** in the interview transcript below.

**Alternatives considered (placement):**

- **After non-root user creation (line 205+):** rejected — runs at container start, not build time.
- **After playwright/crawl4ai (line 189+):** rejected — logical grouping issue (Python tooling should be together before the non-root user switch).

### Decision 3: Smoke-test probe — version assertion

**Choice:** Add a trafilatura probe to `scripts/test-docker-smoke.sh` following the openspec version probe pattern (lines 118-128):

```bash
echo "-> verifying trafilatura (DIA-067: source-capture for @conspecter)..."
traf_ver="$(docker compose exec -T dev trafilatura --version 2>&1)"
if [[ "$traf_ver" != *"2.2.0"* ]]; then
  echo "error: trafilatura --version is '$traf_ver', expected 2.2.0" >&2
  exit 1
fi
echo "ok: trafilatura ${traf_ver}"
```

**Rationale:**

- **Exact same shape** as the openspec probe (line 121-126): `docker compose exec -T dev <tool> --version` + version-string assertion + `echo "ok: <tool> ${ver}"`.
- **Version assertion** catches the case where trafilatura is installed but at the wrong version (e.g., a different `TRAFILATURA_VERSION` ARG).
- **Probe placement** — after the openspec/make probe (line 118-128) and before the mise probe (line 131). Logical grouping: tooling probes together.

**Alternatives considered:**

- **No version assertion (presence-only):** rejected — the openspec probe established that version assertion is the pattern (1.7.0 pin caught version drift).
- **Probe in a separate script:** rejected — the smoke test is the established integration test for Docker tooling; adding a separate script would fragment the test surface.

### Decision 4: No Makefile changes

**Choice:** Do NOT modify the Makefile. `make test-infra` already runs `test-docker-smoke.sh`, which will include the trafilatura probe after this change.

**Rationale:**

- **`test-infra: gen-jsconfig test-shell` → `bash scripts/test-docker-smoke.sh`** (Makefile line 122-123). The smoke test is already wired in.
- **Adding a new Makefile target** would fragment the test surface — the smoke test is the established pattern for Docker tooling verification.

**Alternatives considered:**

- **New `test-trafilatura` target:** rejected — unnecessary fragmentation; the smoke test already covers it.

## Seams (pre-agreed public boundaries where tests will live)

**Confirmed with developer before any test is written:**

### Seam 1: Smoke-test probe

**Boundary:** `scripts/test-docker-smoke.sh` runs `docker compose exec -T dev trafilatura --version` and asserts the output contains `2.2.0`.

**Contract:**

```bash
# In test-docker-smoke.sh (after the openspec probe, before the mise probe):
echo "-> verifying trafilatura (DIA-067: source-capture for @conspecter)..."
traf_ver="$(docker compose exec -T dev trafilatura --version 2>&1)"
if [[ "$traf_ver" != *"2.2.0"* ]]; then
  echo "error: trafilatura --version is '$traf_ver', expected 2.2.0" >&2
  exit 1
fi
echo "ok: trafilatura ${traf_ver}"
```

**Test usage:**

```bash
# Run the full smoke test:
make test-infra
# Or run just the smoke test script:
bash scripts/test-docker-smoke.sh
```

### Seam 2: Dockerfile build-time verification

**Boundary:** The Dockerfile's `RUN uv tool install trafilatura==${TRAFILATURA_VERSION} && trafilatura --version` step itself is the first test — if the install fails, the build fails.

**Contract:**

```dockerfile
# In Dockerfile.dev (after uv install, before Rust toolchain):
ARG TRAFILATURA_VERSION=2.2.0
RUN uv tool install trafilatura==${TRAFILATURA_VERSION} && \
    trafilatura --version
```

**Test usage:**

```bash
# Build the image — the install step runs automatically:
docker compose build dev
# Or:
make build
```

## Risks / Trade-offs

### Risk 1: uv tool install scope (root vs dev user) — CRITICAL

**Risk:** `uv tool install` runs as root during build → installs to `/root/.local/bin`. The non-root `dev` user has `HOME=/home/dev`, so `/root/.local/bin` is NOT on the dev user's PATH. The smoke-test probe would fail with `trafilatura: command not found`.

**Mitigation:** Set `ENV UV_TOOL_BIN_DIR=/usr/local/bin` before the `uv tool install` step. This tells uv to install tool binaries to `/usr/local/bin`, which is on PATH for all users (including the dev user). The tool's Python dependencies still install to uv's internal isolated environment (no system Python pollution).

**Alternative mitigation:** Use `uv pip install --system --break-system-packages` (Option A) — installs to system Python site-packages, on PATH for all users. This is the fallback if `UV_TOOL_BIN_DIR` doesn't work as expected.

**Trade-off:** `UV_TOOL_BIN_DIR` is a uv-specific env var; if uv changes this behavior in a future version, the install may break. The fallback (Option A) is more robust (system Python site-packages is a stable target) but less clean (`--break-system-packages`).

**Detection:** The smoke-test probe catches this immediately — if trafilatura is not on PATH for the dev user, `docker compose exec -T dev trafilatura --version` fails.

**Recovery cost:** Low — change the Dockerfile to use Option A (`uv pip install --system --break-system-packages`), rebuild.

### Risk 2: trafilatura dependency conflicts

**Risk:** `trafilatura` has many dependencies (lxml, httpx, urllib3, certifi, etc.). A dependency conflict with existing system Python packages could cause the install to fail.

**Mitigation (Option C):** uv tools are isolated — they install to their own virtual environment, not the system Python. Dependency conflicts with system packages are not possible.

**Mitigation (Option A fallback):** `--break-system-packages` allows the install to proceed even if there are conflicts. If a conflict causes runtime breakage, the fallback is to use a venv (Option B) — but this was rejected for per-run latency.

**Detection:** Docker build fails at the `uv tool install` step (Option C) or at runtime (Option A).

**Recovery cost:** Low (Option C) — the build fails fast, developer investigates the dependency conflict. Medium (Option A) — runtime breakage may be harder to diagnose.

### Risk 3: Version pin drift

**Risk:** The `TRAFILATURA_VERSION=2.2.0` ARG may drift from the actual installed version if the Dockerfile is edited manually.

**Mitigation:** The `RUN uv tool install trafilatura==${TRAFILATURA_VERSION}` step pins the version at install time. The smoke-test probe asserts the installed version matches `2.2.0`. If the ARG is changed but the probe is not updated, the smoke test fails.

**Trade-off:** The probe hardcodes `2.2.0` rather than reading from the ARG. This is intentional — the probe is a runtime assertion, not a build-time assertion. If the ARG changes, the probe must be updated manually. This is the same pattern as the openspec probe (hardcodes `1.7.0`).

### Risk 4: Disk size impact

**Risk:** trafilatura + dependencies add ~30-50MB to the image (ana001 §Option C Pros).

**Mitigation:** Acceptable for a dev image (already large due to Rust, Playwright, Chromium). The dev image is not deployed to production; disk size is a secondary concern.

**Trade-off:** Option A (system-wide install) adds ~50-100MB; Option C (uv tool) adds ~30-50MB. Option C is slightly more efficient.

## Migration Plan

**Deployment:**

1. Merge the PR with the Dockerfile change + smoke-test probe.
2. `docker compose build dev` — builds the image with trafilatura installed.
3. `make test-infra` — runs the smoke test, asserts trafilatura is present + version 2.2.0.
4. Re-dispatch `@conspecter` — all 11 `sources/*.md` files > 0 bytes.

**Rollback:**

1. `git revert <commit>` — removes the Dockerfile lines + smoke-test probe.
2. `docker compose build dev` — rebuilds the image without trafilatura.
3. No application code is touched. No config files are modified.
4. Rollback is a single `git revert`.

**Fallback (Option A):**

If Option C (`uv tool install`) fails at build time:

1. Replace `RUN uv tool install trafilatura==${TRAFILATURA_VERSION}` with `RUN uv pip install --system --break-system-packages trafilatura==${TRAFILATURA_VERSION}`.
2. Remove the `ENV UV_TOOL_BIN_DIR=/usr/local/bin` line (not needed for Option A).
3. Rebuild the image.
4. The smoke-test probe remains unchanged (still asserts `trafilatura --version` contains `2.2.0`).

## Open Questions

### OPEN QUESTION 1: uv tool install scope (root vs dev user)

**Question:** Does `uv tool install` as root install to `/root/.local/bin` (root's home) or does it respect `UV_TOOL_BIN_DIR`? If the former, we need to set `ENV UV_TOOL_BIN_DIR=/usr/local/bin` before the install. If the latter, the install works as-is.

**Recommendation:** Set `ENV UV_TOOL_BIN_DIR=/usr/local/bin` before the install — this is the safest option and ensures the tool is on PATH for all users. If this doesn't work, fall back to Option A (`uv pip install --system --break-system-packages`).

**Developer decision required:** Confirm the recommended approach (UV_TOOL_BIN_DIR) or choose Option A fallback.

### OPEN QUESTION 2: Probe placement in test-docker-smoke.sh

**Question:** Where exactly should the trafilatura probe be placed in `test-docker-smoke.sh`? Recommended: after the openspec/make probe (line 128) and before the mise probe (line 131). Alternative: after the language-server probes (line 207) and before the postgres probe (line 209).

**Recommendation:** After the openspec/make probe (line 128) — logical grouping with other tooling probes.

**Developer decision required:** Confirm probe placement.

## References

- **Source ticket:** `docs/dev-infra-audit/tickets/DIA-067.md`
- **Strategy analysis:** `knowledge/ana001-docker-trafilatura-strategy/ana001-docker-trafilatura-strategy-report.md` (Option C recommended, 9.0/10)
- **Immediate prior art (Dockerfile pattern):** `Dockerfile.dev` lines 174-189 (playwright/crawl4ai install via uv pip)
- **Immediate prior art (smoke-test pattern):** `scripts/test-docker-smoke.sh` lines 118-128 (openspec version probe)
- **uv documentation:** https://docs.astral.sh/uv/reference/settings/#tool-bin-dir (UV_TOOL_BIN_DIR env var)
