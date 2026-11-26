# Handoff path containment gate findings - DIA-260827-5blh

Date: 2026-10-13
Gate: inline read-only research, explicitly approved by developer because the ai-specialist lane is unavailable.
Ticket: DIA-260827-5blh 'Handoff identity permits path traversal'

## Findings

1. The current `log_decision` path chooses `context.sessionID ?? args.lane_id ?? "unidentified-session"`. `lane_id` is therefore still a fallback when tool context is absent.
2. `.opencode/plugins/lib/handoff.ts` constructs slot, temporary, and archive paths from `sessionId` using `join()` without validating the identifier or checking resolved-path containment. For `../active`, the slot and temporary paths resolve outside `handoffs/` into the parent session directory.
3. The helper's injected filesystem seam in `.opencode/plugins/__tests__/handoff.test.mjs` can verify rejection before any write. The plugin-level fixture in `.opencode/plugins/__tests__/parallel-handoff.test.mjs` can exercise the real `log_decision` path and assert that `../active` creates no file in the parent session directory.
4. Existing test IDs include underscores and hyphens (for example `ses_c2_alpha`) and the production fallback is `unidentified-session`; any safe-id grammar must preserve those characters while rejecting dots and path separators.

## Options

1. Recommended: reject IDs outside an anchored `[A-Za-z0-9_-]+` grammar, then resolve each generated slot/temp/archive path and enforce containment under its trusted directory. Pros: fail-closed, preserves current valid IDs, prevents traversal and naming collisions from sanitization. Cons: malformed runtime IDs fail the handoff write and must be surfaced through the existing error path. Effort: small. Routing: security fix in the existing writer boundary.
2. Sanitize or strip path components from the supplied ID. Pros: may keep a write working for malformed IDs. Cons: distinct IDs can collapse to one filename and misattribute or overwrite handoffs; rejected.
3. Status quo. Pros: no code. Cons: caller-controlled fallback can write slot/temp/archive files outside `handoffs/`; rejected.

## RED test scope

- Drive the real terminal-handoff tool with no session context and `lane_id: "../active"`.
- Assert the call does not create `active.json` or its temp file in the parent session directory and does not mutate the reserved pointer/valid slot.
- Existing valid-ID tests (including underscore and hyphen IDs) must remain green.

## Evidence

- Tier 1: `.opencode/plugins/lib/handoff.ts` `coreAtomicWrite` derives slot, temp, and archive paths from `sessionId` with `join()`; `.opencode/plugins/delegation-observer.ts` passes context ID first but retains `args.lane_id` fallback.
- Tier 1: `handoff.test.mjs` has the fake-fs seam and reserved-name guard; `parallel-handoff.test.mjs` drives the real plugin and creates isolated temporary workspaces.
- [INFERENCE] An anchored component grammar plus resolved containment at the low-level writer is the narrowest defense because it protects every caller of that writer, not only the current plugin call site.

No implementation changes were made during this gate.
