# Tasks: opencode-v2-migration (revision 2, post-audit)

> **Proposal:** `openspec/changes/opencode-v2-migration/proposal.md`
> **Design:** `openspec/changes/opencode-v2-migration/design.md`
> **Ticket:** DIA-261112-exon
> **Binding ADRs:** `.sdd/dev-infra/architecture.md` ADR 11 (lines 94-109) and ADR 15 (lines 139-155).
> **Workflow:** one slice at a time, one fresh context window per group. Each checkbox is independently verifiable. Do not batch deletions or ports across groups.

## Corrected spine (from design D3)

```
S0 -> S1.1 -> S6 -> S2 -> S3.1-3.2 -> S4 -> S9 -> S10a -> S5 -> B4 -> S7 -> S8 -> S10b
```

Translated to this file's groups:

```
0 -> 1 -> 2 -> 3 -> 4 -> 5 -> 6 -> 7 -> 8 -> 9 -> 10 -> 11 -> 12
```

**Why this order.** Layer 3 gates and the Layer 2 evaluate hook can only be verified on a live V2 service, so the plugin port (6), then the V2 runtime gate (7), precede any config conversion (8, 10, 11). Deletion and simplification (3-5) shrink the port surface. Probes (2) precede every port decision. V1 is retired only in 12.

**No false parallelism.** S5 was previously claimed parallel with S1.3-1.5/S6.4; it is not, because all edit `opencode.jsonc` / `oh-my-opencode-slim.jsonc`. S9.5/S9.6 were claimed parallel; they edit the same `subagent` `execute.before` block, so they are merged in task 6.5. The only documented parallel-safe split is task 6.12 (see its annotation).

## Slice map

| Group | Slice    | Outcome                                                         | Blockers | Primary gates                                                                                                                                  | Parallel-safe?          |
| ----- | -------- | --------------------------------------------------------------- | -------- | ---------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------- |
| 0     | S0       | Branch, worktree, snapshot, true baseline                       | none     | step-by-step `make test-config`, `make test-shell`, `make test-typecheck`                                                                      | No                      |
| 1     | S1.1     | `dev-v2` service + per-service install/pin truth                | 0.3      | `make check-compose-config`, `bash scripts/check-pin-sync.sh`, `bash scripts/check-omo-version-sync.sh`, `make test-config`, `make test-shell` | No                      |
| 2     | S6       | Probe matrix on `dev-v2`                                        | 1.7      | probe matrix in design; no repo gate                                                                                                           | No; probes are the gate |
| 3     | S2       | Self-contained tier and explicit cuts deleted; C3 shrink        | 2.5      | `make test-config`, `make test-harness`, `make test-typecheck`, `make test-shell`                                                              | No; shared plugin file  |
| 4     | S3.1-3.2 | Needs-input tier deleted; pre-push/hook repairs                 | 3.8      | `make test-config`, `make test-shell`, `make test-harness`                                                                                     | No                      |
| 5     | S4       | Journal/stall/fetch simplified                                  | 4.3      | `make test-config`, `make test-harness`, `make test-typecheck`                                                                                 | No                      |
| 6     | S9       | One plugin ported to V2 (layout, gates, tools, watchdog)        | 5.4      | `make test-typecheck`, `make test-config`, `make test-harness`                                                                                 | Only 6.12               |
| 7     | S10a     | V2 runtime proven on `dev-v2`; V1 untouched                     | 6.13     | `scripts/test-docker-smoke.sh`                                                                                                                 | No                      |
| 8     | S5       | Config dead weight; top-level container renames; scout/tui      | 7.3      | JSONC parse + targeted validators; full `make test-config` in 9.6                                                                              | No                      |
| 9     | B4       | Four hard-failing validators + two vacuous readers repaired     | 8.5      | `make test-config` green checkpoint                                                                                                            | No                      |
| 10    | S7       | Permission conversion: baseline + 4 critical agents + overnight | 9.6      | `make test-config`, `make test-shell`, `opencode debug agents` / `api agent.get` on `dev-v2`                                                   | No; same config file    |
| 11    | S8       | Remaining agents converted; final no-V1-key mode                | 10.9     | `make test-config`, `opencode debug agents` / `api agent.get` on `dev-v2`                                                                      | No                      |
| 12    | S10b     | V1 service retired; full gates on V2; merge                     | 11.3     | `make test-config`, `make test-shell`, `make test-harness`, `make test-typecheck`, `make test-infra`, `scripts/test-docker-smoke.sh`           | No                      |

---

## 0. Baseline, branch, worktree, snapshot (S0)

- [ ] 0.1 Create branch `feature/DIA-261112-exon-opencode-v2` and the worktree at `.worktrees/opencode-v2` from the main worktree with a direct `git worktree add` (the project script derives `.worktrees/feature-DIA-...` from the branch, so it cannot produce the fixed path the container contract uses), then copy the ADR 9 `.husky/_` shim manually. Record that the branch is ADR 2-compliant and the direct add is a path-only exception. Also record that `.worktrees/opencode-v2-analytics` must be created from the main worktree per DIA-202, never nested.
      **Blockers:** none.
      **Acceptance:** `git worktree list` shows `.worktrees/opencode-v2` on `feature/DIA-261112-exon-opencode-v2`; `git -C .worktrees/opencode-v2 status` succeeds; the ADR 9 `.husky/_` shim exists in the worktree; the snapshot records git HEAD `da41b18c` plus dirty entries, `.opencode/` and the four config files, V1 binary version/path and mise state, cache contents, `dev_cache` / `dev_state` volume state, image ids, and the current compose service definitions; the branch/path exception is recorded.
      **Gates:** `git worktree list`, `git -C .worktrees/opencode-v2 status`, `test -d .worktrees/opencode-v2/.husky/_`, `mise ls`, `opencode --version`.

- [ ] 0.2 Record the true baseline by running every `test-config` recipe step individually (Makefile:257-300), plus `make test-shell` and `make test-typecheck`; do not infer green from `make test-config` because it exits at `Makefile:260`.
      **Blockers:** 0.1.
      **Acceptance:** a table of step -> exit code -> first failure exists; steps after the OMO check are marked verified or mapped to a later group. C1 is closed.
      **Gates:** individual validators, `make test-shell`, `make test-typecheck`.

- [ ] 0.3 Record the ADR preconditions and the measured baseline in the change notes: ADR 11 amended at `.sdd/dev-infra/architecture.md:94`, ADR 15 added at `:139`; V1 1.18.32 via mise; OMO cache contents; healthy V1 plugin telemetry; red pin gates; git state.
      **Blockers:** 0.1.
      **Acceptance:** design and proposal cite the ADRs and measurements; no later group re-derives them; no `.sdd/` edit is made by this change.

## 1. Parallel V2 service and pin authority (S1.1)

- [ ] 1.1 Add the `dev-v2` compose service per ADR 11 decisions 2-3 and the container wiring contract (design D1a): `.:/workspace` with `working_dir: /workspace/.worktrees/opencode-v2` (NOT a single-directory worktree mount, which would hide `/workspace/.git/objects`), `pnpm_store_v2:/workspace/.worktrees/opencode-v2/node_modules`, its own `dev_v2_cache` and `dev_v2_state`, its own image tag, container name and hostname `poetry-dev-v2`, host ports 9100/8100/3100 (env-overridable), and the shared `postgres` on `poetry-net`. `dev` keeps `.:/workspace`, `pnpm_store`, its existing volumes, and ports 9000/8000/3000.
      **Blockers:** 0.3.
      **Acceptance:** `docker compose config` shows the full-repo mount and the worktree working_dir for `dev-v2`; distinct images, container names, hostnames, cache/state volumes, and pnpm stores; published host ports 9100/8100/3100 do not overlap `dev`'s 9000/8000/3000; `dev` is unchanged; no service is started until 1.2 builds the V2 image. The in-container `git status` proof is 1.2.
      **Gates:** host `make check-compose-config`, host `docker compose config`.

- [ ] 1.2 Install authority: remove the `.mise.toml` `opencode` key; install an exact, verified `@opencode/cli` V2 release in the V2 image with npm integrity checking; assert `opencode --version` at build and service startup; correct the V1 service's `OPENCODE_VERSION` to the measured 1.18.32.
      **Blockers:** 1.1.
      **Acceptance:** neither service resolves a mise shim; the V1 service asserts 1.18.32; the V2 service builds and starts; `docker compose exec dev-v2 opencode --version` matches its ARG; `docker compose exec dev-v2 git -C /workspace/.worktrees/opencode-v2 status` succeeds (the worktree `.git` file resolves to the real object store) and the ADR 9 husky shim exists; a wrong ARG fails the build or startup.
      **Gates:** image builds, `opencode --version` in both services, `git status` in `dev-v2`, `test -d /workspace/.worktrees/opencode-v2/.husky/_` in `dev-v2`, `make test-config`.

- [ ] 1.3 Make the pin gates per-service and meaningful: `check-pin-sync.sh` keeps three static toolchain pairs plus a per-service OpenCode declared-vs-runtime assertion; `check-omo-version-sync.sh` resolves per-service config/tui/build sources plus the loaded cache. V1 stays OMO 2.2.19; the V2 service moves its three V2-side declarations to 3.0.7 together.
      **Blockers:** 1.2.
      **Acceptance:** a V1/V2 pin mismatch fails; a matching pair passes; the gate is not a tautology and is not shrunk to three pins.
      **Gates:** `bash scripts/check-pin-sync.sh`, `bash scripts/check-omo-version-sync.sh`, `make test-config`.

- [x] 1.4 Ponytail: provisionally remove the unpinned `@dietrichgebert/ponytail` entry from the V2 config rather than float it. The exact pin decision is closed by probe 2.3 and task 2.6.
      2026-11-26 decided (DIA-261112-exon): keep the ponytail plugin as-is, no code or config change; the ruleset plugin imposes no V2 key or API constraint, so removal is unnecessary.
      **Blockers:** 1.2.
      **Acceptance:** the V2 plugin array carries no unpinned Ponytail entry; the exact-pin decision is explicitly pending 2.6.
      **Gates:** `make test-config`.

- [ ] 1.5 Envsitter: provisionally remove `envsitter-guard@0.0.4` from the V2 config and rely on the native `read *.env` ask rules. The re-add decision is closed by probe 2.3 and task 2.6.
      **Blockers:** 1.2.
      **Acceptance:** no unpinned third-party guard remains in the V2 config; env reads still resolve to `ask`; the final decision is pending 2.6.
      **Gates:** `make test-config`.

- [ ] 1.6 AUD-N2: use only real gates. Do not name `make check-omo-version-sync` (it does not exist; `Makefile:260` is a recipe step). If a dedicated target is desired, add it to `Makefile`; otherwise use `bash scripts/check-omo-version-sync.sh` and `make test-config`.
      **Blockers:** 1.3.
      **Acceptance:** every task acceptance command exists and runs; no phantom make target is referenced.
      **Gates:** `bash scripts/check-omo-version-sync.sh`, `make test-config`.

- [ ] 1.7 Verify isolation: no shared working directory, cache, state, pnpm store, or binary between `dev` and `dev-v2`; record the compose diff and the volume names.
      **Blockers:** 1.1-1.6.
      **Acceptance:** a mount/volume matrix shows zero overlap except the repo mount and `postgres`; `pwd` is `/workspace` in `dev` and `/workspace/.worktrees/opencode-v2` in `dev-v2`; each service reads its own `.opencode`; `dev` remains on V1 and untouched.
      **Gates:** host `docker compose config`, `docker volume ls` (host), `docker compose exec dev pwd`, `docker compose exec dev-v2 pwd`.

- [ ] 1.8 N3 container detection: update `scripts/in-container.sh:11` to accept both `poetry-dev` and `poetry-dev-v2` via an explicit allowlist, and extend `scripts/__tests__/check-compose-config.bats` (it sources the detector and exercises the in-container path) plus the hostname mocks in `scripts/__tests__/check-stack-ready.bats` and `scripts/__tests__/compose-overrides.bats` where they assert the detector.
      **Blockers:** 1.1, 1.2.
      **Acceptance:** `docker compose exec dev-v2 bash -lc 'source scripts/in-container.sh && is_in_dev_container && echo ok'` exits 0; the same check inside `dev` still exits 0; the same check on the host returns non-zero; the extended bats suites pass.
      **Gates:** `make test-shell` (check-compose-config.bats, check-stack-ready.bats, compose-overrides.bats).

## 2. Probe matrix on dev-v2 (S6)

- [ ] 2.1 Start `dev-v2` with the V2 image and the worktree config; record the expected V1 plugin-load failures as the pre-port baseline.
      **Blockers:** 1.7.
      **Acceptance:** the service is up; `opencode --version` is V2; OMO 3.0.7 is present in `dev_v2_cache`; V1 `dev` state is unchanged.

- [ ] 2.2 Run the 9 conspect probes (`NAT:499-541`) and record observed results in the design probe matrix. P1 is confirmed, not re-discovered; P2 is answered by source (`gh-tool-subagent.ts:138-145`) and is not a live probe.
      **Blockers:** 2.1.
      **Acceptance:** each row has an observed result and an evidence pointer; no row says "assumed"; Probe P4 explicitly checks whether `.opencode/plugins/lib/` and `.opencode/plugins/__tests__/` are probed as plugin packages.

- [ ] 2.3 Run the pin/plugin probes: OMO 3.0.7 compatibility, Ponytail V2 release, `envsitter-guard@0.0.4` gap, `--auto` acceptance by the TUI (`scripts/overnight.sh:230`), and whether OMO 3.0.7 registers `cancel_task` / `wait_for_user`.
      **Blockers:** 2.1.
      **Acceptance:** each pin decision has a recorded answer; no target version is pinned on inference; the `--auto` outcome is recorded for task 10.7. If OMO 3.0.7 is incompatible with V2, stop and escalate to the developer; do not silently fall back to 2.2.19.

- [ ] 2.4 Confirm the in-plugin permission surfaces: `ctx.permission.list({sessionID})` and `ctx.permission.reply({sessionID, requestID, decision})`; confirm there is no `ctx.form` domain and no `ctx.permission.request.list`.
      **Blockers:** 2.1.
      **Acceptance:** the watchdog API shape in task 6.7 matches the observed host; the conflict in design D12 is closed by observation.

- [ ] 2.5 Resolve `context.directory` vs `ctx.location.directory` by source read (`gh-tool-subagent.ts:108-200`, `docs-build-plugins-server.md:820-835`); record the contract used by the tool ports.
      **Blockers:** 2.1.
      **Acceptance:** the tool-port contract table in design D9 matches the source; no path API is guessed.

- [ ] 2.6 Apply the pin probe outcomes: pin Ponytail exactly if a V2-compatible release exists, otherwise leave it removed; re-add `envsitter-guard` exact-pinned only if the native env asks leave a real gap; record each outcome.
      **Blockers:** 2.3.
      **Acceptance:** the V2 plugin array contains exact pins only, or no entry; the decision and evidence are recorded; group 8 does not reopen it.
      **Gates:** `make test-config`.

## 3. Delete the self-contained tier and explicit cuts (S2)

- [ ] 3.1 Delete the preset guard and its three suites. **Blockers:** 2.5. **Acceptance:** no production importer remains; `make test-typecheck` green.

- [ ] 3.2 Delete the A1 advisory, context policy/velocity, edit-time formatter, empty-result detection, failure cap, adaptive routing, apoptosis, circuit breaker, and paracrine heuristics, plus their suites and harness scenarios.
      **Blockers:** 2.5.
      **Acceptance:** no surviving hook fires these paths; deleted suites are removed, not skipped; `make test-harness` green.

- [ ] 3.3 Delete capability minting and `lib/capability`, the `mint_capability` tool, and its tests. Update `AGENTS.md` section 2.3 to remove the capability-token bypass; only the procedural `scripts/tickets new` carve-out remains (developer decision 6).
      **Blockers:** 2.5.
      **Acceptance:** no capability lib, tool, or token path remains; the ticket gate has one documented no-ticket path; no dangling prompt/doc references.
      **Gates:** `make test-config`, `make test-shell`.

- [ ] 3.4 Delete `context_usage` and `get-my-session-id` tools and their tests; native `context.sessionID` / `context.agent` replace the helper.
      **Blockers:** 2.5.
      **Acceptance:** no caller references either deleted tool; the tool surface is the surviving set.
      **Gates:** `make test-typecheck`, `make test-config`.

- [ ] 3.5 Delete the bash tripwire (`lib/bash-write-gate.ts` and `tripwire-classifier.test.mjs`) and remove its `Makefile` wiring.
      **Blockers:** 2.5.
      **Acceptance:** no production importer; the protected-path gate remains.
      **Gates:** `make test-config`, `make test-typecheck`.

- [ ] 3.6 AUD-m2: delete the never-listed V1 hooks in the same edit set: the compaction snapshot (`experimental.session.compacting`), the `autocrine_gate_warn` advisory, and the `conspect-pending.json` / `analysis-pending.json` detectors (the last two are the AUD-B3 decision in design D7).
      **Blockers:** 2.5.
      **Acceptance:** every V1 hook in the old entry is either in the surviving set or deleted; no hook is unlisted.
      **Gates:** `make test-harness`, `make test-typecheck`.

- [ ] 3.7 AUD-B2 routing correction: remove the paracrine row scan from `lib/routing-gate.ts:84-90` and make the gate accept an injected prior-dispatch marker in the same commit that deletes the rows. The `ctx.storage` binding lands with the V2 dispatcher in 6.5 (design D4).
      **Blockers:** 3.2.
      **Acceptance:** the routing gate no longer reads deleted rows; it still blocks the out-of-order dispatch case and passes the verification-only case with the injected marker.
      **Gates:** `make test-harness`, `make test-config`.

- [ ] 3.8 Shrink `validate-plugin-structure.sh` in the same edit set (C3): `retained`, `gateA_symbols`, and `prohibited_symbols` cover only surviving libs; remove capability/formatter/circuit-breaker; update `validate-plugin-structure.bats` fixtures. Update the batch-D manifest and any static test that enumerates deleted files or behavior.
      **Blockers:** 3.1-3.7.
      **Acceptance:** the structural gate passes against the surviving libs and would fail a re-introduced duplicate; no suite is skipped to hide a deletion; `make test-config`, `make test-harness`, `make test-shell` are green.

## 4. Needs-input deletion and pre-push repairs (S3.1-3.2)

- [ ] 4.1 Record the locked disposition: variant B without the waiting marker (design D5). No decision gate remains.
      **Blockers:** 3.8.
      **Acceptance:** the change records "delete the tier, keep only the watchdog"; the marker, ticker, toast, and title machinery are out of scope.

- [ ] 4.2 Delete the V1 needs-input tier: `needs-input-observer.ts`, `lib/permission-fast-resolve.ts`, the six suites, `ticker-render.sh`, and the toast/title machinery. Repair the three references: the pre-push toast leg (`verify-pre-push.sh:170`), its bats assertions (`verify-pre-push.bats:194-199`, `:378`), and the batch-D file manifest (`batch-d-infra.test.mjs:653-656`).
      **Blockers:** 4.1.
      **Acceptance:** no needs-input or fast-resolve production file remains; no `ticker.json`/`ticker.md` consumer remains; `verify-pre-push` names no deleted suite.
      **Gates:** `make test-config`, `make test-shell`, `make test-harness`.

- [ ] 4.3 Remove every `ctx.storage` waiting-marker reference from the design/tasks and the surviving code plan; the native session list is the visibility surface. Confirm no task reintroduces `form.list` or a marker.
      **Blockers:** 4.2.
      **Acceptance:** grep finds no waiting-marker key in the port plan; the watchdog in task 6.7 is the only needs-input residue.

## 5. Simplify journal, stall, and fetch (S4)

- [ ] 5.1 Simplify the registry/journal: drop lifecycle heuristics and state the port will not carry; keep the append-only audit trail, boot reconstruction inputs, and file locking/sequence reservation (ADR 15 decision 2). Target ~400 lines.
      **Blockers:** 4.3.
      **Acceptance:** every surviving row type has a consumer; no dead event branch remains; a scripted session still writes registry/messages rows.
      **Gates:** `make test-harness`, `make test-typecheck`.

- [ ] 5.2 Keep the stall sweep as a ~60-line tail-read (design D4, decided). No open variant.
      **Blockers:** 4.3.
      **Acceptance:** one test proves detection on a stuck session and one proves no false positive on a healthy session.
      **Gates:** `make test-harness`.

- [ ] 5.3 Simplify `fetch-source` and the destination policy: keep the 4-tier chain, atomic publish, agent-scoped guard, and destination policy; target ~250 lines.
      **Blockers:** 4.3.
      **Acceptance:** the four tiers and deny destinations are still covered; a non-researcher caller is still rejected.
      **Gates:** `make test-config` (destination policy), `make test-typecheck`.

- [ ] 5.4 Rewrite the affected suites/harness scenarios to assert behavior, not deleted internals.
      **Blockers:** 5.1-5.3.
      **Acceptance:** `make test-harness` and `make test-config` are green; no suite is skipped.

## 6. Plugin consolidation and V2 port (S9)

- [ ] 6.1 AUD-M5/ARC-1 layout: consolidate to one plugin at `.opencode/plugins/delegation-observer/index.ts`, with `lib/` nested inside the package and tests moved to `.opencode/plugin-tests/` (outside the discovery root). Update `validate-observer-dedupe.sh:25`, `validate-plugin-structure.sh:17`, `validate-plugin-loads.sh`, the Makefile `test-harness` path, the plugin tsconfig, and the batch-D manifest in lockstep.
      **Blockers:** 5.4, 2.2 (P4).
      **Acceptance:** V2 discovery sees exactly one plugin package; `lib/` and tests are not immediate children of `.opencode/plugins/`; no validator references the old entry path.
      **Gates:** `make test-config`, `make test-typecheck`.

- [ ] 6.2 SDK swap: replace `@opencode-ai/plugin` with an exact `@opencode/plugin` pin; implement `Plugin.define({ id: "delegation-observer", setup(ctx) })`; return cleanup from `setup`; remove V1 hook-map registration.
      **Blockers:** 6.1.
      **Acceptance:** the plugin typechecks against the V2 SDK and loads on `dev-v2`; the id is the storage scope.
      **Gates:** `make test-typecheck`, `make test-config`.

- [ ] 6.3 Port the registry/journal: file-locked JSONL for the audit trail and sequence order; `ctx.storage` for volatile cross-session maps; `event.subscribe` for live rows; list APIs for boot rebuild. No CAS assumption.
      **Blockers:** 6.2.
      **Acceptance:** a scripted session produces the surviving rows; a reload rebuilds active state; no lost-update path is introduced.
      **Gates:** `make test-harness`.

- [ ] 6.4 Port handoff + `log_decision` with the full tool contract (design D9): JSON Schema `input`, `{ content }` return, `context.signal`, `ctx.location.directory`, `context.sessionID` / `context.agent`; gate-token writes go to `ctx.storage`.
      **Blockers:** 6.3.
      **Acceptance:** the handoff slot/pointer/checksum still work; a non-terminal event writes no handoff; `log_decision(gate-token)` writes a storage token; the tool is registered via `ctx.tool.transform`.
      **Gates:** `make test-harness`.

- [ ] 6.5 AUD-B2/B3 single `execute.before` dispatcher: port the ticket gate, reviewer envelope injection (replace `input.prompt`), and routing gate in ONE `tool.hook("execute.before")` handler for `event.tool === "subagent"`. Read `event.input.agent` / `event.input.sessionID`; block with model-visible `Tool.Error`; keep the envelope duplication guard. This task replaces the previously colliding S9.5/S9.6 split and is single-owner.
      **Blockers:** 6.2.
      **Acceptance:** one handler owns all three gates; an unresolved explicit ticket blocks; a valid ticket gets exactly one envelope; an out-of-order dispatch is blocked; no `subagent_type` or `task_id` read remains.
      **Gates:** `make test-harness`, `make test-config`.

- [ ] 6.6 AUD-B3 completion tracking: subscribe to `session.idle` / `session.execution.*` and correlate the immediate `{ sessionID, status: "running" }` return; use `execute.after` only for immediate correlation, never for child output. The pending detectors are already deleted in 3.6.
      **Blockers:** 6.5.
      **Acceptance:** a background child is marked complete only on an event; no code path expects `<task_result>` in `execute.after`; a child failure is recorded.
      **Gates:** `make test-harness`.

- [ ] 6.7 AUD-M2/ARC-6 watchdog: ~30-40 LOC, no marker. Track `{sessionID, requestID, askedAt}` from `permission.asked` / `form.created`; on timeout call `ctx.permission.list({sessionID})`, match the still-pending `requestID`, then `ctx.permission.reply({sessionID, requestID, decision: "reject"})`. Reject is session-wide.
      **Blockers:** 6.2, 2.4.
      **Acceptance:** a short-threshold test proves one pending ask is rejected and all pending asks in that session are cleared; the test uses the observed API shapes; no `ctx.form` or `ctx.permission.request.list` call exists; no marker is written.
      **Gates:** `make test-harness`.

- [ ] 6.8 AUD-M3 `fetch-source` port: register via `ctx.tool.transform` with JSON Schema input, `{ content }` return, `context.signal` passed to fetch, `context.agent` guard, and `ctx.location.directory`; keep the 4-tier chain, atomic publish, and destination policy. After both tools are registered, delete `.opencode/tools/`.
      **Blockers:** 6.2.
      **Acceptance:** researcher succeeds; other agents fail model-visibly; cancellation aborts the fetch; `.opencode/tools/` is gone and nothing auto-loads.
      **Gates:** `make test-config`, `make test-harness`.

- [ ] 6.9 AUD-B2 Layer 2 hook: implement `permission.hook("evaluate")` and the `ctx.storage` gate-token carrier in the ported plugin. The `.opencode/**` and `AGENTS.md` `ask` base rules are appended at the END of the coder permissions in task 10.3, because they must be written in the same atomic edit as the agent conversion (design D6). The hook upgrades `effect === "ask"` to allow only on a valid token and otherwise sets `deny`; never leave `ask`; never use a `deny` base (the hook is skipped) and never use `policies` for this.
      **Blockers:** 6.4.
      **Acceptance:** a synthetic `ask` event with a valid token becomes allow; without a token or with an expired token it becomes deny; the hook never runs on a configured deny; the end-to-end edit cases are exercised in 10.6.
      **Gates:** `make test-harness`, `make test-config`.

- [ ] 6.10 AUD-B2/C4: rewrite `test-ticket-gate.sh` behaviorally against the ported gate (or a static probe against the V2 entry), keeping the four assertions: tri-state explicit-ID resolution, narrowed exemption regex, config-work hint, weak-correlation branch.
      **Blockers:** 6.5.
      **Acceptance:** the probe passes on the port and fails when a gate branch is removed; it no longer greps V1 source literals.
      **Gates:** `make test-config`.

- [ ] 6.11 AUD-M5/C10: retarget `validate-plugin-loads.sh` to the V2 package entry and wire it into `make test-config`; if a static import cannot prove V2 load, replace it with a load assertion inside `test-docker-smoke.sh` and document why.
      **Blockers:** 6.1, 6.2.
      **Acceptance:** the load gate is either wired or explicitly replaced; no orphaned V1-shaped script remains.
      **Gates:** `make test-config`.

- [ ] 6.12 AUD-m4/ARC-5: retire `scripts/session-analytics.sh` and its make target; it calls the removed V1 CLI (`opencode db` at `:152,165`, `opencode stats` at `:209`). Record the V2 rewrite (`opencode debug paths db` + sqlite3) as a follow-up ticket. Do not add `validate-agent-permissions.sh` or `smoke-agent-fleet.sh`; the matrix assertion lives in `audit-agent-tool-coverage.sh` and runtime health in `test-docker-smoke.sh`.
      **Blockers:** 3.8.
      **Acceptance:** no make target or doc points at the dead script; no new validator/smoke script exists; the follow-up is recorded.
      **Gates:** `make test-config`, `make test-shell`.
      **Parallel-safe:** may be deferred to run in a second worktree `.worktrees/opencode-v2-analytics`, created from the main worktree per DIA-202 on a `feature/DIA-261112-exon-analytics` branch cut from the migration branch (never nested inside `.worktrees/opencode-v2`; use the same direct `git worktree add` + ADR 9 husky-copy exception as task 0.1) while group 10 or 11 edits only `opencode.jsonc` / `.opencode/agents/*.md`. The file sets are disjoint (scripts/Makefile/docs vs config/agent files), and neither lane runs `make test-config` as a pass gate until merged.

- [ ] 6.13 Rewrite/retain the plugin suites against the V2 entry; run the full plugin surface.
      **Blockers:** 6.2-6.12.
      **Acceptance:** every surviving gate has a behavioral test; deleted gates have no skipped test; `make test-typecheck`, `make test-config`, `make test-harness` are green.

## 7. V2 runtime gate (S10a)

- [ ] 7.1 Start `dev-v2` with the ported plugin and the V2 config; confirm zero plugin-load errors and that the single plugin is the only discovered package.
      **Blockers:** 6.13.
      **Acceptance:** the plugin loads; `health check passed` reports the agent/tool/MCP counts; no `lib/` or test directory is discovered.
      **Gates:** service logs, `dev-v2` startup.

- [ ] 7.2 Extend `scripts/test-docker-smoke.sh` for `dev-v2` (existing seam, no new script): assert `opencode --version` equals the V2 ARG, OMO 3.0.7 is the loaded instance, Ponytail/OpenSpec load, and a scripted session writes fresh journal/handoff rows. Include the V1 service as a non-regression check.
      **Blockers:** 7.1.
      **Acceptance:** the smoke passes on `dev-v2`; the V1 service still passes its own smoke; no shared cache/state path is used.
      **Gates:** `scripts/test-docker-smoke.sh` (host with engine), `make test-infra`.

- [ ] 7.3 Record the S10a gate: `dev-v2` is proven, V1 remains day-to-day, and no config conversion has occurred yet.
      **Blockers:** 7.2.
      **Acceptance:** the evidence is recorded in the change; the next group may edit the V2 worktree config only.

## 8. Config dead weight and top-level containers (S5)

- [ ] 8.1 Delete the ollama provider and its three models, `lsp`, `compaction.prune`, the inert `ai-specialist.temperature`, the council seats identified in `BRIEF:116`, and `scout` (AUD-N1).
      **Blockers:** 7.3.
      **Acceptance:** no agent/command references the removed provider or models; `lsp` is gone; `scout` is gone; the config parses.
      **Gates:** JSONC parse; targeted `make test-config` steps (full green in 9.6).

- [ ] 8.2 C8: rename `compaction.reserved` to `compaction.buffer`; rename agent `disable` to `disabled`; resolve `disabled_agents` from the probe (fallback: per-agent `disabled: true`).
      **Blockers:** 8.1.
      **Acceptance:** no deprecated key remains where C8 names it; the built-in agents stay disabled.
      **Gates:** JSONC parse; agent-name lockstep after 9.6.

- [ ] 8.3 AUD-M1 unlisted conversions: convert `plugin` to `plugins` (object form with `{ package, options }`), `skills.urls` to one ordered `skills` array, and `mcp` servers to `mcp.servers` in the V2 config; record any key V2 accepts unchanged instead of inventing a conversion.
      2026-11-26 (DIA-261112-exon): the `plugin` -> `plugins` key conversion is applied in the V2 tree with the existing string entries preserved; the `skills.urls` and `mcp.servers` conversions remain pending.
      **Blockers:** 8.1.
      **Acceptance:** the V2 service loads the converted config without warnings for these containers; no V1-only form remains where the migration map names a V2 form.
      **Gates:** `dev-v2` startup warnings, JSONC parse.

- [ ] 8.4 AUD-N1 docs: remove `scout` from `AGENTS.md` section 9 and from the inventory/memory descriptions; update references to the deleted provider/compaction keys and `tui.json`.
      **Blockers:** 8.1.
      **Acceptance:** no doc claims `scout` exists or lists the deleted config; `make test-config` doc-contract steps pass after 9.6.

- [ ] 8.5 C2 tui deletion: after the V2 panel probe confirms it, delete `.opencode/tui.json` and retarget `check-omo-version-sync.sh` (tui leg at `:10`, `:21`, `:24`, `:34`), `validate-observer-dedupe.sh:50`, `validate-opencode-config.sh:22`, `check-omo-version-sync.bats`, `inventory.md:62`, and the `memory-shelf.yaml:1405` / `memory/repo.md` references. If the panel needs a project entry, keep a single mirror and retain the three-way gate.
      **Blockers:** 7.3, 2.2.
      **Acceptance:** no gate or inventory references a deleted file; the OMO panel still loads on `dev-v2`; the pin gate is per-service and meaningful.
      **Gates:** `make test-config`, `make test-shell`.

## 9. B4 validator repairs and vacuous readers

- [ ] 9.1 AUD-B4b: repair `test-builtin-containment.sh:79-85` for `disabled` (not `disable`), the V2 `subagents` action (not `permission.task`), and the removed `scout` expectations.
      **Blockers:** 8.5.
      **Acceptance:** the gate passes on the V2 shapes and still fails on a real containment regression.
      **Gates:** `make test-config`, `make test-shell`.

- [ ] 9.2 AUD-B4a: repair `audit-agent-tool-coverage.sh:159-163` to accept V2 `permissions` arrays and `agents`; add the effective-matrix assertion and the fail-on-leftover-V1-key check that replaces the invented `validate-agent-permissions.sh` (`ARC-5`). Keep a dual-shape mode until group 11.
      **Blockers:** 8.5.
      **Acceptance:** the gate passes on the V2 shapes; it fails on a leftover V1 key, a mixed-format agent, or a dropped deny.
      **Gates:** `make test-config`.

- [ ] 9.3 AUD-B4c: repair `.opencode/scripts/validate-skills.sh:437-448` for `commands` / `agents` renames, dual-shape until group 11.
      **Blockers:** 8.5.
      **Acceptance:** the gate passes on the V2 shapes and still validates every skill.
      **Gates:** `make test-config`.

- [ ] 9.4 AUD-B4d: repair `batch-d-infra.test.mjs:293-323` for `agents` and `permissions` arrays; leave the S8-specific assertions (`:294-322`) for task 11.2.
      **Blockers:** 8.5.
      **Acceptance:** the suite passes on the V2 shapes; it still asserts the invariants it was created to protect.
      **Gates:** `make test-config`.

- [ ] 9.5 AUD-m3: fix the two vacuous readers. `validate-observer-dedupe.sh:80` must read `cfg.plugins ?? cfg.plugin`, handle `{package, options}` entries, and fail on an empty result. `jsonc-parse.js --doc-drift` must read `cfg.agents ?? cfg.agent` and fail on zero agents, never print a vacuous green.
      2026-11-26 (DIA-261112-exon): `validate-observer-dedupe.sh` now reads `cfg.plugins ?? cfg.plugin` and handles `{package, options}` entries; the `jsonc-parse.js --doc-drift` agents reader remains pending.
      **Blockers:** 8.5.
      **Acceptance:** a renamed-but-empty config fails both gates; the positive path still passes.
      **Gates:** `make test-config`, `make test-shell`.

- [ ] 9.6 B4 checkpoint: run the full `make test-config` on the V2 worktree with all four validators and both readers repaired.
      **Blockers:** 9.1-9.5.
      **Acceptance:** `make test-config` exits 0 with no skipped validator; the run log is recorded.
      **Gates:** `make test-config`.

## 10. Permissions: baseline and critical agents (S7)

- [ ] 10.1 AUD-M1/ARC-4 atomic conversion foundation: change top-level `agent` to `agents` once; convert the global baseline `permission` map to an ordered `permissions` array; convert each critical agent's entire nested entry plus `.opencode/agents/<name>.md` frontmatter in one edit (`permissions`, `disabled`, `steps`, `system`, hex-only `color`); remove V1 siblings (`permission`, `disable`, `maxSteps`, `prompt`, `tools`, `temperature`). `ai-specialist` color `"info"` becomes a hex value (`opencode.jsonc:714`).
      **Blockers:** 9.6.
      **Acceptance:** no agent entry contains both formats; the effective baseline matches the pre-conversion matrix; no leftover V1 key exists in the converted entries.
      **Gates:** `make test-config` (audit-agent-tool-coverage leftover-key mode).

- [ ] 10.2 AUD-m1 orchestrator: convert atomically and delete the orphan V1 permission keys (`doom_loop`, `lsp`, `list`, `apply_patch`, the 23 `envsitter_*` entries, `mint_capability`). Keep `cancel_task` / `wait_for_user` only if probe 2.3 confirms OMO 3.0.7 registers them.
      **Blockers:** 10.1.
      **Acceptance:** the orchestrator cannot perform engineering work itself; the dispatch allow-list survives; no orphan key remains.
      **Gates:** `make test-config`, per-agent verification (10.9).

- [ ] 10.3 coder: convert atomically; append the `.opencode/**` and `AGENTS.md` `ask` rules at the END of the permissions array (after broader edit allows).
      **Blockers:** 10.2.
      **Acceptance:** the permissions array matches the pre-conversion effective-matrix oracle apart from documented task keys; shell/edit flows behave as before; the protected-path ask is the last matching rule.
      **Gates:** `make test-config`, `make test-harness`.

- [ ] 10.4 reviewer: convert atomically; preserve the read-only and no-bash constraints and the envelope assumptions.
      **Blockers:** 10.3.
      **Acceptance:** reviewer can read, cannot perform the forbidden mutations; a benign review flow completes; the matrix matches the oracle.
      **Gates:** `make test-config`, per-agent verification.

- [ ] 10.5 researcher: convert atomically; preserve the `fetch-source` visibility allow and the destination policy.
      **Blockers:** 10.4.
      **Acceptance:** researcher can use `fetch-source`; other lanes still cannot; the matrix matches the oracle.
      **Gates:** `make test-config`, per-agent verification.

- [ ] 10.6 AUD-B2 Layer 2 verification: confirm the protected-path gate installed in 6.9 is reachable under the converted permissions; an edit without a token is denied, a valid token allows, an expired token is denied.
      **Blockers:** 10.3.
      **Acceptance:** the three token cases are exercised on `dev-v2`; no case leaves `ask`; the hook fires.
      **Gates:** `make test-harness`, `make test-config`.

- [ ] 10.7 AUD-M4 overnight: convert `permission.bash`, `permission.read`, and `permission.edit` in one pass; preserve the `.worktrees/*` read/edit rules and add `.worktrees/opencode-v2/*`; keep the 15-pattern baseline; validate last-match resolution, not key presence; drop `OPENCODE_UNATTENDED`; probe `--auto` and remove it from TUI mode if rejected (`scripts/overnight.sh:230`). Update `overnight.bats`.
      **Blockers:** 10.1, 2.3.
      **Acceptance:** a softened or missing deny rule exits 1 before launch; all 15 patterns resolve deny; headless `run --auto` still works; the TUI path matches the probe outcome.
      **Gates:** `make test-shell` (overnight.bats), `make test-config`.

- [ ] 10.8 Replace the invented permission validator: assert the effective matrix and the no-leftover-V1-key rule in `audit-agent-tool-coverage.sh`; switch it to final V2-only mode after group 11. No `validate-agent-permissions.sh`.
      **Blockers:** 10.2-10.7.
      **Acceptance:** the gate fails on a mixed-format or dropped-rule fixture and passes on the converted tree.
      **Gates:** `make test-config`.

- [ ] 10.9 Per-agent verification for the four critical agents on `dev-v2` with ported plugins: use `opencode debug agents` (plural) or `api agent.get`; exercise shell/edit/subagent flows; diff the effective matrix against the oracle; treat any load warning as a failure. Commit each agent separately.
      **Blockers:** 10.2-10.8.
      **Acceptance:** four verification records exist (commands, effective rules, flows, warnings); every delta is explained; V1 service is still untouched.

## 11. Permissions: remaining agents (S8)

- [ ] 11.1 Convert the remaining agents atomically (architector, analyzer, designer, observer, memory-manager, conspecter, openspec-plan, council, ai-specialist, ai-auditor, and any configured alias), including their `.opencode/agents/<name>.md` frontmatter.
      **Blockers:** 10.9.
      **Acceptance:** every agent has exactly one permission format; the effective matrix matches the oracle; zero load warnings.

- [ ] 11.2 AUD-B4d final: update `batch-d-infra.test.mjs:294-322` for the fully converted `agents` / `permissions` shapes and switch `audit-agent-tool-coverage.sh` and `jsonc-parse.js` to final V2-only mode (any leftover V1 key fails).
      **Blockers:** 11.1.
      **Acceptance:** reintroducing a V1 key fails `make test-config`; the tree passes final mode.
      **Gates:** `make test-config`.

- [ ] 11.3 Verify every remaining agent on `dev-v2` with `opencode debug agents` or `api agent.get`; record the matrix diff and any warning.
      **Blockers:** 11.2.
      **Acceptance:** every agent loads and completes a role-appropriate benign tool call; no deleted mechanism is required by an agent prompt.

## 12. Final cutover and V1 retirement (S10b)

- [ ] 12.1 Refresh the snapshot and create the annotated tag `opencode-v2-irreversible` immediately before V1 retirement; record the pins, image ids, snapshot path, volume state, and rollback window.
      **Blockers:** 11.3.
      **Acceptance:** the tag exists with the manifest; the snapshot restore drill (V1 1.18.32 + OMO 2.2.19 + healthy V1 plugins in a scratch environment) is recorded.

- [ ] 12.2 Retire the V1 `dev` container/service. Keep `dev_cache`, `dev_state`, and `pnpm_store` until the branch merges; never touch the workspace; keep `postgres` shared and record the DB test-contention caveat. Point the default workflow at `dev-v2`.
      **Blockers:** 12.1.
      **Acceptance:** `dev` is stopped/removed; `dev_cache`, `dev_state`, and `pnpm_store` still exist; the workspace is unchanged; `postgres` is reachable from `dev-v2`; the contention caveat is documented.
      **Gates:** host `docker compose config`, `docker volume ls` (host), `scripts/test-docker-smoke.sh`.

- [ ] 12.3 Run the full gate set on `dev-v2`: `make test-config`, `make test-shell`, `make test-harness`, `make test-typecheck`, `make test-infra`, and `scripts/test-docker-smoke.sh`.
      **Blockers:** 12.2.
      **Acceptance:** all exit 0; no step is skipped; the evidence lines are recorded.

- [ ] 12.4 Merge the migration branch; post-merge, remove the `dev_v2` worktree and retire the V2 image/worktree as appropriate, then retire `dev_cache` / `dev_state` / `pnpm_store` and the V1 image after the retention window.
      **Blockers:** 12.3.
      **Acceptance:** merged tree is green; the V1 volumes are only removed after the merge; the rollback window is recorded; no orphan worktree remains.

- [ ] 12.5 Post-merge verification and handoff: re-run `scripts/test-docker-smoke.sh` and the four gates on the merged tree; record the tag, snapshot, rollback instructions, and the V1 retirement evidence.
      **Blockers:** 12.4.
      **Acceptance:** merged tree green; handoff names the tag, snapshot, V1 volumes retention, and every deleted mechanism.

---

## Task sizing and file ownership

| Group | Estimated scope                                   | Fits one window?                            | Files that must not be touched by another lane                                                                                  |
| ----- | ------------------------------------------------- | ------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| 0     | snapshot + baseline table                         | Yes                                         | none                                                                                                                            |
| 1     | compose + Dockerfile + 2 pin scripts + entrypoint | Yes                                         | `docker-compose.yml`, `Dockerfile.dev`                                                                                          |
| 2     | probe matrix on one service                       | Yes                                         | none (read-only)                                                                                                                |
| 3     | ~3,000 deleted LOC + structural gate              | Yes                                         | `delegation-observer/index.ts` (or `.ts`), `routing-gate.ts`                                                                    |
| 4     | 1,700 deleted LOC + 3 script repairs              | Yes                                         | `needs-input-observer.ts`, `verify-pre-push.sh`                                                                                 |
| 5     | journal/stall/fetch simplification                | Yes                                         | `registry.ts`, `stall-sweep.ts`, `fetch-source.ts`                                                                              |
| 6     | one plugin port + tools + watchdog                | Borderline; split libs from tools if needed | `delegation-observer/index.ts`, `.opencode/plugin-tests/`                                                                       |
| 7     | runtime smoke on `dev-v2`                         | Yes                                         | `test-docker-smoke.sh`                                                                                                          |
| 8     | config dead weight + containers + tui             | Yes                                         | `opencode.jsonc`, `tui.json`                                                                                                    |
| 9     | four validators + two readers                     | Yes                                         | `audit-agent-tool-coverage.sh`, `validate-skills.sh`, `test-builtin-containment.sh`, `batch-d-infra.test.mjs`, `jsonc-parse.js` |
| 10    | baseline + 4 agents + overnight                   | Yes, commit per agent                       | `opencode.jsonc`, `opencode-overnight.jsonc`                                                                                    |
| 11    | remaining agents                                  | Yes                                         | `opencode.jsonc`, `.opencode/agents/*.md`                                                                                       |
| 12    | cutover + gates + merge                           | Yes                                         | all                                                                                                                             |

<!--
ownership:
  substance: developer (decisions + ADR 11/15; DIA-261112-exon)
  structure: AI (@openspec-plan)
  revision: post-audit revision 2
-->
