---
title: permission asks in unattended lanes gate (DIA-260926-5vin)
date: 2026-09-27
ticket: DIA-260926-5vin
source: ai--2 / ses_f1e9a7716ffeVuSo0qFQkXMjbe (read-only, AGENTS.md 2.5 step 1)
verdict: GO-with-conditions
---

## Confirmed (opencode v1.18.32 source + docs, fetched 2026-09-26)

- INHERITANCE = MERGE (append), NOT replace. Every custom agent is built as
  `Permission.merge(defaults, user)` then
  `Permission.merge(item.permission, Permission.fromConfig(value.permission ?? {}))`;
  `evaluate()` resolves with `findLast` (last match wins). A per-agent
  `permission` object therefore does NOT replace the global one: global rules
  still apply, and an agent rule wins only on a SAME-PATTERN collision.
  Sources: opencode v1.18.32 `packages/opencode/src/agent/agent.ts` and
  `permission/index.ts`; docs https://opencode.ai/docs/permissions/
  ("Agent permissions are merged with the global config, and agent rules take
  precedence").
- CONSEQUENCE: `.opencode/opencode.jsonc:374-376` ("agent-level map does NOT
  inherit global denies (no `*` catch-all here), so destructive forms must be
  denied in-map") is FACTUALLY INCORRECT for 1.18.32. The coder /
  coder-escalated restated denies are harmless redundancy, not load-bearing.
- external_directory: a SEPARATE key, default "ask", applying to
  read/edit/glob/grep AND bash. Already auto-whitelisted in 1.18.32:
  `~/.local/share/opencode/tool-output/*`, `/tmp/opencode/*`, every
  discovered skill dir, and reference dirs. A blanket `{"*":"deny"}` is
  appended LAST and would CLOBBER those (last-match-wins).
- deny vs ask: `deny` returns a DeniedError BEFORE any prompt or wait (no
  stall). `--auto` auto-approves what would otherwise `ask`; explicitly
  configured `deny` stays enforced under `--auto`.
- KEY REFRAME: under `--auto` an `ask` is AUTO-APPROVED, so it does NOT
  stall. The 15 `permission_auto_rejected` stalls (300s) therefore prove
  those lanes ran WITHOUT `--auto`. `--auto` is the stall fix; `ask->deny`
  is what stops `--auto` from silently granting destructive ops.
- PERMISSION_STALL_TIMEOUT_MINUTES is a PROJECT PLUGIN var
  (.opencode/plugins/needs-input-observer.ts:316-323, default 300s), NOT an
  OpenCode core setting. On expiry the plugin force-rejects via the SDK
  (autoRejectPermission ~411-479) and writes the `permission_auto_rejected`
  registry row.

## Conditions

1. Run `opencode debug agent <name>` to confirm the merge empirically
   (rule count = defaults + global + agent) BEFORE any edit.
2. Fix the misleading comment at .opencode/opencode.jsonc:374-376.
3. external_directory: enumerate only real needs and pair `edit: deny` for
   read-only; do NOT blanket-deny the key.
4. DROP the "add explicit '*' catch-all to every permission object" item -
   wrong premise; `bash: {"*":"deny"}` would BREAK agents.
5. Raising PERMISSION_STALL_TIMEOUT_MINUTES is a stopgap, not a fix.

## Sources

- https://opencode.ai/docs/permissions/ ; https://opencode.ai/docs/agents/ ;
  https://opencode.ai/docs/policies/ ; https://opencode.ai/docs/github/ ;
  https://opencode.ai/v2/docs/permissions/
- opencode v1.18.32 source: agent/agent.ts, permission/index.ts,
  tool/truncation-dir.ts, core/global.ts, skill/index.ts

## Outcome

- TODO-pending-implementation: implementation plan pending developer review.
