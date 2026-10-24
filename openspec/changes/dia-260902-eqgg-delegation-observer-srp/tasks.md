# Tasks: Refactor delegation-observer plugin — 7-seam SRP (DIA-260902-eqgg) — amended per V-A 7 corrections

**Change:** `dia-260902-eqgg-delegation-observer-srp` | **Governing ticket:** DIA-260902-eqgg | **Interview:** Q1 Full → Q2 7 seams → Q3 perf → Q4 DI → Q5 fail-loud/fail-soft → Q6 preserve-all → Q7 corrected 6-gate checklist → Q8 libs-own-how → Q9 corrected DAG → D1 per-hook sync/async → D2 formatter verbatim → D3 breaker verbatim → D4 name B + 5 corrections + V-A 7 corrections (see proposal/design)  
**Global exit criteria (Q7 verbatim, amended V-A):** see Acceptance per slice + bottom Global gates. Shell size is **~3,700 lines evidence-based, LOC advisory per V-A correction 1**; binding structural criteria (correction 1) + structural gate (correction 6) apply. DIA-085 best-effort archive (correction 2 rescinds abort).  
**Sizing:** one-context-window per slice. **RED≠GREEN:** DIA-175 — test-author ≠ implementer; **fixes via original GREEN/S8 sessions only per V-A correction 7** (Critical alone does not authorize fresh coder-escalated; escalation only if original lane cannot complete/degrades). **DIA-175:** record `RED:<instance> → GREEN:<instance>` in ticket Fix evidence.  
**Blocking edges:** `A → B` means B after A validation 0. **Spec fidelity:** `skip_specs:true` — parity via normalized harness traces + `make test-config` + per-seam tests.

## Slice 0 — Scaffolding + baseline (no behavior change) [blocking: none → unblocks all]

**Goal:** Parity baseline + empty `lib/` shells; reconcile shells not yet wired.

- [ ] Capture pre-refactor baseline: run `scripts/__tests__/harness-scenario-replay.bats` or `batch-d-infra.test.mjs` golden corpus vs current `delegation-observer.ts`; save normalized `registry.jsonl`/`messages.jsonl` traces (normalize timestamps, generated sequence/session IDs, tmp paths, derived values — Q7 §3) under `openspec/changes/dia-260902-eqgg-delegation-observer-srp/baseline-traces/`.
- [ ] Create empty shells: `.opencode/plugins/lib/{capability,ticket-gate,handoff,registry,stall-sweep,formatter,circuit-breaker}.ts` + optional `lib/types.ts` stub, each with explicit `.ts` imports working under `node --experimental-strip-types --check` (Q4). `scripts/validate-plugin-loads.sh` still passes (shell still monolith).

**Acceptance:** baseline traces normalized committed; `make test-config` 0; Node+Bun Wy-compat; no behavior change. **DIA-175:** N/A.

## Slice 1 — lib/capability.ts (HMAC token) — one canonical interface + reconcile [blocking: S0 → S1]

**Goal:** Extract capability seam as one canonical interface (V-A 3) reconciled with live HMAC semantics (V-A 4), before wiring.

- [ ] **RED (Coder-A):** unit tests on **production interface only** (correction 3 — no speculative aliases, no probe factories): `mintCapabilityToken` → `CAP-{payloadB64}.{sigB64}`, `verifyCapabilityToken` valid/invalid sig / malformed / JSON parse / 5-min expiry, per-process `CAPABILITY_SECRET` restart invalidation (`invalid signature`), `.server` guard present on `CAPABILITY_SECRET`. Inject `randomUUID`/`Date.now`; no FS.
- [ ] **GREEN (Coder-B ≠ RED):** move `CAPABILITY_SECRET` (with `.server` guard), `base64url`, `CapabilityPayload`, `mintCapabilityToken`, `verifyCapabilityToken` verbatim; reconcile exactly with live HMAC/error strings before commit (correction 4). **Do not yet wire shell** — lib exists, shell still monolithic.

**Acceptance:** tests exercise same interface production will use (correction 1c); `make test-config` 0; no aliases. **DIA-175:** record RED/GREEN instances; fixes later via this GREEN session per correction 7.

## Slice 2 — lib/ticket-gate.ts (scan + keyword correlation) — canonical + reconcile [blocking: S1 → S2]

**Goal:** Ticket-gate as one canonical interface, reconciled (stall role classification, scanning semantics), both failure paths.

- [ ] **RED (Coder-C):** isolated tests on production interface only (no `parseAndExec` probe — correction 3): `parseFrontmatterFields` (first `---` anywhere, `#` skip, quoted ` #` strip), `parseTicketDate` (midnight vs ISO), `TICKET_ID_*` datetime-first + 3-char suffix + no `/i` + `.server` guards, `keywordsCorrelate` stopwords, `scanTickets` filename `^DIA-…` + `OPEN/IN-PROGRESS/DISPATCHED` case-insensitive + `title/sessionId/discoveredMs`, meta-task bypass before ticket-id resolution, **both failure semantics: DIA-063 config-work fail-closed when `readdirSync`/`readFileSync` throws vs warning-and-allow fail-soft with same audit/warn signals (correction 2 + design Reconciliation)**. Reconcile with live ticket-gate scanning (correction 4).
- [ ] **GREEN (Coder-D ≠ RED):** move constants/parsers/`scanTickets`/gate checker verbatim reconciled; keep `.server` guards.

**Acceptance:** both fail-closed/fail-soft tests pass; one canonical interface; `make test-config` 0. **DIA-175:** RED≠GREEN.

## Slice 3 — lib/handoff.ts (handoff + boot FS adapter) — best-effort archive + canonical [blocking: S2 → S3]

**Goal:** Handoff adapter with DIA-085 best-effort archive (V-A 2 rescinds abort), one canonical interface, reconciled.

- [ ] **RED (Coder-A):** tests on production interface only: `computeChecksum` (canonical sha256 via `jq -c` stable keys), `atomicWriteHandoff` tmp→fsync→rename→fsync-dir, `active.json` pointer last-writer-wins, **archive best-effort: attempt copy to `handoffs/archive/…`, emit existing warning on failure, new handoff still lands (DIA-085 per V-A 2; abort-on-archive-failure is separate future decision)** — update from prior abort test, legacy `current-handoff.json` not written, reconciled with live handoff outcomes (correction 4).
- [ ] **GREEN (Coder-B):** move `computeChecksum`, `atomicWriteHandoff`, path constants verbatim reconciled; shell `when` not yet wired.

**Acceptance:** best-effort archive test passes (not abort); `make test-config` 0. **DIA-175:** fixes via GREEN.

## Slice 4 — lib/registry.ts (registry/messages writer + boot marker adapter) — canonical + reconcile [blocking: S3 → S4]

**Goal:** Shared writer adapter, one canonical interface, reconciled boot-sequence + error/warning semantics.

- [ ] **RED (Coder-C):** tests on production interface only (no default factories — correction 3): `appendRow`/`appendMessageRow` serialization + monotonic `seq`/`row_id = MAX(max jsonl row_id, last md row)+1` at write time, malformed line skip, `captureConfigLoadSignal` mtimes captured before I/O, `atomicWriteBootMarker` shares `bootId`/`seq` with registry row + same fsync discipline, `boot.json` fields, **errorMessage chain** (`string → .message → data.message → safeJsonStringify circular/[Circular] / Error {name,message,stack} → [unserializable …]`; `undefined`/`null` → `undefined`) and boot-sequence ordering reconciled (correction 4).
- [ ] **GREEN (Coder-D):** move row allocators + boot helpers verbatim reconciled; registry lib is single writer.

**Acceptance:** registry/boot tests pass; `make test-config` 0; `session_boot` row + `boot.json` share `bootId`/`seq`. **DIA-175:** GREEN.

## Slice 5 — lib/stall-sweep.ts (scheduler dedup) — canonical + reconcile [blocking: S4 → S5]

**Goal:** Stall-sweep as one canonical interface, reconciled role classification.

- [ ] **RED (Coder-A):** tests: `stallThresholdMinutes` env fallback, `STALL_SWEEP_INTERVAL_MS=60_000`, `STALL_SWEEP_KEY` globalThis dedup (second load clears prior), first-sweep `pluginLoadMs` cutoff, sweep body sync scan for nonterminal rows, one in-flight guard, per-iteration try/catch, **stall role classification reconciled (READ_ONLY/WRITER vs coder/orchestrator)** (correction 4).
- [ ] **GREEN (Coder-B):** move sweep constants + timer factory verbatim reconciled.

**Acceptance:** stall tests pass; no per-call FS on generic hot path; `make test-config` 0. **DIA-175:** fixes via GREEN.

## Slice 6 — lib/formatter.ts (edit-time hook) — canonical + reconcile per-file cardinality [blocking: S5 → S6]

**Goal:** Formatter as one canonical interface, reconciled per-file signal cardinality.

- [ ] **RED (Coder-C):** tests on production interface only (no default singleton factory — correction 3): `isFormatterIgnoredPath` (4 prefixes + workspaceRoot), `extractPatchPaths` (7 markers dedup), `FORMATTER_MAX_BYTES` 1 MiB skip, allow-list ext gate, `spawnSync npx --no-install prettier --write` 30s timeout, **per-file `format_warn` row cardinality = one per formatted file attempt (correction 4)**, fail-soft → `{warnNote}` → shell single `format_warn` + `tuiSafeWarn` never throw, isolated tmp fixture not tracked source (Q7 §3).
- [ ] **GREEN (Coder-D):** move `FORMATTER_*` constants + helpers verbatim reconciled.

**Acceptance:** formatter tests pass; `make test-config` 0; isolated fixture smoke verifies cardinality. **DIA-175:** fixes via GREEN.

## Slice 7 — lib/circuit-breaker.ts (tool-level breaker) — canonical [blocking: S6 → S7]

**Goal:** Breaker as one canonical interface.

- [ ] **RED (Coder-A):** tests on production interface: `CB_WINDOW_SIZE=5`, `CB_ERROR_THRESHOLD=3`, `CB_COOLDOWN_MS=5min`, `CLOSED→OPEN` on ≥3/5, `OPEN→HALF_OPEN` after 5min, `HALF_OPEN→CLOSED` on success / `→OPEN` on fail, `tryPass` blocks only `OPEN` or second `HALF_OPEN`, `record` transitions. Clock injected.
- [ ] **GREEN (Coder-B):** move `ToolCircuitBreaker` verbatim.

**Acceptance:** breaker tests pass; `make test-config` 0. **DIA-175:** fixes via GREEN.

## Slice 8 — Reconciliation gate (verify all 7 libs vs live) [blocking: S7 → S8]

**Goal:** Explicit gate that every retained lib is reconciled with exact live behavior before any wiring (V-A 4). No wiring yet.

- [ ] Diff each `lib/*.ts` export against live `delegation-observer.ts` handling for: registry error/warning + boot-sequence, stall role classification, ticket-gate scanning, formatter per-file signal cardinality, handoff outcomes (design Reconciliation checklist). Fix mismatches in lib source (not shell) and re-run `make test-config`.
- [ ] Verify each lib has **exactly one canonical interface** (no speculative aliases/parseAndExec/probe accommodations/default factories) — `grep -R "parseAndExec|probe|default.*Factory"` in `lib/` is empty or justified (V-A 3).

**Acceptance:** reconciliation checklist all pass; one canonical interface per lib; `make test-config` 0. **DIA-175:** fixes via original GREEN sessions if patching libs (correction 7).

## Slice 9 — Per-seam wiring: one seam at a time, delete shell duplicate, parity after each seam (7 micro-steps) [blocking: S8 → S9a→S9b→…→S9g]

**Goal:** Wire libs into production shell one at a time per V-A correction 5 — wire, delete, parity, before next seam.

- [ ] **S9a capability:** add `import {…} from "./lib/capability.ts"` to `delegation-observer.ts`, delegate `mint/verify` calls, **delete corresponding shell implementation immediately**, `make test-config` + harness normalized trace diff empty (stable fields) + `node --experimental-strip-types --check` + Bun Wy-compat.
- [ ] **S9b ticket-gate:** wire `lib/ticket-gate.ts`, delete shell `parseFrontmatterFields`/`scanTickets`/gate checker, parity as above (lazy ticket scan still only for `task()` — correction 3 wording).
- [ ] **S9c handoff:** wire `lib/handoff.ts`, delete shell `computeChecksum`/`atomicWriteHandoff` + path constants, parity (best-effort archive preserved).
- [ ] **S9d registry:** wire `lib/registry.ts`, delete shell `appendRow`/`appendMessageRow`/`captureConfigLoadSignal`/`atomicWriteBootMarker`, parity (`bootId`/`seq` sharing preserved).
- [ ] **S9e stall-sweep:** wire `lib/stall-sweep.ts`, delete shell stall constants/timer body, parity (stall rows normalized).
- [ ] **S9f formatter:** wire `lib/formatter.ts`, delete shell `FORMATTER_*`/`isFormatterIgnoredPath`/`extractPatchPaths`/`runEditTimeFormatter`, parity (per-file `format_warn` cardinality preserved, isolated fixture smoke).
- [ ] **S9g circuit-breaker:** wire `lib/circuit-breaker.ts`, delete shell `ToolCircuitBreaker`, parity.

After each micro-step: `make test-config` 0, harness empty diff, restart smoke passes (if wired). **Shell expectation now ~3,700 lines (LOC advisory — correction 1), not ~150; reviewer uses structural criteria not grep LOC.**

**Acceptance:** all 7 wires landed, no shell duplicates, harness parity at each step. **DIA-175:** wiring fixes via **S9’s GREEN session(s)** that performed the wire (not fresh escalated), per correction 7.

## Slice 10 — Structural gate: production imports + no duplicate shell definitions [blocking: S9 → S10]

**Goal:** Enforce binding structural criteria per V-A corrections 1 & 6.

- [ ] **Gate A — Production importer:** every retained `lib/{capability,ticket-gate,handoff,registry,stall-sweep,formatter,circuit-breaker}.ts` appears in `grep -R "from \"./lib/" .opencode/plugins/delegation-observer.ts` (static import). Missing importer fails gate.
- [ ] **Gate B — No duplicate shell definition:** for each seam’s canonical symbols (`CAPABILITY_SECRET`, `mintCapabilityToken`/`verifyCapabilityToken`, `parseFrontmatterFields`/`scanTickets`/`TICKET_ID_*`, `computeChecksum`/`atomicWriteHandoff`, `appendRow`/`appendMessageRow`/`captureConfigLoadSignal`/`atomicWriteBootMarker`, `STALL_SWEEP_KEY`/`stallThresholdMinutes`, `isFormatterIgnoredPath`/`extractPatchPaths`/`FORMATTER_*`, `ToolCircuitBreaker`/`CB_*`), `delegation-observer.ts` contains no definition beyond import delegation (ast-grep/grep check). Duplicate fails gate.
- [ ] **Gate C — Tests on production interface:** each lib’s test suite imports the same interface the shell imports (correction 1c) — no probe-only alias coverage.

**Acceptance:** Gates A+B+C all pass; `make test-config` 0; report evidence (grep outputs + harness diff) in ticket Fix. **DIA-175:** gate fixes via S10’s GREEN if needed, or via original S9 GREEN if lib-side.

## Slice 11 — Thin shell + parity + perf smoke (revised S8) [blocking: S10 → S11]

**Goal:** Close the 6-gate checklist with corrected expectations (Q7 as amended V-A).

- [ ] Verify shell is **composition/lifecycle only** (static imports + path construction + `globalThis` singleton ownership + hook/tool registration + cross-seam orchestration) — evidence-based ~3,700 lines (LOC advisory per correction 1; binding is S10 gates, no distortion; reviewer verifies diff + dep graph, not grep LOC)
- [ ] Preserve corrected sync/async per-hook contract (factory async, `experimental.session.compacting` async, stall timer async with sync body, formatter sync spawnSync, other hot hooks sync — correction 1)
- [ ] Preserve corrected perf wording (correction 3) + unchanged formatter/breaker constants (D2/D3)
- [ ] Full parity: `make test-config` 0 incl. `validate-plugin-loads.sh` Node+Bun Wy-compat; existing `scripts/__tests__/*` + harness suites pass; restart OpenCode + smoke real plugin load + representative hooks; formatter smoke on isolated tmp fixture (Q7 §3)
- [ ] Warm-up + multi-sample no-op `tool.execute.before/after` benchmark before/after on same runtime, excl. formatter; after-minus-before p95 <5 ms; record p50/p95 in ticket Fix evidence (Q7 §5) — no flaky CI assertion unless harness stable

**Acceptance (Global gates Q7 §1–6 as amended):** `openspec validate` 0; structural binding criteria + S10 gates pass; behavioral parity normalized traces exact on stable fields; perf p95 <5 ms; shell ~3,700 advisory.

**Dependencies:** S10. **Size:** integration. **DIA-175:** fixes via this slice’s GREEN (original wire owner if shell patch).

## Slice 12 — Re-review + ai-auditor (mandatory, non-binding; fixes via original sessions) [blocking: S11 → S12]

**Goal:** Independent review with DIA-175/ correction 7 discipline.

- [ ] Dispatch `@ai-auditor` independent review (mandatory, non-binding per correction 4 — APPROVE not mandatory); developer disposes findings; all accepted findings verified closed or residual risk explicitly accepted by developer (Q7 §6 as amended).
- [ ] **Accepted fixes applied through original GREEN/S11 implementer sessions per DIA-175 (V-A correction 7).** Critical severity alone does not authorize replacing them with fresh coder-escalated sessions. Escalation (`coder-escalated`) only if original lane cannot complete or repeatedly degrades — must be justified in ticket.
- [ ] Re-review cycle (max 2): after fixes, re-dispatch `@ai-auditor` targeted on prior accepted findings (`verified-closed`/`still-open`/`partial`).
- [ ] Register learnings only if reusable; `scripts/changelog-add --ticket DIA-260902-eqgg` + `scripts/changelog-render`; fill ticket Fix/Re-verify evidence (incl. S10 gate evidence + p50/p95 perf) before closure.

**Acceptance:** ai-auditor review completed + disposition + accepted findings closed/ risk accepted; all fixes via original sessions unless escalation justified; `openspec validate` 0; ticket closed. **DIA-175:** enforced.

## Ordering summary

`S0 → S1 capability → S2 ticket-gate → S3 handoff (best-effort) → S4 registry → S5 stall-sweep → S6 formatter → S7 breaker → S8 reconciliation+canonical-interface gate → S9a-g per-seam wiring (wire+delete+parity each) → S10 structural gate (production importer + no duplicate + tests-on-production-interface) → S11 shell parity+perf → S12 re-review+ai-auditor (fixes via original GREEN/S11)` — each slice unblocks next; no parallel coder slices violating DIA-175; escalation only per correction 7.

## Risks / notes

- Do not use grep line counts as binding gate (LOC advisory ~3,700 — correction 1; binding is S10 A+B+C)
- Do not retune formatter/breaker thresholds (D2/D3 deferred)
- Archive abort-on-failure is separate behavior-changing decision (correction 2); no new metrics (Q6)
- One canonical interface per lib (correction 3); reconciliation before wiring (correction 4); wire-one-at-a-time + delete+parity (correction 5); structural gate (correction 6); fixes via original sessions (correction 7)
