# Design: Refactor delegation-observer plugin — 7-seam SRP extraction (DIA-260902-eqgg)

**Parent proposal:** `proposal.md` — Why/What/Impact there. This doc is HOW.  
**Gate:** DIA-104 waived `refactor-no-behavior-change`. No `.sdd/` exists for this module; design references `architecture.md` (guiding principles: single responsibility, decoupling, high cohesion, DI, testable in isolation) and precedent `lib/errors.ts` (DIA-260825-oyh). No new module boundary or technology decision requiring `@architector` opspec.  
**Interview trace:** Every decision below cites Q#/D#/correction #.

## Context

Current ` .opencode/plugins/delegation-observer.ts` is 4,985 lines, one closure `async (ctx) => {…}` owning all reliability seams (Q1). On every tool call `tool.execute.before/after` fires (hot path — Q3), plus `event` session lifecycle and `experimental.session.compacting`. Closure captures `ctx.directory`, paths, and 15+ Maps/Sets. Prior verbatim move `lib/errors.ts` proved the `lib/` seam is not a phantom plugin (top-level scan only) and must use explicit `.ts` imports under `node --experimental-strip-types` (Q4). Scope grew to 7 seams per Q2 to include the shared `appendRow`/`appendMessageRow` writer; `lib/errors.ts` stays reused (OUT). Behavior is frozen — import discipline only (Q2). Five corrections after summary approval tighten per-hook sync/async, ticket-scan fail-closed/fail-soft, perf wording, auditor non-binding, and archive-before-overwrite (corrections 1–5).

## Goals / Non-Goals

**Goals (Q2/Q3/Q7 as amended V-A corrections 1–7):**

- Move subsystem algorithms + persistence serialization under `lib/*.ts`, shell becomes composition/lifecycle only — evidence-based expectation ~3,700 lines for seven-seam scope per V-A correction 1; LOC remains advisory. Binding structural criteria: every retained seam module has a production importer; no corresponding implementation remains duplicated in the shell; tests exercise the same interface used by production (correction 1)
- Preserve hook/tool/event names, order/cardinality, stable payload fields, error behavior, state transitions, fsync discipline verbatim (Q7 §3, Q8) — archive is best-effort before overwrite per DIA-085 (D5 rescinded per V-A correction 2; abort-on-archive-failure separate decision)
- Keep hot path <5 ms p95 regression vs. baseline on same runtime, warm-up + multi-sample, excl. formatter (Q3, Q7 §5, correction 3 wording)
- Make each seam independently unit-testable with DIA-175 RED (test-author) ≠ GREEN (implementer), narrow each retained module to one canonical interface (remove speculative aliases/parseAndExec/probe accommodations/default factories per V-A correction 3), and reconcile each module with exact live behavior before wiring (registry error/warning + boot-sequence, stall role classification, ticket-gate scanning, formatter per-file signal cardinality, handoff outcomes per V-A correction 4) (Q7 §4 + corrections 3/4)

**Non-Goals (Q2 OUT, D2/D3):**

- No behavior/feature/tuning change — formatter `30s`/`1 MiB`/allow-list/ignore-prefixes verbatim (D2), circuit `5/3/5min` verbatim (D3), no new metrics (Q6), no new files/schemas (Q8)
- No touching `needs-input-observer.ts`, `opusFormattingFilter`, `scripts/`, ledger, `opencode.jsonc` (Q2)
- No bundler, no dynamic import on hot path (Q3/Q4)

## Decisions

### D1 — Shell owns lifecycle; libs own how (Q4/Q8/Q9 + corrections 1/5)

Shell: static `import {…} from "./lib/….ts"` (explicit `.ts`), build all paths from `ctx.directory` once, own `globalThis` singletons `STALL_SWEEP_KEY`/`BOOT_EMITTED_KEY`/`ROUTING_WRITE_KEY` (process-scoped dedup, clear prior interval/timer on reload), register hooks in same order, decide _when_ to call persistence adapters, own cross-seam orchestration + single `tuiSafeWarn`/`appendRow` emission.

Libs: DAG `shell → lib`; seam libs never import shell or each other; only `errors.ts` + genuinely shared narrow `types.ts` may cross (Q9 verbatim). Pure calcs = pure functions; stateful seams = factory/class with injected env deps (fs, clock, UUID, spawn, paths, timers) only where tests need control — no `appendRow`/`tuiSafeWarn` callbacks into every lib (Q9). Persistence adapters exception: `registry.ts` owns registry/messages serialization + append side effects; `handoff.ts` owns handoff/boot FS write protocols (tmp→fsync→rename→fsync-dir); shell calls adapters, does not reimplement _how_ (Q8/Q9).

Rationale over alternatives: keeps hot path static-import at load (Q3), satisfies `node --experimental-strip-types` + Wy guard travel requirement (Q5), and avoids recreating coupling via lib→lib cross.

### D2 — Per-hook sync/async contract (correction 1 — replaces D1 summary shorthand)

- Plugin factory `async (ctx) => …` remains async (Plugin type) — correction 1
- `experimental.session.compacting` remains async as in current impl — correction 1
- Stall sweep: async timer (`setInterval` 60s) with synchronous sweep body — correction 1 / D1 / Q8
- Formatter: synchronous via `spawnSync` (`npx --no-install prettier --write`, 30s timeout) — stays sync, never `spawn`/`execAsync` — D2 / correction 1
- Other tool hot-path hooks `tool.execute.before`/`tool.execute.after`/`event` remain synchronous — correction 1 / D1

### D3 — Ticket-scan failure is caller-specific, not globally fail-soft (correction 2)

Preserve two caller-specific semantics:

- DIA-063 config-work ticket validation **fail-closed** when ticket scanning/reading fails (block dispatch)
- Existing warning-and-allow paths remain **fail-soft** and emit same audit/warning signals (`tuiSafeWarn`, registry audit row)
  Tests must cover both behaviors (see Testing Decisions + `tasks.md` S1).

### D4 — Perf wording is generic-hot-path + lazy ticket scan (correction 3)

Replace "no per-call FS scans" with: _"No filesystem scans on the generic tool hot path. Ticket scanning remains lazy and is allowed only for relevant `task()` dispatch validation."_ (correction 3 / Q3)

### D5 — Archive-before-overwrite is best-effort per DIA-085 (V-A correction 2 — rescinds prior correction 5)

**RESCINDED:** Prior correction 5 (archive failure prevents overwrite) is rescinded per V-A correction 2. Established DIA-085 behavior is preserved: archive is **attempted** before overwrite; archive failure emits the existing warning and the new handoff **still lands**. `lib/handoff.ts` and its tests must reflect this best-effort semantics. Any abort-on-archive-failure policy must be handled as a **separate behavior-changing decision** with its own proposal/design. (Q8 / DIA-085)

## Approach — Filing under `lib/` without phantom plugin

```
.opencode/plugins/
  delegation-observer.ts   # composition/lifecycle shell — evidence-based ~3,700 lines for seven-seam scope (LOC advisory per V-A correction 1; binding = production importer + no shell duplication + tests on production interface)
  lib/
    errors.ts              # already extracted, reuse
    capability.ts          # one canonical interface (remove speculative aliases/probe factories — V-A correction 3)
    ticket-gate.ts         # one canonical interface (remove parseAndExec/probe aliases — correction 3)
    handoff.ts             # one canonical interface (remove speculative wrappers — correction 3; archive best-effort per correction 2)
    registry.ts            # one canonical interface (remove default factories/aliases — correction 3)
    stall-sweep.ts         # one canonical interface
    formatter.ts           # one canonical interface (remove default factories — correction 3)
    circuit-breaker.ts     # one canonical interface
    types.ts               # only if ≥2 seams share a contract (Q9)
```

Files use explicit `.ts` extensions; `lib/` is not top-level so OpenCode auto-discovery ( `opencode debug config` verified) never picks it as plugin (Q4). Wy non-function exports (`CAPABILITY_SECRET` Buffer, `TICKET_ID_*` RegExps) keep `.server = async()=>({})` guard in owning lib (Q5). **Reconciliation first:** before wiring, each lib is reconciled with exact live behavior (registry error/warning + boot-sequence, stall role classification, ticket-gate scanning, formatter per-file signal cardinality, handoff outcomes per V-A correction 4). **Wiring:** one seam at a time, delete corresponding shell implementation immediately, re-run production parity after each seam (V-A correction 5). **Structural gate:** verify every retained `lib/*.ts` has a production importer from the shell and no duplicate definition remains in the shell (V-A correction 6).

### Reconciliation — exact live behavior before wiring (V-A correction 4)

Each module must be reconciled with the current live `delegation-observer.ts` before it is wired. Reviewer will diff module exports against live shell semantics; mismatches fail parity.

- **Registry + boot-sequence:** errorMessage extraction chain (string → top-level `.message` → `data.message` → `safeJsonStringify` → `[unserializable …]` fallback; `undefined`/`null` returns `undefined`), `safeJsonStringify` circular → `"[Circular]"`, `Error` → `{name,message,stack}`, function → `[Function …]`, boot `processStartedAt` captured before any I/O, `bootId`/`seq` shared between `registry session_boot` row and `boot.json`, row write ordering, fail-soft warn+unlink
- **Stall role classification:** `READ_ONLY_LANES`/`WRITER_LANES` sets, coder vs orchestrator vs subagent classification, `isSafeTaskBatch` branching (read-only fan-out, single-writer+readers, review pair, parallel coders with distinct WORKTREE), env fallback thresholds
- **Ticket-gate scanning:** filename regex `TICKET_ID_FILENAME_RE` order (datetime-first), `OPEN_TICKET_STATUSES` set, frontmatter first `---` anywhere + `#` skip + quoted ` #` strip, date-only vs ISO `parseTicketDate`, stopword filtering, dispatch `description+"\n"+prompt`, bypass before ticket-id resolution, fail-closed (DIA-063) vs fail-soft (warning-and-allow) per caller
- **Formatter per-file signal cardinality:** `FORMATTER_EXTENSIONS`/`IGNORE_PREFIXES`/`MAX_BYTES`/`TIMEOUT_MS`, `isFormatterIgnoredPath` (workspace-relative), `extractPatchPaths` 7 markers with dedup, per-file `spawnSync npx --no-install prettier --write`, non-fatal `format_warn` row cardinality = one per formatted file attempt (not one per batch), timeout/error → warn row + `tuiSafeWarn` never throw
- **Handoff outcomes:** `computeChecksum` canonical ordering via `jq -c` stable keys, `atomicWriteHandoff` tmp→fsync→rename→fsync-dir + `active.json` pointer last-writer-wins + archive **best-effort** (warning on failure, new slot still lands per correction 2), `active.json` stigmergic write only on terminal handoff with `next_action`

### One canonical interface per module (V-A correction 3)

Remove speculative aliases, `parseAndExec` wrappers, test-probe accommodations, and default factories not required by production. Each `lib/*.ts` exports exactly the interface the shell imports (production importer) — e.g., `lib/capability.ts` exports only `CAPABILITY_SECRET` + `mint/verify` (no `parseAndVerify` alias), `lib/ticket-gate.ts` exports only the gate primitives used by `tool.execute.before` (no `parseAndExec` probe), `lib/formatter.ts` exports only `isFormatterIgnoredPath`/`extractPatchPaths`/`runEditTimeFormatter` (no default singleton factory). Tests import the production interface, not a probe alias.

### Structural gate — production imports + no duplicate shell definitions (V-A correction 6)

After each wire, run: (1) `grep -R "from \"./lib/" .opencode/plugins/delegation-observer.ts` lists every `lib/*.ts` with a production importer; (2) `ast-grep`/`grep` for each seam’s canonical symbols (e.g., `CAPABILITY_SECRET`, `scanTickets`, `atomicWriteHandoff`, `appendRow`, `STALL_SWEEP_KEY`, `isFormatterIgnoredPath`, `ToolCircuitBreaker`) in `delegation-observer.ts` — any duplicate definition beyond the import delegation fails the gate; (3) harness normalized trace still empty.

## Seams — pre-agreed public boundaries where tests live (7 libs → responsibilities, contracts, ownership, failure, order)

Source line refs are to pre-refactor `delegation-observer.ts` (§1,000–4,985); extraction is verbatim move then DI wiring — reviewer verifies from diff, not line numbers.

| #   | Seam / file              | Current responsibilities (source)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          | Dependency contract (DI)                                                                                           | Ownership                                                                            | Failure behavior                                                                                                                                                                                                         | Extraction order                     |
| --- | ------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------ |
| 1   | `lib/capability.ts`      | `CAPABILITY_SECRET = randomBytes(32)` with `.server` guard, `base64url`, `CapabilityPayload`, `mintCapabilityToken` (id + scope + reason + exp 5min, HMAC sha256), `verifyCapabilityToken` (strip `CAP-`, split `.` , timingSafeEqual, JSON parse, expiry) — ~42–200; **one canonical interface per V-A correction 3 — no speculative aliases/probe factories; reconciled with live HMAC/error chain (correction 4)**                                                                                                                                                      | Pure functions; no FS; inject `randomUUID`, `Date.now` only for tests; export guard travels                        | Shell owns re-mint on restart invalidation (Q5)                                      | Sign/verify fail returns `{valid:false,error}` (correction 2 style — discriminated); invalid type → `invalid token type`                                                                                                 | 1                                    |
| 2   | `lib/ticket-gate.ts`     | `parseFrontmatterFields` (first `---` anywhere, `#` skip, quoted ` #` strip), `parseTicketDate` (date-only midnight vs ISO), `ScannedTicket`, `OPEN_TICKET_STATUSES`, `TICKET_KEYWORD_STOPWORDS`, `keywordsCorrelate`, `TICKET_ID_RE/_FIND/_FILENAME` (datetime-first alt, 3-char suffix, `.server` guards), `scanTickets(dir)` (filename regex + status set), meta-task bypass + capability token check before ticket-id resolution; **one canonical interface per correction 3 — no parseAndExec probe wrappers; reconciled with live scanning contract (correction 4)** | Pure + FS injected (`readdirSync`, `readFileSync`) for test fakes; no shell import                                 | Shell calls `scanTickets` only on `task()` with `description`/`prompt` (Q3 lazy)     | **Two semantics:** DIA-063 config-work path fail-closed on scan/read failure; other callers fail-soft warn-and-allow with same audit row (correction 2) — both tested                                                    | 2                                    |
| 3   | `lib/handoff.ts`         | `computeChecksum` (jq `-c` stable order), `atomicWriteHandoff` (JSON canonical + "\n", tmp→fsync→rename→fsync-dir, archive **best-effort** before overwrite per DIA-085, `handoffSlotsDir`/`handoffPointerPath`/`handoffArchiveDir`/`handoffReconciledPath`, stigmergic `active.json` writer; **one canonical interface per correction 3; reconciled with live handoff outcomes (correction 4)**                                                                                                                                                                           | Injected `fs` (write/read/rename/fsync), `path`, clock; never calls `appendRow` directly                           | Shell decides _when_ (log_decision handoff)                                          | Archive best-effort: attempt copy to archive, warning on failure, **new slot still lands** (DIA-085, V-A correction 2 rescinds abort); other FS fail → `tuiSafeWarn`, unlink tmp, return `{ok:false}` — shell warns once | 3                                    |
| 4   | `lib/registry.ts`        | `appendRow`/`appendMessageRow` (seq/row_id = MAX(max jsonl row_id, last md row)+1 at write time, monotonic — DIA-098), `maxRowIdInJsonl`/`lastMessagesMdRowNumber`, `captureConfigLoadSignal` (stat mtimes before I/O), `atomicWriteBootMarker` (shares bootId/seq with registry row, same fsync discipline)                                                                                                                                                                                                                                                               | Injected `fs`, `path`, clock, `randomUUID`; single writer for `registry.jsonl`/`messages.jsonl`/`boot.json`        | Shell triggers single boot shot at top-level, captures `processStartedAt` before I/O | Boot/handoff FS fail → `tuiSafeWarn`, unlink tmp, never crash session                                                                                                                                                    | 4 (after handoff, shares FS helpers) |
| 5   | `lib/stall-sweep.ts`     | `stallThresholdMinutes(env,fallback)`, `STALL_SWEEP_INTERVAL_MS=60_000`, threshold mins (subagent 10, orchestrator 20, dead 60), `STALL_SWEEP_KEY` globalThis singleton, first-sweep `pluginLoadMs` cutoff, sweep body (scan registry for nonterminal rows)                                                                                                                                                                                                                                                                                                                | Injected `setInterval`/`clearInterval`, clock, `readdir`/`readFile` via registry helper; factory sync, timer async | Shell owns `globalThis[STALL_SWEEP_KEY]` handle, clears prior on reload              | Per-iteration try/catch, next interval continues; env parse fallback                                                                                                                                                     | 5                                    |
| 6   | `lib/formatter.ts`       | `FORMATTER_EXTENSIONS` allow-list (`.ts/.tsx/.js/.jsx/.mjs/.cjs/.vue/.css/.scss/.html/.md/.json/.jsonc/.yaml/.yml`), `FORMATTER_IGNORE_PREFIXES` (4 prefixes), `FORMATTER_MAX_BYTES=1 MiB`, `FORMATTER_TIMEOUT_MS=30_000`, `isFormatterIgnoredPath`, `extractPatchPaths` (7 markers: Index:/diff --git/+++ b/ + 4 `*** Add/Update/Delete/Move` ), `runEditTimeFormatter` (spawnSync `npx --no-install prettier --write`)                                                                                                                                                   | Injected `spawnSync`, `fs.statSync`, `path`, `workspaceRoot`                                                       | Shell calls only for edit/write/apply_patch on allow-listed ext                      | Non-fatal: error/timeout → `{warnNote}` → shell writes single `format_warn` row + `tuiSafeWarn`, never throws                                                                                                            | 6                                    |
| 7   | `lib/circuit-breaker.ts` | `CB_WINDOW_SIZE=5`, `CB_ERROR_THRESHOLD=3`, `CB_COOLDOWN_MS=5min`, `CircuitState/Entry`, `class ToolCircuitBreaker { record, tryPass, getState }` — window shift, `CLOSED→OPEN→HALF_OPEN→CLOSED/OPEN`, `tryPass` blocks only `OPEN` or second `HALF_OPEN` call                                                                                                                                                                                                                                                                                                             | Pure in-memory, clock injected; no FS                                                                              | Shell calls `tryPass` before dispatch, `record` after result                         | Never throws                                                                                                                                                                                                             | 7                                    |

Extraction order is topological (1→7) so each successor can reuse `types.ts` if needed and shell can wire incrementally; no lib→lib cross except `errors.ts`/`types.ts` (Q9).

## Boundary Contract — verbatim Q9 corrected DAG

> Dependency direction: shell → seam libs; seam libs never import shell; seam libs do not import one another; only `errors.ts` and genuinely shared narrow `types.ts` may be imported across seams. Shell owns lifecycle, trigger timing, hook ordering, globalThis singleton keys, cross-seam orchestration, warning decisions. Pure calcs = pure functions; stateful seams = factory/class with injected deps where state required — not forced one-class-per-seam. Do not wrap every fn in `{ok,error}` — infallible pures return value; recoverable I/O → discriminated Result; invalid config → fail-loud; gate violations keep throwing where blocking. Feature libs return structured outcomes + signal intents, never call `registry.ts`/`tuiSafeWarn` directly; shell interprets, emits single warning, invokes persistence adapter. Persistence exceptions: `registry.ts` owns registry/messages serialization + append; `handoff.ts` owns handoff/boot FS protocols; shell calls adapters, decides when. Inject only real env deps (fs, clock, UUID, spawn, paths, timers); types narrow/colocated, promote to `types.ts` only when ≥2 seams share.

## Performance & Observability

- Hot path: `tool.execute.before/after`/`event` stay sync excl. stall timer; no FS scans on generic hot path (correction 3); ticket scan lazy only for `task()` (Q3). p95 regression <5 ms on warm-up + multi-sample no-op round-trip before/after (Q7 §5); record p50/p95 in ticket, no flaky CI assertion unless harness stable.
- Observability preserved verbatim: `registry.jsonl`/`messages.jsonl`/`boot.json`/handoff slot/pointer/archive event names + fields unchanged; `format_warn`/`a5_quality_gate`/`session_boot` etc. unchanged; no new per-lib metrics (Q6). Libs return structured outcomes for testability; shell owns single write/warn with `[delegation-observer]` prefix + lib-name tag.

## Risks / Trade-offs

- **Risk: Import path typo breaks whole plugin** → Mitigation: fail-loud at load, not masking; `make test-config` + `validate-plugin-loads.sh` Node+Bun checks gate every slice (Q5/Q7)
- **Risk: Wy loader missing `.server` guard on moved RegExp/Buffer** → Mitigation: guards travel with symbol (capability vs ticket-gate libs), asserted in `lib/capability` + `lib/ticket-gate` unit tests (Q5)
- **Risk: Archive-best-effort mis-copied as abort-on-failure** → Mitigation: D5 rescinded; DIA-085 best-effort preserved (warning + new slot still lands); abort policy is separate decision (V-A correction 2) — tests assert best-effort, not abort
- **Risk: Speculative aliases/factories widen interface** → Mitigation: one canonical interface per module; structural gate rejects probe aliases (V-A correction 3/6)
- **Risk: Module drift from live behavior (registry/stall/ticket/formatter/handoff)** → Mitigation: reconciliation check before each wire (V-A correction 4) — diff against live semantics; writer fixes land via original GREEN/S8 sessions per DIA-175 (V-A correction 7)
- **Risk: Hot-path regression from extra indirection** → Mitigation: static imports at load only, no per-call allocation, measured p95 gate (Q3/Q7 §5)
- **Risk: Lib→lib entanglement recreates monolith** → Mitigation: DAG check in review (diff + dep graph, no grep LOC — Q7 §2 as amended; LOC advisory ~3,700 — correction 1)

## Migration Plan — wire one seam at a time with reconciliation + structural gate (V-A corrections 4–7)

1. **Reconcile → test → wire one seam at a time:** For each of the 7 libs in extraction order (Seams table 1→7), (a) reconcile module exports with exact live behavior (V-A correction 4 checklist above), (b) narrow to one canonical interface (remove speculative aliases/parseAndExec/probe factories — correction 3), (c) RED tests on production interface (DIA-175), (d) GREEN wire + **delete corresponding shell implementation immediately**, (e) re-run production parity: `make test-config` + harness normalized trace diff empty + structural gate (production importer exists + no duplicate shell definition — correction 6) before proceeding to next seam (correction 5)
2. Each wire: harness normalized trace diff + `make test-config` per-seam; accepted fixes land through the original GREEN/S8 implementer sessions per DIA-175 — Critical severity alone does not authorize fresh coder-escalated sessions; escalation only if original lane cannot complete or repeatedly degrades (V-A correction 7)
3. Full suite after all 7 wires: `scripts/__tests__/harness-scenario-replay.bats` + `batch-d-infra.test.mjs` bundling real plugin → byte-equal stable fields vs. baseline (normalize timestamps/IDs/tmp paths) (Q7 §3); restart smoke on real plugin (Q7 §3/§6); performance warm-up multi-sample p95 <5 ms
4. `@ai-auditor` independent review completed (mandatory, non-binding per correction 4); developer disposes findings; all accepted findings verified closed or residual risk explicitly accepted — fixes via original GREEN/S8 sessions (correction 7); final re-review
5. Rollback: `git revert` the 7 lib files + shell restore (~3,700 lines advisory — correction 1; binding is structural criteria)

## Open Questions

None — all deferred tunings (formatter timeout/size, circuit thresholds) are follow-ups with measured evidence (D2/D3), not unknowns blocking this design.
