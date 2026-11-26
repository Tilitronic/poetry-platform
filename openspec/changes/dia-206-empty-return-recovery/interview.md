# Interview: dia-206-empty-return-recovery (compressed)

> Compressed interview resolving the four key design questions. Substance derived
> from the DIA-206 check audit context (empty-result detection + recovery gap) and
> the existing code at delegation-observer.ts ~4011-4092. Practice-protected zone:
> the user supplied the audit findings; the four decisions below are recorded as the
> locked interview outcome. ASCII-only (DIA-079).

## Q1 - Per-lane state machine shape (registry row field? in-memory map?)

**Decision:** in-memory `Map<laneId, LaneFailureState>`, mirroring the EXISTING
`failureCap` pattern. `laneId` = agent name from `childSessionAgent.get(sessionID)`
(fallback `"subagent"`). `LaneFailureState = { count, firstFailure, lastSessionId, state }`.

**Rationale:** reuses the proven in-memory map pattern; no new registry schema, no
persistence, no over-engineering (ponytail: reuse before invent). The existing
`failureCap` was already a `Map<string, {count, firstFailure}>` keyed by session id;
we only change the key from session id to lane id and add `state` + `lastSessionId`.

## Q2 - How does the orchestrator consume the recovery signal?

**Decision:** extend the EXISTING crisis message rows with two fields - `lane_id` and
`recovery_action` (`"redispatch"` | `"stop"`). No new hook event type. The orchestrator
already listens for `content_ref=empty-result-requires-redispatch`; the added fields give
it the structured directive DIA-099 needs. The orchestrator maps `redispatch` to its
resume-truncated-lane protocol (may resume same session or redispatch fresh).

**Rationale:** minimal surface; the message-row channel is the established crisis path.
Adding a new hook event would be a larger, unnecessary seam.

## Q3 - Cap value + at-cap behavior?

**Decision:** keep `FAILURE_CAP_THRESHOLD = 3` (consecutive empty results per lane) and
`FAILURE_CAP_COOLDOWN_MS = 600_000` (10 min). At cap: transition lane `state="stopped"`,
emit `failure_cap_reached` with `recovery_action="stop"` and `resolution_status="escalated"`
(was `"in-flight"`, which was non-resolving). The plugin does NOT auto-dispatch; it signals
stop and the orchestrator decides (redispatch / resume / surface to developer). Idempotency:
a capped lane does not re-emit `failure_cap_reached` on further empty results.

**Rationale:** keeps the existing tuned threshold; only changes the resolution semantics from
"warning only" to "structured stop signal". Aligns with DIA-224 (orchestrator retains control).

## Q4 - Test approach?

**Decision:** new hermetic test file `.opencode/plugins/__tests__/empty-return-recovery.test.mjs`,
reusing the `failure-cap.test.mjs` / `empty-result-detection.test.mjs` harness (mkdtemp +
`@opencode-ai/plugin` mock + dynamic import). Assert at seam O1 (messages.jsonl rows):
per-lane counting across 3 distinct session ids, signal fields on each row, reset on
non-empty, cooldown expiry, idempotency, and the DIA-260826-zvu4 exemption regression.

**Rationale:** the public hook surface (S1-S4) is already the tested seam; no new seam needed.
6 concrete cases map 1:1 to proposal success criteria.

## Locked decisions summary

| Question          | Locked decision                                                                           |
| ----------------- | ----------------------------------------------------------------------------------------- |
| Q1 state shape    | in-memory `Map<laneId, LaneFailureState>` (reuse existing pattern)                        |
| Q2 signal channel | extend existing crisis rows with `lane_id` + `recovery_action`                            |
| Q3 cap + at-cap   | threshold 3, `state="stopped"`, `recovery_action="stop"`, `resolution_status="escalated"` |
| Q4 test           | hermetic `empty-return-recovery.test.mjs` at seam O1, 6 cases                             |

---

<!--
ownership:
  substance: AI
  structure: AI
  interview_depth: compressed
-->
