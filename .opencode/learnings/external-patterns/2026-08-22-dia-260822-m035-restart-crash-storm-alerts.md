# DIA-260822-m035: OpenCode restart crash-storm alerts - investigation-only findings (2026-08-22)

- **Date:** 2026-08-22
- **Source:** ai-specialist session ses_fd4d6b67dffeobME4K94bPJBJY (verified findings). Registered per AGENTS.md section 10 Phase 1 (orchestrator registers findings before config-adjacent forensic work).
- **Status:** INVESTIGATION-ONLY. No remediation approved. Do NOT modify plugin/config behavior, tickets, or unrelated memory on the basis of this artifact.
- **Ticket:** DIA-260822-m035 'investigate-opencode-restart-crash-storm-alerts' (docs/dev-infra-audit/tickets/DIA-260822-m035-investigate-opencode-restart-crash-storm-alerts.md, OPEN).

## Context

A crash-storm alert cascade was observed after rapid OpenCode restarts. The ai-specialist traced the alert terms to plugin lifecycle and persisted state, NOT to confirmed process crashes. This artifact records the four verified root-cause findings as evidence only, to gate further config-adjacent forensic work. No fix is approved.

## Findings (evidence-only)

### F1: Rapid OpenCode restarts create duplicate plugin stall sweep timers

The delegation-observer plugin arms a single 60s stall sweep via setInterval at module/plugin-function scope. The interval handle is stored in a local const and only cleared in the dispose hook. On rapid restarts where the prior plugin instance's dispose does not reliably fire before the next load, a new interval is created while the prior process may still hold a reference, producing duplicate/overlapping sweep timers that each scan the registry and emit independent stall_detected rows.

- Source: .opencode/plugins/delegation-observer.ts:445 (STALL_SWEEP_INTERVAL_MS = 60_000), :2409-2417 (setInterval + try/catch sweep), :4630-4633 (clearInterval only in dispose hook).

### F2: Stale non-terminal session registry rows trigger stall and silent-failure alert cascades

Both detectors key off non-terminal dispatch_state rows (RUNNING / DISPATCHED) with no terminal row:

- Proactive sweep sweepStalledSessions() emits stall_detected for any key whose latest dispatch_state row is non-terminal past role thresholds (10/20 min) and a stall_detected escalation:"dead" past 60 min (ana011 claim-staleness protocol; note text "assumed dead - still non-terminal past STALL_DEAD_MINUTES").
- Reactive checkSilentFailures() emits silent_failure_alert for any group with non-terminal rows and no terminal row.

Stale non-terminal rows from prior sessions (never resolved by a terminal event) therefore re-fire on every sweep tick and on every terminal boundary scan, cascading into thousands of alert rows.

- Source: .opencode/plugins/delegation-observer.ts:2171-2213 (checkSilentFailures), :2292-2376 (sweepStalledSessions + dead escalation), :2270 (dead note text).
- Corroborating runtime artifact: .opencode/session/registry.jsonl (generated, 9010 rows as of 2026-08-22) contains 6686 stall_detected rows and 138 silent_failure_alert rows; sample dead-escalation rows carry the ana011 note above.

### F3: probe/oracle alert terms derive from persisted adaptive routing state and disabled agent names, not confirmed crashes

The "probe" term in routing state is the adaptive-routing circuit-breaker field last_probe. It is a health-gate timer (probe cooldown / HALF_OPEN transition on failure), not a crash signal. The "oracle" term derives from the disabled agent name in config (oh-my-opencode-slim.jsonc disabled_agents includes "oracle"; AGENTS.md section 9 lists @oracle as disabled). Neither term indicates a confirmed OpenCode crash; both are persisted-state / configuration artifacts that the crash-storm alert wording surfaced.

- Source: .opencode/plugins/delegation-observer.ts:1616 (last_probe type), :1671 / :1726 (init), :1815-1835 (probe cooldown + HALF_OPEN transition), :1926-1929 (last_probe set on failure); .opencode/oh-my-opencode-slim.jsonc:5 (disabled_agents includes "oracle"); AGENTS.md section 9 (agent naming, @oracle disabled).

### F4: Stale ticker entries persist across restarts

needs-input-observer seeds its in-memory waiting / errors / permissions maps from ticker.json on every boot via seedFromDisk(). Entries are only removed by explicit CLEAR transitions; there is no TTL/expiry sweep on the waiting/errors maps themselves (only the permission-ask timers are re-armed with remaining time). A ticker entry written before a restart therefore survives indefinitely and is re-loaded verbatim on the next boot, so stale "needs-input" state persists across restarts until manually cleared.

- Source: .opencode/plugins/needs-input-observer.ts:306-320 (in-memory maps + boot seed comment), :627-697 (seedFromDisk re-reads ticker.json, re-arms permission timers with remaining time), :699+ (clear only on explicit CLEAR transition).

## Concluded forensic correction (final pass, 2026-08-22)

The "restart crash-storm" framing in the title and F1 is misleading. Final read-only forensics establish:

- OpenCode ran as a STABLE PID 1 throughout the incident. No process restart occurred.
- No accessible OS-level crash evidence exists. The crash-storm alert wording implied process crashes that did not happen.
- The seven plugin reloads in ~40 seconds occurred INSIDE the stable PID 1 (plugin-lifecycle reload, not a process restart). This is the real trigger for the duplicate stall-sweep timers in F1; the "prior process may still hold a reference" wording in F1 is incorrect - the duplicate intervals arose from in-process plugin reloads, not a prior process.
- 390 stale non-terminal registry keys (not the vaguer "thousands of alert rows") drove the 20:07 dead-session cascade. The 6686 stall_detected / 138 silent_failure_alert rows in F2 are downstream emissions from these 390 keys.
- probe/oracle confirmed as state/config terms (F3 stands): last_probe = adaptive-routing circuit-breaker health-gate timer; oracle = disabled agent name. Neither indicates a crash.

Remediation surface (if ever approved): in-process plugin-reload hygiene + registry-key terminal-resolution. NOT process-restart handling.

## Outcome field

PENDING - INVESTIGATION ONLY. No remediation approved. This artifact is a gate for further config-adjacent forensic work on DIA-260822-m035. Do not modify plugin/config behavior, tickets, or unrelated memory on the basis of these findings. [Update after developer disposition.]

## Tags

DIA-260822-m035, restart-crash-storm, stall-sweep-timer, registry-non-terminal, silent-failure-cascade, adaptive-routing-probe, disabled-agent-oracle, ticker-persistence, investigation-only, no-remediation, ai-specialist
