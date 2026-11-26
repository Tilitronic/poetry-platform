# DIA-124 - orchestrator must write and verify a terminal handoff BEFORE presenting session-end / new-session prompt

<!-- UPDATE 2026-08-13 (IMPLEMENTED + AUDITED + FINDINGS FIXED - TICKET CLOSED): implemented by cod-31 (ses_002c5e0faffe4LAJc25uTZXrIO): (1) NEXT-RUN.md section 7.2 HARD RULE (DIA-124) - handoff MUST be written via log_decision(handoff, JSON.stringify(prognosis)) BEFORE final summary presentation, 3-step sequence (write, confirm, present), plugin-failure fallback flags missing handoff + resume_instructions MUST include 'lane-0 checksum delegation required' (DIA-093 crisis path); (2) NEXT-RUN.md section 1 note 1.6 (missing handoff at boot = prior session failed the rule, record as finding, not blocker); (3) NEXT-RUN.md section 7.3 DETECTION self-check note; (4) AGENTS.md section 6 'Session-end handoff (DIA-124)' rule block; (5) delegation-observer.ts comment-only gate assessment (documented-not-built: session.idle cannot cheaply identify final-summary turn; per-turn handoff MESSAGES row would false-positive; staleness check noisy on first idle; reliable cheap signal is boot-time). ai-auditor (ai--6) CONFORMANT-WITH-NOTES; developer disposition FIX both findings - applied this lane: step 2 tightened to require fresh-file identity (current session_id + populated 64-hex checksum via delegated file read; 'plugin confirmation' alternative removed - log_decision return text is not a write confirmation because atomic-write failures are caught-and-warned while the tool still returns success). Validation: make test-config exit 0, make test-shell exit 0, tsc clean (comment-only plugin diff), drift gate 8 markers intact. Ticket CLOSED per Re-verify convention; commit deferred to end-of-session.
     Planning ticket filed 2026-08-13 from a session-observation (developer
     catch, 2026-08-13). The orchestrator presented a session-end / "start a
     new session" flow BEFORE writing a terminal handoff for the current
     session (ses_007e403fdffeQ4ZzfBpwumRLHP). At that moment the on-disk
     handoff file (.opencode/session/current-handoff.json) still belonged to
     the PRIOR session (ses_0088b118, timestamp 2026-08-12T22:32:39Z, cycle
     DIA-122). The developer caught the failure and the handoff was only
     written afterwards (2026-08-12T22:54:27Z, session_id ses_007e403f, status
     manual-halt, checksum populated). This is an opencode-config process
     failure. Planning ticket - no implementation performed yet. -->

---

id: DIA-124
title: "orchestrator must write and verify a terminal handoff BEFORE presenting session-end / new-session prompt"
area: opencode-config
severity: Major
status: CLOSED
blocked_by: [] # no blockers
discovered: 2026-08-13
source: session-observation (developer, 2026-08-13)
date: 2026-08-13
created: 2026-08-13
updated: 2026-08-13

# --- Session Attribution (v2 schema, optional) ---

session_id: ""
lane_id: ""
agent: ""
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: ""
files_touched: []
artifacts: []
evidence: []

---

## Description

**Background (2026-08-13, session ses_007e403fdffeQ4ZzfBpwumRLHP):** the
orchestrator presented a session-end / "start a new session" flow BEFORE
writing a terminal handoff for the current session. The developer caught it:
"it is a serious issue that you say user to start new session before creating a
handoff". The terminal handoff was written only AFTER the developer's
intervention.

**(a) The incident (who, when, what happened, what was on disk at the time):**

1. The orchestrator completed real recoverable work: commit c515077, push of
   omo-slim-changes to origin, creation of the DIA-123 ticket, and
   restart-detection evidence.
2. The orchestrator then presented a cycle-completion summary to the developer
   asking them to run verification steps - i.e. teeing up a new-session flow.
3. At that moment, the on-disk handoff file
   (.opencode/session/current-handoff.json) STILL belonged to the PRIOR
   session: ses_0088b118, timestamp 2026-08-12T22:32:39Z, cycle DIA-122. No
   terminal handoff for the current session had been written.
4. The developer caught the failure. The handoff was subsequently written and
   verified (2026-08-12T22:54:27Z, session_id ses_007e403f, status
   manual-halt, checksum populated
   3575761ad8de6106954fe911f2d9d09877baf143359c99a576da99f855211a33), but
   only AFTER the developer's intervention.

**(b) Impact analysis:**

If the developer had started a new session immediately, the batch-approval
boot gate would have presented the STALE prior-session handoff (ses_0088b118 /
cycle DIA-122). This session's work (commit c515077, the push of
omo-slim-changes, DIA-123, restart evidence) would have been recoverable only
via log archaeology (registry.jsonl / messages.jsonl) rather than through a
handoff checkpoint. The recoverable-work loss window was real; only the
developer's manual catch prevented a stale-state boot.

**(c) Root cause:**

There is no enforced gate tying "session-end presentation / new-session
prompt" to an existing, verified handoff file for the CURRENT session (correct
session_id + populated checksum). The Pre-Handoff Verification Gate exists at
cycle termination, but there is no mechanical rule preventing the orchestrator
from presenting a new-session flow before the handoff is written.

**(d) Proposed fix (to be designed at fix time, NOT implemented now):**

1. HARD RULE in orchestrator rules (AGENTS.md / NEXT-RUN.md section 7): never
   present a session-end or "start a new session" flow without first calling
   log_decision(event_type='handoff', prognosis=...) AND verifying
   current-handoff.json shows the CURRENT session_id with a populated checksum.
2. Consider a plugin-enforced gate (delegation-observer or sibling) that
   detects an orchestrator session-end presentation pattern and blocks/warns
   unless a fresh handoff for the current session exists (similar to the
   DIA-063 ticket-gate mechanical enforcement).
3. Boot-gate self-check: at batch-approval presentation, the orchestrator
   re-reads current-handoff.json and confirms session_id matches its own
   get-my-session-id before claiming resume state.

**Workflow requirements:** the fix touches orchestrator rules / opencode
tooling, so it must route through the AI Devtools Modernization Workflow
(section 10: gate research -> developer review -> design -> implement ->
validate -> independent review -> register) and/or the docs workflow. DIA-063
section-10 ticket gate satisfied by this ticket.

## Verification

- [x] (a) NEXT-RUN.md section 7.2 HARD RULE (DIA-124): handoff written via log_decision(handoff, JSON.stringify(prognosis)) BEFORE final summary presentation; 3-step sequence (write, confirm, present); plugin-failure fallback flags missing handoff + 'lane-0 checksum delegation required'.
- [x] (b) NEXT-RUN.md section 1 note 1.6: missing handoff at boot = prior session failed the rule, recorded as finding, not blocker.
- [x] (c) NEXT-RUN.md section 7.3 DETECTION self-check note.
- [x] (d) AGENTS.md section 6 'Session-end handoff (DIA-124)' rule block.
- [x] (e) delegation-observer.ts comment-only gate assessment (documented-not-built; boot-time is the reliable cheap signal).
- [x] (f) ai-auditor finding 1 (MEDIUM) fixed: step 2 requires FRESH-FILE IDENTITY - current-handoff.json's session_id equals current orchestrator session AND checksum populated (64-hex).
- [x] (g) ai-auditor finding 2 (MINOR) fixed: 'plugin confirmation' alternative removed; delegated file read required (log_decision return text is not a write confirmation).
- [x] (h) make test-config exit 0 (drift gate 8 markers x 3 presets); make test-shell exit 0; tsc clean (comment-only plugin diff).

## Fix

FIX COMPLETE 2026-08-13 (cod-31 + findings lane): hard rule in NEXT-RUN.md 7.2 + AGENTS.md 6, plugin gate assessed documented-not-built, ai-auditor findings fixed (fresh-file identity step 2 + no plugin-confirmation alternative). See top UPDATE.

## Re-verify

RE-VERIFY PASS 2026-08-13: make test-config exit 0, make test-shell exit 0, tsc clean. Procedural policy; restart-verify N/A for runtime (comment-only plugin change), policy smoke next real session-end.
