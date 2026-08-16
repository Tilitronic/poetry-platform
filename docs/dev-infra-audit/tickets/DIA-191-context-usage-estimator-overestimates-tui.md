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

## UPDATE 2026-08-15 (coder lane, branch omos/dia-183-191)

EBDV decision (developer, 2026-08-15): **V1 — reweight the formula** (ana025,
`knowledge/ana025-context-usage-calibration/ana025-context-usage-calibration-report.md`).
Chosen because it is the only variant that removes the root-cause term
(session\*10000 = 70% of the over-estimate), calibrates within 7% of the TUI at
the observed failure point, preserves the conservative under-estimate bias, and
is a 5-constant low-risk change. V2 (DB cumulative read) rejected: cumulative is
8.7x over in-context post-compact, would worsen premature reruns. V3 (flat
correction) rejected: divergence is non-monotonic across the compaction
boundary. V4 (abort) rejected: dual failure mode persists.

Implemented:

- `.opencode/plugins/delegation-observer.ts` context_usage estimator reweight
  (ana025 V1):
  `estimatedTokens = delegationCount * 5000 + messageCount * 500 + 30000`
  (flat 30000 ONE-TIME system-prompt term replaces the sessionCount\*10000 term;
  sessionCount still computed/reported but no longer weighted). Doc comment
  updated with the WHY. Tool description + threshold fields retuned
  (threshold_30pct/threshold_50pct -> threshold_15pct/threshold_25pct) so the
  tool output agrees with the retuned NEXT-RUN.md thresholds.
- `docs/dev-infra-audit/NEXT-RUN.md` self-rerun thresholds retuned per ana025:
  30%/50% -> 15%/25% (ALL occurrences: section 2 primary/safety-net, manual
  fallback, C4 soft rerun note, section 6 handoff rule, section 7.6 tracked
  reruns; 300K -> 150K tokens for the 1M-window figure).
- Verification: plugin typecheck `tsc --noEmit --strict` exit 0;
  `make test-config` exit 0 (56 tests, incl. batch-d-infra which bundles the
  real plugin); parallel-handoff harness 6/6; make test-shell exit 0.
  Estimator sanity at the DIA-191 reference snapshot (D=33, M=41 at snapshot):
  NEW = 33*5000 + 41*500 + 30000 = 215,500 tokens = 21.55% vs TUI 234.6K
  (23.5%) -> ratio 0.92 (within 7% under, conservative). Matches ana025's
  predicted 21.5%.
- Commit: f18281f `fix(plugin): DIA-191 context_usage V1 reweight + self-rerun
thresholds 15/25 (ana025)` (branch omos/dia-183-191).

RESTART-VERIFY PENDING (per ana025 post-fix verification plan + this ticket's
Re-verify section): start a fresh orchestrator session, read context_usage vs
TUI at 3 depths (fresh / mid / deep post-compact), assert |proxy - tui| /
tui < 0.25 at each, and confirm the retuned 15/25 thresholds fire at the
intended actual in-context. NOTE for restart-verify: the OMO inline
orchestrator prompts (.opencode/oh-my-opencode-slim.jsonc lines 26/209/433)
still summarize 30/50 — the dispatch scoped the threshold retune to NEXT-RUN.md
(the referenced authority); reconciling the inline prompt summaries is a
follow-up decision, flag for the reviewer.
