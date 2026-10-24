# DIA-080 context_usage cumulative-proxy root cause + session-scoping fix (2026-08-11)

- **Date:** 2026-08-11
- **Source:** DIA-080 (orchestrator halts/stops mid-work repeatedly across sessions) - developer report 2026-08-10 + session-6 correlation evidence; Option A fix implemented by coder lane (commits 4f5bb46 + 84be46f); S10-P6 registration by code-executor lane.
- **Status:** IMPLEMENTED + ai-auditor APPROVE (cycle 2, prior finding verified-closed); restart-verify PENDING (next OpenCode boot).
- **Outcome note:** context_usage now reports a low session-scoped fraction instead of a cumulative 100%; ticket DIA-080 stays OPEN pending-validate until the post-restart reading is confirmed.

## Ticket

- **DIA-080** (Major, OPEN pending-validate) - "orchestrator halts/stops mid-work repeatedly across sessions - requires developer continue nudges".
- **Related:** NEXT-RUN.md self-rerun handoff threshold (>=50%), DIA-063 (ticket-creation gate / handoff integrity), DIA-061 (checksum / handoff protocol).

## Root cause pattern

- **tool reads ALL registry/messages rows with zero session filtering** - the context_usage proxy summed every session since 2026-08-04: message_count 1716, delegation_count 1226 cumulative.
- **+ estimate formula caps at 100%** - delegationCount*3000 + messageCount*1000 + sessionCount*10000 produced estimated_tokens 5,524,000 vs context_window 1,000,000 -> usage_percent always ~100%.
- **= false self-rerun trigger** - the proxy ALWAYS read >= the >=50% NEXT-RUN.md threshold, firing premature idle/handoff stops on EVERY session regardless of true current-session usage.

## Fix (implemented 2026-08-11, Option A)

- **4f5bb46** - in-memory per-session counters: context_usage estimate computed from the current session only (session-scoped message/delegation counts), no longer cumulative across sessions.
- **84be46f (ai-auditor cycle-1 Major nit fix)** - calling-session key resolved from ToolContext.sessionID (not a sticky first-captured process variable), closing the session-key drift finding.

## Outcome

- ai-auditor cycle 2 VERDICT approve: prior finding verified-closed, all regression checks clean, no new observations, RESTART_VERIFY_READY yes.
- Restart-verify PENDING (S10 Phase 5): on next OpenCode boot, context_usage should report a low session-scoped fraction instead of 100%. Ticket stays OPEN pending-validate - do NOT flip to CLOSED.

## Reusable lesson

Session-scoped telemetry must key on the current tool-invocation session, not a sticky first-captured process variable. A cumulative read of a global event store makes any fixed percentage threshold useless as a trigger: a proxy that always reports >=100% fires every threshold guard regardless of actual per-session usage. Both the aggregation scope (per-session) and the session identity source (ToolContext.sessionID at call time) must be correct - fixing only the formula leaves the session-key drift that reintroduces cross-session bleed.

## Tags

DIA-080, context_usage, session-scoping, cumulative-proxy, delegation-observer, ToolContext.sessionID, self-rerun-threshold, telemetry, restart-verify-pending
