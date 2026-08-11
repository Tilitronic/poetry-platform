# DIA-080 — orchestrator halts/stops mid-work repeatedly across sessions — requires developer "continue" nudges

<!-- Developer report 2026-08-10 ("it looks like you stopped again..."), observed
     across multiple sessions. Filed by the docs lane (code-executor re-route)
     2026-08-10. -->

---

id: DIA-080
title: "orchestrator halts/stops mid-work repeatedly across sessions — requires developer \"continue\" nudges"
area: opencode-config
severity: Major
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
discovered: 2026-08-10
source: test-lane
date: 2026-08-10
created: 2026-08-10
updated: 2026-08-11

# --- Session Attribution (v2 schema, optional — GRANDFATHERED for DIA-001..049) ---

session_id: "" # OpenCode session ID that owned this ticket
lane_id: "" # e.g. cod-1, ai--3
agent: "" # agent name (coder, reviewer, etc.)
model: "" # model ID used
parent_session_id: "" # orchestrator's session ID (populated via get-my-session-id tool)
attempts: 0 # how many delegations attempted
lease_expires_at: "" # ISO-8601; set on DISPATCHED, cleared on COMPLETE
files_touched: [] # list of file paths modified
artifacts: [] # list of artifact references (commits, test outputs)
evidence: [] # list of evidence URIs (messages.md#row, registry.jsonl#seq)

---

## Description

Developer reports (2026-08-10): "it looks like you stopped again. You stop
frequently, I noticed it in previous sessions too." The orchestrator halts
mid-task without completing planned work, requiring the developer to manually send
"continue" to resume. Observed across multiple sessions.

Impact: broken autonomous completion, workflow friction, risk of incomplete
campaigns/handoffs (a stop mid-campaign can leave work half-done).

Root-cause hypotheses to investigate:

(a) context/token budget exhaustion where the >=50% self-rerun handoff threshold
(NEXT-RUN.md) is not triggering;
(b) orchestrator emitting a final message without a required continuation action;
(c) delegation-observer session.idle handling causing premature stop;
(d) empty-return lane patterns (cf. cod-2/cod-3 empty returns, lesson
L20260810-001);
(e) permission-denied tool calls silently halting progress;
(f) wait_for_user misuse.

Investigation scope: correlate stop points with context_usage estimates,
registry.jsonl session outcomes, and message flow; verify whether stops coincide
with specific tool calls or delegation completions.

## Session-6 correlation evidence (2026-08-11, campaign c-20260809-residual-closure)

Observed stops THIS session (orchestrator ses_01011db5affeaGyNFicHS5WLWj):

1. ~09:01:22Z "orchestrator idle turn - delegations complete" (messages.jsonl
   row 1703) after 6 lanes; next lane spawned 09:03:34Z -> a developer
   "continue" nudge was required.
2. ~09:17:32Z session-6 exit handoff written (row 1708) after 8 lanes; next
   verification lane spawned 09:21:17Z -> developer nudge required again.
   current-handoff.json records: "Session halted at context threshold (DIA-080
   stop occurred mid-session) - self-rerun handoff written per NEXT-RUN.md".

Lane counts: session-5 orchestrator (ses_01238cd3fffec3XtXzQEDln1As) spawned
15 subagent lanes on 2026-08-11; this session's orchestrator spawned 12. All
12 completed (registry COMPLETE); NO session_failed / silent_failure_alert /
anomaly_backward_transition rows exist for either orchestrator session today
-> no plugin-level idle/error anomaly at the registry layer. (The
anomaly_backward_transition "multi-idle child session" pattern appears only on
2026-08-09/10, not today.)

context_usage correlation (KEY FINDING): the context_usage proxy reports 100%
(usage_percent) and was 100% at stop time. But it is a LOW-CONFIDENCE
CUMULATIVE estimate, not per-session: estimated_tokens 5,524,000 vs
context_window 1,000,000; message_count 1716 (= total messages.jsonl rows
across all 13 sessions since 2026-08-04); delegation_count 1226 cumulative.
Consequence: the proxy ALWAYS reads >= the NEXT-RUN.md self-rerun threshold
(>=50%), so hypothesis (a) "token-budget exhaustion triggering the handoff
threshold" fires on EVERY session regardless of true current-session usage -
a false positive that explains the repeated premature idle/handoff stops.

Recommendation (developer-approved direction):

- Lower the self-rerun handoff threshold to ~40% (NEXT-RUN.md).
- Batch lanes earlier and front-load small lanes; avoid long single-lane tails
  (cf. cod-5 11m09s empty return this session).
- Re-scope the context_usage proxy to the CURRENT session (or base the
  self-rerun decision on current-session signals) - a cumulative 100% reading
  makes any fixed threshold useless as a trigger.
- Keep hypothesis (c) delegation-observer idle handling in view: the "idle
  turn - delegations complete" semantic events precede both stops, even though
  the registry shows no idle anomaly today.

## Verification

- [ ] Observe 3+ consecutive sessions; count involuntary stops requiring a "continue" nudge.
- [ ] Correlate each stop with context_usage / registry.jsonl / messages.jsonl evidence to identify the root cause.
- [ ] Implement the fix.
- [ ] Confirm: 2+ consecutive sessions complete planned work without developer "continue" nudges.

## Fix

May be §10-routed depending on root cause (config/plugin/prompt).

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
