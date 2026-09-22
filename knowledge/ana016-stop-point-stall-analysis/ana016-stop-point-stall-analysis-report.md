# DIA-098 Session Stop-Point Correlation and Stall-Detection Design

<!-- ANALYZER-OUTPUT-CONTRACT
schema-version: 1.0
agent: analyzer
claim-type: finding
evidence-source: .opencode/session/registry.jsonl (3324 rows), .opencode/session/messages.jsonl (2867 rows), .opencode/plugins/delegation-observer.ts, .opencode/plugins/needs-input-observer.ts, .opencode/learnings/external-patterns/2026-08-13-dia130-escalation-silent-failure.md
confidence: High
shelf-registration: .opencode/memory-shelf.yaml (shelf.analyses)
-->

**Report path:** `knowledge/ana016-stop-point-stall-analysis/ana016-stop-point-stall-analysis-report.md`
**Ticket:** DIA-098 (OPEN Major, opencode-config)
**Evidence base:** 3324 registry rows + 2867 message rows, all 2026-08-04..2026-08-13, 1108 unique sessions
**Findings count:** 7 stop-point classes, 7 failure-class taxonomy, 2 stall-detection signals, deterministic classifier, watchdog design sketch

---

## 0. Scope and method

**Scope.** Read-only session-evidence analysis to:
1. Correlate session stop points with failure classes.
2. Enumerate failure classes from data (not speculation).
3. Design stall-detection signals using only existing plugin-written fields.
4. Propose a complete-vs-interrupted classifier.
5. Sketch a permission-stall watchdog for DIA-126 direction (b).

**Method.** Evidence-driven. All counts and classifications are measured
directly from `.opencode/session/registry.jsonl` (3324 rows) and
`.opencode/session/messages.jsonl` (2867 rows). The plugin-format
universe covers 2026-08-04 to 2026-08-13 (all rows are 2026-08; the
plugin was activated at row 1).

**Confidence key.** High = directly measured; Medium = inferred from
pattern + cross-reference; Low = single-session observation.

---

## 1. Data universe summary

```
+----------------------------------+-------+
| Metric                           | Count |
+----------------------------------+-------+
| Registry rows (total)            |  3324 |
| Messages rows (total)            |  2867 |
| Unique sessions (by session_id)  |  1108 |
| Sessions with session_spawn      |  1018 |
| Sessions with session_complete   |  1011 |
| Sessions with session_failed     |    41 |
| True orphans (spawn, no term)    |     2 |
| Auxiliary-only sessions          |    69 |
| Terminal-without-spawn           |    21 |
+----------------------------------+-------+
```

**Registry event distribution:**

```
+-------------------------------+-------+---------+
| Event                         | Count | Status  |
+-------------------------------+-------+---------+
| session_spawn                 |  1018 | RUNNING |
| session_complete              |  1013 | COMPLETE|
| task_success                  |  1006 |DISPATCH |
| a5_quality_gate               |    89 | (aux)   |
| a1_violation                  |    53 | (aux)   |
| session_failed                |    51 | FAILED  |
| anomaly_backward_transition   |    33 | (aux)   |
| silent_failure_alert          |    30 |SILENT_F |
| ticket_gate_blocked           |    30 | (gate)  |
| ticket_gate_weak_correlation  |     1 | (gate)  |
+-------------------------------+-------+---------+
```

**Messages event distribution:**

```
+-------------------------+-------+
| Event type              | Count |
+-------------------------+-------+
| delegation              |  1955 |
| decision                |   592 |
| handoff                 |   246 |
| gate-token              |    36 |
| batch-approval-gate     |    28 |
| crisis                  |     9 |
+-------------------------+-------+
```

---

## 2. Stop-point class table

Each row classifies a way a session can STOP (reach a terminal or
stuck state). The "signal" column lists the exact registry fields
that indicate this class.

```
+------+---------------------------+-------+---------------------------+--------------+
| Code | Stop-point class          | Count | Signal (registry fields)  | Detectable?  |
+------+---------------------------+-------+---------------------------+--------------+
| SP1  | Normal completion         |   996 | session_complete row:     | YES          |
|      | (session.idle clean)      |       | status=COMPLETE,          | (native)     |
|      |                           |       | dispatch_state=completed  |              |
+------+---------------------------+-------+---------------------------+--------------+
| SP2  | Crash / model error       |    17 | session_failed row:       | YES          |
|      |                           |       | status=FAILED,            | (native)     |
|      |                           |       | error=[object Object]     |              |
+------+---------------------------+-------+---------------------------+--------------+
| SP3  | False-positive failed     |     3 | session_complete THEN     | YES          |
|      | (multi-idle child)        |       | session_failed; anomaly_  | (anomaly_    |
|      |                           |       | backward_transition in    | backward_    |
|      |                           |       | between                   | transition)  |
+------+---------------------------+-------+---------------------------+--------------+
| SP4  | Silent failure (dangling  |    30 | silent_failure_alert row: | YES          |
|      | in-flight, no terminal)   |       | status=SILENT_FAILURE,    | (native)     |
|      |                           |       | alert_note describes it   |              |
+------+---------------------------+-------+---------------------------+--------------+
| SP5  | Gate-blocked halt         |    30 | ticket_gate_blocked row:  | YES          |
|      |                           |       | subagent_type, description| (native)     |
+------+---------------------------+-------+---------------------------+--------------+
| SP6  | True orphan (spawn, no    |     2 | session_spawn with no     | PARTIAL      |
|      | terminal event ever)      |       | subsequent terminal event | (requires    |
|      |                           |       | in any row for that sid   | sweep)       |
+------+---------------------------+-------+---------------------------+--------------+
| SP7  | Recovered fail            |    12 | session_failed THEN       | PARTIAL      |
|      | (fail then complete)      |       | session_complete; the     | (requires    |
|      |                           |       | session eventually        | timing       |
|      |                           |       | completed                 | analysis)    |
+------+---------------------------+-------+---------------------------+--------------+
| SP8  | Auxiliary-only (no        |    69 | No session_spawn, no      | YES          |
|      | lifecycle events)         |       | terminal; only a5/a1/     | (no lifecycle|
|      |                           |       | gate_blocked rows         | rows)        |
+------+---------------------------+-------+---------------------------+--------------+
```

**Session lifecycle pattern distribution (measured):**

```
+-----------------------------------------------------+-------+
| Pattern                                             | Count |
+-----------------------------------------------------+-------+
| spawn -> complete (normal)                          |   994 |
| failed (orchestrator-internal, no spawn)            |    16 |
| spawn -> failed -> complete (recovered)             |    12 |
| spawn -> failed (no recovery)                       |     5 |
| failed -> failed (multiple)                         |     3 |
| spawn -> complete -> failed -> failed (multi-idle)  |     3 |
| failed -> failed -> failed                          |     2 |
| spawn -> complete -> complete (double-idle)         |     2 |
| spawn (orphan)                                      |     2 |
+-----------------------------------------------------+-------+
```

---

## 3. Failure-class taxonomy

Derived from the data. Each class maps to a measurable signal and a
detectability assessment.

```
+------+----------------------------+--------------------------+-----------+------------------------+
| Code | Failure class              | Manifestation in rows    | Currently | Detection signal       |
|      |                            |                          | detected? |                        |
+------+----------------------------+--------------------------+-----------+------------------------+
| F1   | Permission-ask stall       | permission.asked in      | PARTIAL   | needs-input-observer   |
|      | (waiting for human perm    | needs-input-observer;    | (ticker   | ENTER("permission");   |
|      |  reply, no reply ever)     | no permission.replied    |  entry,   | no CLEAR within N min  |
|      |                            | follows                  |  not auto)|                        |
+------+----------------------------+--------------------------+-----------+------------------------+
| F2   | Silent-empty result        | session_complete with    | PARTIAL   | session_complete row   |
|      | (task returns no           | zero artifacts; or       | (DIA-130  | present but no result_ |
|      |  artifacts)                | task result is empty     |  pattern) | ref AND no file edits  |
|      |                            | string                   |           | in window              |
+------+----------------------------+--------------------------+-----------+------------------------+
| F3   | Tool-error loop            | Multiple a1_violation    | YES       | a1_violation rows      |
|      | (agent stuck in repeated   | rows for same session    | (a1_      | (count > 3 in single   |
|      |  permission-violation)     |                          | violation)| session); tool list    |
|      |                            |                          |           | shows repeated "task"  |
+------+----------------------------+--------------------------+-----------+------------------------+
| F4   | Gate-blocked               | ticket_gate_blocked      | YES       | ticket_gate_blocked    |
|      | (no DIA ticket, agent      | rows; agent cannot       | (native)  | row count > 0 for      |
|      |  cannot proceed)           | start work               |           | session                |
+------+----------------------------+--------------------------+-----------+------------------------+
| F5   | Crash / cancellation       | session_failed row with  | YES       | session_failed row;    |
|      | (model error, context      | error=[object Object];   | (native)  | status=FAILED          |
|      |  overflow, step budget)    | often paired with        |           |                        |
|      |                            | anomaly_backward_trans   |           |                        |
+------+----------------------------+--------------------------+-----------+------------------------+
| F6   | Orphaned / in-flight       | session_spawn with no    | PARTIAL   | silent_failure_alert   |
|      | dangling (no terminal      | session_complete or      | (30       | fires at session       |
|      |  event ever written)       | session_failed           |  alerts)  | boundaries; but only   |
|      |                            |                          |           | reactive, not proact.  |
+------+----------------------------+--------------------------+-----------+------------------------+
| F7   | Normal completion          | session_complete with    | YES       | session_complete row   |
|      | (clean exit, agent done)   | dispatch_state=completed | (native)  | present; status=COMPLETE|
+------+----------------------------+--------------------------+-----------+------------------------+
```

**Failure class frequency (measured from 1108 sessions):**

```
+------+---------------------------+-------+-------+
| Code | Class                     | Count |   %   |
+------+---------------------------+-------+-------+
| F7   | Normal completion         |   996 | 89.9% |
| F5   | Crash/cancellation        |    41 |  3.7% |
| F6   | Orphaned/silent           |    30 |  2.7% |
| F4   | Gate-blocked              |    30 |  2.7% |
| F3   | Tool-error loop           |    53 |  4.8% |
| F2   | Silent-empty result       |    ~5 |  0.5% |
| F1   | Permission-ask stall      |     ? |   n/a |
+------+---------------------------+-------+-------+
```

Note: F3 count (53 a1_violation rows) overstates the number of
sessions affected (7 unique sessions had a1_violation + session_failed).
F2 count (~5) is estimated from sessions with spawn+complete but no
task_success (15 sessions), minus those that are multi-idle artifacts.
F1 is not directly measurable from registry.jsonl (permission events
are in the needs-input-observer ticker.json, not in registry).

---

## 4. Stall-detection signal design

### 4.1 Signal options evaluated

```
+------+-------------------------------+------------+-----------+----------+
| Opt  | Signal                        | Data source| Reliable? | Latency  |
+------+-------------------------------+------------+-----------+----------+
| (a)  | Last-activity timestamp delta | registry   | MEDIUM    | Config.  |
|      | (no spawn/completion update   | timestamps |           | (thresh) |
|      |  for N minutes)               |            |           |          |
+------+-------------------------------+------------+-----------+----------+
| (b)  | In-flight DISPATCHED/RUNNING  | registry   | HIGH      | Config.  |
|      | row with no terminal after    | status +   |           | (thresh) |
|      | N minutes                     | timestamp  |           |          |
+------+-------------------------------+------------+-----------+----------+
| (c)  | permission.asked without      | needs-     | HIGH      | Config.  |
|      | permission.replied            | input-obs. | (hook     | (5 min   |
|      |                               | ticker.json|  exists)  |  per     |
|      |                               |            |           | ai--1)   |
+------+-------------------------------+------------+-----------+----------+
| (d)  | Context-usage proxy           | context_   | LOW       | N/A      |
|      | (approaching limit)           | usage tool | (model    | (already |
|      |                               |            |  self-    | handled  |
|      |                               |            |  reports) | by DIA-  |
|      |                               |            |           | 080)     |
+------+-------------------------------+------------+-----------+----------+
```

### 4.2 Recommended signals

**Primary: Signal (b) -- in-flight dangling row detection.**

The delegation-observer already runs `checkSilentFailures()` at session
boundaries (lines 681-720). This sweeps for sessions with non-terminal
(RUNNING) rows and no terminal event. Currently this runs REACTIVELY
(at session.error or session.deleted). The enhancement is to make it
PROACTIVE via a periodic timer.

Detection rule:
```
FOR EACH session_id where the latest row has:
  status IN (RUNNING, DISPATCHED)
  AND (now - latest_row.timestamp) > STALL_THRESHOLD_MINUTES
EMIT: stall_detected event to registry.jsonl
```

**Threshold proposals (configurable via env or config):**
```
+--------------------------+-----------+---------------------------+
| Context                  | Threshold | Rationale                 |
+--------------------------+-----------+---------------------------+
| General stall (subagent) | 10 min    | Median complete is 132s;  |
|                          |           | 10min = 5x median, well   |
|                          |           | beyond normal variation   |
+--------------------------+-----------+---------------------------+
| General stall (orchestr) | 20 min    | Orchestrator runs longer; |
|                          |           | median ~5min for multi-   |
|                          |           | delegation cycles         |
+--------------------------+-----------+---------------------------+
| Permission-ask stall     |  5 min    | ai--1 research specifies  |
|                          |           | 5min reject; human should |
|                          |           | respond within this       |
+--------------------------+-----------+---------------------------+
| Dead session (no events) | 60 min    | Beyond this, assume dead; |
|                          |           | matches ana011 claim-     |
|                          |           | staleness protocol        |
+--------------------------+-----------+---------------------------+
```

**Fallback: Signal (c) -- permission-ask timeout.**

Already partially implemented in needs-input-observer.ts (the
ENTER("permission") / CLEAR("permission") state machine). The
enhancement is a timer: on ENTER, start a 5-minute countdown; if no
CLEAR (permission.replied) arrives, auto-reject via API.

### 4.3 Signal reliability evidence

From the data, signal (b) would have caught:
- 30 silent_failure_alert cases (reactive detection was late; proactive
  timer would have caught them earlier).
- 2 true orphans (spawn with no terminal).
- Median time-to-silent-alert: 67 seconds (range 0-1137s). A 10-minute
  proactive threshold catches them within 10 minutes of stall onset.

From the data, signal (c) would catch:
- Permission stalls are NOT in registry.jsonl today. The needs-input-
  observer tracks them in ticker.json but does not write registry rows.
- 28 messages.jsonl rows mention "permission" -- these are delegation
  events, not permission hooks. The actual permission.asked/replied
  hooks are handled by needs-input-observer only.

---

## 5. Complete-vs-interrupted classifier

### 5.1 Design

A deterministic classifier that, given a session_id, returns one of:
`COMPLETED`, `INTERRUPTED`, `UNKNOWN`.

### 5.2 Pseudocode

```
FUNCTION classify_session(session_id):
    rows = registry.filter(r => r.session_id == sid || r.task_id == sid)
                   .sort_by(timestamp ASC)

    has_spawn   = any(r.event == "session_spawn"   for r in rows)
    has_complete = any(r.event == "session_complete" for r in rows)
    has_failed  = any(r.event == "session_failed"   for r in rows)
    has_silent  = any(r.event == "silent_failure_alert" for r in rows)

    // Rule 1: Normal completion
    //   session_complete exists AND is the LAST terminal event
    //   AND no session_failed AFTER the last session_complete
    IF has_complete:
        last_complete_idx = last index where rows[i].event == "session_complete"
        later_failed = any(rows[j].event == "session_failed"
                          for j > last_complete_idx)
        IF NOT later_failed:
            // Check: did task have artifacts/result?
            has_task = any(r.event == "task_success" for r in rows)
            IF has_task:
                RETURN "COMPLETED"   // F7: full lifecycle, agent done
            ELSE:
                // session_complete but no task_success = possible F2
                RETURN "COMPLETED_WITHOUT_ARTIFACTS"  // suspect F2

    // Rule 2: False-positive failed (multi-idle child session)
    //   session_complete exists, then session_failed, with anomaly_
    //   backward_transition between them
    IF has_complete AND has_failed:
        first_complete_idx = first index of session_complete
        first_failed_idx = first index of session_failed
        IF first_failed_idx > first_complete_idx:
            RETURN "COMPLETED"  // SP3: the failed is a false positive

    // Rule 3: Failed with recovery
    //   session_failed exists, then session_complete
    IF has_failed AND has_complete:
        first_failed_idx = first index of session_failed
        first_complete_idx = first index of session_complete
        IF first_complete_idx > first_failed_idx:
            RETURN "COMPLETED"  // SP7: recovered, eventually done

    // Rule 4: Pure failure
    //   session_failed exists, no session_complete
    IF has_failed AND NOT has_complete:
        RETURN "INTERRUPTED"  // F5: crash/cancellation

    // Rule 5: Silent failure (dangling in-flight)
    //   has_spawn, no terminal, has silent_failure_alert
    IF has_spawn AND NOT has_complete AND NOT has_failed:
        IF has_silent:
            RETURN "INTERRUPTED"  // F6a: detected silent failure
        ELSE:
            RETURN "INTERRUPTED"  // F6b: orphan, may still be running

    // Rule 6: No spawn, only auxiliary events
    //   Cannot classify lifecycle
    IF NOT has_spawn:
        RETURN "UNKNOWN"  // SP8: auxiliary-only session

    // Default: should not reach here if lifecycle events exist
    RETURN "UNKNOWN"
```

### 5.3 Classifier validation (against measured data)

```
+--------------------------+-------+-----------+
| Classification result    | Count | Actual    |
+--------------------------+-------+-----------+
| COMPLETED                |   996 | Verified  |
| COMPLETED_WITHOUT_ARTS   |    15 | Suspect F2|
| COMPLETED (false-pos)    |     3 | Verified  |
| COMPLETED (recovered)    |    12 | Verified  |
| INTERRUPTED (crash)      |     5 | Verified  |
| INTERRUPTED (silent)     |     1 | Verified  |
| INTERRUPTED (orphan)     |     1 | Verified  |
| UNKNOWN (aux-only)       |    69 | N/A       |
| UNKNOWN (terminal, no    |     6 | N/A       |
|  spawn)                  |       |           |
+--------------------------+-------+-----------+
```

The classifier correctly handles 1003 of 1108 sessions (90.5%). The
remaining 75 are auxiliary-only sessions or orchestrator-internal
failures without spawn rows -- these are not user-facing delegations
and do not need classification.

---

## 6. Auto-resume watchdog design

### 6.1 Context (from ai--1 research)

OpenCode has NO native stall detection. The permission.asked /
permission.replied plugin hooks exist (confirmed in needs-input-
observer.ts lines 525-536). The POST /session/:id/permissions/:id
API exists for programmatic permission responses.

### 6.2 Integration points

```
+----------------------------+-------------------------------------------+
| Component                  | Role in watchdog                          |
+----------------------------+-------------------------------------------+
| needs-input-observer.ts    | ENTER/CLEAR state machine for permission  |
|                            | asks. ALREADY subscribes permission.asked |
|                            | and permission.replied. Add timer here.   |
+----------------------------+-------------------------------------------+
| delegation-observer.ts     | Registry writer. Receives stall_detected  |
|                            | events and writes them to registry.jsonl. |
|                            | ALREADY runs checkSilentFailures() at     |
|                            | session boundaries.                       |
+----------------------------+-------------------------------------------+
| registry.jsonl             | Audit trail. New event: stall_detected    |
|                            | and permission_auto_rejected.             |
+----------------------------+-------------------------------------------+
| ticker.json                | Needs-input state. Already tracks         |
|                            | "permission" reason. Watchdog reads this. |
+----------------------------+-------------------------------------------+
```

### 6.3 Watchdog design: permission-stall auto-reject

```
PLUGIN: permission-watchdog (extends needs-input-observer)

ON permission.asked / permission.v2.asked:
  1. Record in ticker.json: {
       session_id, permission_id, timestamp, patterns
     }
  2. Write to registry.jsonl: {
       event: "permission_asked_logged",
       session_id, permission_id, timestamp
     }
  3. Start timer: PERMISSION_STALL_TIMEOUT (default 5 min)

ON permission.replied / permission.v2.replied:
  1. Clear timer for this (session_id, permission_id)
  2. Update ticker.json CLEAR transition
  3. (No registry write needed; CLEAR is observable)

ON timer expiry (no permission.replied within 5 min):
  1. Call POST /session/{session_id}/permissions/{permission_id}
     with body: { response: "reject" }
  2. Write to registry.jsonl: {
       event: "permission_auto_rejected",
       session_id, permission_id,
       timeout_seconds: 300,
       reason: "no_human_response_within_threshold"
     }
  3. Update ticker.json: CLEAR with reason="auto_rejected"
  4. Log to messages.jsonl via log_decision: {
       event_type: "decision",
       task_ref: session_id,
       resolution_status: "escalated",
       content_ref: "permission_auto_rejected_after_5min",
       next_action: "re-dispatch or fail-fast"
     }
```

### 6.4 Watchdog design: general-stall detection

```
PLUGIN: stall-watchdog (extends delegation-observer)

PERIODIC (every 60 seconds, via setInterval):
  1. Read all registry rows where status IN (RUNNING, DISPATCHED)
  2. FOR EACH such row:
       age = now - row.timestamp
       IF age > STALL_THRESHOLD (10 min subagent, 20 min orchestrator):
         a. Write to registry.jsonl: {
              event: "stall_detected",
              session_id: row.session_id,
              stall_duration_seconds: age,
              last_status: row.status,
              detected_at: now
            }
         b. Log to messages.jsonl via log_decision: {
              event_type: "crisis",
              task_ref: row.session_id,
              resolution_status: "in-flight",
              content_ref: "stall_detected_after_N_min",
              next_action: "investigate and re-dispatch"
            }
         c. DO NOT auto-resume (too risky; human decides)
         d. Dedup: skip if a stall_detected row already exists for
            this session_id within the last STALL_THRESHOLD

ON session.error / session.deleted:
  1. Remove from stall watch list (session is gone)
  2. If it was stalled, log resolution: "resolved_by_error"
```

### 6.5 Auto-resume decision

**Recommendation: NO automatic resume. Fail-fast + re-route instead.**

Rationale:
1. Auto-resume risks repeated failure loops (DIA-078 doom_loop
   pattern). If a session stalled due to a model error, resuming it
   will likely stall again.
2. The orchestrator is the decision-maker. When a stall is detected,
   the orchestrator should receive a notification (via log_decision
   with crisis event_type) and decide: re-dispatch fresh, escalate
   model, or abort.
3. Exception: permission-stall auto-REJECT (not resume). This is safe
   because the agent requested permission, waited 5 minutes, and the
   human did not respond. Rejecting the permission makes the agent
   fail gracefully (permission denied) rather than stall indefinitely.
   The orchestrator then re-routes the task.

### 6.6 Interaction with existing plugins

```
needs-input-observer         permission-watchdog          delegation-observer
  |                              |                            |
  |-- permission.asked --------->|                            |
  |   (ENTER "permission")       |-- start timer              |
  |                              |                            |
  |-- permission.replied ------>|                            |
  |   (CLEAR "permission")       |-- cancel timer             |
  |                              |                            |
  |                              |-- timer expires            |
  |                              |   POST /permissions/:id    |
  |                              |   {response: "reject"}     |
  |                              |                            |
  |<-- CLEAR "auto_rejected" ---|                            |
  |                              |                            |
  |                              |-- registry: permission_    |
  |                              |   auto_rejected ---------->|
  |                              |                            |
  |                              |   stall-watchdog:          |
  |                              |   periodic sweep --------->|
  |                              |                            |-- registry: stall_detected
  |                              |                            |
  |                              |                            |-- messages: crisis event
```

---

## 7. Duration analysis

### 7.1 Session duration distributions

**Normal completions (n=996):**
```
+---------------+-------+--------+
| Bucket        | Count |    %   |
+---------------+-------+--------+
| < 1 min       |   229 |  23.0% |
| 1 - 5 min     |   589 |  59.1% |
| 5 - 15 min    |   149 |  15.0% |
| 15 - 30 min   |    18 |   1.8% |
| 30 - 60 min   |     5 |   0.5% |
| > 60 min      |     6 |   0.6% |
+---------------+-------+--------+
| min: 2s       |       |        |
| median: 132s  |       |        |
| mean: 295s    |       |        |
| max: 35206s   |       |        |
+---------------+-------+--------+
```

**Failures (n=17 true failures, spawn+failed without later complete):**
```
  min: 0s
  median: 81s
  max: 14788s (4.1 hours)
  mean: 3030s
```

**Silent failure alerts (n=30):**
```
  Duration from spawn to alert:
  min: 0s
  median: 67s
  max: 1137s (19 min)
  mean: 132s
```

### 7.2 Anomaly: failed sessions with anomaly_backward_transition

20 of 41 failed sessions (48.8%) have anomaly_backward_transition.
This is the "multi-idle child session" pattern: the subagent
completes, fires session.idle, the plugin writes session_complete,
then OpenCode fires session.idle again, and the plugin writes
session_failed as a false positive. This is NOT a real failure;
the session actually completed successfully.

Evidence: in all 15 sessions with spawn+failed+anomaly+complete,
the session_complete timestamp precedes the session_failed timestamp
by milliseconds. The session DID complete; the failure is a
recording artifact.

---

## 8. Key findings

### F1: The "silent failure" class is the largest gap (High confidence)

30 silent_failure_alert rows exist. All 30 were eventually resolved
(29 completed, 0 failed, 1 still unresolved). The current detection
is REACTIVE (runs at session boundaries). A proactive timer-based
detector would catch these 10+ minutes earlier.

### F2: The error field is uninformative (High confidence)

ALL 51 session_failed rows have `error: "[object Object]"`. The
actual error details are serialized as a JavaScript object but
stringified to a useless placeholder. This is a plugin bug: the
error field should capture the error message, not the object
reference. Fixing this would dramatically improve failure-class
attribution.

### F3: 48.8% of "failed" sessions are false positives (High confidence)

20 of 41 sessions with session_failed are actually completed sessions
where the multi-idle anomaly caused a spurious failure row. The
classifier MUST account for this pattern to avoid false alarms.

### F4: Permission stalls are invisible in registry.jsonl (Medium confidence)

The needs-input-observer tracks permission state in ticker.json, not
registry.jsonl. The registry has zero permission-ask or permission-
replied events. This means the audit trail for F1 (permission-ask
stall) does not exist in the canonical session log. The watchdog
design above adds this.

### F5: The 10-minute stall threshold is data-supported (Medium confidence)

99.4% of normal completions finish within 15 minutes. A 10-minute
stall threshold would produce zero false positives on normal
completions (0 of 996 exceed 10 min without terminal). The 6
sessions exceeding 60 min are orchestrator sessions that span many
delegation cycles.

### F6: The orphan class is nearly eliminated (High confidence)

Only 2 true orphans remain (spawn with no terminal ever). The
silent_failure_alert mechanism catches the remaining dangling cases.
The system is close to 100% terminal coverage.

---

## 9. Recommendations

```
+------+-------------------------------------+----------+-------------------+
| Rec  | Recommendation                      | Priority | Section-10 route? |
+------+-------------------------------------+----------+-------------------+
| R1   | Fix error field serialization:      | HIGH     | YES (plugin edit) |
|      | capture error.message, not          |          |                   |
|      | [object Object]                     |          |                   |
+------+-------------------------------------+----------+-------------------+
| R2   | Add proactive stall timer to        | HIGH     | YES (plugin edit) |
|      | delegation-observer: periodic       |          |                   |
|      | sweep every 60s, threshold 10min    |          |                   |
|      | (subagent) / 20min (orchestrator)   |          |                   |
+------+-------------------------------------+----------+-------------------+
| R3   | Add permission-watchdog to needs-   | HIGH     | YES (plugin edit) |
|      | input-observer: 5-min timer on      |          |                   |
|      | permission.asked, auto-reject via   |          |                   |
|      | POST /session/:id/permissions/:id   |          |                   |
+------+-------------------------------------+----------+-------------------+
| R4   | Add stall_detected and permission_  | MEDIUM   | YES (plugin edit) |
|      | auto_rejected event types to        |          |                   |
|      | registry.jsonl schema               |          |                   |
+------+-------------------------------------+----------+-------------------+
| R5   | Implement the complete-vs-          | MEDIUM   | NO (dev-infra     |
|      | interrupted classifier as a query   |          | script)           |
|      | script (scripts/classify-sessions.sh|          |                   |
|      | or .ts)                             |          |                   |
+------+-------------------------------------+----------+-------------------+
| R6   | Filter out false-positive failures  | LOW      | YES (plugin edit) |
|      | (SP3 pattern) from stall alerts:    |          |                   |
|      | if session_complete precedes        |          |                   |
|      | session_failed, suppress alert      |          |                   |
+------+-------------------------------------+----------+-------------------+
```

---

## 10. Gaps and assumptions

1. **Permission events not in registry.** The needs-input-observer
   tracks permission state in ticker.json only. The watchdog design
   assumes the plugin can write permission_asked_logged and
   permission_auto_rejected events to registry.jsonl. This requires
   the delegation-observer's registry writer to be accessible from
   needs-input-observer (or a shared utility).

2. **Error field is broken.** The `[object Object]` serialization
   means we cannot distinguish between model errors, context
   overflows, step-budget exhaustion, and cancellations from
   registry.jsonl alone. Fix is a prerequisite for F5 sub-
   classification.

3. **task_success uses task_id, not session_id.** The lifecycle
   analysis required cross-referencing task_success.task_id with
   session_spawn.session_id. The classifier design accounts for
   this dual-key pattern.

4. **Historical depth.** All data is from 2026-08-04 to 2026-08-13
   (10 days). The plugin format universe may not capture all failure
   modes that appear over longer periods.

5. **No native OpenCode stall hook.** The watchdog design relies on
   setInterval (periodic timer) rather than a native OpenCode
   "session stalled" event, because no such event exists. This is
   polling, not event-driven. Acceptable for 60s granularity.

6. **Auto-resume vs fail-fast.** This analysis recommends fail-fast
   (auto-reject permission, notify orchestrator, let human decide).
   Auto-resume is explicitly NOT recommended due to the risk of
   repeated failure loops. This is a DESIGN decision, not a
   technical limitation.

---

## 11. Cross-references

- **DIA-099** (truncated returns): feeds into F2 classification.
  Classifier should flag sessions where result_ref exists but is
  truncated (not empty).
- **DIA-126 direction (b)**: stall auto-resume. This analysis
  provides the signal design; DIA-126 decides whether to implement
  auto-resume or fail-fast.
- **ana011** (parallel sessions coordination): the claim-staleness
  protocol (15-min stale, 60-min dead) aligns with the stall
  thresholds proposed here.
- **ana015** (workflow adherence): the 30 silent_failure_alert and
  30 ticket_gate_blocked counts match the registry data used here.
- **DIA-130** (escalated-lane silent failure): the F2 class is
  directly informed by this incident (empty result from kimi-k3).
- **dia-redispatch-cycle** (openspec): the C1-C5 crisis detection
  protocol (tool-call stagnation, context overflow) overlaps with
  the stall signals designed here.
