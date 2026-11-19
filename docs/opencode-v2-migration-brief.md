# OpenCode V1 to V2: migration requirements, blockers, and what to delete instead

## TL;DR

- Newest release v2.2.7 (2026-11-10). npm dist-tag latest is still 1.19.5 by design, so no npm/pnpm upgrade crosses the major; V2 arrives only via curl installer, WinGet, Homebrew, or `opencode upgrade --major`.
- V2 is a plugin API REWRITE, not a rename. Every project-authored plugin must be rewritten regardless of strategy.
- Therefore the cheapest path is to delete first: 52 percent of authored plugin LOC (5,353 of 10,321) never needs a V2 adaptation - 3,966 deleted, 1,387 shrunk.
- Rated verdict over 34 components: 16 DELETE, 5 SIMPLIFY, 10 PORT, 1 PORT-LAST, 2 KEEP-AS-IS.
- Biggest single kill: `.opencode/plugins/needs-input-observer.ts` (1,728 LOC + 216 LOC lib + 2,621 test lines + 7 hook sites).
- Biggest single risk: the V1 `permission` to V2 `permissions` config migration fails open silently.
- Two blockers exist BEFORE any migration and should be fixed now: a malformed Dockerfile install block, and a container pin (2.2.6) that cannot run the V1 plugins in the tree.

## 1. The version trap

The dist-tag split is deliberate. Newest release is v2.2.7 (2026-11-10), but npm dist-tag `latest` still resolves to 1.19.5: OpenCode 1 update checks only consult the npm `latest` version, the 1.x install script refuses to install 2.x, and Homebrew Core installs (which track OpenCode 2) are skipped for 1.x updates. V1 was never offered a 2.x build through any package manager.

Cross-major upgrade is explicit only: the curl installer (it replaces the V1 binary), WinGet, Homebrew Core, or `opencode upgrade --major` from a 1.x install.

Consequences:

- No incremental rehearsal exists. Nothing between 1.19.5 and 2.2.7 can be staged through the normal update path; the jump is one explicit, largely irreversible act (V1 code path removal cannot be undone without reinstalling V1).
- A team can also defer indefinitely. Because no automated channel ever offers 2.x, "stay on V1" is a decision that must be made and recorded, not a default the toolchain drifts into.

## 2. What V2 requires (surface map)

| Our V1 surface                                                           | V2 replacement                                                                          | Note                                                                                |
| ------------------------------------------------------------------------ | --------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| plugin entry `export const P = async ({directory, client}) => ({hooks})` | `Plugin.define({ id, setup(ctx) })`                                                     | stable id required because plugin storage is scoped to it                           |
| `tool.execute.before` / `tool.execute.after`                             | `ctx.tool.hook("execute.before"\|"execute.after", event)`                               | renamed, single mutable event, new signature                                        |
| `event` hook                                                             | `ctx.event.subscribe({signal})` async iterator                                          | abort from the cleanup returned by `setup`                                          |
| `chat.message`                                                           | `ctx.session.hook("prompt", ...)`                                                       | prompt hook runs before durable prompt admission                                    |
| `experimental.session.compacting`                                        | `ctx.session.hook("compaction", ...)`                                                   |                                                                                     |
| `experimental.compaction.autocontinue`                                   | NO V2 equivalent                                                                        | must be redesigned                                                                  |
| `dispose()`                                                              | cleanup function returned from `setup(ctx)`                                             |                                                                                     |
| `ctx.client.*`                                                           | domain methods on ctx (ctx.session, ctx.permission, ctx.agent, ...)                     | `ctx.client` itself is gone                                                         |
| `tool({...})` with tool.schema                                           | `ctx.tool.transform((e) => e.add({ name, input: JSONSchema, execute -> { content } }))` | input becomes JSON Schema; execute returns structured content                       |
| `permission` map                                                         | ordered `permissions` array of {action, resource, effect}, last match wins              | actions renamed bash->shell, task->subagent, write/patch->edit                      |
| `agent` / `plugin` / `provider` / `mcp`                                  | `agents` / `plugins` / `providers` / `mcp.servers`                                      | `prompt`->`system`, `maxSteps`->`steps`; nested entries must be entirely one format |
| `session.compacted` event                                                | `session.compaction.started` / `.ended`                                                 | removed in v2.1.0                                                                   |
| `lsp: true`, `compaction.prune`, agent `temperature`                     | inert or ignored-with-warning in V2                                                     | delete rather than migrate                                                          |

Ordered migration sequence: uninstall V1 (irreversible), install V2, verify config unchanged, port plugins (the hard gate), port server integrations, optional native config conversion, restart. No database migration is required. `tui.json` auto-migrates to a GLOBAL `~/.config/opencode/cli.json`, so a project-local `tui.json` silently stops mattering: V2 client config is global and project-local client settings are not migrated.

## 3. Blockers

### 3.1 Present today, before any migration

| #   | Evidence                                                                                                                                                                              | Consequence                                                                                                                                          |
| --- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| B1  | Host opencode 1.18.32 (`.mise.toml:12`) vs container `@opencode/cli` 2.2.6 (`Dockerfile.dev:30`), compared as one identity by `scripts/check-pin-sync.sh:102`                         | parity gate fails today                                                                                                                              |
| B2  | oh-my-opencode-slim pinned three ways: 2.2.19 (`opencode.jsonc:817`), 2.2.19 (`tui.json:2`), 3.0.7 (`Dockerfile.dev:33`), equality demanded by `scripts/check-omo-version-sync.sh:34` | gate fails; the image may pre-install a different OMO than the runtime resolves                                                                      |
| B3  | `@dietrichgebert/ponytail` unpinned (`opencode.jsonc:822`)                                                                                                                            | floats to latest; a breaking release lands with no diff                                                                                              |
| B4  | Plugin SDK split: `@opencode-ai/plugin` 1.17.7 in `.opencode/package.json:3` vs 1.18.13 pinned inside OMO (`Dockerfile.dev:287`)                                                      | a local typecheck proves little about the container runtime                                                                                          |
| B5  | `Dockerfile.dev:280` begins with a literal plus character inside the `RUN npm install ... && \` block                                                                                 | the install block is invalid shell as written; a rebuild fails or skips the version check                                                            |
| B6  | Project-local `tui.json` is not migrated by V2                                                                                                                                        | the OMO pin declared there is lost                                                                                                                   |
| B7  | The container pin is 2.2.6 while the plugins are V1                                                                                                                                   | if the image really runs 2.2.6 the current plugins cannot load at all; either the pin is stale or the container is already broken. Verify live first |

### 3.2 Only at V2

| #   | Blocker                                                                                                                                 |
| --- | --------------------------------------------------------------------------------------------------------------------------------------- |
| B8  | Permission half-migration fails open silently (the highest risk): renamed actions never match and lost rules fall through to base allow |
| B9  | Plugin entry and package import rewrite (`@opencode-ai/plugin` -> `@opencode/plugin`)                                                   |
| B10 | Hook rewrites (see surface map; `autocontinue` has no equivalent)                                                                       |
| B11 | Tool registration rewrite (`tool()` -> `ctx.tool.transform(...).add(...)`)                                                              |
| B12 | Config renames and the nested-mixing rule (nested entries must be entirely one format)                                                  |
| B13 | Local plugin discovery may require directories not files                                                                                |
| B14 | LSP removed (`lsp: true` is preserved but inert)                                                                                        |
| B15 | Compaction keys changed or ignored (`prune`/`tail_turns` ignored with a warning)                                                        |
| B16 | `session.compacted` removed (use `session.compaction.started`/`.ended`)                                                                 |
| B17 | `disabled_agents` unverified in V2                                                                                                      |
| B18 | Client config global-only (project-local `tui.json` not migrated)                                                                       |

### 3.3 Probes required before porting any gate

| #   | Probe                                                                                                                         | Components it gates                                                                                                                                                            |
| --- | ----------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| P1  | Does `execute.before` expose `task()` args (`subagent_type`, `description`, `prompt`) and allow prompt mutation before spawn? | ticket gate, reviewer envelope, routing gate, batch advisory                                                                                                                   |
| P2  | Does `execute.before` run before permission evaluation for the target tool?                                                   | same four as P1: together P1/P2 gate the ticket gate, reviewer envelope, routing gate and batch advisory; a permission prompt before the gate would leak an unguarded dispatch |
| P3  | Does the tool `execute` context still carry `agent`, `sessionID`, `directory`, `abort`?                                       | `fetch-source` agent guard, `log_decision` slot identity, `get-my-session-id`                                                                                                  |
| P4  | Are top-level `.opencode/plugins/*.ts` files auto-discovered in V2, or must each be a directory with an index entrypoint?     | placement of all three plugins; filesystem restructure decision                                                                                                                |
| P5  | Which event names and payload shapes survive (`session.idle`, `session.error`, `session.status`, permission/question events)? | registry lifecycle writer, stall sweep, any notification logic                                                                                                                 |
| P6  | Can `ctx.session.hook("compaction")` inject text into the compaction context the way V1 `output.context.push` does?           | compaction snapshot (PORT-LAST)                                                                                                                                                |
| P7  | Is there a V2-native programmatic context-usage read?                                                                         | `context_usage` (drop rather than simplify if yes)                                                                                                                             |
| P8  | Is OMO 3.0.7 V2-compatible, and can 2.2.19 run under V2?                                                                      | all three OMO pins (config, tui, image) and everything OMO provides                                                                                                            |
| P9  | Does V2 keep the stored-permission model and the `ask` fallback exactly as documented?                                        | the permission rewrite (per-agent permission blocks, B8)                                                                                                                       |
| P10 | Does `ctx.tool.transform(...).add(...)` support early disposal and per-tool metadata?                                         | tool lifecycle for the five tools                                                                                                                                              |

## 4. What to delete, simplify, and port

### 4.1 Scoreboard

| Verdict    | Components |   Authored LOC |      Bun suites | Test lines | Hook sites |  Tools |
| ---------- | ---------: | -------------: | --------------: | ---------: | ---------: | -----: |
| DELETE     |         16 |          3,966 |              19 |      7,221 |    9 of 14 | 1 of 5 |
| SIMPLIFY   |          5 | 1,387 (shrink) | 0 (2 rewritten) |          0 |          0 |      1 |
| PORT       |         10 |              0 |              16 |      8,731 |          5 |      3 |
| PORT-LAST  |          1 |              0 |               0 |          0 |          0 |      0 |
| KEEP-AS-IS |          2 |              0 |               0 |          0 |          0 |      0 |

Reading of the columns: DELETE counts removals; SIMPLIFY counts LOC shrunk (2 suites rewritten in place, 1 tool simplified); PORT counts what must be carried over (16 suites / 8,731 lines retained and rewritten, 5 surviving hook sites, 3 tools). Component rows sum to 34.

Headline: 5,353 of 10,321 authored plugin LOC (52 percent) never needs a V2 adaptation: 3,966 deleted outright, 1,387 shrunk instead of rewritten.

### 4.2 Delete first, in order

1. `preset-model-guard.ts` + 3 suites: zero production references outside tests; duplicates V2 config; its own header admits it cannot exempt a real `--model` choice. Lost: env-preset auto-correction at `session.created`.
2. A1 batch-dispatch advisory: warn-only, no block, no suite. Lost: a log line when an unsafe parallel batch is assembled.
3. Context velocity + adaptive compaction policy: advisory; native `compaction.auto` remains. Lost: 60/85 percent nudges.
4. Edit-time formatter: commit-time lint-staged is authoritative; failures were already non-fatal. Lost: formatting debt surfaced at edit time instead of commit time.
5. Empty-result detection + failure cap: 99.2 percent false-positive history; manual review is the real check. Lost: automatic flagging of empty child results and the consecutive-failure counter.
6. Adaptive routing state: EMA health layer, no measured benefit; duplicate-dispatch block can reject legitimate retries. Lost: idempotency dedupe, per-agent EMA, probe cooldown.
7. Apoptosis + circuit breaker + paracrine: three interacting heuristics; V2 session errors and `cancel_task` cover the need; releases 1,326 test lines. Lost: auto-termination of a runaway session and state signals (`build.passed`, `tests.failed`, ...).
8. `mint_capability` + `lib/capability`: the `scripts/tickets new` procedural carve-out already resolves the deadlock; also removes a tool with no in-tool agent guard. Lost: short-lived signed bypass for bootstrap dispatches.
9. `needs-input-observer.ts` + `lib/permission-fast-resolve`: 1,728 + 216 LOC, 7 hook sites, 6 suites, 2,621 test lines, plus `scripts/ticker-render.sh` and its bats suite. Lost: cross-session waiting ticker and toasts, word-pair terminal titles, 5-minute auto-reject, unattended fast-resolve.
10. Config dead weight: ollama provider + 3 models, `lsp`, `compaction.prune`, `ai-specialist.temperature`, 3 council seats. Lost: unused local models, local LSP diagnostics (already gone in V2), three council voices, one tuning knob that never worked in V2.

### 4.3 Simplify, do not delete

| Component        |   Now |                 To | Why it stays                                                                      |
| ---------------- | ----: | -----------------: | --------------------------------------------------------------------------------- |
| Registry/journal | 1,209 |         ~350 lines | append-only `registry.jsonl` / `messages.jsonl` / `boot.json` are the audit trail |
| Stall sweep      |   349 | ~60-line tail-read | kept because a hung session emits neither error nor idle                          |
| Bash tripwire    |   289 |               ~150 | keep redirection, tee, in-place edit; drop 10 command-form parsers                |
| `context_usage`  |   260 |               ~120 | direct token read only                                                            |

### 4.4 Must survive, ported by transliteration

- Registry + messages journal (simplified)
- Handoff seam: slot, pointer, archive, checksum - the session-end handoff rule (DIA-124) depends on it
- `log_decision` (only handoff writer)
- Ticket gate (DIA-217, DIA-063)
- Reviewer FIXED_POINT envelope + duplication guard
- Protected-path edit gate + gate token
- Routing gate (DIA-230)
- `fetch-source` + destination policy
- `get-my-session-id`
- Per-agent permission blocks (the security boundary for every agent)
- envsitter denies and MCP servers
- Compaction snapshot last

## 5. What deleting too aggressively would cost

1. The audit trail is load-bearing, not decorative. Deleting the registry would not visibly break a session; it would break ticket attribution, stats queries, the handoff checksum proof, and every script that reconstructs what happened.
2. The three gates (ticket gate, reviewer envelope, routing gate) encode failure history: weak-correlation false positives, the meta-task deadlock, the duplicate-envelope injection bug, the reviewer-with-no-bash problem. A from-scratch rewrite re-opens those bug classes. Port by transliteration, not redesign, and keep their tests.
3. needs-input is the only cross-session "who is waiting" signal, and its unattended fast-resolve path prevents permission stalls from burning a bound. Decide the policy first: either accept that a human watches the session list, or keep a ~50-line waiting marker and drop only the auto-reject and notification machinery.
4. The stall sweep is the only proactive hang detector. `session.error` and `session.idle` cover normal and failing sessions, but a session that is simply stuck emits neither.
5. Some knowledge exists only in those plugins and tests: the handoff slot-identity fix (DIA-260827-y9n9) and the envelope duplicate guard (DIA-261023-d6b9) are not derivable from the surrounding docs. Git preserves the code, not the reasons, so record the reasons before deleting.
6. The safest-looking config deletion (ollama, `lsp`, `compaction.prune`) is genuinely dead, but the per-agent permission blocks are NOT. Half-migrating them turns restrictions into base-allow.

## 6. Recommended sequence

| Phase | Action                                                                                                                                                                                                   | Reversible           | Gate                                    |
| ----- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------- | --------------------------------------- |
| 0     | Snapshot `.opencode/`, config files, plugins; record reasons for every deletion in memory                                                                                                                | Yes                  | reasons recorded before any delete      |
| 1     | Delete the self-contained tier: preset guard, A1 advisory, context policy/velocity, formatter, empty-result + failure cap, adaptive routing; remove their suites                                         | Yes (git revert)     | `make test-config`, `make test-harness` |
| 2     | Delete needs-input + its suites + fix the three script references (`scripts/verify-pre-push.sh:170`, `scripts/__tests__/verify-pre-push.bats`, `scripts/__tests__/batch-d-infra.test.mjs` file manifest) | Yes                  | shell + harness suites                  |
| 3     | Simplify registry/stall/tripwire/context_usage; rewrite their tests                                                                                                                                      | Yes                  | `make test-harness`                     |
| 4     | Delete config dead weight                                                                                                                                                                                | Yes                  | `make test-config`                      |
| 5     | Probe P1-P10 in a disposable V2 install                                                                                                                                                                  | N/A                  | probe report                            |
| 6     | Port permissions first, compaction snapshot last                                                                                                                                                         | No (V1 path removed) | full gates + V2 smoke                   |

The rule: do not port a gate before P1/P2 answer, because a gate that silently stops firing is worse than one visibly absent.

## 7. Decisions needed from the team

- (a) Are unattended/overnight runs still in scope? (Decides whether needs-input is deleted outright or reduced to a waiting marker.)
- (b) Is council actively used? (Decides whether the github-copilot seats and provider dependency stay.)
- (c) Is parallel worktree work still the norm? (Decides the value of the cross-session waiting signal.)
- (d) Who owns verifying B7 live in the container before any planning proceeds?

## 8. Evidence and how to reproduce

Deep artifacts:

- `knowledge/res-261112-1ima-opencode-version-migration/res-261112-1ima-opencode-version-migration-conspect.md` - the migration conspect (684 lines, 94 citations, 32 archived upstream sources under the sibling `sources/` dir, with a `.source-urls.txt` manifest listing per-source relevance and reliability).
- `knowledge/ana-261112-ibny-opencode-infra-keep-or-delete-matrix/ana-261112-ibny-opencode-infra-keep-or-delete-matrix-report.md` - the full 34-component matrix, savings ledger, inversion analysis.

Traceability ticket: DIA-261112-exon.

## 9. Caveats

- The DELETE/SIMPLIFY verdicts rest on measured repo evidence.
- Every PORT cost is an estimate because the V2 semantics are unprobed (P1-P10); the analysis confidence is Medium for that reason.
- The tree has 14 lib modules (not 15) and 35 test suites (not 34) as measured.
- The pin/parity gates were read, not executed, by read-only analysis, so treat B1/B2 as static derivations to be confirmed by running the gates.
