# Proposal: opencode-v2-migration

> **Status:** proposed (revision 2, post-audit) | **Scope:** dev-infra / AI tooling (container topology, `.opencode/` config and plugins)
> **Ticket:** DIA-261112-exon
> **Design authority:** `.sdd/dev-infra/architecture.md` ADR 11 (lines 94-109) and ADR 15 (lines 139-155) are binding. This proposal does not restate them.
> **Audit basis:** `docs/opencode-v2-migration-audit-register.md` (4 BLOCKER, 6 MAJOR, 4 MINOR, 2 NOTE, 8 architecture verdicts).

## Why

The project runs OpenCode V1 inside the dev container while the tree declares parts of a V2 image. Measured on 2026-11-13 in `poetry-dev`: the resolved binary is **1.18.32** through a mise shim (`.mise.toml:12`), while `Dockerfile.dev:30` declares `@opencode/cli` **2.2.6**; `@opencode/cli` is not installed globally, so the image pin is inert. OMO is pinned three ways (`opencode.jsonc:817` 2.2.19, `tui.json:2` 2.2.19, `Dockerfile.dev:33` 3.0.7), and the cache has 2.2.14 / 2.2.15 / 2.2.17 / 2.2.19 but not 3.0.7. Two gates are red (`check-pin-sync` exit 1, `check-omo-version-sync` exit 1), and `make test-config` exits 2 at `Makefile:260`, leaving 13 recipe steps unverified.

V2 is a plugin API rewrite: V1 plugins do not run in V2 (`MIG:175-258`, `MIG:436-462`). Yet 52 percent of authored plugin LOC (5,353 of 10,321) needs no V2 adaptation (`BRIEF:7`, `BRIEF:93-103`). The migration is cheapest if it deletes first and ports only the surviving integrity core.

The first draft of this change was rejected because it planned an in-place conversion while the live container still ran V1 (`AUD-B1`/`ARC-3`), mis-wired the gate layers and the gate-token carrier (`AUD-B2`/`ARC-2`), assumed a synchronous subagent result (`AUD-B3`), omitted four hard-failing validators (`AUD-B4`), and violated V2's no-nested-mixing rule (`AUD-M1`/`ARC-4`). The ADRs now exist and settle the topology and governance model:

- **ADR 11** (amended 2026-11-19) requires a **parallel V2 compose service** (`dev-v2`) beside V1 `dev`, with per-service install authority, separate image tags and volumes, and a meaningful live-pin gate.
- **ADR 15** (new 2026-11-19) fixes the three-layer gate boundary, the single-plugin `ctx.storage` plus file-locked JSONL/handoff durability split, the whole-agent atomic conversion rule, and the needs-input reduction to a ~30-40 LOC ask-timeout watchdog with no waiting marker.

The developer has further fixed the workspace isolation: the two services must **not** share the same working directory. Both mount the repo `.:/workspace` (a worktree's `.git` is a file pointing at the main object store, so a single-directory bind would break git), but `dev` works at `/workspace` and `dev-v2` at `/workspace/.worktrees/opencode-v2`. A shared working directory would let V2 config conversion break the live V1 service, reintroducing `AUD-B1` through compose. The repo already supports this pattern: `opencode-overnight.jsonc:240-245` grants `.worktrees/*` read/edit.

Reference aliases:

- `MIG` = `knowledge/res-261112-1ima-opencode-version-migration/res-261112-1ima-opencode-version-migration-conspect.md`
- `NAT` = `knowledge/res-261113-hi88-opencode-v2-native-capabilities/res-261113-hi88-opencode-v2-native-capabilities-conspect.md`
- `BRIEF` = `docs/opencode-v2-migration-brief.md`
- `REGISTER` = `docs/opencode-v2-migration-audit-register.md`

Baseline facts (measured 2026-11-13, evidence not inference):

- Inside `poetry-dev`; `scripts/in-container.sh` exit 0.
- OpenCode 1.18.32 via mise; `@opencode/cli` absent globally.
- OMO cache: 2.2.14, 2.2.15, 2.2.17, 2.2.19; no 3.0.7; no `node_modules` in the cache root.
- V1 plugins healthy: `registry.jsonl` 1.8 min old, `ticker.json` 26 s old, OMO log `health check passed {"agents":23,"tools":9,"mcps":2}`, zero plugin-load errors. Blocker B7 is resolved as NOT the case: the container is V1, not broken.
- Red gates: `check-pin-sync` exit 1; `check-omo-version-sync` exit 1; `validate-plugin-structure` exit 0; `make test-config` exit 2 at `Makefile:260`; later steps unverified.
- Git: HEAD `da41b18c` on `omo-slim-changes`, 13 dirty entries including `Dockerfile.dev`, `.opencode/memory-shelf.yaml`, the learnings index, two ticket files, and untracked knowledge/docs artifacts. No `pre-v2-migration` tag.

**Corrected install statement.** The previous draft treated `@opencode/cli` as an unverified channel and cited `MIG:29`. That was a misreading: `MIG:29-52` is about the V1 `opencode-ai` package, whose npm `latest` stays on 1.19.5. `@opencode/cli` is the documented V2 install channel (`docs-cli-commands.md:18`), and the conflict is recorded as resolved in design D2 and D12: install an exact, integrity-checked `@opencode/cli` release and assert the resolved binary at image build and service startup, satisfying both the documented-channel finding (`AUD-M6`) and the verified-artifact requirement (`ARC-7`).

## What Changes

1. **Parallel V2 service, not an in-place cutover.** Add `dev-v2` beside `dev` per ADR 11 decision 2. It has its own image tag, hostname, OpenCode pin (exact V2 release), OMO 3.0.7, `dev_v2_cache` / `dev_v2_state` / `pnpm_store_v2` volumes, and `.:/workspace` with `working_dir: /workspace/.worktrees/opencode-v2` (so git sees the real object store and OpenCode reads only the worktree's `.opencode`). `dev` keeps `.:/workspace`, its `dev_cache`/`dev_state` volumes, `pnpm_store`, and V1 pins (OpenCode 1.18.32, OMO 2.2.19). Day-to-day work continues on `dev` until `dev-v2` passes every gate. Postgres remains shared, with a test-contention caveat. Acceptance includes `git status` succeeding inside `dev-v2`, distinct container names/hostnames, and published ports disjoint from `dev`'s 9000/8000/3000.
2. **One install authority per service.** Remove the mise `opencode` shim from the container path. Install an exact `@opencode/cli` V2 release in the V2 image with npm integrity checking and assert `opencode --version` at build and startup. Correct the V1 service's declared ARG to its measured 1.18.32 so its own assertion is truthful. Keep pin parity meaningful per ADR 11 decision 4: three static toolchain pairs plus per-service OpenCode/OMO declared-vs-runtime assertions.
3. **Delete first, on the migration worktree.** Delete the preset guard, A1 advisory, context policy/velocity, formatter, empty-result/failure cap, adaptive routing, apoptosis/circuit breaker/paracrine, capability minting, `context_usage`, the bash tripwire, `get-my-session-id`, the V1 needs-input tier, the compaction snapshot, the autocrine warn, and the two pending detectors. Reclaim the surviving core: journal, handoff + `log_decision`, ticket gate, reviewer envelope, protected-path gate, routing gate, `fetch-source` + destination policy, and a ~60-line stall sweep.
4. **Needs-input variant B without the waiting marker.** Keep only the ~30-40 LOC ask-timeout watchdog. Delete `needs-input-observer.ts`, `lib/permission-fast-resolve.ts`, the `ctx.storage` marker, `ticker-render`, and the toast/title machinery. Watchdog API: `ctx.permission.list({sessionID})` and `ctx.permission.reply({sessionID, requestID, decision})`, tracking `requestID`/`sessionID` from `permission.asked` / `form.created`.
5. **One plugin with stable id `delegation-observer`.** Move `lib/` and the tests out of the immediate `.opencode/plugins/` discovery root (package `delegation-observer/index.ts` with `lib/` inside; tests under `.opencode/plugin-tests/`). Register `log_decision` and `fetch-source` through `ctx.tool.transform`; remove `.opencode/tools/`.
6. **Three-layer gates per ADR 15.** Ticket, envelope, and routing gates run in `ctx.tool.hook("execute.before")` on `subagent`, reading `event.input.agent` / `event.input.sessionID`. The protected-path token is written by `log_decision` into `ctx.storage`, read by `permission.hook("evaluate")`, and upgrades `effect === "ask"` to allow only on a valid token; an invalid or expired token is **denied**, never left as `ask`. `policies` carry only unconditional hard denies. `lib/routing-gate.ts` stops reading the deleted paracrine rows and reads `ctx.storage`.
7. **Atomic whole-agent conversion, conversion last.** After `dev-v2` is proven, convert top-level `agent` -> `agents` and each agent's entire nested entry plus `.opencode/agents/<name>.md` frontmatter in one edit: `permissions`, `disabled`, `steps`, `system`, hex-only `color`. Remove orphan V1 keys (`doom_loop`, `lsp`, `list`, `apply_patch`, 23 `envsitter_*`, `mint_capability`). Critical agents first, then the rest.
8. **Config dead weight and validator repair.** Delete ollama + its three models, `lsp`, `compaction.prune`, `ai-specialist.temperature`, the council seats, and `scout`. Rename `compaction.reserved` -> `buffer` and `disable` -> `disabled`. Repair the four validators that hard-fail on V2 shapes and the two vacuous readers. No new validator scripts.
9. **V1 retirement last.** Cut over only after `dev-v2` passes all runtime, plugin, and permission gates. Retire the V1 container first; keep `dev_cache` / `dev_state` until the migration branch merges (they are the rollback point); never touch the workspace; postgres may remain shared with the contention caveat.

## Capabilities

This is a dev-infra / AI-tooling change within existing module boundaries. It does not change Poetry Platform product behavior and creates no spec-level capability. `.openspec.yaml` sets `skip_specs: true`; no `specs/` deltas are authored.

### New Capabilities

None (`skip_specs: true`).

### Modified Capabilities

None at the Poetry Platform spec level.

## Impact

**Container topology:** `docker-compose.yml` (new `dev-v2` service, separate image tag and volumes, worktree bind), `Dockerfile.dev` (V2 build args/stage, V1 ARG correction, install assertion), `dev-entrypoint.sh` (runtime version assertion), `.mise.toml` (no `opencode` key).

**Configuration (migration worktree only until S10a):** `.opencode/opencode.jsonc` (top-level `agents`, atomic per-agent entries, `plugins`, `skills`, `mcp.servers`, permission arrays, dead-weight removal), `.opencode/oh-my-opencode-slim.jsonc`, `.opencode/opencode-overnight.jsonc` (bash + read + edit maps), `.opencode/tui.json`, `.opencode/package.json`, `.opencode/plugins/` layout, `.opencode/plugin-tests/`, `.opencode/agents/*.md` frontmatter.

**Plugins and tools:** the single `delegation-observer` plugin, its `lib/` package (journal/registry, handoff, ticket gate, envelope gate, routing gate, destination policy, errors), the ask-timeout watchdog, and the `log_decision` / `fetch-source` tools. Deleted: needs-input, fast-resolve, preset guard, formatter, circuit breaker, capability, bash tripwire, `context_usage`, `get-my-session-id`, pending detectors, compaction snapshot, autocrine warn.

**Gates and scripts:** `Makefile`, `check-pin-sync.sh`, `check-omo-version-sync.sh`, `validate-plugin-structure.sh`, `validate-plugin-loads.sh`, `validate-observer-dedupe.sh`, `validate-opencode-config.sh`, `jsonc-parse.js`, `audit-agent-tool-coverage.sh`, `validate-skills.sh`, `test-builtin-containment.sh`, `batch-d-infra.test.mjs`, `overnight.sh`, `verify-pre-push.sh`, `test-docker-smoke.sh`, `session-analytics.sh` (retired), `ticker-render.sh` (deleted).

**Docs and memory:** `AGENTS.md` section 2.3 (capability bypass removed) and section 9 (`scout` removed), `docs/dev-infra-audit/inventory.md`, `.opencode/memory-shelf.yaml`, `.opencode/memory/*` references to `tui.json` / V1 plugin facts.

**Runtime state:** `dev_cache` / `dev_state` (V1 rollback point), `dev_v2_cache` / `dev_v2_state`, `.opencode/session/handoffs/*`, `registry.jsonl`, `messages.jsonl`, OMO caches. All gitignored.

**No Poetry Platform application code changes. No product behavior change.**

## Testing Decisions

> Per `openspec/config.yaml`: state what makes a good test, which modules are tested, and the prior art. Seams are restricted to repositories that already exist; the previous draft's invented validator and fleet scripts are cut (`ARC-5`).

### What makes a good test here

1. **Behavioral plugin tests at the production import seam**: call the real gate/service function or load the real plugin. A test fails when a gate stops firing, not when a source string moves.
2. **Effective-config assertions**: resolve the last matching rule, assert the permission matrix and the no-mixed-format rule. The four hard-failing validators and the two vacuous readers are repaired, not bypassed.
3. **Runtime truth on `dev-v2`**: extend the existing `scripts/test-docker-smoke.sh` to assert the binary version, loaded OMO instance, plugin load, and fresh journal/handoff rows. Pin strings alone are insufficient (DIA-127 lesson).

The failure mode to avoid is the static source probe: `scripts/test-ticket-gate.sh` greps V1 literals and breaks on the port (`AUD-B4` class). Ported gates get behavioral tests.

### Modules tested (existing seams only)

- **Plugin behavior**: relocated `.opencode/plugin-tests/`, run by `make test-harness` (Makefile:388-390) and `make test-typecheck`.
- **Config and permissions**: `make test-config` (Makefile:257-300) with `jsonc-parse.js`, `audit-agent-tool-coverage.sh`, `validate-skills.sh`, `test-builtin-containment.sh`, `batch-d-infra.test.mjs`, `validate-observer-dedupe.sh`, `validate-plugin-structure.sh`, `validate-plugin-loads.sh`.
- **Shell launchers**: `make test-shell` with `overnight.bats`, `test-config-wiring.bats`, `check-omo-version-sync.bats`.
- **Runtime**: existing `scripts/test-docker-smoke.sh`, extended for the `dev-v2` service.
- **Pins**: existing `scripts/check-pin-sync.sh` and `scripts/check-omo-version-sync.sh`, updated to per-service assertions.

No `validate-agent-permissions.sh`, no `smoke-agent-fleet.sh`, no `smoke-container-runtime.sh`. The permission matrix is asserted inside `audit-agent-tool-coverage.sh`; runtime health stays in `test-docker-smoke.sh` (`ARC-5`).

### Prior art

`ticket-gate.test.mjs`, `handoff.test.mjs`, `registry.test.mjs`, `envelope-gate.test.mjs`, `routing-order-gate.test.mjs`, `destination-policy.test.mjs`, `test-config-wiring.bats`, `overnight.bats`, `check-omo-version-sync.bats`, `validate-plugin-structure.bats`, and `test-docker-smoke.sh`.

### What we explicitly do NOT test

- Real overnight wall-clock behavior; the watchdog gets a short-threshold test and one headless `run --auto` smoke.
- Worktree lock races; V2 has no lock (`NAT:347-356`).
- A V2 rewrite of `session-analytics.sh`; it is retired and a follow-up ticket records the rewrite (`AUD-m4`).
- Global host config under `~/.config/opencode/`.

### Test risk and mitigation

- **Risk:** static probes rot. **Mitigation:** rewrite `test-ticket-gate.sh` behaviorally and retarget `validate-plugin-loads.sh` in the port slice.
- **Risk:** vacuous validator passes after renames. **Mitigation:** `validate-observer-dedupe.sh` reads `cfg.plugins ?? cfg.plugin` and fails on empty; `jsonc-parse.js` reads `cfg.agents ?? cfg.agent` and fails on zero agents (`AUD-m3`).
- **Risk:** permission coverage measured by rule presence. **Mitigation:** `audit-agent-tool-coverage.sh` resolves the effective matrix and fails on leftover V1 keys; per-agent verification runs on `dev-v2` with `opencode debug agents` (plural) or `api agent.get`.
- **Risk:** shared postgres causes test contention between `dev` and `dev-v2`. **Mitigation:** serialize DB-mutating suites or use a separate schema; documented in the cutover task.

## Non-goals

- No Poetry Platform application code or product spec changes.
- No in-place V1 cutover; the V2 service is a peer until every gate passes.
- No shared working directory between services; both mount the repo, but `dev` works at `/workspace` and `dev-v2` at `/workspace/.worktrees/opencode-v2`.
- No waiting marker, ticker renderer, toast, or title machinery.
- No `mint_capability` / capability-token bypass; only the procedural `scripts/tickets new` carve-out survives.
- No rewrite of `session-analytics.sh` in this change; retire it and record a follow-up.
- No new validator or smoke scripts; extend existing ones.
- No `.sdd/` edits; ADR 11 and ADR 15 are preconditions and are cited, not restated.
- No edits under `docs/dev-infra-audit/tickets/`.
- No re-introduction of deleted mechanisms behind a flag.

## Alternatives considered

- **In-place cutover on the single `dev` service.** Rejected by ADR 11 decision 2 and `ARC-3`: V2 config/plugins would break the live V1 workstation as soon as they land, halting day-to-day work; it also provided no live per-agent verification path (`AUD-B1`). Tier-1: `REGISTER` section 3; `MIG:175-258`.
- **Disposable V2 probes only, no parallel service.** Rejected by ADR 11 decision 2 and `ARC-3`: it drifts from the real compose/volume topology and defers container verification to the final step. Tier-1: `.sdd/dev-infra/architecture.md:109`.
- **Parallel V2 service with a shared working directory.** Rejected by the developer refinement and ADR 11 decision 3's isolation principle: a shared working root would let V2 config conversion change the files the live V1 service reads, reproducing `AUD-B1` through compose. Tier-1: `opencode-overnight.jsonc:240-245` shows the worktree model already supported.
- **Parallel V2 service with a separate worktree and isolated volumes (chosen).** Day-to-day V1 work never stops; every V2-only config change lands in `.worktrees/opencode-v2`; `dev-v2` is proven before conversion; V1 volumes remain the rollback point. Tier-1: ADR 11 decisions 2-3; ADR 15; `REGISTER` section 5.
- **Status quo / stay on V1.** V1 works today, but the runtime pin is misreported, gates are red, and the rewrite cost only grows. Rejected. Tier-1: measured baseline; `MIG:29-52`.

**Chosen option:** parallel `dev-v2` service with an isolated worktree and volumes, delete-first porting, V2 runtime proof before any conversion, then V1 retirement, because it is the only topology that satisfies ADR 11 while keeping the live V1 service as the rollback path.

## Rollback Plan

**Conversion is last.** The V1 service, its volumes, and the main workspace remain untouched through deletion, simplification, plugin porting, and V2 runtime proof. No V2-only config lands in the V1 workspace. The V2 work is a peer service and a separate worktree until cutover.

**Snapshot before the first destructive step (S0).** Record: git HEAD `da41b18c` plus dirty entries, `.opencode/` and config copies, V1 binary path/version and mise state, cache contents, `dev_cache` / `dev_state` volume state, image ids, compose service definitions. The environment snapshot is the real rollback asset; the tag is secondary.

| Artifact                                        | Revert                                                                  |
| ----------------------------------------------- | ----------------------------------------------------------------------- |
| V2 compose service / worktree                   | Remove `dev-v2`, delete `.worktrees/opencode-v2`; `dev` is unaffected   |
| Deletion slices on the migration branch         | `git revert`; committed before the tag                                  |
| Plugin ports                                    | `git revert` to the V1 tree; V1 code paths remain until the tag         |
| Permission/config conversion on the V2 worktree | `git revert` each agent atomically; pre-conversion matrix is the oracle |
| Pin/install changes                             | `git revert`; rebuild the V1 image from its corrected ARG               |
| `dev_cache` / `dev_state`                       | Never deleted before merge; they are the V1 rollback point              |
| `dev_v2_cache` / `dev_v2_state`                 | Disposable; recreated from the V2 pins                                  |
| Workspace                                       | Never touched by the V2 service; `dev-v2` uses `.worktrees/opencode-v2` |

**Cutover destruction policy (S10b).** Safe to destroy: the V1 **container/service** after the V2 gates pass. Not safe until the branch merges: `dev_cache` and `dev_state` (V1 rollback point). Never: the workspace. Postgres may stay shared; note the test-contention caveat.

**Irreversible after the tag:** retiring the V1 container and merging the V2-only branch. Restoring V1 after the merge requires the snapshot, the V1 volumes (if retained), and a V1 reinstall. The annotated tag `opencode-v2-irreversible` is created immediately before the V1 service is retired, and the V1 volumes are held until the merge completes.

<!--
ownership:
  substance: developer (decisions + ADR 11/15; DIA-261112-exon)
  structure: AI (@openspec-plan)
  revision: post-audit revision 2
-->
