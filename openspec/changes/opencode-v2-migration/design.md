# Design: opencode-v2-migration (revision 2, post-audit)

> **Proposal:** `openspec/changes/opencode-v2-migration/proposal.md`
> **Ticket:** DIA-261112-exon
> **Scope:** dev-infra / AI tooling. Implementation design only; no system architecture is authored here.
> **Binding ADRs:** `.sdd/dev-infra/architecture.md` ADR 11 (lines 94-109) and ADR 15 (lines 139-155). This design cites them; it does not restate or override them.

Reference aliases:

- `MIG` = `knowledge/res-261112-1ima-opencode-version-migration/res-261112-1ima-opencode-version-migration-conspect.md`
- `NAT` = `knowledge/res-261113-hi88-opencode-v2-native-capabilities/res-261113-hi88-opencode-v2-native-capabilities-conspect.md`
- `BRIEF` = `docs/opencode-v2-migration-brief.md`
- `REGISTER` = `docs/opencode-v2-migration-audit-register.md`

## Context

`proposal.md` carries the motivation and the measured baseline. This design is shaped by four constraints:

- **ADR 11** mandates a parallel V2 compose service (`dev-v2`) with its own image tag, hostname, OpenCode/OMO pins, and dedicated `dev_v2_cache` / `dev_v2_state` volumes; one install authority per service; a live declared-vs-runtime pin assertion; and no shared `/home/dev/.cache`, `/home/dev/.local/share`, or `/usr/local/bin/opencode` between V1 and V2 (`.sdd/dev-infra/architecture.md:100-108`).
- **ADR 15** fixes the three gate layers, the single-plugin `ctx.storage` plus file-locked JSONL/handoff durability split, the whole-agent atomic conversion rule, and the needs-input reduction to a ~30-40 LOC watchdog with no waiting marker (`.sdd/dev-infra/architecture.md:143-155`).
- **The two services must not share the same working directory.** Both mount the repo at `.:/workspace` (git needs the real object store), but `dev` works at `/workspace` and `dev-v2` at `/workspace/.worktrees/opencode-v2`. A single-directory bind into `dev-v2` would hide `/workspace/.git/objects` and break git; a shared working directory would let a V2 config edit change the files the live V1 service reads, reproducing `AUD-B1` through compose. The worktree model is already supported (`opencode-overnight.jsonc:240-245`).
- **The first draft was rejected.** `REGISTER` section 3 is the defect list; section 5 is the required change set. This revision implements all of it.

The V2 API facts the design relies on:

- `permission.hook("evaluate")` runs for `allow` and `ask` only; a configured `deny` is final and skips it (`NAT:153-165`).
- `ctx.storage` is durable, plugin-id-scoped, prefix-scannable, and has no CAS or lock (`NAT:59-101`).
- `subagent` input is `input.agent` / `input.sessionID`; the tool returns `{ sessionID, status: "running" }` immediately and `execute.before` runs before `permission.assert` (`gh-tool-subagent.ts:18-56`, `:108-145`).
- `execute.after` never sees the child's final output; completion is observed on `event.subscribe` (`session.idle` / `session.execution.*`) (`.sdd/dev-infra/architecture.md:147`).
- The event stream is live-only; `question.*` -> `form.*`, `session.compacted` -> `session.compaction.*` (`NAT:263-307`).

## Goals / Non-Goals

**Goals:**

- A peer V2 service that can be proven while V1 remains the day-to-day runtime.
- The smallest verified surviving core, ported onto the ADR 15 layers with one plugin and one storage namespace.
- A permission/config conversion that happens only on a live V2 service and cannot silently fall back to base `* allow *`.
- A cutover whose rollback point (V1 service, V1 volumes, workspace) is explicit and preserved until merge.

**Non-Goals (design-level):**

- No new module/package boundary, no Poetry Platform product behavior.
- No shared workspace or shared cache/state volumes between services.
- No waiting marker, ticker, toast, title, or pending-detector machinery.
- No new validator or fleet-smoke scripts; existing gates are repaired/extended (`ARC-5`).
- No V1 plugin compatibility shim; V1 code paths are deleted, not dual-maintained.
- No `.sdd/` content authored here.

## Decisions

### D1 - Topology: parallel services with an isolated worktree (ADR 11 decisions 2-3)

| Service  | Image                          | Workspace                                                                                      | Volumes                                         | Pins                         | Role                                    |
| -------- | ------------------------------ | ---------------------------------------------------------------------------------------------- | ----------------------------------------------- | ---------------------------- | --------------------------------------- |
| `dev`    | `poetry-platform-dev:latest`   | `.:/workspace`                                                                                 | `dev_cache`, `dev_state`                        | OpenCode 1.18.32, OMO 2.2.19 | Day-to-day V1; rollback point           |
| `dev-v2` | `poetry-platform-dev-v2:<tag>` | `.:/workspace`; roots at `/workspace` (no `working_dir`; worktree override retired 2026-11-25) | `dev_v2_cache`, `dev_v2_state`, `pnpm_store_v2` | exact V2 release, OMO 3.0.7  | V2 peer; proof and later cutover target |

Both connect to the shared `postgres` on `poetry-net`. Postgres may stay shared; DB-mutating suites must be serialized or use a separate schema, and the cutover task records the contention caveat.

**Why the worktree is load-bearing.** The isolation boundary is the working directory, not the mount. Both services mount the repo so git can resolve the worktree's `.git` pointer, but `dev` works at `/workspace` and `dev-v2` at `/workspace/.worktrees/opencode-v2`; each OpenCode process resolves its project root at its own working directory, so V2 reads `.worktrees/opencode-v2/.opencode` and V1 reads `/workspace/.opencode`. A V2-only config edit (permission arrays, `agents`, `plugins`) is therefore invisible to the live V1 service, which is the `AUD-B1` containment. The V2 service's `.opencode/session/` is inside that worktree and is naturally isolated (ADR 4). **Amended 2026-11-25:** `dev-v2` now roots at the repository root, so this worktree isolation argument is superseded; see the D1a amendment.

### D1a - Container wiring contract (N1-N4)

- **N1 - git worktree pointer.** A worktree's `.git` is a FILE pointing at `<main>/.git/worktrees/<name>`, not a directory. Mounting only `./.worktrees/opencode-v2:/workspace` hides `/workspace/.git/objects` and breaks every git command and husky hook. `dev-v2` therefore mounts the whole repo `.:/workspace` and sets `working_dir: /workspace/.worktrees/opencode-v2`. Git sees the real object store; OpenCode resolves the project root at the worktree and never reads the V1 config. Do not "optimize" this back to a single-directory mount. _(Superseded 2026-11-25: `dev-v2` now roots at `/workspace`; the whole-repo mount and its git rationale still apply - see the D1a amendment.)_
- **N2 - isolation beyond config.** `dev-v2` gets `pnpm_store_v2:/workspace/.worktrees/opencode-v2/node_modules` (never V1's `pnpm_store` at `docker-compose.yml:53`), its own `dev_v2_cache` / `dev_v2_state`, its own container name and hostname `poetry-dev-v2`, and host ports 9100/8100/3100 (env-overridable), disjoint from V1's 9000/8000/3000 (`docker-compose.yml:40-46`). A shared pnpm store would let the task 6.2 SDK swap poison V1. _(Superseded 2026-11-25: `pnpm_store_v2` now mounts `/workspace/node_modules`; see the D1a amendment.)_
- **N3 - container detection.** `scripts/in-container.sh:11` must accept both `poetry-dev` and `poetry-dev-v2`; otherwise every container-gated script hard-fails inside `dev-v2`, including `verify-pre-commit.sh` and `check-stack-ready.sh`. Extend `scripts/__tests__/check-compose-config.bats` (it sources the detector and exercises the in-container path) plus the hostname mocks in `check-stack-ready.bats` / `compose-overrides.bats`.
- **N4 - worktree creation.** Task 0.1 uses a direct `git worktree add .worktrees/opencode-v2` with the ADR 2-compliant branch `feature/DIA-261112-exon-opencode-v2` and a manual `.husky/_` copy per ADR 9. The project script is bypassed only because it derives the path from the branch (`.worktrees/feature-DIA-...`) while the container contract pins `.worktrees/opencode-v2`; the branch name stays ADR 2-compliant (`scripts/worktrees.sh:118`). DIA-202 still requires creation from the main worktree (`scripts/worktrees.sh:20-21`), so `.worktrees/opencode-v2-analytics` is created there, never nested.

**Amendment (2026-11-25): `dev-v2` builds from and roots at the repository root.** A developer decision on 2026-11-25 superseded the worktree-root wiring in N1/N2 above. `dev-v2` now uses `build.context: .` against the repository root and runs at the image `WORKDIR /workspace` with no `working_dir` override, so it reads `/workspace/.opencode` (the migration tree) - the same tree the container actually runs. `.dockerignore` excludes `.worktrees/`, so worktrees are not copied into the build context. The whole-repo mount `.:/workspace` and its N1 git rationale are retained (a single-directory mount would still hide `/workspace/.git/objects`); only the working directory changed. `pnpm_store_v2` now mounts `/workspace/node_modules` (N2's isolation intent is unchanged; V1's `pnpm_store` stays separate). N1/N2 above are kept as the superseded reasoning, not current wiring. The OMO pin gate resolves this same `working_dir` from `docker-compose.yml` (default `/workspace`), so gate and image read one tree (DIA-261125-p1kd).

**Consequence for slice order.** `dev-v2` must exist before any V2-only config lands (S1.1 before S2). The V2 service initially reads the V1-shaped config from the worktree, which V2 normalizes in memory; it will report V1 plugin failures until the port lands. That is expected and contained to `dev-v2`. (Amended 2026-11-25: it reads the repository-root migration tree, not a worktree.)

**Cutover destruction policy (S10b).**

| Object                                          | Safe to destroy at cutover?         | Reason                         |
| ----------------------------------------------- | ----------------------------------- | ------------------------------ |
| V1 container/service                            | Yes, after all V2 gates pass        | It is the retired runtime      |
| `dev_cache`, `dev_state`, `pnpm_store`          | **No, not until the branch merges** | They are the V1 rollback point |
| Workspace                                       | **Never**                           | Shared source of truth         |
| `dev_v2_cache`, `dev_v2_state`, `pnpm_store_v2` | Yes                                 | Reproducible from V2 pins      |
| `postgres` / `pgdata`                           | Not part of this change             | Shared; contention caveat only |

### D2 - Pin authority and the corrected `@opencode/cli` reading (ADR 11 decisions 1 and 4)

- `.mise.toml` must not install or shim `opencode` inside either container; remove the `opencode` key. Each service resolves its own image-baked binary.
- V1 service: correct `OPENCODE_VERSION` to the measured **1.18.32** so its declared pin matches its live binary; this is a pin-truth fix, not a V1 upgrade.
- V2 service: install an exact, integrity-checked `@opencode/cli` release. The channel is documented at `docs-cli-commands.md:18`; `MIG:29-52` is about V1's `opencode-ai` npm `latest` and does not describe this package. The earlier draft's "unverified package" premise was a misreading; the conflict is resolved in D12.
- Build and service startup assert `opencode --version` equals the service's `ARG OPENCODE_VERSION` (ADR 11 decision 1).
- Pin gate: keep four pin families (node, pnpm, bun, OpenCode). Three remain static `.mise.toml` vs `Dockerfile.dev` pairs; OpenCode becomes a per-service assertion: declared build ARG vs live `opencode --version`, V1 and V2 separately while both exist. Do not shrink the gate to three pins (ADR 11 decision 4; `ARC-7`). The fourth pair's partner is the per-service live runtime, not a static `.mise.toml` string: ADR 11 decision 4 supersedes the register's `.mise.toml` / package-version suggestion and is binding. `.opencode/package.json` still pins `@opencode/plugin` exactly for the SDK, but that version is not asserted equal to the CLI version; the runtime assertion is the meaningful check.
- OMO: per-service. V1 stays 2.2.19; the V2 service moves its three V2-side declarations (config, `tui.json` while it exists, V2 build ARG) together to 3.0.7. `check-omo-version-sync.sh` resolves per-service sources plus the loaded cache version; a single cross-service equality is forbidden because it would force V1 onto 3.0.7.

### D3 - Slice spine derived from the ADR 15 layers

The spine is not arbitrary; it follows the three layers and the parallel-container boundary:

- **Layer 3 and Layer 2 changes require a live V2 service.** The ticket, envelope, and routing gates (`Layer 3`) and the protected-path evaluate hook (`Layer 2`) can only be verified against a running V2 plugin host with V2 permission evaluation. Therefore the plugin port lands, then the V2 service is proven (`S10a`), and only then does any config conversion begin.
- **Deletion and simplification precede porting.** They shrink the port surface before the V2 entry is written.
- **Probes precede deletion/port decisions** (OMO/Ponytail/envsitter compatibility, discovery behavior, `--auto`, `cancel_task`/`wait_for_user`).
- **Configuration conversion is last** and lives only in the V2 worktree.

Corrected spine:

```
S0 -> S1.1 -> S6 -> S2 -> S3.1-3.2 -> S4 -> S9 -> S10a -> S5 -> B4 -> S7 -> S8 -> S10b
```

**No false parallelism.** The previous draft claimed S5 could run beside S1.3-1.5/S6.4 and that S9.5/S9.6 could run in parallel. Both are false: S5 edits `opencode.jsonc` and `oh-my-opencode-slim.jsonc`, which S1.3-1.5/S6.4 also read or edit; S9.5 and S9.6 edit the same `subagent` `execute.before` block. This revision merges the gate work into one dispatcher task and runs the config slices serially.

**Parallel safety.** Default is serial. One split is safe: retiring `session-analytics.sh` (scripts/Makefile/docs only) may run in a second worktree `.worktrees/opencode-v2-analytics`, created from the main worktree per DIA-202 on a branch cut from the migration branch (never nested), while an agent-conversion slice edits only `opencode.jsonc` / `.opencode/agents/*.md`. The file sets are disjoint and neither lane runs `make test-config` as a pass gate until merged. No other pair is parallel-safe; any lane that edits `opencode.jsonc`, `delegation-observer/index.ts`, the `subagent` `execute.before` block, or `scripts/__tests__/batch-d-infra.test.mjs` must be serial.

### D4 - Delete-first and the V2 primitive mapping

The surviving set: journal, handoff + `log_decision`, ticket gate, reviewer envelope, protected-path gate, routing gate, `fetch-source` + destination policy, stall sweep, and the ask-timeout watchdog. Everything else is deleted or reduced.

| Component                                                                                                        | Planning LOC now | V2 carrier                                                                                                           | Target | Evidence                                              |
| ---------------------------------------------------------------------------------------------------------------- | ---------------- | -------------------------------------------------------------------------------------------------------------------- | ------ | ----------------------------------------------------- |
| Journal / registry                                                                                               | 1,283            | File-locked `registry.jsonl` / `messages.jsonl` + `ctx.storage` volatile maps + `event.subscribe` + list-API rebuild | ~400   | ADR 15 decision 2; `NAT:94-101`, `NAT:437-448`        |
| Handoff                                                                                                          | 218              | File slots + `active.json` + checksum with file locking                                                              | ~110   | ADR 15 decision 2; `NAT:429-433`                      |
| `log_decision`                                                                                                   | ~350             | `ctx.tool.transform` + `context.sessionID` / `context.agent`; gate token to `ctx.storage`                            | ~160   | `NAT:384-401`; ADR 15 decision 2                      |
| Ticket gate                                                                                                      | ~605             | `tool.hook("execute.before")` on `subagent`; `Tool.Error`; custom domain                                             | ~330   | ADR 15 Layer 3; `NAT:413-423`                         |
| Reviewer envelope                                                                                                | ~182             | Same `execute.before` dispatcher; replace `input.prompt`; duplication guard                                          | ~70    | ADR 15 Layer 3; `NAT:227`                             |
| Routing gate                                                                                                     | ~201             | Same `execute.before` dispatcher; prior-dispatch marker in `ctx.storage`                                             | ~110   | ADR 15 Layer 3; `NAT:33` was wrong-layer              |
| Protected-path gate                                                                                              | ~116             | `edit` ask base at end of coder permissions + `permission.hook("evaluate")` + `ctx.storage` token                    | ~55    | ADR 15 Layer 2; `NAT:153-215`                         |
| `fetch-source`                                                                                                   | 335              | `ctx.tool.transform` + `context.agent` + `context.signal`; keep 4-tier chain, atomic publish, destination policy     | ~250   | `NAT:424-430`; `docs-build-plugins-server.md:802-835` |
| `get-my-session-id`                                                                                              | 22               | Native `context.sessionID` / `context.agent`; delete                                                                 | 0      | `NAT:397-401`                                         |
| Stall sweep                                                                                                      | 349              | ~60-line tail-read; keep                                                                                             | ~60    | `BRIEF:123`, `NAT:25`                                 |
| Needs-input                                                                                                      | 1,728 + 216      | ~30-40 LOC watchdog only; no marker/ticker/toast/title                                                               | ~35    | ADR 15 decision 2; D5                                 |
| `context_usage`                                                                                                  | 260              | Delete                                                                                                               | 0      | Developer decision                                    |
| Bash tripwire                                                                                                    | 289              | Delete                                                                                                               | 0      | Developer decision                                    |
| Preset guard, A1, formatter, empty-result/failure cap, adaptive routing, apoptosis/circuit/paracrine, capability | ~3,000 + suites  | Delete                                                                                                               | 0      | `BRIEF:105-117`; developer decision                   |

**Routing-gate correction.** `lib/routing-gate.ts` currently reads paracrine rows (`:84-90`) that S2.2 deletes. The same commit that deletes those rows removes the row scan and makes the gate accept an injected prior-dispatch marker; the V2 dispatcher binds that marker to `ctx.storage` in task 6.5 (ADR 15 decision 2). The gate stays a `Layer 3` dispatch-order gate; it is not moved to model resolution.

### D5 - Needs-input: ask-timeout watchdog only (variant B without the marker)

Scope is fixed: ~30-40 LOC, no `ctx.storage` marker, no `ticker-render`, no toast/title/PowerShell, no `needs-input-observer.ts`, no `lib/permission-fast-resolve.ts`.

Behavior:

1. Subscribe to `permission.asked` and `form.created`; record `{ sessionID, requestID, askedAt }` for each pending event. There is no `ctx.form` domain and no `ctx.permission.request.list`; the correct in-plugin surface is `ctx.permission.list({ sessionID })` (`gh-plugin-host-core.ts:447-456`; `docs-build-plugins-server.md:618-622`).
2. On a short timer, for each tracked session, call `ctx.permission.list({ sessionID })`, match the still-pending `requestID`, and after the threshold call `ctx.permission.reply({ sessionID, requestID, decision: "reject" })`.
3. Reject is session-wide: it clears every pending ask in that session (`NAT:130-132`, `NAT:358-368`). The watchdog must record that consequence and not assume a single ask.
4. The timeout is configurable for tests (a few hundred ms) and defaults to the existing operational threshold. No waiting marker is written; the native session list is the visibility surface.

V2 never expires an ask on its own and has no auto-deny and no `OPENCODE_UNATTENDED` (`NAT:316-331`); the watchdog is the only guard.

### D6 - Three-layer gates and whole-agent atomic conversion

**Layer assignment (ADR 15 decision 1).**

| Layer   | Mechanism                                             | Gates                                                                     | Rules                                                                                                                                                                                                                                                  |
| ------- | ----------------------------------------------------- | ------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Layer 1 | committed `policies`                                  | unconditional `tool.use` hard denies only (for example force-push family) | Binary allow/deny; never a conditional, ticket, envelope, routing, or token rule (`NAT:134-145`)                                                                                                                                                       |
| Layer 2 | ordered `permissions` + `permission.hook("evaluate")` | protected-path edit gate on `.opencode/**` and `AGENTS.md`                | `ask` base appended at the END of coder permissions, after broader edit allows; evaluate upgrades `effect === "ask"` to allow only on a valid token; missing/invalid/expired token becomes **deny**, never `ask` (developer decision 5)                |
| Layer 3 | `tool.hook("execute.before")` on `subagent`           | ticket gate, reviewer envelope injection, routing-order gate              | One dispatcher; reads `event.input.agent` / `event.input.sessionID`; blocks with model-visible `Tool.Error`; `execute.before` runs before `permission.assert` (`gh-tool-subagent.ts:138-145`), so P2 is answered by source and no live P2 probe is run |

**Protected-path token carrier.** Built-in `edit` does not carry custom metadata into `permission.assert`, so the token cannot ride `event.metadata`. `log_decision(event_type="gate-token")` writes a short-lived token into `ctx.storage`; the `evaluate` hook reads it. The hook only upgrades an `ask`; it never creates an allow from a `deny` (the hook is skipped for deny). The token is single-writer and stored under the single plugin id, which is why plugin consolidation is load-bearing.

**Atomic whole-agent conversion (ADR 15 decision 4; AUD-M1/ARC-4).** In one edit per agent:

- Top-level `agent` -> `agents` (once, before the per-agent edits).
- The entire nested entry, not just the permission key: `permissions` (native array), `disabled`, `steps`, `system`, hex-only `color` (`ai-specialist` currently has `"color": "info"` at `opencode.jsonc:714`, which is invalid in V2), and removal of V1 siblings (`permission`, `disable`, `maxSteps`, `prompt`, `tools`, `temperature`).
- The matching `.opencode/agents/<name>.md` frontmatter: V2 frontmatter is one format per file; a file with any of `permissions`, `request`, `system`, `disabled` is read as V2 and its V1 keys are ignored (`MIG:342-346`).
- Remove orphan V1 permission keys: `doom_loop`, `lsp`, `list`, `apply_patch`, the 23 `envsitter_*` entries, and `mint_capability` (`opencode.jsonc:181`, `:184-191`, `:267-269`, `:374`, `:478`, `:736`, `:738-752`, `:756`; AUD-m1). Keep `cancel_task` / `wait_for_user` only if probe S6 shows OMO 3.0.7 still registers them.
- The validator fails on any leftover V1 key or mixed format. This assertion lives in `audit-agent-tool-coverage.sh`, not a new script (`ARC-5`).

**Order.** Orchestrator, coder, reviewer, researcher, then the remaining agents. Each agent is converted, verified on `dev-v2`, and committed before the next. The pre-conversion effective matrix is the oracle.

**Overnight profile (AUD-M4).** Convert `permission.bash`, `permission.read`, and `permission.edit` in one pass. The `.worktrees/*` read/edit rules (`opencode-overnight.jsonc:240-245`) must survive and must include `.worktrees/opencode-v2/*`. The launcher validates last-match resolution for all 15 baseline patterns, not key presence. Probe whether V2 TUI accepts `--auto` at `scripts/overnight.sh:230`; remove it if rejected (headless `run --auto` remains).

### D7 - Runtime compatibility: background subagent and completion tracking

- The `subagent` tool always returns `{ sessionID, status: "running" }` immediately (`gh-tool-subagent.ts:18-27`, `:224`). `execute.after` sees that immediate return, never `<task_result>`.
- Completion tracking moves to `ctx.event.subscribe()`: `session.idle`, `session.execution.succeeded/failed/interrupted`, and `session.tool.*` (`NAT:287-307`). The immediate return gives the child `sessionID` for correlation.
- The `conspect-pending.json` and `analysis-pending.json` detectors are **deleted**, not relocated. They were `execute.after` result detectors; the surviving lifecycle rows come from `event.subscribe`. This is an explicit `AUD-B3` decision, not an omission.
- The compaction snapshot hook (`experimental.session.compacting`) and the `autocrine_gate_warn` advisory are **deleted**; neither is in the surviving set and neither has a consumer after the journal simplification (`AUD-m2`).
- Event map: `question.*` -> `form.created/replied/cancelled`; `session.compacted` -> `session.compaction.*`; permission events stay live-only and are journaled by live subscription, not replay (`NAT:263-307`).

### D8 - One plugin, stable id, and the discovery layout (ADR 15 decision 3)

- `Plugin.define({ id: "delegation-observer", setup(ctx) })`. One id, one `ctx.storage` namespace, one event subscription, one cleanup.
- V2 discovers direct `.ts`/`.js` files and immediate subdirectories of `.opencode/plugins/` as plugin packages (`MIG:263-267`; `docs-plugins.md:37-45`). `lib/` and `__tests__/` must not remain immediate children.
- Chosen layout: `.opencode/plugins/delegation-observer/index.ts` with `lib/` nested inside the package; tests move to `.opencode/plugin-tests/` (outside the discovery root). `validate-observer-dedupe.sh:25` and `validate-plugin-structure.sh:17` are updated in lockstep to the new entry path; `validate-plugin-loads.sh` is retargeted; Makefile `test-harness` and the plugin tsconfig point at the new test path; the batch-D manifest is updated.
- `log_decision` and `fetch-source` are registered through `ctx.tool.transform`; `.opencode/tools/` is deleted so V2 does not auto-load V1-shaped tools.

### D9 - Tool-port contracts (AUD-M3)

| Contract       | Requirement                                                                                             | Evidence                               |
| -------------- | ------------------------------------------------------------------------------------------------------- | -------------------------------------- |
| Registration   | `ctx.tool.transform((editor) => editor.add({ name, description, input, execute }))`                     | `docs-build-plugins-server.md:802-835` |
| Input          | A JSON Schema object, not a Zod shape                                                                   | `docs-build-plugins-server.md:802-835` |
| Return         | `{ content: [...] }` structured content, not a bare string                                              | `NAT:372-389`                          |
| Cancellation   | `context.signal` (AbortSignal); `context.abort` is gone                                                 | `docs-build-plugins-server.md:825-835` |
| Paths          | `ctx.location.directory` in setup; `context.sessionID` / `context.agent` in execute                     | `NAT:384-401`                          |
| `log_decision` | Native tool transform, session identity from context, gate token to `ctx.storage`                       | ADR 15 decision 2                      |
| `fetch-source` | Native tool transform, `context.agent` guard, `context.signal` passed to fetch, atomic publish retained | `NAT:424-430`                          |
| Removal        | Delete `.opencode/tools/` after both registrations land                                                 | `AUD-M3`                               |

### D10 - Gate and validator repairs (C1-C10 + AUD-B4 + AUD-m3 + AUD-N1/N2)

| ID      | Defect                                                                                                             | Repair / real gate                                                                                                                                                           | Task group |
| ------- | ------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------- |
| C1      | No green baseline; `test-config` dies at `Makefile:260`; `test-shell` depends on `check-pin-sync` (`Makefile:148`) | Run every recipe step individually; record exit codes; pin repair restores the two red gates                                                                                 | 0          |
| C2      | `tui.json` removal touches 3 scripts, 1 bats suite, inventory/memory                                               | Delete after the V2 panel probe; retarget `check-omo-version-sync.sh`, `validate-observer-dedupe.sh:50`, `validate-opencode-config.sh:22`, the bats suite, inventory, memory | 8          |
| C3      | `validate-plugin-structure.sh:30-60` hardcodes deleted libs                                                        | Shrink `retained`/`gateA_symbols`/`prohibited_symbols` in the deletion commit; update bats fixtures                                                                          | 3          |
| C4      | `test-ticket-gate.sh` greps V1 literals                                                                            | Rewrite behaviorally against the ported gate                                                                                                                                 | 6          |
| C5      | Permission validators are V1-shaped                                                                                | Teach `jsonc-parse.js` `permissions` arrays; resolve last-match; update `test-config-wiring.bats`                                                                            | 9, 10      |
| C6      | Overnight profile is a fourth surface                                                                              | D6 overnight conversion; launcher resolves last-match                                                                                                                        | 10         |
| C7      | `dev_cache` masks rebuilds                                                                                         | Per-service `dev_v2_cache` and build/startup version assertion; no shared cache                                                                                              | 1          |
| C8      | `compaction.reserved` -> `buffer`, `disable` -> `disabled`, `disabled_agents`                                      | Rename; probe `disabled_agents`; fallback per-agent `disabled: true`                                                                                                         | 8          |
| C9      | `envsitter-guard@0.0.4` unverified                                                                                 | Drop; native `read *.env` ask                                                                                                                                                | 1, 2       |
| C10     | `validate-plugin-loads.sh` orphaned/V1-shaped                                                                      | Retarget to the V2 package entry and wire it into `test-config`, or delete it if a static import cannot prove V2 load                                                        | 6          |
| AUD-B4a | `audit-agent-tool-coverage.sh:159-163` exits 2 on `permissions` lists                                              | Accept V2 arrays; assert the effective matrix and leftover V1 keys; final mode after group 11                                                                                | 9, 10, 11  |
| AUD-B4b | `test-builtin-containment.sh:79-85` on `disable`/`disabled` + `permission.task`                                    | Accept `disabled` and the V2 `subagents` action; remove `scout` expectations                                                                                                 | 8, 9       |
| AUD-B4c | `.opencode/scripts/validate-skills.sh:437-448` on `command`/`agent` renames                                        | Accept `commands`/`agents`; keep both during the window, final V2-only after group 11                                                                                        | 9, 10, 11  |
| AUD-B4d | `batch-d-infra.test.mjs:293-323` on per-agent permission maps                                                      | Accept arrays and `agents`; update the final assertions (`:294-322`)                                                                                                         | 9, 10, 11  |
| AUD-m3a | `validate-observer-dedupe.sh:80` reads only `cfg.plugin`                                                           | Read `cfg.plugins ?? cfg.plugin`, handle `{package, options}` entries, fail on empty                                                                                         | 9          |
| AUD-m3b | `jsonc-parse.js --doc-drift` reads only `cfg.agent`                                                                | Read `cfg.agents ?? cfg.agent`; fail on zero agents, never vacuous green                                                                                                     | 9          |
| AUD-N1  | `scout` does not exist in V2                                                                                       | Remove from config, AGENTS.md section 9, `test-builtin-containment.sh`                                                                                                       | 8, 9       |
| AUD-N2  | Task 1.3 gated on non-existent `make check-omo-version-sync`                                                       | Use `bash scripts/check-omo-version-sync.sh` and `make test-config`; no phantom target                                                                                       | 1          |

### D11 - Cutover and rollback

- `S10a` is the **V2 runtime gate**, not cutover: `dev-v2` runs the ported plugin and passes `scripts/test-docker-smoke.sh` extended for the V2 service. V1 remains day-to-day.
- `S10b` is the final cutover: retire the V1 container/service; keep `dev_cache` and `dev_state` until the branch merges; never touch the workspace; postgres stays shared with the contention caveat. Run the full gate set on `dev-v2`.
- Annotated tag `opencode-v2-irreversible` immediately before V1 retirement. Snapshot refreshed at S0 and S10b.
- After merge, remove the V1 volumes and the V2 worktree; the V1 image may be retained for one retention window at the developer's discretion.

### D12 - Recorded conflicts resolved

1. **`@opencode/cli` reading.** Resolved in favor of `AUD-M6` plus `ARC-7` verification: `docs-cli-commands.md:18` documents `npm install --global @opencode/cli` as the V2 channel; `MIG:29-52` concerns the V1 `opencode-ai` package. The design installs an exact release with npm integrity checking and asserts the resolved binary at build and startup, which satisfies both findings.
2. **ctx vs HTTP pending surfaces.** Resolved in favor of `AUD-M2`: there is no `ctx.form` domain and no `ctx.permission.request.list`; the watchdog uses `ctx.permission.list({sessionID})` and `ctx.permission.reply({sessionID, requestID, decision})`. The waiting marker is deleted, so `form.list` is not used.
3. **Invalid gate token.** Resolved by developer decision 5: deny, never `ask`. The evaluate hook upgrades `ask` on a valid token and otherwise sets `deny` (or the `execute.before` handler rejects with `Tool.Error`).

## Seams (existing repo seams only)

`ARC-5` cuts the invented `validate-agent-permissions.sh` and `smoke-agent-fleet.sh`; the runtime seam stays in the existing `test-docker-smoke.sh`.

### S1 - Plugin behavioral seam (existing, relocated)

- **Boundary:** the single plugin entry and its exported decision functions.
- **Where:** `.opencode/plugin-tests/`, run by `make test-harness` (Makefile:388-390) and `make test-typecheck`.
- **Prior art:** `ticket-gate.test.mjs`, `handoff.test.mjs`, `registry.test.mjs`, `envelope-gate.test.mjs`, `routing-order-gate.test.mjs`.
- **Good test:** call the real gate or load the real entry; assert the decision and the model-visible error.

### S2 - Config and permission seam (existing)

- **Boundary:** V2 config plus the validators that resolve it.
- **Where:** `make test-config` (Makefile:257-300), including `jsonc-parse.js`, `audit-agent-tool-coverage.sh`, `validate-skills.sh`, `test-builtin-containment.sh`, `batch-d-infra.test.mjs`, `validate-observer-dedupe.sh`, `validate-plugin-structure.sh`, `validate-plugin-loads.sh`.
- **Prior art:** `test-config-wiring.bats`, `validate-plugin-structure.bats`, `check-omo-version-sync.bats`.
- **Good test:** resolve the effective last-match matrix; fail on mixed formats and leftover V1 keys; never vacuous-green.

### S3 - Shell launcher seam (existing)

- **Boundary:** launchers and their fail-closed validation.
- **Where:** `make test-shell` (`overnight.bats`, `test-config-wiring.bats`).
- **Good test:** a fake `opencode` binary; a softened/missing deny rule exits 1 before launch.

### S4 - Runtime seam (existing, extended)

- **Boundary:** the running `dev-v2` service.
- **Where:** `scripts/test-docker-smoke.sh`, extended for `dev-v2`.
- **Asserts:** `opencode --version` == ARG; OMO 3.0.7 loaded (`health check passed`); zero plugin-load errors; fresh journal/handoff rows; deleted mechanisms absent.
- **Why existing:** `test-docker-smoke.sh` already owns host-with-engine runtime checks (ADR 14); no new script.

### S5 - Pin seam (existing)

- **Boundary:** declared pins vs live runtime per service.
- **Where:** `scripts/check-pin-sync.sh` (three static pairs + per-service OpenCode), `scripts/check-omo-version-sync.sh` (per-service config/tui/build + loaded cache).
- **Good test:** a mismatched service ARG or a shadowing shim fails; a matching service passes.

## Risks / Trade-offs

- **V2 config breaking the live V1 service.** -> Separate worktree bind; V2-only edits never touch the V1 workspace; `dev-v2` is the only reader of `.worktrees/opencode-v2`. (Amended 2026-11-25: `dev-v2` roots at the repository root; see the D1a amendment.)
- **Fail-open permission conversion.** -> Atomic whole-agent conversion, top-level `agents` once, matrix oracle, leftover-key fail in `audit-agent-tool-coverage.sh`, per-agent verification on `dev-v2`.
- **Wrong-layer gates / token bypass.** -> ADR 15 layer table; protected path on `ask` + evaluate; invalid token deny; Layer 3 gates in one `execute.before` dispatcher; `policies` only unconditional.
- **Background subagent breaks completion tracking.** -> `event.subscribe` completion; pending detectors deleted; `execute.after` not used for results.
- **Validator gate collapse.** -> Four hard-failing validators and two vacuous readers repaired before the config conversion; `make test-config` checkpoint at B4.
- **Discovery probes `lib/` and `__tests__/`.** -> Package layout and tests outside the discovery root; probe P4 explicitly checks both.
- **Pin gate tautology.** -> Per-service declared-vs-runtime assertion; four pin families retained (`ARC-7`).
- **OMO 3.0.7 / Ponytail / envsitter compatibility.** -> Probe S6; fall back or drop; no inference.
- **V2 TUI rejects `--auto`.** -> Probe; remove the TUI flag, keep headless `run --auto`.
- **Shared postgres test contention.** -> Serialize DB-mutating suites or use a separate schema; documented at cutover.
- **Session-analytics dead CLI.** -> Retire the script/target; follow-up ticket for a V2 rewrite.

## Migration Plan

`tasks.md` is authoritative. The spine is D3; the cutover policy is D1/D11. The V1 service and volumes remain the rollback path until S12 merges.

## Open Questions (probe-gated, not design-open)

1. OMO 3.0.7, Ponytail, and `envsitter-guard@0.0.4` V2 compatibility; `cancel_task` / `wait_for_user` registration (`REGISTER` section 7).
2. Whether V2 TUI accepts `--auto` (`scripts/overnight.sh:230`).
3. Whether V2 auto-discovery warns or fails on `.opencode/plugins/lib/` and `__tests__/` (probe P4; the layout fix is unconditional).
4. `context.directory` vs `ctx.location.directory` (source read of `gh-tool-subagent.ts:108-200` and `docs-build-plugins-server.md:820-835`).

## Audit disposition

Every register ID appears exactly once. All are closed; none is deferred.

| ID     | Status | Closed by                                                                                                             |
| ------ | ------ | --------------------------------------------------------------------------------------------------------------------- |
| AUD-B1 | closed | tasks 0.1, 1.1, 3.x-6.x (only in `.worktrees/opencode-v2`), 7.3, 10.9/11.3                                            |
| ARC-3  | closed | Same as AUD-B1; corrected spine in D3 and tasks groups 0-12                                                           |
| AUD-B2 | closed | tasks 3.7 (row-scan removal), 6.5 (Layer 3 dispatcher), 6.9 (Layer 2 hook/token), 10.3 (ask rules), 10.6 (end-to-end) |
| ARC-2  | closed | Same as AUD-B2; ADR 15 Layer 2/3 cited in D6                                                                          |
| AUD-B3 | closed | tasks 6.5 (`input.agent`/`input.sessionID`), 6.6 (`event.subscribe`), 3.6 (pending detectors deleted)                 |
| AUD-B4 | closed | tasks 9.1-9.6 (four validators + two readers + checkpoint), 10.8, 11.2                                                |
| AUD-M1 | closed | tasks 10.1-10.5 (atomic), 8.3 (top-level containers), 10.8/11.2 (leftover-key fail)                                   |
| ARC-4  | closed | Same as AUD-M1; ADR 15 decision 4 cited in D6                                                                         |
| AUD-M2 | closed | task 6.7 (watchdog APIs, no marker)                                                                                   |
| ARC-6  | closed | Same as AUD-M2; D5                                                                                                    |
| AUD-M3 | closed | tasks 6.4, 6.8; design D9                                                                                             |
| AUD-M4 | closed | task 10.7                                                                                                             |
| AUD-M5 | closed | task 6.1                                                                                                              |
| ARC-1  | closed | Same as AUD-M5; D8                                                                                                    |
| AUD-M6 | closed | task 1.2; design D2/D12                                                                                               |
| ARC-7  | closed | task 1.2; design D2                                                                                                   |
| AUD-m1 | closed | task 10.2                                                                                                             |
| AUD-m2 | closed | task 3.6                                                                                                              |
| AUD-m3 | closed | task 9.5                                                                                                              |
| AUD-m4 | closed | task 6.12 + Seams section                                                                                             |
| ARC-5  | closed | task 6.12 + Seams section                                                                                             |
| AUD-N1 | closed | tasks 8.1, 8.4, 9.1                                                                                                   |
| AUD-N2 | closed | task 1.6                                                                                                              |
| ARC-8  | closed | ADR 11 amended (line 94) and ADR 15 added (line 139); D1/D6 cite them                                                 |
| N1     | closed | task 1.1 (whole-repo mount + `working_dir`) and task 1.2 (`git status` succeeds inside `dev-v2`)                      |
| N2     | closed | task 1.1 (`pnpm_store_v2`, distinct container/hostname, disjoint ports 9100/8100/3100)                                |
| N3     | closed | task 1.8 (`in-container.sh` accepts `poetry-dev-v2`; `check-compose-config.bats` + hostname-mock suites extended)     |
| N4     | closed | task 0.1 (direct worktree add, ADR 2 branch, ADR 9 husky copy) and task 6.12 (analytics worktree from main, DIA-202)  |

Disposition count: 24 register IDs + 4 execution conditions (N1-N4) = 28 rows, 0 unclosed, 0 deferred.

<!--
ownership:
  substance: developer (decisions + ADR 11/15; DIA-261112-exon)
  structure: AI (@openspec-plan)
  revision: post-audit revision 2
-->
