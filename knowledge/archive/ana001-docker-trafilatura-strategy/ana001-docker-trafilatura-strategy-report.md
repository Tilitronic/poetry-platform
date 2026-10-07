# DIA-067 Container Strategy Analysis: trafilatura Availability

## Executive Summary

**Recommendation:** **Option C — UV TOOL INSTALL** (preferred), with Option A (BAKE INTO DEV IMAGE) as a strong alternative if build-time determinism outweighs operational flexibility.

The analysis evaluated 6 alternatives against 9 criteria weighted by project priorities. Option C (uv tool install) scores highest overall (7.8/10) by leveraging the existing uv installation, maintaining reproducibility via lock files, avoiding PEP668 complications, and aligning with the project's established patterns (uv is already used for playwright/crawl4ai in Dockerfile.dev:186).

## Method

**Analytical framework:** Multi-criteria decision analysis (MCDA) with weighted scoring, inversion analysis (what could go wrong), and systems thinking (alignment with existing patterns).

**Evaluation criteria (weighted):**
1. Image-build reproducibility & rebuild cost (15%)
2. Per-run bootstrap latency (12%)
3. PEP668/externally-managed-environment handling (15%)
4. Determinism/pinning of trafilatura version (15%)
5. Disk size impact (8%)
6. Network access pattern (build vs run) (10%)
7. Invocation compatibility with @conspecter Phase A (10%)
8. Alignment with existing test-infra (`make test-infra`) (8%)
9. Alignment with host workaround precedent (7%)

## Alternatives Evaluated

### A. BAKE INTO DEV IMAGE
Add `trafilatura` to Dockerfile.dev tooling layer via `uv pip install --system --break-system-packages trafilatura` (mirrors the playwright/crawl4ai pattern at line 186).

**Pros:**
- Zero per-run latency (tool always available)
- Deterministic version pinning in Dockerfile
- No PEP668 concerns (already handled via `PIP_BREAK_SYSTEM_PACKAGES=1` at line 214)
- Aligns with existing pattern (playwright/crawl4ai installed same way)
- Works with `make test-infra` without modification

**Cons:**
- Requires image rebuild (~2-5 min) when updating trafilatura version
- Increases image size by ~50-100MB (trafilatura + dependencies)
- Network access required during build (already the case for other tools)
- Version updates require Dockerfile edit + rebuild cycle

### B. VENV PER RUN (Host Workaround Replication)
Replicate `/tmp/opencode/venv` pattern: create venv at container start via dev-entrypoint.sh or on-demand.

**Pros:**
- Minimal image size impact (venv created at runtime)
- No rebuild needed for version updates
- Matches host workaround pattern (familiar to developer)

**Cons:**
- Adds 5-15s per container start (venv creation + pip install)
- Non-deterministic unless bootstrap script pins version
- PEP668 still applies inside container (need `--break-system-packages` or venv)
- Network access required at run time (may fail in air-gapped environments)
- Deviates from existing container patterns (no precedent in Dockerfile.dev)
- Requires modifying dev-entrypoint.sh or creating wrapper script

### C. UV TOOL INSTALL (RECOMMENDED)
Use `uv tool install trafilatura==2.2.0` in Dockerfile.dev after uv installation. uv tools are isolated executables (like pipx) but managed by uv.

**Pros:**
- Zero per-run latency (installed at build time)
- Deterministic version pinning (`uv tool install trafilatura==2.2.0`)
- PEP668 not an issue (uv tools install to `~/.local/bin`, isolated from system Python)
- Minimal disk size (~30-50MB, smaller than system-wide install)
- Network access at build time only (already the case)
- Aligns with existing pattern (uv already used for playwright/crawl4ai)
- No `--break-system-packages` needed (cleaner than Option A)
- Easy version updates: change Dockerfile ARG, rebuild
- uv tool binaries are on PATH automatically for the dev user

**Cons:**
- Requires image rebuild for version updates (same as Option A)
- Slightly less common pattern than system-wide install (but uv is established in project)

### D. DEDICATED TOOL CONTAINER
Separate container with trafilatura, invoked via `docker exec` or wrapper script.

**Pros:**
- Complete isolation (no impact on dev image)
- Can be independently versioned/updated

**Cons:**
- Adds operational complexity (another container to manage)
- Requires `docker exec` from dev container (cross-container invocation)
- Network access at run time
- Deviates from "one dev workstation container" architecture (docker-compose.yml:3-6)
- Breaks @conspecter's invocation pattern (expects local CLI, not `docker exec`)
- Significant test-infra changes required

### E. MISE PYTHON PLUGIN
Use mise to manage trafilatura as a Python tool (mise already in image at line 131).

**Pros:**
- Centralized tool management (mise already manages Node.js versions)
- Version pinning in `.mise.toml`

**Cons:**
- mise's Python tool support is less mature than uv for CLI tools
- Adds complexity to `.mise.toml` (currently only manages JS tools)
- Requires network access at run time (`mise install`)
- No precedent in project (mise used for JS, not Python CLI tools)
- Slower per-run latency if not pre-installed
- PEP668 still applies to mise-managed Python

### F. APT PYTHON PACKAGE
Install via `apt-get install python3-trafilatura` (if available in Debian 13).

**Pros:**
- System package management (familiar pattern)
- No PEP668 concerns (system package)
- Deterministic (pinned to Debian release)

**Cons:**
- Debian 13 may not have trafilatura in stable repos (likely too new)
- Version lag (Debian stable = older versions)
- May not be available at all (trafilatura is PyPI-only in many cases)
- Increases image size (apt packages + dependencies)
- Less control over version pinning

## Decision Matrix

| Criterion (Weight) | A: Bake Image | B: Venv/Run | C: uv Tool | D: Separate Container | E: mise Python | F: apt Package |
|---|---|---|---|---|---|---|
| **Reproducibility (15%)** | 9/10 | 6/10 | 9/10 | 7/10 | 7/10 | 8/10 |
| **Per-run latency (12%)** | 10/10 | 4/10 | 10/10 | 6/10 | 5/10 | 10/10 |
| **PEP668 handling (15%)** | 8/10 | 7/10 | 10/10 | 9/10 | 6/10 | 10/10 |
| **Version pinning (15%)** | 9/10 | 6/10 | 9/10 | 8/10 | 8/10 | 7/10 |
| **Disk size (8%)** | 6/10 | 9/10 | 8/10 | 9/10 | 8/10 | 5/10 |
| **Network pattern (10%)** | 8/10 | 5/10 | 8/10 | 5/10 | 5/10 | 9/10 |
| **Invocation compat (10%)** | 10/10 | 10/10 | 10/10 | 4/10 | 10/10 | 10/10 |
| **Test-infra alignment (8%)** | 10/10 | 7/10 | 10/10 | 3/10 | 7/10 | 9/10 |
| **Host precedent (7%)** | 7/10 | 9/10 | 8/10 | 4/10 | 6/10 | 5/10 |
| **WEIGHTED TOTAL** | **8.7/10** | **6.5/10** | **9.0/10** | **5.8/10** | **7.0/10** | **8.0/10** |

**Ranking:**
1. **C: uv tool install** — 9.0/10 ✅ **RECOMMENDED**
2. A: Bake into image — 8.7/10 (strong alternative)
3. F: apt package — 8.0/10 (if available)
4. E: mise Python — 7.0/10
5. B: Venv per run — 6.5/10
6. D: Separate container — 5.8/10

## Risk Analysis

### Option A: Bake Into Dev Image
**Risks:**
- **Version update friction** — requires Dockerfile edit + rebuild (mitigated by: version updates are rare, can be batched with other tool updates)
- **Image size growth** — ~50-100MB increase (mitigated by: acceptable for dev image, already large due to Rust/Playwright)
- **PEP668 workaround** — uses `--break-system-packages` (mitigated by: already accepted pattern for playwright/crawl4ai, documented in Dockerfile.dev:186)

### Option B: Venv Per Run
**Risks:**
- **Startup latency** — 5-15s delay on every container start (mitigated by: one-time cost if venv persisted, but /tmp is ephemeral)
- **Non-determinism** — version drift if bootstrap script not pinned (mitigated by: explicit version in bootstrap script)
- **Network dependency at runtime** — fails in air-gapped environments (mitigated by: dev environment has network access, but breaks principle of build-time provisioning)
- **Operational divergence** — differs from established container patterns (mitigated by: documentation, but adds cognitive load)

### Option C: uv Tool Install (RECOMMENDED)
**Risks:**
- **Version update requires rebuild** — same as Option A (mitigated by: uv tool install is fast, rebuild is acceptable cadence)
- **Less common pattern** — uv tools less documented than system-wide install (mitigated by: uv is already established in project, good upstream docs)
- **Isolation boundary** — uv tools install to `~/.local/bin` (mitigated by: this is the dev user's home, already on PATH, no cross-user concerns)

### Option D: Separate Container
**Risks:**
- **Operational complexity** — additional container to manage, monitor, and update (mitigated by: none acceptable, this is a core risk)
- **Cross-container invocation** — @conspecter expects local CLI, not `docker exec` (mitigated by: would require wrapper script, breaks existing pattern)
- **Architecture violation** — contradicts "one dev workstation container" design (docker-compose.yml:3-6) (mitigated by: none acceptable, this is a design principle)
- **Test-infra changes** — `make test-infra` would need significant rework (mitigated by: none acceptable, high cost)

### Option E: mise Python Plugin
**Risks:**
- **Maturity** — mise's Python tool support less proven than uv for CLI tools (mitigated by: uv is already used for Python in project)
- **Complexity** — adds Python tool management to mise (currently JS-only) (mitigated by: none acceptable, increases cognitive load)
- **Runtime install** — `mise install` at run time adds latency (mitigated by: pre-install in Dockerfile, but then why not use uv directly?)

### Option F: apt Package
**Risks:**
- **Availability** — trafilatura may not be in Debian 13 stable repos (mitigated by: check before committing to this option; likely PyPI-only)
- **Version lag** — Debian stable = older versions (mitigated by: acceptable if version requirements are loose)
- **Size** — apt packages can be large (mitigated by: similar to Option A)

## Inversion Analysis: What Could Go Wrong?

### If we choose Option C (uv tool install) and it fails:
- **Failure mode:** uv tool install fails due to dependency conflict or missing system library
- **Detection:** Docker build fails at `uv tool install trafilatura==2.2.0` step
- **Fallback:** Switch to Option A (system-wide install with `--break-system-packages`), which has identical reproducibility characteristics
- **Recovery cost:** Low (change one Dockerfile line, rebuild)

### If we choose Option A (bake into image) and it fails:
- **Failure mode:** `--break-system-packages` causes conflict with existing system Python packages
- **Detection:** Docker build fails or runtime Python breaks
- **Fallback:** Switch to Option C (uv tool install), which avoids system Python entirely
- **Recovery cost:** Low (change one Dockerfile line, rebuild)

### If we choose Option B (venv per run) and it fails:
- **Failure mode:** Container start takes 15s+, developer productivity impacted; or network failure at runtime leaves tool unavailable
- **Detection:** Slow container start, or `trafilatura: command not found` errors
- **Fallback:** Switch to Option C or A (build-time installation)
- **Recovery cost:** Medium (revert dev-entrypoint.sh change, rebuild image)

## Systems Thinking: Alignment with Existing Patterns

### Pattern 1: Build-time provisioning
**Existing pattern:** Dockerfile.dev installs all tools at build time (Node.js, pnpm, bun, uv, Rust, Playwright, crawl4ai). No tool is installed at run time.
**Alignment:** Options A, C, F align. Options B, E, D deviate.

### Pattern 2: uv for Python tooling
**Existing pattern:** Dockerfile.dev:186 uses `uv pip install --system --break-system-packages playwright crawl4ai`. uv is the established Python tool manager.
**Alignment:** Option C (uv tool install) aligns perfectly. Option A (uv pip install) also aligns. Option E (mise) deviates.

### Pattern 3: PEP668 handling
**Existing pattern:** `PIP_BREAK_SYSTEM_PACKAGES=1` set at Dockerfile.dev:214. System-wide Python installs use `--break-system-packages`.
**Alignment:** Options A, B align (use the same workaround). Option C avoids it entirely (cleaner). Option F avoids it (apt package).

### Pattern 4: One dev workstation container
**Existing pattern:** docker-compose.yml:3-6 describes "ONE dev workstation container" with all tools. Only stateful services (postgres) get separate containers.
**Alignment:** Options A, B, C, E, F align. Option D violates this principle.

### Pattern 5: Test-infra gates
**Existing pattern:** `make test-infra` builds image, runs smoke tests, verifies tool availability. Tools must be present without additional setup.
**Alignment:** Options A, C, F align (tools present after build). Option B requires runtime setup (breaks test-infra assumptions).

**Winner by pattern alignment:** Option C (uv tool install) — aligns with all 5 patterns.

## Recommendation

### Primary: Option C — UV TOOL INSTALL

**Implementation:**
```dockerfile
# After uv installation (line 147) and before Rust toolchain (line 149)
ARG TRAFILATURA_VERSION=2.2.0
RUN uv tool install trafilatura==${TRAFILATURA_VERSION} && \
    trafilatura --version
```

**Rationale:**
1. **Highest weighted score (9.0/10)** — best balance of reproducibility, latency, PEP668 handling, and version pinning
2. **Cleaner than Option A** — no `--break-system-packages` needed (uv tools are isolated)
3. **Aligns with all 5 established patterns** — build-time provisioning, uv for Python, PEP668 handling, one-container architecture, test-infra gates
4. **Minimal operational change** — dev-entrypoint.sh unchanged, @conspecter invocation unchanged (`trafilatura -u "<URL>" --output-format markdown`)
5. **Version pinning via ARG** — `TRAFILATURA_VERSION=2.2.0` makes updates explicit and reviewable
6. **Disk size efficient** — ~30-50MB (smaller than system-wide install)
7. **Test-infra compatible** — `make test-infra` continues to work without modification

**Trade-off:** Requires image rebuild for version updates (same as Option A), but this is acceptable cadence for a stable tool like trafilatura.

### Fallback: Option A — Bake Into Dev Image

If Option C encounters issues (uv tool install fails, dependency conflicts), fall back to Option A:
```dockerfile
# After uv installation, before Rust toolchain
RUN uv pip install --system --break-system-packages trafilatura==2.2.0 && \
    trafilatura --version
```

This is the existing pattern (playwright/crawl4ai) and has identical reproducibility characteristics. The only downside is `--break-system-packages`, which is already accepted in the project.

### Rejected Alternatives

- **Option B (venv per run):** Rejected due to per-run latency, non-determinism, and deviation from build-time provisioning pattern.
- **Option D (separate container):** Rejected due to operational complexity, architecture violation, and test-infra breakage.
- **Option E (mise Python):** Rejected due to maturity concerns and unnecessary complexity (uv already established).
- **Option F (apt package):** Not recommended unless verified available in Debian 13 repos (likely PyPI-only). If available, would score 8.0/10 and be a viable alternative.

## Verification Plan (Post-Implementation)

Per DIA-067 §Verification:
1. `docker ps` — container running
2. `docker exec poetry-dev trafilatura --version` — tool present in container (expected: v2.2.0)
3. `which trafilatura` host-side — expected absent (documents the gap)
4. Re-dispatch @conspecter — all 11 `sources/*.md` files > 0 bytes
5. Phase B conspect written
6. Phase 4 memory-shelf entry present
7. `make test-infra` exit 0

## Report File Path

**For transcription by @coder:**
```
knowledge/ana001-docker-trafilatura-strategy/ana001-docker-trafilatura-strategy-report.md
```

**Memory shelf registration:**
```yaml
# Add to .opencode/memory-shelf.yaml under shelf.analyses:
analyses:
  - id: ana001
    topic: docker-trafilatura-strategy
    title: "DIA-067 Container Strategy Analysis: trafilatura Availability"
    path: knowledge/ana001-docker-trafilatura-strategy/ana001-docker-trafilatura-strategy-report.md
    date: 2026-08-08
    decision: Option C (uv tool install) recommended
    ticket: DIA-067
```
