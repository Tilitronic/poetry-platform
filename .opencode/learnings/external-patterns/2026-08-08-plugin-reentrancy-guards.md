# DIA-070 §10 gate findings — plugin re-entrancy guard gaps (2026-08-08)

- **Date:** 2026-08-08
- **Source:** §10 Phase-1 gate research by @ai-specialist for DIA-070 (telemetry plugin re-entrancy guard gaps — P1-P4 guard coverage across opencode-telemetry@0.1.19 and opencode-token-monitor@0.5.0). Registered per AGENTS.md §10 ("orchestrator registers the findings"); the executor lane persists them so they are recoverable beyond the git diffs. Developer disposition: learnings entry only — no conspect pipeline (zero external sources; config/plugin-internal topic).
- **Status:** REGISTERED 2026-08-08 — learnings-only registration per developer disposition; **updated 2026-08-08 (Phase 6 follow-up)** to reflect that the DIA-070 fixes WERE implemented as vendored patches (3 patches, `.bak-dia070` backups, commit 3ac8c0f), Phase 5 runtime proof PASSED, and the Phase 6 audit disposition completed (Patch-3 ordering fix + shadow-copy risk, below).

## Outcome

- **Learnings-only registration (2026-08-08).** The @ai-specialist §10 Phase-1 gate for DIA-070 returned findings flagged `PERSISTENCE_RECOMMENDED: true`. The developer chose "learnings entry only" for the GATE registration (no conspect pipeline — zero external sources, config/plugin-internal topic). This document is the standard §10 registration artifact. **The DIA-070 fix implementation was NOT deferred** — it followed in the implementation phase: three vendored patches in the volatile npm cache (commit 3ac8c0f, `.bak-dia070` backups for all three files): P4 persistence migration v6 `idx_turns_message_id` UNIQUE partial index (opencode-telemetry `src/db.ts`), P2a `inFlightMessageIds` Set (opencode-telemetry `src/handlers.ts`), P2b `seenMessageIds` Set (opencode-token-monitor `dist/plugin.js`). Phase 5 runtime proof PASSED (process PID 106897 started 21:09:18Z > 20:11Z patch; `schema_version='6'` via `_meta`; `idx_turns_message_id` index live; 0 duplicate `message_id` rows; `make test-config` exit 0; git status clean except untracked DIA-071 dir). Phase 6 @ai-auditor audit disposition completed 2026-08-08 (see "Phase 6 follow-ups" below).

## Findings

- **1 — P1-P4 guard coverage matrix (source-inspected ground truth):**
  - opencode-telemetry@0.1.19: P4 only — `seenMessageIds` in-memory Set (src/handlers.ts:19, check at :74) — LACKS P1/P2/P3
  - opencode-token-monitor@0.5.0: P1 only — `inFlightSessions` Set (dist/plugin.js:1506, check :2150, cleanup :2182 in finally) — LACKS P2/P3/P4
  - BOTH lack P2 (context suppression) and P3 (message-level dedup Set)
  - Audit verdict: NO active infinite loops, MEDIUM-HIGH confidence normal operation safe — this is defense-in-depth, not an active bug
- **2 — Key API constraint:** OpenCode `EventMessageUpdated` hook carries `info: Message` (id/sessionID/role/time/tokens) but NO re-entry marker — a context-carried suppression flag is NOT feasible via the event itself. Fixes must be plugin-local state. Message `id` is stable.
- **4 — Subagent-output anomaly resolved:** `opencode-subagent-output` deliberately removed from both plugin arrays (CHANGELOG.md:229, 2026-08-02 P5 fix — repo had no package.json, never loaded). De-scoped from DIA-070. Residual doc gap: global `~/.config/opencode/plugins/subagent-reporter.ts` exists but is NOT in the global plugin array — CHANGELOG claim "global uses local subagent-reporter.ts" is stale; separate cleanup ticket.
- **5 — Shadow-copy risk (Phase 6, 2026-08-08):** stale UNPATCHED copies of the plugins exist outside the patched cache path: `~/.config/opencode/node_modules/opencode-telemetry` (migrations only to v5 — no `idx_turns_message_id`, no `inFlightMessageIds`) and cache aliases `opencode-telemetry@latest`, `opencode-telemetry` (unscoped), `opencode-token-monitor@latest`, `opencode-token-monitor` (unscoped) — all verified to lack the P2/P4 patch markers (0 hits for `idx_turns_message_id` / `seenMessageIds`). If `~/.cache/opencode/packages/` is cleared (cache churn / plugin reinstall), the duplicate-turn bug SILENTLY regresses — the runtime loads the unpatched copy. **Mitigation (documented, NOT implemented):** a durable runtime source-of-truth for patched plugin bits OR a startup fingerprint/checksum guard; re-apply the patches to stale copies when cache churn occurs.

## Recommendations

- **3 — Recommended fix pattern (DIA-070):**
  - P4 persistence: add `UNIQUE(message_id)` partial index (`WHERE message_id IS NOT NULL`) to telemetry `turns` table via migration v6 — `INSERT OR IGNORE` already at src/db.ts:247 → silent dedup across restarts. Check for existing duplicates first; warn+skip if found. SQLite allows multiple NULLs in UNIQUE.
  - P2a telemetry: add `inFlightMessageIds` Set — check at entry, add, delete in finally (mirror token-monitor's P1 pattern but keyed by msg.id)
  - P2b token-monitor: add `seenMessageIds` Set for P4 symmetry — plugin is COMPILED (dist/plugin.js) → upstream PR preferred, or vendor patched copy under `.opencode/plugins/` (like delegation-observer.ts)
  - Follows the DIA-069 ADR pattern (a8f2be0): interim guard → vendored patch with .bak backups → upstream PR
- **Implementation status (2026-08-08):** all three recommended fixes IMPLEMENTED (commit 3ac8c0f, `.bak-dia070` backups) — see Outcome + "Phase 6 follow-ups" below. Upstream PRs NOT yet created (out of scope for the lane).

## Phase 6 follow-ups (2026-08-08)

- **Patch-3 ordering fix (FOUND → FIXED).** @ai-auditor found an ordering defect in the vendored token-monitor patch: `seenMessageIds.add(msgInfo.id)` executed BEFORE the `inFlightSessions` check (dist/plugin.js ~2150-2154). If the session was already in flight, the handler returned early and the message ID stayed "seen" — potentially suppressing later first-time processing for that ID. Fixed by reordering the entry sequence: role filter → `inFlightSessions` check (return WITHOUT adding to `seenMessageIds`) → `seenMessageIds` check (return if already seen) → `seenMessageIds.add(msgInfo.id)` (only when actually proceeding to process) → existing processing path unchanged. New backup `dist/plugin.js.bak-dia070-fix` (original `.bak-dia070` untouched); `node --check` exit 0.
- **Registration fidelity reconciled.** This entry + the learnings index row updated from "no implementation touched / deferred" to "applied/implemented" (3 patches, `.bak-dia070` backups, commit 3ac8c0f, Phase 5 runtime proof PASSED, Phase 6 audit disposition completed).
- **Shadow-copy risk** — documented as finding 5 above; mitigation documented, NOT implemented.
- **Deferred:** AGENTS.md §2.5 doc-drift (implementation-phase narrative there still says fixes "deferred" / Phase 5 "PENDING") — future §10 change.

## Sources

- DIA-070 ticket: `docs/dev-infra-audit/tickets/DIA-070.md`
- Project config: `.opencode/opencode.jsonc` plugin array :359-365
- Global config: `~/.config/opencode/opencode.jsonc` :130-138
- Plugin source (telemetry): `~/.cache/opencode/packages/opencode-telemetry@0.1.19/node_modules/opencode-telemetry/src/{handlers.ts,db.ts}`
- Plugin source (token-monitor, compiled): `~/.cache/opencode/packages/opencode-token-monitor@0.5.0/node_modules/opencode-token-monitor/dist/plugin.js`
- `.opencode/CHANGELOG.md` :229
- Zero external fetches (all sources local)

## Tags

§10-gate, plugins, re-entrancy, DIA-070, opencode-telemetry, opencode-token-monitor, dedup, defense-in-depth, plugin-local-state, upstream-patch
