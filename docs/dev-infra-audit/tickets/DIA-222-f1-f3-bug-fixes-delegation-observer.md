---
id: DIA-222
title: 'F-1/F-3 bug fixes in delegation-observer.ts'
area: tests-infra
severity: Critical
status: CLOSED
blocked_by: []
discovered:
  source: council-consensus
  date: 2026-08-18
created: 2026-08-18
updated: 2026-08-18
session_id: ''
lane_id: ''
agent: ''
model: ''
parent_session_id: ''
attempts: 0
lease_expires_at: ''
files_touched: []
artifacts: []
evidence: []
---

## Description

Fix two CRITICAL bugs in delegation-observer.ts. After this slice, the archive name is collision-free and the slot identity never falls back to "unknown".

**Sub-step (a): F-1 fix -- archive name disambiguation**

Line 1353: change `const archiveName = \`${sessionId}.${iso}.json\``to`const archiveName = \`${sessionId}.${iso}.${randomUUID()}.json\``. `randomUUID` is already imported at line 42.

**Sub-step (b): F-3 fix -- slot identity fallback chain**

- Line 1196: `sessionID ?? parentSessionId ?? "unknown"` -> `sessionID ?? parentSessionId ?? sessionID`
- Line 3305: `parentSessionId ?? sessionID ?? "unknown"` -> `parentSessionId ?? sessionID ?? "unidentified-session"`
- Line 3512: `parentSessionId ?? sessionID ?? "unknown"` -> `parentSessionId ?? sessionID ?? "unidentified-session"`
- Line 3743: `parentSessionId ?? args.lane_id ?? "unknown"` -> `parentSessionId ?? args.lane_id ?? context?.sessionID ?? "unidentified-session"`
- Line 3948: `context?.sessionID ?? parentSessionId ?? "unknown"` -> `context?.sessionID ?? parentSessionId ?? "unidentified-session"`

**Routing:** section 10 (plugin change) -> @ai-specialist research -> @coder implementation -> @ai-auditor review

**DIA-175:** this is the GREEN implementation. The RED tests (DIA-223) are written by a DIFFERENT instance.

## Verification

1. Archive filename includes UUID suffix (line 1353)
2. All 5 slot-identity fallback chains no longer use `"unknown"` as the last-resort key
3. Line 3743 (log_decision handoff path) adds `context?.sessionID` as a fallback before the sentinel
4. No new TypeScript type errors
5. Plugin still loads (no syntax errors)
