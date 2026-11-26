# OpenCode custom-tool permission gate: registration, visibility gate, hook ordering, and childSessionAgent fail-open (2026-11-04)

- Date: 2026-11-04
- Ticket: DIA-260827-ft3z (shell permissions bypass write scopes)
- Status: registered from a config-gate report (facts as filed for the campaign; each claim carries its evidence and was not re-derived here)
- Scope: OpenCode v1.18.32, plugin SDK @opencode-ai/plugin 1.17.7

## Findings

1. **Custom tools register from the tools directory; the filename stem is the name.** Custom tools are registered from `.opencode/tools/*.{js,ts}` (the singular `.opencode/tool/` is also scanned). The filename stem is the tool name; a named export becomes `<stem>_<export>`. Evidence: `packages/opencode/src/tool/registry.ts` (v1.18.32); https://opencode.ai/docs/custom-tools/.

2. **A custom tool is its own permission key, not gated by `bash`.** A custom tool is its own permission key and is NOT gated by the `bash` key; an agent with `"bash": "deny"` can still call it. Evidence (repo proof): `.opencode/tools/get-my-session-id.ts` is called by lanes whose maps have no entry for it.

3. **Undeclared permission keys resolve to ALLOW.** Undeclared permission keys resolve to ALLOW through the built-in baseline, so an explicit allow is cosmetic UNLESS a deny exists elsewhere. Evidence: built-in permission baseline in `permission/index.ts` (v1.18.32); mechanism recorded in `.opencode/learnings/external-patterns/2026-10-06-undeclared-permission-baseline-allow-drift.md`.

4. **The only pre-execute control for a custom tool is the visibility gate.** A flat `"<tool>": "deny"` hides the tool from that agent's schema; an object map with trailing allows is a NO-OP because the plugin-tool execute wrapper performs no `ctx.ask`. Evidence: `permission/index.ts` `disabled()` (v1.18.32); registry.ts `fromPlugin` wrapper.

5. **Custom-tool file writes are not governed by the agent `edit` permission.** `edit` covers only edit/write/apply_patch, so a custom tool's file writes fall outside it; the in-tool `context.agent` guard is therefore the real runtime access control. Evidence: `permission/index.ts` `disabled()` mapping; https://opencode.ai/docs/permissions/.

6. **`tool.execute.before` contract and throw semantics.** `tool.execute.before(input, output)` where input={tool, sessionID, callID} and output={args}; for bash the command string is `output.args.command`; throwing from the hook skips `item.execute`. Evidence: `@opencode-ai/plugin/dist/index.d.ts:235-241`; `packages/opencode/src/session/tools.ts` (v1.18.32); docs plugins page.

7. **ORDERING: the hook runs BEFORE the permission check.** Permission asks happen inside each built-in tool's execute via `ctx.ask`, so a hook denial is the outermost per-call gate and a config-denied command is still seen by it first. Evidence: docs plugins page (hook before permission asks); the in-repo carrier for the ask-inside-execute citations is `openspec/changes/researcher-fetch-adapter-and-protected-path-gate/design.md` D5 (asks live in execute bodies, `oh-my-opencode-slim@2.2.19/dist/index.js:43111-43132`; throw precedent `delegation-observer.ts:1781-1784`, `1850-1855`).

8. **Permission evaluation is `findLast` over the flattened ruleset; agent rules win.** A flat string becomes pattern `*`; agent rules are appended AFTER global rules and win. Consequence: a flat agent deny fully overrides a global allow, and a deny-first map is correct only when its allows come last. Evidence: `permission/index.ts` `evaluate()` (v1.18.32); recorded in `.opencode/learnings/external-patterns/2026-11-01-opencode-permission-resolver-findlast-and-deny-first-maps.md`.

9. **Patterns match the WHOLE raw command string, and a trailing catch-all deny hides the tool.** A grant written as `scripts/foo.sh` does not match `bash scripts/foo.sh`; starred forms must be used. And a map must NEVER end with a catch-all deny: the visibility gate reads the last matching rule, so a trailing `"*": "deny"` hides the entire tool instead of restricting it. Evidence: wildcard matcher semantics in `permission/index.ts` (v1.18.32); both halves recorded in `.opencode/learnings/external-patterns/2026-11-01-opencode-permission-resolver-findlast-and-deny-first-maps.md` (sections 4) and `2026-08-13-bash-permission-wildcard-anti-pattern.md`.

10. **`childSessionAgent` is populated only in `tool.execute.after` and fails open.** `childSessionAgent` (`delegation-observer.ts:532`) is populated only in tool.execute.after (`:2748`) keyed by child session id. It returns undefined (fail-open) for: root sessions never dispatched through task(), sessions predating a plugin/OpenCode restart (in-memory only), task_revive sessions, and dispatches whose task output carried no parseable id. A backfill source exists via the `session.created` event's `info.agent` (precedent: `needs-input-observer.ts:1407-1416`). Evidence: `delegation-observer.ts:532`, `:2748`; `needs-input-observer.ts:1407-1416`.

## Cross-references

- DIA-260827-ft3z (parent - shell permissions bypass write scopes)
- `.opencode/learnings/external-patterns/2026-11-01-opencode-permission-resolver-findlast-and-deny-first-maps.md` (resolver semantics companion)
- `.opencode/learnings/external-patterns/2026-10-06-undeclared-permission-baseline-allow-drift.md` (visibility-gate / baseline-allow companion)

## Outcome

Outcome: pending implementation (update after DIA-260827-ft3z lands)
