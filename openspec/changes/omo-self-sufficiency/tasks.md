## 1. Project Config Declarations

- [ ] 1.1 Add `"oh-my-opencode-slim@2.2.14"` to `.opencode/opencode.jsonc` plugin array (after the existing entries: envsitter-guard, delegation-observer, needs-input-observer)
- [ ] 1.2 Update `.opencode/tui.json` from `{}` to `{"plugin": ["oh-my-opencode-slim@2.2.14"]}` for panel registration (lessons L20260814-001: createLegacyTuiPluginHost reads tui.json, not opencode.jsonc)
- [ ] 1.3 Add `"oh-my-opencode-slim@2.2.14"` to `tools/opencode-docker/config/opencode.json` plugin array (consistency for standalone `bin/opencode-docker` tool)

**Acceptance:** `make test-config` passes (JSONC parse, no duplicate entries). All three config files carry the pinned OMO entry.

## 2. Dockerfile.dev: OpenCode Upgrade + Installer Hardening

- [ ] 2.1 Update `OPENCODE_VERSION` ARG from `1.18.4` to `1.18.18` (line 24)
- [ ] 2.2 Add `OMO_VERSION=2.2.14` ARG to the ARG block (lines 21-44, alongside other pinned versions)
- [ ] 2.3 Replace the opencode install block (lines 128-133) with direct binary download from GitHub release asset + SHA256 verification. Use the node/snip/uv/mise pattern: curl tarball, sha256sum -c, extract to /usr/local/bin. Linux-x64 digest: `0cddc222418b8553669905a8980c0cda7088f00da24d83d6ac76b01c9fdb2aaf`. Repo URL: `https://github.com/anomalyco/opencode/releases/download/v${OPENCODE_VERSION}/opencode-${OC_ARCH}.tar.gz`
- [ ] 2.4 Fetch arm64 binary digest from the same GitHub release and add it to the case statement in 2.3
- [ ] 2.5 Add OMO cache pre-population RUN step: `mkdir -p /home/dev/.cache/opencode && cd /home/dev/.cache/opencode && npm init -y --silent && npm install oh-my-opencode-slim@${OMO_VERSION} && chown -R ${USER_UID}:${USER_GID} /home/dev/.cache/opencode`. Must run BEFORE the non-root user switch (line 302).
- [ ] 2.6 Verify cache structure: after build, `docker compose exec dev ls /home/dev/.cache/opencode/node_modules/oh-my-opencode-slim` shows the package. If not found, apply Variant B fallback (`npm install -g oh-my-opencode-slim@${OMO_VERSION}`).

**Acceptance:** `docker build` exits 0. `opencode --version` inside container shows 1.18.18. OMO package present in cache. `.sdd/dev-infra/architecture.md` patterns respected (pinned versions, SHA256-verified).

## 3. Phase 1 Verification (Project + Global Safety Net)

- [ ] 3.1 Rebuild container: `make build` (picks up Dockerfile changes)
- [ ] 3.2 Verify container runtime: `make opencode` -> OMO loads, panel visible in TUI, version shows 2.2.14, no "plugin not found" errors
- [ ] 3.3 Restart host opencode: verify OMO loads from project config (panel visible, version 2.2.14). Host global entries still present (safety net). No triple-load.
- [ ] 3.4 Run `make test-config` + `make test-infra` -> both exit 0

**Acceptance:** Container + host both load OMO @2.2.14. Panel visible. Test gates green. Global entries still present (rollback safety).

## 4. Phase 2: Host Global Removal

- [ ] 4.1 Remove `"oh-my-opencode-slim@2.2.14"` from `~/.config/opencode/opencode.jsonc` plugin array (line 136)
- [ ] 4.2 Remove `"oh-my-opencode-slim@2.2.14"` from `~/.config/opencode/tui.json` plugin array (or empty the file to `{}`)
- [ ] 4.3 Restart host opencode: verify OMO still loads from project config alone (panel visible, version 2.2.14). No triple-load, no duplicate-load.
- [ ] 4.4 Verify `make opencode` in container still works (container never had global entries; project config is sufficient)

**Acceptance:** Host opencode loads OMO from project config alone (global entries removed). Container unchanged. No version mismatch.

## 5. Reference Sweep + Cleanup

- [ ] 5.1 Grep the repo for `sst/opencode` references (repo relocated to `anomalyco/opencode` per res028). Update any remaining references in Dockerfile, docs, scripts. Code-navigator lane can assist.
- [ ] 5.2 Update DIA-188 ticket frontmatter: gate_state -> "grilled", gate_triggers -> [cross-boundary, cross-cutting, hard-to-reverse], gate_waivers -> []
- [ ] 5.3 Update DIA-188 Verification checklist: mark items (a)-(e) as passed. Item (f) "teammate-sim" is satisfied by the self-sufficient design (no manual docs needed per Q7 decision).
- [ ] 5.4 File follow-up tickets: DIA-190 (conspecter permission defect, already filed by concurrent session), DIA-191 (Windows-native config pin)

**Acceptance:** No `sst/opencode` references remain (or are documented as intentional). DIA-188 ticket updated. Follow-up tickets filed.

## 6. Final Validation

- [ ] 6.1 Run full test suite: `make test-config` + `make test-interview` + `make test-infra` -> all exit 0
- [ ] 6.2 Commit all changes with message: `feat: DIA-188 OMO self-sufficiency (project-level plugin declaration + Docker bake + installer hardening)`
- [ ] 6.3 Register spec in `.opencode/memory-shelf.yaml` under `shelf.specs` (dispatch @memory-manager)

**Acceptance:** All test gates green. Commit on branch. Memory shelf updated.
