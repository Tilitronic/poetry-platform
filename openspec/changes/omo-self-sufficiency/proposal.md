## Why

The poetry-platform project's oh-my-opencode-slim (OMO) plugin loads ONLY from the host global config (`~/.config/opencode/opencode.jsonc` + `tui.json`). Neither the project `.opencode/` configs nor the Docker dev image declare OMO. A teammate cloning the repo gets a bare opencode without OMO -- the project is not self-sufficient. Additionally, the Dockerfile bakes opencode 1.18.4 which is too old for OMO >= 2.2.13 (requires >= 1.18.13), and uses a stale/unstable install-script SHA pattern that breaks when upstream mutates the script.

## What Changes

- Add `"oh-my-opencode-slim@2.2.14"` to project `.opencode/opencode.jsonc` plugin array
- Add `{"plugin": ["oh-my-opencode-slim@2.2.14"]}` to project `.opencode/tui.json` (panel registration via createLegacyTuiPluginHost)
- Add `"oh-my-opencode-slim@2.2.14"` to `tools/opencode-docker/config/opencode.json` plugin array
- Upgrade `OPENCODE_VERSION` in `Dockerfile.dev` from 1.18.4 to 1.18.18 (newest stable per res028)
- Switch Dockerfile opencode install from script-based (SHA of mutable install script) to direct binary download from GitHub release asset with SHA256 verification (linux-x64 digest `0cddc222418b8553669905a8980c0cda7088f00da24d83d6ac76b01c9fdb2aaf`; arm64 digest fetched at implementation time)
- Add `OMO_VERSION=2.2.14` ARG to Dockerfile ARG block (lines 21-44)
- Pre-populate `/home/dev/.cache/opencode/node_modules/` during Docker build via `npm install oh-my-opencode-slim@${OMO_VERSION}` (offline-capable, deterministic)
- Post-build verification: `opencode --version` inside container confirms OMO loads
- Fallback: if cache pre-population fails, switch to `npm install -g oh-my-opencode-slim@${OMO_VERSION}` (Variant B, matches DCP pattern)
- Two-phase host global removal: (1) add project declarations + rebuild container + restart host + verify OMO loads from project config with global as safety net, (2) remove global entries from `~/.config/opencode/opencode.jsonc` + `tui.json` + restart + verify OMO loads from project config alone
- Sweep `sst/opencode` -> `anomalyco/opencode` references in Dockerfile (repo relocation per res028)

## Capabilities

### New Capabilities

None. This is a dev-infra/config change with no user-facing spec-level behavior changes.

### Modified Capabilities

None.

## Impact

**Affected files:**

- `.opencode/opencode.jsonc` (plugin array)
- `.opencode/tui.json` (panel registration)
- `tools/opencode-docker/config/opencode.json` (plugin array)
- `Dockerfile.dev` (OPENCODE_VERSION, OMO_VERSION ARG, install block, cache pre-population)
- `~/.config/opencode/opencode.jsonc` (global OMO entry removed in Phase 2)
- `~/.config/opencode/tui.json` (global OMO entry removed in Phase 2)

**Dependencies:**

- opencode 1.18.18 binary from GitHub release (anomalyco/opencode)
- oh-my-opencode-slim@2.2.14 from npm
- @opencode-ai/plugin@1.18.13 + @opencode-ai/sdk@1.18.13 (OMO peer deps, auto-resolved by npm)

**Systems:**

- Docker dev container (poetry-dev)
- Host opencode (Linux)
- Standalone `bin/opencode-docker` tool

**Non-regressible:**

- Conspecter permission hardening (commit 753e374)
- Agent-name lockstep S1-S4 (`scripts/validate-agent-names.sh`)
- Skill-sync behavior
- `make test-config` + `make test-interview` + `make test-infra` must exit 0
- Host OMO @2.2.14 keeps working during transition

## Rollback Plan

**Phase 1 rollback (project declarations added, global still present):**

- Remove OMO entries from project `.opencode/opencode.jsonc` + `.opencode/tui.json` + `tools/opencode-docker/config/opencode.json`
- Rebuild container (`make build`)
- Restart host opencode
- Global OMO still works (no downtime)

**Phase 2 rollback (global removed, project-only):**

- Restore global entries in `~/.config/opencode/opencode.jsonc` + `tui.json`
- Restart host opencode
- OMO loads from global (restores prior state)

**Dockerfile rollback:**

- Revert `OPENCODE_VERSION` to 1.18.4
- Revert install block to script-based pattern
- Remove `OMO_VERSION` ARG and cache pre-population
- Rebuild container

## Testing Decisions

**What makes a good test for this change:**
This is a config + Docker change, not application code. Good tests verify:

1. Config syntax validity (JSONC parse, no duplicate entries)
2. Docker build succeeds (opencode binary SHA256 matches, OMO cache populated)
3. Container runtime loads OMO (panel visible, version correct)
4. Host runtime loads OMO from project config (Phase 1 with global safety net, Phase 2 project-only)
5. No triple-load or version mismatch (single plugin load, correct version)

**Modules tested:**

- `.opencode/opencode.jsonc` (plugin array syntax, no duplicates)
- `.opencode/tui.json` (plugin array syntax)
- `tools/opencode-docker/config/opencode.json` (plugin array syntax)
- `Dockerfile.dev` (build succeeds, opencode version correct, OMO cached)
- Host global configs (entries removed in Phase 2)

**Prior art in the codebase:**

- `scripts/__tests__/batch-d-infra.test.mjs` (plugin classification, config grep checks)
- `scripts/validate-agent-names.sh` (agent-name lockstep S1-S4)
- `scripts/validate-decision-variants.sh` (EBDV validation)
- `scripts/validate-grilling-gate.sh` (DIA-104 gate markers)
- DIA-123 second-boot pattern (deterministic restart verification)
- DIA-127 reopen (upgrade verification must check LOADED instance + ALL declaration sources)

**Test gates:**

- `make test-config` (config validation, agent-name lockstep, decision-variants, grilling-gate)
- `make test-infra` (Docker smoke test, Python tests)
- Manual verification: `make opencode` in container, host `opencode` restart, panel visible, version shows 2.2.14

## Alternatives Considered

- **Variant B (Q2: separate installer hardening ticket):** keep DIA-188 scope narrow, file installer pattern change as separate ticket - rejected because the Dockerfile lines are touched anyway by the version upgrade; bundling avoids a guaranteed follow-up that re-treads the same block; the script SHA is already stale/unstable (res028 finding)
- **Variant B (Q3: npm install -g for OMO bake):** use the DCP pattern (global npm install) instead of cache pre-population - rejected because OpenCode docs state plugins are cached in `~/.cache/opencode/node_modules/`, not resolved from global; cache pre-population directly targets where OpenCode looks; Variant B kept as fallback if cache structure fails
- **Variant B (Q5: single-phase global removal):** add project + remove global atomically, one restart - rejected because if project config fails, no fallback; two-phase with verification gate (DIA-123 second-boot pattern) provides rollback safety at step 3
- **Variant A (Q7: add docs section to docs/docker-dev.md):** document the self-sufficient setup explicitly - rejected because config files are the single source of truth; docs would duplicate version pins and drift
- **Variant A (Q8: include Windows pin in DIA-188):** pin the dormant Windows-native config as part of this change - rejected because Windows config is outside Linux/Docker scope; labeled "Follow-up" in original ticket; separate ticket after DIA-188
- **Status-quo / do nothing:** keep OMO in host global only, Docker builds without OMO, container runs opencode 1.18.4 - rejected because the project is not self-sufficient; a teammate cloning the repo gets bare opencode; the Dockerfile install script SHA is stale and will break on upstream mutation

**Chosen option:** project-level plugin declaration + Docker cache pre-population + installer hardening + two-phase global removal - because the project must be self-sufficient for OMO (core requirement), the installer pattern must be hardened (res028 finding), and two-phase removal provides rollback safety (DIA-123 pattern).
