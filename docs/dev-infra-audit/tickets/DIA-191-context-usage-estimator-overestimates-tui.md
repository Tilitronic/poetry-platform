# DIA-191 - context_usage tool overestimates vs TUI indicator (48% proxy vs 23% actual, ~2x) causing premature SELF-RERUN

<!-- FILED 2026-08-15 (docs lane, coder agent). NOTE: dispatch requested
     DIA-187, but that number was already taken by the committed ticket
     DIA-187-omo-slim-2-2-14-update-evaluation.md (commit 0a8b1a2).
     Per COORDINATION.md number-allocation protocol (allocator = max+1),
     this ticket is filed as DIA-191, the next free number. -->

---

id: DIA-191
title: "context_usage tool overestimates vs TUI indicator (48% proxy vs 23% actual, ~2x) causing premature SELF-RERUN"
area: opencode-config
severity: Medium
status: OPEN
blocked_by: [] # no blockers
parent_epic: ""

# DIA-104 grilling-gate markers (ai--7 validated design): fill at creation time

# with the defaults below (absent = legacy/skipped, grandfather precedent).

gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered:
source: developer-report
date: 2026-08-15
created: 2026-08-15
updated: 2026-08-15

# --- Session Attribution (v2 schema, optional) ---

session_id: "ses_ffb4f4852ffeErNg7NgiK1pzdG" # filing lane (docs, coder agent)
lane_id: "docs"
agent: "coder"
model: "opencode-go/deepseek-v4-flash"
parent_session_id: "ses_ffd538953ffeHi5JxeN4RF1aAp" # orchestrator session that observed the defect
attempts: 0
lease_expires_at: ""
files_touched: [docs/dev-infra-audit/tickets/DIA-191-context-usage-estimator-overestimates-tui.md, docs/dev-infra-audit/tickets/README.md]
artifacts: []
evidence: [.opencode/images/ses_ffd538953ffeHi5JxeN4RF1aAp/clipboard-02618c40.png, context_usage tool output (usage_percent 48, confidence low, message_count 78, delegation_count 38)]

---

## Description

The `context_usage` tool (delegation-observer plugin) overestimates actual
context usage versus the OpenCode TUI's native token-accurate indicator,
observed 2026-08-15 ~09:05Z in orchestrator session
ses_ffd538953ffeHi5JxeN4RF1aAp.

Observed numbers (same point in time):

- `context_usage` tool: usage_percent 48, confidence "low", fallback_note
  "proxy estimation, not token-accurate", message_count 78, delegation_count 38.
- OpenCode TUI bottom status bar: "234.6K (23%)" - native token accounting;
  header "DeepSeek V4 Flash (2x usage)", cost $0.12, no session id rendered.
- Divergence factor: ~2.1x (48% proxy vs 23% actual) at this session depth.

Operational impact: the orchestrator acted on the 48% figure and triggered
SELF-RERUN (handoff written, NEXT-RUN.md section 2 primary 30% / safety-net
50% thresholds) when actual usage was 23% - the rerun was premature,
causing unnecessary session churn and a broken handoff cycle. The
NEXT-RUN.md section 2 threshold decisions rest entirely on this estimator,
so the overestimate has direct operational consequences. If the estimator
also UNDERestimates at other session depths (the divergence shape is not yet
characterized), the opposite failure mode is a missed true limit - running
past the real context budget.

Mechanism: `context_usage` derives its figure from registry.jsonl activity
signals (message_count / delegation_count weighted heuristically) as a proxy,
not from the native token accounting the TUI consumes. DIA-080 (2026-08-11)
scoped the proxy from cumulative-to-session (commit 4f5bb46); this ticket
documents a separate defect: even session-scoped, the proxy's activity-count
heuristic overestimates tokens at the observed depth.

Evidence:

- Screenshot: .opencode/images/ses_ffd538953ffeHi5JxeN4RF1aAp/clipboard-02618c40.png
  (read by observer lane; TUI status bar right shows "234.6K (23%)").
- context_usage tool output at the same point: usage_percent 48, confidence
  low, fallback_note "proxy estimation, not token-accurate", message_count
  78, delegation_count 38.
- Session id: ses_ffd538953ffeHi5JxeN4RF1aAp (the session in which both
  readings coexisted).

## Verification

Reproduce / confirm the divergence:

1. Run `context_usage` (scope: session) at several session depths (e.g. a
   fresh session, mid-length, and a long delegation-heavy session) and
   record usage_percent, message_count, delegation_count, confidence.
2. At each point, read the OpenCode TUI bottom status bar "N.NNx (NN%)"
   indicator (native token accounting) and record the percentage and token
   figure.
3. Document the divergence factor at each depth. Determine whether the
   divergence is:
   - linear (~2x constant), as the single observed point suggests, or
   - a constant offset, or
   - depth-dependent (e.g. growing or shrinking with message/delegation
     counts).
4. Verify the OPPOSITE direction: does the proxy ever UNDERestimate the TUI
   percentage? A depth scan above should reveal both tails.
5. Record the results as a small table in the Fix section when the fix lane
   runs, so the correction factor (if adopted) is evidence-backed.

## Fix

> To be filled at fix time.

A follow-up lane investigates calibration. Candidate options (not yet
chosen): weight registry rows by real token cost per message/delegation;
read native session token data from `opencode db` / `opencode stats`
(see DIA-182 native-telemetry analytics wrapper as a potential data source);
or apply a correction factor to the proxy estimate. If the plugin estimator
itself changes, the fix routes through AGENTS.md section 2.5 (AI devtools
modernization workflow).

## Re-verify

> To be filled at re-verify time.
