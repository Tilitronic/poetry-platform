# DIA-188 - OMO self-sufficiency: project-level plugin declaration + docker bake (openCode >= 1.18.13 in image)

<!-- UPDATE 2026-08-15: EBDV decision recorded (variant A - project-level plugin
     declaration + docker bake). Diagnosis complete; implementation started.
     Route: openspec-plan spec -> coder implementation -> test gates ->
     ai-auditor + reviewer -> restart-verify (combined with the pending 2.2.14
     restart-verify from the prior evaluation ticket) -> registration. -->

<!-- IMPLEMENTED 2026-08-15 (coder lane): Phase 1 complete - project config
     declarations (opencode.jsonc + tui.json + tools/opencode-docker), Dockerfile
     opencode 1.18.18 direct-binary install + SHA256, OMO 2.2.14 bake into
     ~/.cache/opencode. Image built + content-verified. Host gates green.
     PENDING: restart-verify (swap poetry-dev to new image, confirm OMO panel +
     single load with host global still present) then Phase 2 (remove host
     global entries). Full evidence in Fix section. -->

<!-- FILED 2026-08-15 (docs lane, coder agent). Tracking ticket - no config or
     code change performed yet. Diagnosed 2026-08-15: the oh-my-opencode-slim
     plugin loads ONLY from the host GLOBAL config; neither the project
     .opencode/ configs nor the docker dev image declare it, so a teammate
     cloning the repo gets a non-self-sufficient setup. Structural precedent:
     the 2.2.14 evaluation ticket (same ticket family: oh-my-opencode-slim
     tooling). -->

---

id: DIA-188
title: "OMO self-sufficiency: project-level plugin declaration + docker bake (openCode >= 1.18.13 in image)"
area: opencode-config
severity: Medium
status: OPEN
blocked_by: [] # no blockers
parent_epic: ""

# DIA-104 grilling-gate markers (ai--7 validated design): fill at creation time

# with the defaults below (absent = legacy/skipped, grandfather precedent).

gate_state: "grilled" # grilled | waived | bypassed | partial | skipped
gate_triggers: [cross-boundary, cross-cutting, hard-to-reverse] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered:
source: developer requirement
date: 2026-08-15
created: 2026-08-15
updated: 2026-08-15

# --- Session Attribution (v2 schema, optional) ---

session_id: "ses_ffb7d22e5ffeXw05iRPq5AwVVw" # filing lane (docs, coder agent)
lane_id: "docs"
agent: "coder"
model: "opencode-go/deepseek-v4-flash"
parent_session_id: "" # orchestrator session (filing dispatch context)
attempts: 0
lease_expires_at: ""
files_touched: [docs/dev-infra-audit/tickets/DIA-188-omo-slim-project-self-sufficiency.md, docs/dev-infra-audit/tickets/README.md, .opencode/opencode.jsonc, .opencode/tui.json, tools/opencode-docker/config/opencode.json, Dockerfile.dev]
artifacts: []
evidence: []

---

## Description

Developer requirement: the project + its dev docker must be SELF-SUFFICIENT
for oh-my-opencode-slim, so a teammate cloning the repo gets an identical
setup without hand-installing global plugins.

Current state (diagnosed 2026-08-15): OMO plugin is loaded ONLY from the host
GLOBAL config (~/.config/opencode/opencode.jsonc plugin array + tui.json),
pinned @2.2.14; the project .opencode/opencode.jsonc plugin array (lines
~578-583) has NO OMO entry (envsitter-guard@0.0.4,
@tarquinen/opencode-dcp@3.1.14, delegation-observer.ts,
needs-input-observer.ts); project .opencode/tui.json is empty {};
tools/opencode-docker/config/opencode.json has no OMO entry; the docker dev
container (poetry-dev) bakes opencode 1.18.4 (TOO OLD for OMO 2.2.14 which
requires >= 1.18.13) with an EMPTY ~/.config/opencode and NO OMO - so `make
opencode` runs bare opencode without OMO. A historical dead project entry
file:///workspace/.opencode/oh-my-opencode-slim was removed during the 2.2.13
cleanup because the directory is not a loadable plugin (no package.json/dist;
it is the live prompt-override dir + unbuilt src).

### Decision (EBDV, recorded 2026-08-15)

Variant A - project-level plugin declaration + docker bake. Rationale:
declares OMO in every layer the project controls (project opencode.jsonc,
project tui.json, docker opencode.json, baked image) so a fresh clone builds a
functioning OMO setup offline; removes the host-global dependency after the
project declaration is verified.

### Scope

1. Add "oh-my-opencode-slim@2.2.14" to the project .opencode/opencode.jsonc
   plugin array.
2. Add it to project .opencode/tui.json (currently {}) so the OMO panel
   registers from the project config (legacy TUI plugin host reads project +
   global tui.json).
3. Add the same entry to tools/opencode-docker/config/opencode.json.
4. Dockerfile.dev: upgrade the baked opencode to >= 1.18.13 (target 1.18.18
   to match host) AND bake oh-my-opencode-slim@2.2.14 into the container so
   the image is offline-capable and deterministic.
5. AFTER project declaration is verified working (post-restart), remove the
   OMO entry from the host GLOBAL config (opencode.jsonc + tui.json) to avoid
   duplicate plugin load (triple-load incident history - verify single load).
6. Follow-up: pin the dormant Windows-native config
   (/mnt/c/Users/qualt/.config/opencode/opencode.jsonc + tui.json) to
   @2.2.14 (diagnosed LIVE-but-dormant 2026-08-15 - real binary + state db,
   last activity mid-July; unpinned bare entry = drift hazard).

### Non-regressible

- conspecter permission hardening (commit 753e374);
- agent-name lockstep S1-S4 (scripts/validate-agent-names.sh);
- skill-sync behavior;
- make test-config + make test-interview green;
- host OMO @2.2.14 keeps working during transition.

### Route

Section 2.4/2.5 chain: openspec-plan interview + spec (proposal/design/tasks),
then coder implementation, test gates (make test-config, make test-interview,
make test-infra), review (ai-auditor for opencode-config part + reviewer for
dev-infra part), restart-verify (combined with the pending 2.2.14
restart-verify from the prior evaluation ticket), registration (CHANGELOG +
learnings), memory-manager.

## Verification

> Phase 1 implementation evidence (2026-08-15). Items (a)(b)(e) PASSED; (c)
> pending post-restart; (d) Phase 2 (deliberately NOT done this dispatch - see
> Fix); (f) satisfied by design per Q7 (no docs change; baked image + project
> declaration is the teammate-sim answer).

- [x] (a) project plugin array + tui.json + docker config all carry the pinned
      entry (make test-config exit 0; three config files checked)
- [x] (b) container image builds with opencode >= 1.18.13 + OMO baked
      (docker compose build dev exit 0; image verified: opencode 1.18.18,
      OMO 2.2.14 in ~/.cache/opencode/node_modules, ownership dev:dev)
- [ ] (c) after restart: OMO loads from PROJECT config, panel present, single
      plugin load (no duplicate/triple-load) -- PENDING restart-verify (swap
      poetry-dev to new image with host global still present as safety net)
- [ ] (d) host global config no longer declares OMO (after project verified)
      -- Phase 2, not executed in this dispatch
- [x] (e) make test-config/test-interview exit 0 (test-infra pending
      restart-verify; the smoke test rebuilds the stack on the new image)
- [x] (f) teammate-sim: fresh clone + docker build gives OMO without manual
      global install (satisfied by the self-sufficient design per Q7 - baked
      OMO cache + project declarations; no docs change)

## Fix

> Implemented 2026-08-15 (coder lane, DIA-188). Phase 1 scope only per
> dispatch: project declarations + Dockerfile changes + rebuild + verify.
> Spec: openspec/changes/omo-self-sufficiency (validated, exit 0). Decisions
> DD1-DD5 applied. Host global configs (~/.config/opencode/opencode.jsonc +
> tui.json) UNTOUCHED (Phase 2, after restart-verify per two-phase Q5).

Applied changes:

1. .opencode/opencode.jsonc plugin array: added "oh-my-opencode-slim@2.2.14"
   (comment at line ~135 already referenced 2.2.14 - in sync, no change).
2. .opencode/tui.json: {} -> {"plugin": ["oh-my-opencode-slim@2.2.14"]} for
   project-level OMO panel registration (createLegacyTuiPluginHost reads
   project + global tui.json).
3. tools/opencode-docker/config/opencode.json plugin array: added
   "oh-my-opencode-slim@2.2.14" (DD5).
4. Dockerfile.dev:
   - OPENCODE_VERSION ARG 1.18.4 -> 1.18.18 (DD1, newest stable per res028,
     matches host).
   - Added OMO_VERSION=2.2.14 ARG (DD3).
   - Replaced the install-script pattern (opencode.ai/install + script SHA
     fc3c1b2...) with direct binary download from
     github.com/anomalyco/opencode releases + sha256sum -c of the binary
     (DD2). linux-x64 digest 0cddc222... verified against the release asset;
     linux-arm64 digest dcb1b5ec... fetched from the same v1.18.18 release at
     implementation time. Case statement per architecture, matching the
     node/snip/uv/mise pattern.
   - Added OMO cache pre-population RUN before the non-root USER switch:
     npm install oh-my-opencode-slim@2.2.14 into /home/dev/.cache/opencode,
     chown -R to dev:dev. npm's own cache redirected to /tmp and discarded so
     no root-owned ~/.npm is left in /home/dev (documented in the Dockerfile).
     Transitive exact-pins @opencode-ai/plugin@1.18.13 + @opencode-ai/sdk@1.18.13
     resolved into the same tree (verified in the built image).
   - sst/opencode reference sweep: no FUNCTIONAL references remain. All 14
     grep hits are documentary (res028 conspect, spec artifacts,
     memory-shelf, archived res004 source URL) - they document the relocation
     itself and are intentional. Dockerfile previously used opencode.ai/install
     (no explicit sst/opencode string); the install block now points at
     anomalyco/opencode releases directly.

Verification evidence (all recorded 2026-08-15):

- make test-config: exit 0 (56 pass, 0 fail; JSONC parse, plugin
  classification, agent-name lockstep, grilling-gate, EBDV, batch-d suite)
- make test-interview: exit 0 (all 5 checks PASS)
- openspec validate omo-self-sufficiency: exit 0 ("Change is valid")
- docker compose build dev: exit 0 (image poetry-platform-dev:latest built)
- Image content verify (docker run --rm poetry-platform-dev:latest):
  opencode --version -> 1.18.18; ls ~/.cache/opencode/node_modules | grep
  oh-my-opencode-slim -> hit; package version 2.2.14; @opencode-ai/plugin
  1.18.13 + @opencode-ai/sdk 1.18.13; cache owned dev:dev
- docker compose ps: poetry-dev Up 9 hours (healthy) [running container still
  on the OLD image sha256:f8e909... - image-only build; container swap to
  poetry-platform-dev:latest happens at restart-verify]

NOT executed this dispatch (deliberately, per Phase-1-only scope):

- make test-infra (heavy smoke test that rebuilds/starts the stack on the new
  image) - deferred to restart-verify phase (tasks.md 3.4/6.1)
- Container swap to the new image + runtime OMO load check (post-restart)
- Phase 2: host global OMO entry removal (~/.config/opencode/opencode.jsonc
  line ~136 + tui.json)
- Windows-native config pin (/mnt/c/...) - separate follow-up ticket (Q8)
- docs/docker-dev.md - NOT modified per Q7
- conspecter permission - DIA-190, separate

Restart-verify checklist (next lane):

1. docker compose up -d dev (swap poetry-dev to poetry-platform-dev:latest)
2. docker compose ps: poetry-dev Up (healthy)
3. make opencode: OMO loads, panel visible, version 2.2.14, no "plugin not
   found" errors (container never had global entries - project config must
   suffice)
4. Host opencode restart: OMO loads from project config (panel visible,
   version 2.2.14); host global entries STILL present (safety net); NO
   triple-load / duplicate-load
5. make test-infra: exit 0
6. Only then: Phase 2 (remove host global entries, re-verify host loads OMO
   from project alone)

## Re-verify

> To be filled at re-verify time.
