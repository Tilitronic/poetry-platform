## Context

See proposal.md -- Why and What Changes. Current state: OMO loads only from host global config; Dockerfile bakes opencode 1.18.4 with install-script SHA pattern; neither project configs nor Docker image declare OMO. Constraints: opencode >= 1.18.13 required for OMO >= 2.2.13 (res019); project tui.json panel registration works on opencode 1.18.18 (lessons L20260814-001); OpenCode auto-installs npm plugins into `~/.cache/opencode/node_modules/` at startup (opencode.ai/docs/plugins).

**Governing design documents:**

- `.sdd/dev-infra/architecture.md` -- worktree parallel dev model, branch conventions, safe/destructive operations (DIA-100). DIA-188 operates within the established dev-infra pattern (Docker image, config files).
- `.sdd/opencode-config/architecture.md` -- batch-pattern ADRs (Batch D parallel coders, singleton-batch exemption, DIA-175 instance separation). DIA-188 does not modify batch patterns; it adds OMO to the plugin declaration surface.

## Goals / Non-Goals

**Goals:**

- Project self-sufficiency: a fresh clone + `make up` + `make opencode` yields OMO @2.2.14 with zero manual plugin installation
- Docker image determinism: opencode 1.18.18 binary SHA256-verified from GitHub release; OMO pre-cached at build time
- Installer hardening: replace stale/unstable install-script SHA with direct binary download + SHA256 (matching the Dockerfile's existing node/snip/uv/mise pattern)
- Safe transition: two-phase global removal with verification gate (DIA-123 second-boot pattern); rollback at every step

**Non-Goals:**

- Windows-native config pin (separate follow-up ticket; dormant environment outside Linux/Docker scope)
- Conspecter permission defect fix (DIA-190; pre-existing, not caused by DIA-188)
- Documentation updates to docs/docker-dev.md (config files are single source of truth per Q7 decision)
- New .sdd/ ADRs (DIA-188 operates within established dev-infra and opencode-config patterns; no new architectural decisions)

## Decisions

### DD1: OpenCode version = 1.18.18 (newest stable)

**Decision:** Upgrade `OPENCODE_VERSION` from 1.18.4 to 1.18.18.

**Rationale:** res028 confirms 1.18.18 is the newest stable (published 2026-08-13, GitHub releases/latest). No 1.19.x or 2.x stable exists. 1.18.18 == host version, eliminating host/container drift. OMO 2.2.14 compatibility floor is @opencode-ai/plugin@1.18.13, satisfied with headroom. No breaking changes 1.18.4->1.18.18 for plugin loading, TUI plugin host, or config schema.

**Alternatives considered:**

- 1.18.13 (minimum floor) -- rejected: host/container drift; tui.json project-level behavior unverified at this version
- Latest floating -- rejected: contradicts pinned-version doctrine (Dockerfile line 17)

### DD2: Direct binary download (not install script)

**Decision:** Replace the opencode install block (lines 128-133) with direct binary download from GitHub release asset + SHA256 verification.

**Rationale:** res028 finding: the install script at opencode.ai/install lives on a mutable `dev` branch (anomalyco/opencode/refs/heads/dev/install) and performs NO sha256 verification of the downloaded binary. The current Dockerfile pins the SHA256 of the INSTALL SCRIPT (`fc3c1b2...`) which is stale/unstable -- any upstream change breaks the build. Direct binary download with SHA256 matches the Dockerfile's existing node/snip/uv/mise pattern. Repo relocation: `sst/opencode` -> `anomalyco/opencode`.

**Implementation:**

```dockerfile
# OpenCode CLI (pinned binary from GitHub release, SHA256-verified)
RUN OC_ARCH=$(case "${TARGETARCH:-$(uname -m)}" in x86_64|amd64) echo "linux-x64" ;; aarch64|arm64) echo "linux-arm64" ;; esac) && \
    curl -fsSL "https://github.com/anomalyco/opencode/releases/download/v${OPENCODE_VERSION}/opencode-${OC_ARCH}.tar.gz" -o /tmp/opencode.tar.gz && \
    case "${OC_ARCH}" in \
      linux-x64)   echo "0cddc222418b8553669905a8980c0cda7088f00da24d83d6ac76b01c9fdb2aaf  /tmp/opencode.tar.gz" | sha256sum -c - ;; \
      linux-arm64) echo "<ARM64_DIGEST>  /tmp/opencode.tar.gz" | sha256sum -c - ;; \
    esac && \
    tar xzf /tmp/opencode.tar.gz -C /usr/local/bin/ && \
    rm -f /tmp/opencode.tar.gz && \
    opencode --version
```

**Open question (implementation-time):** arm64 digest must be fetched from the same GitHub release at implementation time.

### DD3: OMO bake via cache pre-population

**Decision:** Pre-populate `/home/dev/.cache/opencode/node_modules/` during Docker build via `npm install oh-my-opencode-slim@${OMO_VERSION}`. Add `OMO_VERSION=2.2.14` ARG to ARG block (lines 21-44). Post-build verification: `opencode --version` inside container confirms OMO loads.

**Rationale:** OpenCode docs state npm plugins are cached in `~/.cache/opencode/node_modules/` and installed via Bun at startup. Pre-populating the cache directly targets where OpenCode looks, ensuring offline-capable startup. The Dockerfile already uses multiple distinct install patterns (binary download, npm global, uv pip system, rustup, bun global), so one more is not architecturally surprising.

**Implementation:**

```dockerfile
ARG OMO_VERSION=2.2.14

# Pre-install OMO into OpenCode's plugin cache for offline-capable startup
# (must run BEFORE the non-root user switch so cache is owned by dev)
RUN mkdir -p /home/dev/.cache/opencode && \
    cd /home/dev/.cache/opencode && \
    npm init -y --silent 2>/dev/null && \
    npm install oh-my-opencode-slim@${OMO_VERSION} && \
    chown -R ${USER_UID}:${USER_GID} /home/dev/.cache/opencode
```

**Fallback:** if cache pre-population fails (cache structure mismatch, transitive dep resolution issue), fall back to `npm install -g oh-my-opencode-slim@${OMO_VERSION}` (Variant B, matches DCP pattern at line 140).

**Open question (implementation-time):** verify that `npm install` into `/home/dev/.cache/opencode/` produces the structure OpenCode expects. If not, adjust the install command or use Variant B fallback.

### DD4: Two-phase global removal

**Decision:** Two-phase removal with verification gate. Phase 1: add project declarations + rebuild container + restart host + verify OMO loads from project config (global still present as safety net). Phase 2: remove global entries + restart + verify OMO loads from project config alone.

**Rationale:** The triple-load incident (lessons L20260814-001) was caused by version MISMATCH across declaration sources. OpenCode deduplicates same-name+version npm packages (loaded once), so Phase 1 is safe. But the goal is self-sufficiency, which means project must work WITHOUT global. Two-phase provides rollback at step 3 (if project config fails, global still works). Mirrors DIA-123 second-boot pattern (config changes verified across two restarts to prove determinism).

**Phase 1 verification criteria:**

- `make opencode` inside container: OMO loads, panel visible, version 2.2.14
- Host `opencode` restart: OMO loads from project config, panel visible, version 2.2.14
- No "plugin not found" errors
- `make test-config` passes

**Phase 2 verification criteria:**

- Remove global entries from `~/.config/opencode/opencode.jsonc` (line 136) + `~/.config/opencode/tui.json`
- Restart host opencode: OMO still loads from project config alone
- `make opencode` in container: OMO still loads (container never had global entries)
- No triple-load, no duplicate-load, no version mismatch

### DD5: Add OMO to tools/opencode-docker/config/opencode.json

**Decision:** Add `"oh-my-opencode-slim@2.2.14"` to the standalone `bin/opencode-docker` tool's config (per original ticket scope item 3).

**Rationale:** Both opencode entry points (poetry-dev container + standalone tool) should have OMO for consistency. The standalone tool is used outside the poetry-platform context, but its users benefit from OMO. This is the ticket's original scope, not an expansion.

**Open question (implementation-time):** the standalone tool's config has no corresponding tui.json. Does `bin/opencode-docker` need a tui.json for panel registration? Low priority; the standalone tool may not need the panel.

## Risks / Trade-offs

**[Risk] Cache pre-population structure mismatch** -> OpenCode may not find the pre-cached OMO if the directory structure differs from what Bun creates at startup. **Mitigation:** post-build verification (`opencode --version` inside container catches this); Variant B fallback (`npm install -g`) if cache fails.

**[Risk] arm64 digest unavailable at build time** -> the arm64 binary digest must be fetched from GitHub release; if the release is yanked or the digest changes, the build fails. **Mitigation:** the build fails loudly (sha256sum -c); the digest is fetched at implementation time and pinned in the Dockerfile; if the release is yanked, pin to the previous version.

**[Risk] Triple-load during Phase 1** -> if project config declares @2.2.14 but host global declares a different version, version mismatch causes triple-load. **Mitigation:** Phase 1 verification checks panel version; if mismatch detected, do NOT proceed to Phase 2; fix version first.

**[Risk] Host global removal breaks host opencode** -> if project config fails to load OMO after global removal, host opencode has no OMO. **Mitigation:** Phase 2 rollback is trivial (restore 2 lines in global configs); Phase 1 verification proves project config works before global removal.

**[Trade-off] Installer pattern change expands scope** -> DD2 (direct binary download) goes beyond the original "version bump" scope. **Accepted because:** the Dockerfile lines are touched anyway; the script SHA is already stale/unstable (res028); bundling avoids a guaranteed follow-up ticket.

**[Trade-off] No documentation update** -> DD5 (no docs change) means the "self-sufficient" property is implicit, not documented. **Accepted because:** config files are the single source of truth; docs would duplicate version pins and drift; the `make opencode` target is self-explanatory.

## Seams

This is a config + Docker change, not application code. The "seams" are the config files and Docker build/runtime boundaries where verification occurs:

| Seam                                                      | What is tested                                                                     | How                                                           |
| --------------------------------------------------------- | ---------------------------------------------------------------------------------- | ------------------------------------------------------------- |
| `.opencode/opencode.jsonc` plugin array                   | Syntax validity, no duplicate OMO entries                                          | `make test-config` (JSONC parse, plugin classification)       |
| `.opencode/tui.json` plugin array                         | Syntax validity                                                                    | `make test-config`                                            |
| `tools/opencode-docker/config/opencode.json` plugin array | Syntax validity                                                                    | `make test-config`                                            |
| `Dockerfile.dev` build                                    | opencode binary SHA256 matches; OMO cache populated; `opencode --version` succeeds | `docker build` exit 0; `make test-infra` (smoke test)         |
| Container runtime                                         | OMO loads from project config; panel visible; version 2.2.14                       | `make opencode` (manual verification)                         |
| Host runtime (Phase 1)                                    | OMO loads from project config + global (safety net); panel visible                 | `opencode` restart (manual verification)                      |
| Host runtime (Phase 2)                                    | OMO loads from project config alone; no triple-load                                | `opencode` restart after global removal (manual verification) |

**Test prior art:** `scripts/__tests__/batch-d-infra.test.mjs` (plugin classification, config grep checks); `scripts/validate-agent-names.sh` (lockstep); `scripts/validate-grilling-gate.sh` (gate markers).

## Migration Plan

**Deploy sequence:**

1. Add OMO entries to project configs (`.opencode/opencode.jsonc`, `.opencode/tui.json`, `tools/opencode-docker/config/opencode.json`)
2. Update `Dockerfile.dev` (OPENCODE_VERSION, OMO_VERSION ARG, install block, cache pre-population)
3. Rebuild container (`make build`)
4. Phase 1 verification (container + host with global safety net)
5. Remove global entries (`~/.config/opencode/opencode.jsonc`, `~/.config/opencode/tui.json`)
6. Phase 2 verification (host with project-only)
7. Commit + push

**Rollback:**

- Phase 1 rollback: remove project OMO entries, rebuild container, restart host (global still works)
- Phase 2 rollback: restore global entries, restart host (restores prior state)
- Dockerfile rollback: revert OPENCODE_VERSION + install block + remove OMO_VERSION ARG, rebuild

## Open Questions (implementation-time, not design-blocking)

1. **arm64 binary digest:** res028 provided linux-x64 digest. The arm64 digest must be fetched from the GitHub release at implementation time.
2. **Cache directory structure:** verify that `npm install oh-my-opencode-slim@2.2.14` into `/home/dev/.cache/opencode/` produces the structure OpenCode expects. If not, adjust or use Variant B fallback.
3. **sst/opencode -> anomalyco/opencode reference sweep:** grep the repo for any remaining `sst/opencode` references and update them (code-navigator lane at implementation time).
4. **tools/opencode-docker tui.json:** the standalone tool's config has no tui.json. Determine if panel registration is needed for the standalone tool (low priority).
