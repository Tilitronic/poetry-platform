# DIA-070 §10 gate findings — plugin re-entrancy guard gaps (2026-08-08)

- **Date:** 2026-08-08
- **Source:** §10 Phase-1 gate research by @ai-specialist for DIA-070 (telemetry plugin re-entrancy guard gaps — P1-P4 guard coverage across opencode-telemetry@0.1.19 and opencode-token-monitor@0.5.0). Registered per AGENTS.md §10 ("orchestrator registers the findings"); the executor lane persists them so they are recoverable beyond the git diffs. Developer disposition: learnings entry only — no conspect pipeline (zero external sources; config/plugin-internal topic).
- **Status:** REGISTERED 2026-08-08 — learnings-only registration per developer disposition. No plugin sources, config files, or implementation code touched; no commit (the commit happens with the DIA-070 implementation phase later).

## Outcome

- **Learnings-only registration (2026-08-08).** The @ai-specialist §10 Phase-1 gate for DIA-070 returned findings flagged `PERSISTENCE_RECOMMENDED: true`. The developer chose "learnings entry only" (no conspect pipeline — zero external sources, config/plugin-internal topic). This document is the standard §10 registration artifact; the DIA-070 fix implementation (P4 persistence migration, P2a/P2b guard Sets) and its commit are deferred to the DIA-070 implementation phase.

## Findings

- **1 — P1-P4 guard coverage matrix (source-inspected ground truth):**
  - opencode-telemetry@0.1.19: P4 only — `seenMessageIds` in-memory Set (src/handlers.ts:19, check at :74) — LACKS P1/P2/P3
  - opencode-token-monitor@0.5.0: P1 only — `inFlightSessions` Set (dist/plugin.js:1506, check :2150, cleanup :2182 in finally) — LACKS P2/P3/P4
  - BOTH lack P2 (context suppression) and P3 (message-level dedup Set)
  - Audit verdict: NO active infinite loops, MEDIUM-HIGH confidence normal operation safe — this is defense-in-depth, not an active bug
- **2 — Key API constraint:** OpenCode `EventMessageUpdated` hook carries `info: Message` (id/sessionID/role/time/tokens) but NO re-entry marker — a context-carried suppression flag is NOT feasible via the event itself. Fixes must be plugin-local state. Message `id` is stable.
- **4 — Subagent-output anomaly resolved:** `opencode-subagent-output` deliberately removed from both plugin arrays (CHANGELOG.md:229, 2026-08-02 P5 fix — repo had no package.json, never loaded). De-scoped from DIA-070. Residual doc gap: global `~/.config/opencode/plugins/subagent-reporter.ts` exists but is NOT in the global plugin array — CHANGELOG claim "global uses local subagent-reporter.ts" is stale; separate cleanup ticket.

## Recommendations

- **3 — Recommended fix pattern (DIA-070):**
  - P4 persistence: add `UNIQUE(message_id)` partial index (`WHERE message_id IS NOT NULL`) to telemetry `turns` table via migration v6 — `INSERT OR IGNORE` already at src/db.ts:247 → silent dedup across restarts. Check for existing duplicates first; warn+skip if found. SQLite allows multiple NULLs in UNIQUE.
  - P2a telemetry: add `inFlightMessageIds` Set — check at entry, add, delete in finally (mirror token-monitor's P1 pattern but keyed by msg.id)
  - P2b token-monitor: add `seenMessageIds` Set for P4 symmetry — plugin is COMPILED (dist/plugin.js) → upstream PR preferred, or vendor patched copy under `.opencode/plugins/` (like delegation-observer.ts)
  - Follows the DIA-069 ADR pattern (a8f2be0): interim guard → vendored patch with .bak backups → upstream PR

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
