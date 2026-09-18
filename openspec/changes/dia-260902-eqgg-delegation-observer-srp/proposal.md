# Proposal: Refactor delegation-observer plugin — extract 7 subsystems into lib modules (SRP, DIA-260902-eqgg / DIA-260901-3y39 F1)

**Governing ticket:** DIA-260902-eqgg — Refactor delegation-observer plugin: extract 7 seam modules into lib modules (SRP, DIA-260901-3y39 F1)  
**Gate:** DIA-104 WAIVED `refactor-no-behavior-change` — no separate SDD/@architector. Design references `architecture.md` + precedent `lib/errors.ts` (DIA-260825-oyh).  
**Interview:** Full depth (Q1 B) — 7 seams per Q2 expansion (6 + registry writer). All claims trace to Q#/D# exchanges below.

## Why

Finding F1 in DIA-260901-3y39 flagged ` .opencode/plugins/delegation-observer.ts` as a Single Responsibility breach: one 4,985-line closure owns 6–7 subsystems that are the project's reliability backbone (boot evidence, handoff, ticket gate, stall detection, formatter, circuit breaker, plus the shared registry writer). The file is on the hot path of every tool call (`tool.execute.before/after`), hard to test in isolation, and already showed the cost once — `lib/errors.ts` was extracted verbatim as precedent (DIA-260825-oyh). A mechanical SRP extraction into separate lib modules makes each seam testable, keeps the plugin shell as composition/lifecycle only (~3,700 lines evidence-based expectation for seven-seam scope per V-A correction 1; LOC advisory — binding criteria are production importer, no shell duplication, tests exercise production interface), and preserves behavior exactly — import discipline only — so future reliability fixes can be reasoned about per seam. (Why now: F1 accepted by developer 2026-09-01; section 2.5 chain requires spec before implementation.)

## What Changes

- **Extract 7 seams into `.opencode/plugins/lib/*.ts`** (static `import {…} from "./lib/….ts"` with explicit `.ts`, no bundler, no per-call dynamic import — Q3/Q4):
  1. `lib/capability.ts` — `CAPABILITY_SECRET`, `base64url`, `CapabilityPayload`, `mintCapabilityToken`, `verifyCapabilityToken` (+ Wy `.server` guard travels with `CAPABILITY_SECRET`) — Q2 IN 1, D1 sync
  2. `lib/ticket-gate.ts` — `parseFrontmatterFields`, `parseTicketDate`, `ScannedTicket`, `OPEN_TICKET_STATUSES`, `TICKET_KEYWORD_STOPWORDS`, `keywordsCorrelate`, `TICKET_ID_*` regexes (+ `.server` guards), `scanTickets`, ticket-gate validation (DIA-217/DIA-063) — Q2 IN 2, D1 sync
  3. `lib/handoff.ts` — `computeChecksum`, `atomicWriteHandoff`, handoff slot lifecycle `handoffs/<session-id>.json`, pointer `handoffs/active.json`, archive `handoffs/archive/<id>.<ts>.<uuid>.json`, stigmergic `active.json` pointer — Q2 IN 3, Q8 libs-own-how
  4. `lib/stall-sweep.ts` — `stallThresholdMinutes`, `STALL_SWEEP_INTERVAL_MS=60_000`, `STALL_SWEEP_KEY`, `pluginLoadMs`, `stallSweepFirstDone`, sweep timer dedup on `globalThis` — Q2 IN 4, D1 timer-async/sync-body
  5. `lib/formatter.ts` — `FORMATTER_EXTENSIONS`, `FORMATTER_IGNORE_PREFIXES`, `FORMATTER_MAX_BYTES=1 MiB`, `FORMATTER_TIMEOUT_MS=30_000`, `isFormatterIgnoredPath`, `extractPatchPaths`, `runEditTimeFormatter` (spawnSync, non-fatal `format_warn`) — Q2 IN 5, D1 sync-spawnSync, D2 verbatim
  6. `lib/circuit-breaker.ts` — `ToolCircuitBreaker`, `CB_WINDOW_SIZE=5`, `CB_ERROR_THRESHOLD=3`, `CB_COOLDOWN_MS=5min`, `CLOSED→OPEN→HALF_OPEN→CLOSED/OPEN` — Q2 IN 6, D1 sync, D3 verbatim
  7. `lib/registry.ts` — **added per Q2 expansion** — `appendRow`, `appendMessageRow`, `maxRowIdInJsonl`, `lastMessagesMdRowNumber`, `captureConfigLoadSignal`, `atomicWriteBootMarker`, `boot.json` marker — Q2 IN 7, Q8 libs-own-how

- **Keep shell as composition/lifecycle only** ` .opencode/plugins/delegation-observer.ts` — static imports, path construction from `ctx.directory`, `globalThis` singleton ownership (`STALL_SWEEP_KEY`, `BOOT_EMITTED_KEY`, `ROUTING_WRITE_KEY`), hook/tool registration (`tool.execute.before/after`, `event`, `experimental.session.compacting`, `context_usage`/`log_decision`/`mint_capability`), cross-seam orchestration only — Q4 shell-owns-globalThis, Q8 shell-owns-when. Evidence-based expectation ~3,700 lines for seven-seam scope per V-A correction 1; LOC remains advisory. Binding structural criteria (correction 1): every retained seam module has a production importer; no corresponding implementation remains duplicated in the shell; tests exercise the same interface used by production.

- **Preserve all existing contracts verbatim** — hook names, tool names, event order/cardinality, stable payload fields (`registry.jsonl`/`messages.jsonl`/`boot.json`/handoff), fsync discipline `tmp→fsync→rename→fsync-dir`, fail-soft per-seam + fail-closed for DIA-063 ticket validation, Wy loader guards, 5-min HMAC expiry with restart invalidation — Q5/Q6/Q8/D2/D3 + 5 corrections (§1–5) as amended by V-A corrections (D5 rescinded per correction 2: archive is best-effort before overwrite per DIA-085 — failure emits existing warning and new handoff still lands; abort-on-archive-failure is a separate future behavior-changing decision).

- **NO behavior change** — import discipline only; no new metrics, no per-seam metric emission, no threshold tuning, no new files/schemas — Q6 preserve-all, D2/D3 deferred.

## Capabilities

None — pure refactor with no spec-level behavior change. This change introduces no new user-visible capability and modifies no existing `openspec/specs/` requirement; it only moves code across files preserving the same hook/tool/event contracts. `.openspec.yaml` sets `skip_specs: true` (mechanical extraction, tests prove parity). Do not invent a requirement to satisfy validation.

## Impact

- **Files:** ` .opencode/plugins/delegation-observer.ts` (shell, net negative lines), new `.opencode/plugins/lib/capability.ts`, `lib/ticket-gate.ts`, `lib/handoff.ts`, `lib/stall-sweep.ts`, `lib/formatter.ts`, `lib/circuit-breaker.ts`, `lib/registry.ts` (move verbatim + DAG wiring), shared narrow `lib/types.ts` only if ≥2 seams genuinely share a contract (Q9). No changes to `needs-input-observer.ts`, `opusFormattingFilter`, `scripts/`, ledger, or `opencode.jsonc` (Q2 OUT).
- **Gates:** `make test-config` (incl. `validate-plugin-loads.sh` Node+Bun Wy-compat), existing `scripts/__tests__/harness-scenario-replay` + `batch-d-infra.test.mjs` bundling real plugin, restart OpenCode + smoke, `@ai-auditor` independent review (mandatory, non-binding — correction 4).
- **Dependencies:** none new (`node:crypto`, `node:fs`, `node:path`, `@opencode-ai/plugin` already present; `lib/errors.ts` precedent reused).
- **Rollback:** `git revert` the 7 lib files + shell restore; registry/messages traces remain comparable via normalized harness diff (Q7 §3).

## Alternatives considered

- **A. Mechanical 7-seam extraction into `lib/` with thin shell (CHOSEN):** 7 libs + shell as above, static `.ts` imports, DAG `shell→lib`, persistence adapters (`registry.ts`/`handoff.ts` own fsync protocol, shell owns timing), preserves all existing fail-soft/fail-closed, formatter/breaker constants verbatim, <5 ms p95 regression gate. _Evidence:_ Tier-1 `lib/errors.ts` verbatim move proved `lib/` not phantom-plugin + pattern precedent (DIA-260825-oyh); `architecture.md` §1 guiding principles (single responsibility, decoupling); interview Q2–D3 full battery with 5 corrections. Lowest risk, no behavior change, each seam independently unit-testable.
- **B. Keep monolith, add internal namespaces/comments only:** rejected — preserves 4,985-line SRP breach, no testability gain, FINDING F1 remains open; hot-path reasoning still spans 7 subsystems. Tier-1: DIA-260901-3y39 F1 Major.
- **C. Extract via bundler or dynamic `import()` per call:** rejected — violates hot-path <5 ms budget (Q3) + `node --experimental-strip-types` explicit-`.ts` contract (Q4); dynamic import would add per-call latency and break `validate-plugin-loads.sh` Bun/Node checks. Tier-1: `agents.md` §2.5 plugin load discipline + Q3 static-import decision.
- **D. Extract + re-tune formatter (10 s) / circuit (10-window) in same change:** rejected — mixes refactor with tuning, hides regressions, violates D2/D3 verbatim-preserve rule; tuning belongs in follow-up with failure-injection evidence. Tier-1: interview D2/D3.
- **E. Status-quo / do nothing:** rejected — leaves reliability backbone untestable; future fixes continue to risk the whole plugin. Tier-1: DIA-260902-eqgg Verification checklist requires SRP.
  Chosen option: A — because it is the only option that closes F1 without behavior change while keeping the hot path <5 ms p95, preserving all existing wire/fsync contracts, and enabling per-seam RED/GREEN tests per DIA-175 with prior art `lib/errors.ts`.

## Testing Decisions

What makes a good test for this change: a test that proves (1) parity — normalized `registry.jsonl`/`messages.jsonl` traces for a golden harness run are byte-equal on stable fields before/after, (2) each seam’s edge cases are covered without touching the filesystem or other seams, and (3) the two caller-specific ticket-scan failure semantics diverge as specified (correction 2).

Modules tested (per Q7 §4 + corrections 2/5):

- `lib/capability.ts` — HMAC sign/verify, scope, 5-min expiry, restart invalidation (new secret → old token `invalid signature`), Wy guard still present — sync, no FS
- `lib/ticket-gate.ts` — `parseFrontmatterFields` (first `---` anywhere, `#` comments, quoted ` #` suffix), `parseTicketDate` (date-only vs ISO), `TICKET_ID_*` alt order datetime-first + 3-char suffix, `keywordsCorrelate` stopwords/boundary, `scanTickets` filename `^DIA-(\d{6}-[a-z0-9]+|\d+)` + status `OPEN/IN-PROGRESS/DISPATCHED` case-insensitive, **and both failure semantics: DIA-063 config-work path fail-closed when scan/read fails vs. warning-and-allow path fail-soft with same audit/warn signals** (correction 2); meta-task bypass before ticket-id resolution — sync, injected `readdirSync`/`readFileSync` fakes
- `lib/handoff.ts` — `computeChecksum` canonical stable ordering, `atomicWriteHandoff` tmp→fsync→rename→fsync-dir, `active.json` pointer last-writer-wins, **archive is best-effort before overwrite per DIA-085: attempt archive, emit existing warning on failure, new handoff still lands (D5 rescinded per V-A correction 2; abort-on-archive-failure is separate future decision)** — sync, injected `fs`
- `lib/registry.ts` — `appendRow`/`appendMessageRow` serialization, monotonic `seq`/`row_id = MAX(max jsonl row_id, last md row #)+1`, `captureConfigLoadSignal` mtimes, `atomicWriteBootMarker` shares `bootId`/`seq` with registry row — sync, injected `fs`
- `lib/stall-sweep.ts` — 60 s interval, `STALL_SWEEP_KEY` globalThis dedup (second load clears prior interval), first-sweep load-time cutoff `pluginLoadMs`, threshold env `STALL_*_MINUTES` fallbacks, one in-flight sweep guard — timer injected (`setInterval`/`clearInterval` fake)
- `lib/formatter.ts` — `isFormatterIgnoredPath` (4 ignore prefixes + ext allow-list), `extractPatchPaths` (all 7 markers), `FORMATTER_MAX_BYTES` 1 MiB skip, `spawnSync` `npx --no-install prettier --write` with 30 s timeout, fail-soft `format_warn` + `tuiSafeWarn` — spawn/fs injected, tmp fixture not tracked source
- `lib/circuit-breaker.ts` — sliding window 5 / threshold 3 / cooldown 5 min, `CLOSED→OPEN→HALF_OPEN→CLOSED/OPEN`, `tryPass` blocks only `OPEN` or second `HALF_OPEN` call, `record` transitions — pure in-memory, clock injected
- Shell smoke — `make test-config` (plugin loads under Node + Bun, Wy-compat), harness replay byte-equal on normalized traces, restart + representative hooks, formatter smoke on isolated tmp fixture (Q7 §3)

Prior art in codebase:

- `lib/errors.ts` (DIA-260825-oyh) — verbatim move, explicit `.ts`, not phantom plugin, pattern for this change (Tier-1)
- `scripts/__tests__/harness-scenario-replay.bats` + `batch-d-infra.test.mjs` — corpus driving real plugin via Bun bundle, harness byte-equality check to copy (Q7 §3)
- `scripts/__tests__/routing-order-gate.test.mjs` — ticket-gate regex + routing-order contract mirror, inject `readdirSync` pattern to reuse (Q6/Q7)
- `scripts/__tests__/verify-pre-push.bats` / `compose-env.bats` — Docker-mocked bats pattern for `make test-config` static checks
- `scripts/validate-plugin-loads.sh` — `node --experimental-strip-types --check` + Bun `Object.values(mod)` Wy guard check (Q5)

Interview trace: Q1 Full → Q2 7 seams → Q3 perf <5 ms static imports lazy scan → Q4 shell-owns-globalThis DI → Q5 fail-loud imports / fail-soft per-seam / Wy guards → Q6 preserve-all / no new metrics → Q7 corrected 6-gate checklist verbatim → Q8 libs-own-how/shell-owns-when → Q9 corrected DAG verbatim → D1 per-hook sync/async (correction 1) → D2 formatter verbatim → D3 breaker verbatim → D4 name B + 5 corrections (1 per-hook contract, 2 fail-closed/fail-soft, 3 perf wording, 4 auditor non-binding, 5 archive-before-overwrite) + V-A 7 corrections (1 ~3,700 lines/advisory + binding criteria, 2 D5 rescission/DIA-085 best-effort, 3 one canonical interface, 4 reconcile exact live behavior, 5 wire-one-seam-at-a-time, 6 structural gate production-importer+no-duplication, 7 fixes via original GREEN/S8 per DIA-175).
