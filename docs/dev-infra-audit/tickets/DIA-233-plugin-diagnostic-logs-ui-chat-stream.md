# DIA-233 - Plugin diagnostic logs via TUI-safe app.log channel

---

id: DIA-233
title: "Plugin diagnostic logs via TUI-safe app.log channel"
area: opencode-plugins
severity: Major
status: CLOSED
blocked_by: [DIA-204]
parent_epic: ""
gate_state: "skipped"
gate_triggers: []
gate_waivers: []
gate_override: ""
discovered:
source: review
date: 2026-08-19
created: 2026-08-19
updated: 2026-08-19

session_id: ""
lane_id: ""
agent: ""
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: ""
files_touched: []
artifacts: []
evidence: []

---

## Description

delegation-observer.ts still used console.warn for plugin diagnostics (27 call sites). In OpenCode's TUI runtime, console.warn surfaces as high-severity chat-stream notifications, creating noisy false alarms for benign operational events (archive skips, in-flight handoff filters, parse fallbacks).

DIA-204 established the precedent: plugin diagnostics must use ctx.client.app.log instead of console.warn. DIA-233 completes the migration by converting all remaining console.warn calls to the tuiSafeWarn helper.

## Verification

- [ ] Zero console.warn calls remain in delegation-observer.ts
- [ ] All 7 test files capture app.log entries instead of suppressing console.warn
- [ ] `bun test` passes (plugin tests: 81 pass, 0 fail)
- [ ] `make test-config` passes (56 pass, 0 fail)

## Fix

Extracted tuiSafeWarn helper function in delegation-observer.ts and converted all 27 console.warn calls to use ctx.client.app.log. Updated 7 test files to capture app.log entries via the logs array pattern instead of monkey-patching console.warn.

**Files:** `.opencode/plugins/delegation-observer.ts`, `.opencode/plugins/__tests__/parallel-handoff.test.mjs`, `.opencode/plugins/__tests__/empty-result-detection.test.mjs`, `.opencode/plugins/__tests__/failure-cap.test.mjs`, `.opencode/plugins/__tests__/dia217-ticket-gate.test.mjs`, `.opencode/plugins/__tests__/dia220-apoptosis-paracrine.test.mjs`, `.opencode/plugins/__tests__/circuit-breaker.test.mjs`, `.opencode/plugins/__tests__/context-velocity.test.mjs`, `.opencode/plugins/__tests__/harness-scenarios/empty-result-silent-failure.scenario.mjs`

## Re-verify

- `bun test` (plugin tests): 81 pass, 0 fail
- `make test-config`: 56 pass, 0 fail
- `bun test` (full suite): 215 pass, 0 fail
