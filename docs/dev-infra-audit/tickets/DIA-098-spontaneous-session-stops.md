# DIA-098 - Spontaneous subagent/session stops: stalled-agent detection, auto-resume, complete-vs-interrupted classification

<!-- UPDATE 2026-08-14 (CLOSED - full chain complete; restart-verify
     DEFERRED to next session per developer disposition, DIA-123 pattern):
     ana016 stop-point analysis -> R1-R3 implemented (0f3f675: error
     serialization fix + proactive 60s stall timer + permission watchdog)
     -> ai-auditor NON-CONFORMANT (advisory-not-binding, 3 findings,
     developer accepted all) -> re-fix fd9481d (collision-safe seq/row_id
     - both plugins recompute MAX+1 over current file state; typed
     serializer fallback - never undefined, never [object Object]; no-id
     permission asks audited in registry) -> ai-auditor re-verify
     CONFORMANT-WITH-NOTES (all 3 findings verified-closed, 0 regressions)
     -> developer disposition 2026-08-14: ACCEPT + close with restart-verify
     deferred to the NEXT session (this session runs the PRE-fix plugin
     code; live verification requires a subsequent launch - see the
     Re-verify section for the deferred plan). Status OPEN -> CLOSED.
     Validation: make test-config exit 0 (drift gate 3 presets x 8 markers,
     0 gaps), make test-shell exit 0 (283 bats), scripts/tickets rollup
     --check exit 0, node --check both plugins exit 0. -->

<!-- UPDATE 2026-08-14 (IMPLEMENTED - section-10 lane, branch
     omo-slim-changes, commit pending): R1 error serialization fix + R2
     proactive 60s stall timer in delegation-observer.ts + R3 permission
     watchdog in needs-input-observer.ts. Validated: npx tsc / make
     test-config / make test-shell / prettier --check / node --check all
     exit 0 (drift gate 3 presets x 8 markers, 0 gaps). Status stays OPEN:
     closure is a separate lane (ai-auditor Phase 6 + disposition + live
     restart-verify). -->

<!-- UPDATE 2026-08-13 (STOP-POINT ANALYSIS COMPLETE - ana-3): report
     knowledge/ana016-stop-point-stall-analysis/ (memory-shelf
     analyses[16]). Eight stop-point classes from registry.jsonl (~1108
     sessions since 2026-08-04): SP1 normal completion 996, SP2
     crash/model-error 17 (error=[object Object] USELESS - serialization
     bug), SP3 false-positive failed 3 (complete-then-failed backward
     transition), SP4 silent failure 30 (reactive), SP5 gate-blocked 30,
     SP6 true orphan 2, SP7 recovered fail 12, SP8 auxiliary-only 69.
     Seven failure classes: F1 permission-ask stall (PARTIAL detect -
     needs-input-observer ENTER, no CLEAR within 5min), F2 silent-empty
     result (PARTIAL - DIA-130), F3 tool-error loop (YES -
     a1_violation>3), F4 gate-blocked (YES), F5 crash (YES but error
     useless), F6 orphan (PARTIAL - reactive), F7 normal (89.9%).
     STALL-DETECTION DESIGN: primary = periodic 60s sweep for
     RUNNING/DISPATCHED rows older than threshold (subagent 10min,
     orchestrator 20min, dead session 60min) emitting stall_detected +
     crisis; fallback = permission-ask timeout 5min via
     needs-input-observer -> POST /session/:id/permissions/:id
     {response: reject} + permission_auto_rejected log.
     COMPLETE-vs-INTERRUPTED CLASSIFIER: 6-rule pseudocode (validated
     1003/1108 = 90.5%, 0 false negatives). AUTO-RESUME = FAIL-FAST not
     auto-resume (auto-reject permission stall, notify orchestrator via
     log_decision crisis, human decides; auto-resume risks doom_loop
     DIA-078). GAPS: G1 error-field serialization [object Object] HIGH,
     G2 permission events not in registry HIGH, G3 10-day window, G4 no
     native stall event (setInterval ok), G5 fail-fast is design
     decision, G6 task_success uses task_id not session_id. Top-3 for
     DIA-126(b): fix error serialization, proactive stall timer,
     permission watchdog - all section-10. This ticket stays OPEN - the
     design is analysis-phase only; implementation is section-10 plugin
     work feeding DIA-126(b). -->

---

id: DIA-098
title: "spontaneous subagent/session stops: stalled-agent detection, auto-resume, complete-vs-interrupted classification"
area: opencode-config
severity: Major
status: CLOSED
blocked_by: [] # DIA-NNN refs, or empty
discovered:
source: inventory
date: 2026-08-11
created: 2026-08-11
updated: 2026-08-14

# --- Session Attribution (v2 schema, optional) ---

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

Root-cause investigation of spontaneous agent/session stops beyond the DIA-080
context_usage fix (which addressed one root cause: cumulative proxy reading
100%). Broader problem: (a) detect stalled agents (no progress for N seconds);
(b) auto-resume vs manual "continue" nudge; (c) distinguish completion (agent
done) from interruption (agent truncated/stopped). DIA-080's session-scoping
fix is a partial solution; this ticket addresses residual failure classes
(delegation-observer idle handling, step-budget truncation,
empty-first-response pattern).

### Investigation requirements

1. Correlate stop points with registry.jsonl session outcomes + messages.jsonl.
2. Enumerate failure classes: context_usage threshold, idle-turn semantic
   event, step-budget exhaustion, empty-first-response, permission-denied
   silent halt, wait_for_user misuse.
3. Design stalled-agent detection signal (duration without tool call? message
   count plateau?).
4. Evaluate auto-resume mechanism (persistence-pending.json? registry retry?).
5. Define complete-vs-interrupted classifier.

### Deliverables

- Failure-class taxonomy with evidence from 3+ sessions.
- Detection-signal design (which registry/messages fields indicate stall).
- Auto-resume mechanism proposal (or explicit "manual nudge required" ruling).
- Complete-vs-interrupted classifier design.

## Verification

- (a) Taxonomy covers 5+ failure classes with session evidence.
- (b) Detection signal defined (fields + thresholds).
- (c) Auto-resume decision documented (implement vs defer with rationale).
- (d) Classifier design documented with test cases.
- (e) Cross-linked with DIA-099 (truncated returns).
- [x] Stop-point correlation + failure-class enumeration + stall-detection design + complete-vs-interrupted classifier delivered (ana-3, 2026-08-13, see top UPDATE).

## Fix

IMPLEMENTED 2026-08-14 (section-10 lane, branch omo-slim-changes). Scope
R1-R3 per developer approval (analysis-phase design is FIXED - no re-design).

R1 - Error serialization (delegation-observer.ts, errorMessage +
safeJsonStringify):
Root cause (ana016 F2): the runtime session.error payload is one of the
SDK error shapes ({ name, data: { message } }) - NOT a JS Error with a
top-level .message - so String(err) produced "[object Object]" in all 52
session_failed rows. Fix resolves string -> top-level .message -> SDK
data.message -> circular-safe JSON dump (nested Error collapse +
[Circular] marker, never "[object Object]") -> typed
"[unserializable <kind>]" fallback. The error field stays a string
(registry schema stability). The same serializer was mirrored into
needs-input-observer.ts (ticker error bucket).

R2 - Proactive stall timer (delegation-observer.ts, sweepStalledSessions +
sessionRoleFromRows + emitStall + logStallResolutionIfStalled):
60s setInterval sweep (handle stored, cleared in the dispose hook). Per
delegation key (session_id ?? task_id - same id space as
checkSilentFailures) whose latest dispatch_state row is still
RUNNING/DISPATCHED: age > role threshold -> stall_detected registry row
(stall_duration_seconds, last_status, detected_at) + log_decision crisis
row (resolution_status in-flight, content_ref
stall_detected_after_N_min, next_action investigate and re-dispatch).
Thresholds env-configurable: STALL_SUBAGENT_MINUTES=10,
STALL_ORCHESTRATOR_MINUTES=20, STALL_DEAD_MINUTES=60. Identity heuristic:
parentSessionId / sessionMeta role plus persistent row role / parent_session
fields; unidentifiable sessions default to the 10-min subagent
threshold (safe). Dedup: skip when a stall_detected row exists within
the session's own threshold window. Dead escalation: a session still
non-terminal past 60 min gets a second stall_detected row with
escalation:"dead" (ana011 claim-staleness protocol). NO auto-resume
(fail-fast, ana016 section 6.5). session.error / session.deleted write a
stall_resolved row (resolved_by_error / resolved_by_deleted) when the
session was stalled. Sessions already carrying a silent_failure_alert
row are skipped (existing reactive detection, ana016 F1).

R3 - Permission watchdog (needs-input-observer.ts, permissionAsks +
pendingPermissionTimers + startPermissionWatch / clearPermissionWatch /
autoRejectPermission):
On permission.asked / permission.v2.asked: record {session_id,
permission_id, timestamp, patterns} in ticker.json permissions list +
registry "permission_asked_logged" row + arm PERMISSION_STALL_TIMEOUT
timer (env PERMISSION_STALL_TIMEOUT_MINUTES, default 5 min). On
permission.replied / permission.v2.replied (permissionID / requestID):
clear the timer + ticker CLEAR. On expiry: auto-reject via the SDK
endpoint ctx.client.postSessionIdPermissionsPermissionId (URL
/session/{id}/permissions/{permissionID}, body {response:"reject"} -
the real API implementing the ana016 section 6.3 POST /session/
{session_id}/permissions/{permission_id} proposal; deviation noted: the
path parameter is camelCase permissionID) + registry
"permission_auto_rejected" row (timeout_seconds, reason
no_human_response_within_threshold) + ticker CLEAR + messages
log_decision decision row (resolution_status escalated, content_ref
permission_auto_rejected_after_Nmin, next_action re-dispatch or
fail-fast). Registry writer: no shared utility exists (ana016 gap 1) -
implemented a minimal appendRow-equivalent inside needs-input-observer
using the SAME row conventions (seq/timestamp/event/writer for
registry.jsonl; row_id/event_uuid/timestamp/gen_ai.provider.name/writer
for messages.jsonl); both plugins recompute MAX+1 over the CURRENT file
state at write time (see the ai-auditor re-fix note below — no cached
counters remain). Timers re-armed from ticker.json on
boot with remaining time; dispose hook clears all timers. Fail-fast, no
auto-resume (ana016 section 6.5). A permission event without a
permission id is audited but NOT auto-rejected (rejecting an
unidentifiable permission could reject the wrong request).

Validation evidence (2026-08-14):

- npx tsc (plugins, isolated strict) exit 0
- make test-config exit 0 (drift gate: 3 presets x 8 markers, 0 gaps;
  ticket-gate bats green; agent-name/tool-coverage audits 0 gaps)
- make test-shell exit 0 (283 bats)
- prettier --check exit 0 (both plugin files)
- node --experimental-strip-types --check exit 0 (both plugin files)
- scripts/tickets rollup --check exit 0 (frontmatter counts unchanged)

Status: OPEN - closure is a separate lane (ai-auditor Phase 6 +
disposition + live restart-verify). Restart-verify PENDING: the plugin
changes require an OpenCode restart to take effect.

RE-FIX 2026-08-14 (ai-auditor NON-CONFORMANT, advisory-not-binding;
developer ACCEPTED all 3 findings; re-fix commit pending):

F1 (Critical) - Cross-plugin counter model not collision-safe:
delegation-observer.ts no longer keeps cached in-memory counters.
appendRow recomputes seq = maxRegistrySeq() + 1 (MAX over existing seq
values AND line count — the DIA-123 line-count floor is preserved) from
the CURRENT file state at write time; appendMessageRow recomputes
row_id = MAX(max row_id in messages.jsonl, last messages.md row #) + 1
(the legacy messages.md floor is kept as the migration safeguard). The
old `let seq` / `let nextRowId` seeds and their ++ increments were
removed. needs-input-observer.ts already recomputed MAX+1 per write and
is unchanged in behavior. UNIFIED MODEL: every writer on both plugins
allocates its id from the current file state at write time — no cached
counters exist anywhere. Both plugins share one server process and
append synchronously (appendFileSync), so read-compute-append is atomic
in the JS thread: no write can interleave between another writer's read
and its append, and MAX+1 is provably collision-free under
mixed-plugin interleaving (verified with a 500-write interleave
simulation + 300-write mixed-legacy simulation: zero duplicate ids).
The messages.md floor only lifts delegation-observer ids higher and
never affects uniqueness (every write lands in the file before the next
read). Race-safety comments in both plugins updated to describe this
actual mechanism (the old needs-input-observer comment claiming safety
against "cached counters" was wrong and was rewritten).

F2 (Major) - R1 serializer fallback incomplete:
errorMessage() in BOTH plugins now always terminates in a string for
any non-null error value: error.message -> SDK data.message ->
safeJsonStringify -> typed "[unserializable <kind>]" fallback (kind =
err.name when present, else "object"). A safeJsonStringify failure
(undumpable object, e.g. BigInt fields that make JSON.stringify throw)
now falls through to the typed fallback instead of returning undefined
and omitting the error field. undefined/null input still returns
undefined (no error present — the field is legitimately omitted).
Verified with a node check over 10 value classes (string, Error, SDK
shapes, plain object, circular ref, number, boolean, throwing getter,
BigInt): every non-null path returns a string.

F3 (Minor) - No-id permission asks not written to registry:
permission_asked_logged is now written even when the permission id is
absent. permission_id is omitted per the registry's optional-field
convention (conditional spread — existing rows omit absent fields, they
do not null them) and a note "permission_id absent - watchdog timer not
armed" marks the ask as unidentifiable. The watchdog timer is still
only armed with a real id (auto-rejecting an unidentifiable permission
could reject the wrong request). Verified row shapes for both cases.

Re-validated 2026-08-14: npx tsc (plugins) 0; eslint (both plugins) 0;
prettier --check 0; node --experimental-strip-types --check 0; make
test-config 0 (drift gate 3 presets x 8 markers, 0 gaps; ticket-gate
bats green); make test-shell 0 (283 bats); scripts/tickets rollup
--check 0 (frontmatter counts unchanged).

## Re-verify

\*\*LIVE RESTART-VERIFY DEFERRED (2026-08-14, developer disposition: ACCEPT

- close with restart-verify deferred to next session — DIA-123 pattern).\*\*

This session runs the PRE-fix plugin code: commits 0f3f675 + fd9481d land
AFTER this launch, so the live plugin behavior cannot be observed here. The
deferred verification_request items for the NEXT opencode launch:

(a) **Live stall sweep** — launch opencode, let a subagent delegation sit in
RUNNING/DISPATCHED for >10 min (or temporarily set
STALL_SUBAGENT_MINUTES=1), then confirm: - the 60s `sweepStalledSessions` interval fires (registry.jsonl gains a
`stall_detected` row with `stall_duration_seconds`, `last_status`,
`detected_at`); - the matching messages.jsonl crisis row
(`event_type:"crisis"`, `content_ref:"stall_detected_after_N_min"`,
`resolution_status:"in-flight"`) appears; - a second sweep within the threshold window does NOT duplicate the
stall_detected row (dedup); - `session.error` / `session.deleted` for a stalled session writes
`stall_resolved` (resolved_by_error / resolved_by_deleted).

(b) **Permission-timeout auto-reject** — trigger a permission.asked and
withhold the human reply for 5 min (or set
PERMISSION_STALL_TIMEOUT_MINUTES=1), then confirm: - the watchdog timer fires and rejects via the REAL SDK endpoint
`postSessionIdPermissionsPermissionId`
(POST /session/{id}/permissions/{permissionID},
body `{response:"reject"}` — verified against the installed
@opencode-ai/sdk types, no deviation from the ana016 section 6.3
path beyond the camelCase permissionID param); - registry rows `permission_asked_logged` (on ask) and
`permission_auto_rejected` (timeout_seconds, reason
no_human_response_within_threshold) appear; - the ticker CLEAR transition fires and the messages.jsonl decision row
(escalated, permission_auto_rejected_after_Nmin) is written.

(c) **Log row integrity (collision check)** — after mixed-plugin activity
(at least one needs-input-observer registry/messages write interleaved
with delegation-observer writes), confirm NO duplicate `seq` in
registry.jsonl and NO duplicate `row_id` in messages.jsonl. Both
plugins now recompute MAX+1 over the CURRENT file state at write time;
single-process synchronous appends (appendFileSync) make
read-compute-append atomic, so MAX+1 is provably collision-free — the
live check confirms no regression from the pre-fix cached-counter model.

Evidence for this deferred plan: commits 0f3f675 (R1-R3) + fd9481d
(ai-auditor findings 1-3 re-fix) + this closure commit, all on branch
omo-slim-changes, pushed 2026-08-14. Pre-commit + pre-push hooks ran with
all gates exit 0 (test-config drift 0 gaps, test-shell 283 bats, rollup
--check, node --check).
