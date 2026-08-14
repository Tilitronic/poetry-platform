# DIA-063 — Orchestrator starts §10 work without creating a ticket first — ticket-creation gate not enforced

<!-- Discovered 2026-08-07: When the developer flagged the orchestrator model misconfiguration
     (deepseek-v4-pro instead of deepseek-v4-flash), the orchestrator immediately dispatched
     @ai-specialist for §10 Phase 1 research WITHOUT creating a ticket first. The developer had
     to interrupt and correct: "you work incorrectly, you must create tickets." This is the
     second process-discipline failure in the same session (DIA-061: failed to write handoff;
     DIA-063: failed to create ticket before starting work). Both are gate failures — the
     orchestrator skips mandatory workflow steps. The ticket-creation gate is: before any §10
     engineering work begins, a DIA ticket must exist in docs/dev-infra-audit/tickets/ tracking
     the issue.

     UPDATE 2026-08-13 (INDEPENDENT VERIFICATION + CLOSED): the S10
     ticket-creation gate is LIVE and ENFORCED. The fix was implemented by the
     DIA-076 fix lane (Option B plugin enforcement, 2026-08-10) - DIA-076 is
     VERIFIED and archived per the DIA-074 convention (archive/
     DIA-076-dia063-fix-implementation.md); M3 post-restart smoke + M4
     2-session durability both PASSED 2026-08-10. On-disk evidence re-confirmed
     this lane: scanTickets() at .opencode/plugins/delegation-observer.ts L425
     (throws on missing tickets dir); evaluateTicketCorrelation() L468 (Path 1
     explicit-DIA-id STRICT tri-state L495-504, Path 2 session-owned L507, Path
     3 recent-keyword L511-512); hard-block path L954-970 (ticket_gate_blocked
     row L954-960 + throw "S10 TICKET GATE: No correlating DIA ticket found",
     L961-970); weak-correlation warn-not-throw L933-948; boot-gate exemption
     L901-907. Plugin wired: .opencode/opencode.jsonc "plugin" array L573
     (file:///workspace/.opencode/plugins/delegation-observer.ts). Plugin file
     is committed (git ls-files tracked; zero working-tree diff this lane).
     Gate probes: scripts/test-ticket-gate.sh 6/6 exit 0; make test-config
     exit 0 (DIA-076 evidence). Ticket flipped CLOSED 2026-08-13 per Re-verify
     convention. -->

---

id: DIA-063
title: "Orchestrator starts §10 work without creating a ticket first — ticket-creation gate not enforced"
area: opencode-config
severity: Blocker
status: CLOSED
blocked_by: ["DIA-060-restart"]
discovered: 2026-08-07
source: fix-lane
date: 2026-08-07
created: 2026-08-07
updated: 2026-08-13
tracked_by: ["DIA-076"]

# --- Session Attribution (v2 schema, optional) ---

session_id: ""
lane_id: ""
agent: "code-executor"
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: ""
files_touched: ["docs/dev-infra-audit/tickets/DIA-063-ticket-creation-gate.md"]
artifacts: []
evidence: []

---

## Description

**Summary:** when the developer flagged the orchestrator model misconfiguration
(deepseek-v4-pro instead of deepseek-v4-flash), the orchestrator immediately dispatched
@ai-specialist for §10 Phase 1 research WITHOUT creating a ticket first. The developer
had to interrupt and correct: "you work incorrectly, you must create tickets."

This is the second process-discipline failure in the same session:

- **DIA-061:** Failed to write handoff after completing work
- **DIA-063** (this ticket): Failed to create ticket BEFORE starting work

Both are gate failures — the orchestrator skips mandatory workflow steps. The
ticket-creation gate is: before any §10 engineering work begins, a DIA ticket must exist
in `docs/dev-infra-audit/tickets/` tracking the issue.

**Evidence:** the orchestrator's response to "orchestrator for some reason works on
deepseek v4 pro instead of deepseek v4 flash" was to immediately dispatch @ai-specialist
for research — no ticket creation step. This is visible in the session log at the point
where the developer says "you work incorrectly, you must create tickets."

**Root cause hypothesis:** the orchestrator's workflow rules require ticket creation
before §10 work, but this is stated as a convention ("create a ticket to track this")
rather than a hard gate. The orchestrator treats it as optional/forgettable. Candidate
causes:

- No mechanical hook that requires a ticket ID before §10 Phase 1 research begins
- The orchestrator's internal workflow shortcuts from "user reports problem" →
  "dispatch research" without the intermediate "create ticket" step
- Same class of failure as DIA-061: the orchestrator does not self-trigger mandatory
  gates

**Why this is a Blocker:** without a ticket, §10 work is invisible at next boot. The
orchestrator reads the tickets directory at session start to discover what's in-flight.
If work was dispatched without a ticket, it falls through the cracks — no tracking,
no blocking edges, no handoff reference. Combined with DIA-061 (no handoff produced),
the session leaves zero structured trace of in-progress §10 work.

**Desired state:** before any §10 Phase 1 research dispatch, the orchestrator MUST:

1. Create a DIA ticket for the issue (or confirm one already exists)
2. Reference the ticket ID in the research dispatch
3. NOT proceed to research without a ticket

**Precedent (2026-08-07):** the model-misconfiguration issue was caught because the
developer was actively monitoring. In normal operation, the orchestrator would silently
skip ticket creation and the work would be untrackable.

**Related:** DIA-061 (orchestrator skips handoff gate), DIA-060 (orchestrator read
scope missing tickets directory — same class of process-discipline failure where the
orchestrator cannot reliably discover tickets; both compound).

## Verification

1. **Confirm current gap (reproducible from any §10-scoped issue report):**
   - Boot orchestrator on a session where the developer reports a §10-scoped issue
     (model config, agent config, permissions, etc.)
   - Observe: orchestrator routes to §10 workflow
   - Observe: orchestrator dispatches @ai-specialist for Phase 1 research
   - Observe: no ticket exists in `docs/dev-infra-audit/tickets/` for the issue
   - Observe: orchestrator does not ask "Has a ticket been created for this issue?"
     before dispatching research

2. **Confirm ticket creation CAN be triggered when prompted:**
   - After the above, explicitly prompt the orchestrator: "create a ticket for this
     issue"
   - Observe: orchestrator creates a DIA ticket in `docs/dev-infra-audit/tickets/`
     with correct format (id, title, area, severity, status, blocked_by, description,
     verification, fix sections)

3. **Post-fix (after prompt hardening or structural fix applied and OpenCode restarted):**
   - Boot orchestrator on a §10-scoped issue
   - Observe: orchestrator creates a DIA ticket BEFORE dispatching @ai-specialist
   - Observe: ticket ID is referenced in the research dispatch
   - Observe: no developer intervention needed to prompt ticket creation
   - Repeat for 2+ consecutive sessions with §10-scoped issues to confirm the
     gate is durable, not one-shot

4. **Build validation (if fix touches `.opencode/` config):**
   - `make test-config` → exit 0
   - No JSONC/YAML syntax errors in modified config files
   - Phase 6 independent review via `@ai-specialist` (per §10 workflow)

## Fix

> IMPLEMENTED 2026-08-10 via the DIA-076 fix lane (Option B - plugin
> enforcement in `.opencode/plugins/delegation-observer.ts`); DIA-076 VERIFIED
> (M3 post-restart smoke + M4 2-session durability PASSED) and archived per
> the DIA-074 convention. Independent closure verification 2026-08-13
> confirmed the gate live on disk (see UPDATE block + Re-verify).

**Option B - plugin enforcement (IMPLEMENTED, DIA-076):**

1. **A1 - Path-1 explicit-OPEN tri-state** (`evaluateTicketCorrelation` L495-504):
   an explicit DIA-id reference resolves ONLY against OPEN tickets
   (explicit-id precedence; no `isSessionOwned || isRecent` requirement) -
   kills the 24h recency-boundary over-fire on long-lived valid tickets.
2. **A2 - Boot-gate exemption** (L901-907): mechanical boot verification
   dispatches (DIA-061 checksum/handoff-integrity pattern) are NOT S10 work -
   breaks the boot circular deadlock (observed 3x).
3. **A3 - `configWorkHint` narrowed** (L876-882): scope regex
   `/opencode\.jsonc|AGENTS\.md|skill|plugin/i` - `.opencode/session/`
   transient files no longer flagged as S10 work.
4. **A4 - Path-3 warn-not-throw** (L933-948): weak correlation (no DIA-id
   mentioned) emits `ticket_gate_weak_correlation` console.warn + allow;
   explicit-ids-no-OPEN-match remains a HARD throw (L954-970,
   `ticket_gate_blocked` + "S10 TICKET GATE: No correlating DIA ticket
   found").
5. **Probe:** `scripts/test-ticket-gate.sh` (NEW, 6/6 regression checks)
   wired into `make test-config` (DIA-076 evidence: 18 passed / 0 failed).

**S10 routing note:** the fix itself was routed through S10 (ai-specialist
gate -> design -> coder -> ai-auditor Phase-6 review); AGENTS.md S2.5/S2.4
Phase-6 review matrix corrected to @ai-auditor (DIA-076 m1). Full fix detail:
see archived DIA-076-dia063-fix-implementation.md.

**Historical (superseded by the implemented Option B above; kept for
traceability) - candidate approaches evaluated at design time:**

- **A — Prompt hardening:** add explicit language to the orchestrator system prompt
  that forces ticket creation before §10 Phase 1 research (e.g., "You MUST NOT dispatch
  @ai-specialist for §10 research without first creating a DIA ticket in
  docs/dev-infra-audit/tickets/")

- **B — Plugin enforcement:** a plugin hook that detects @ai-specialist dispatch
  in a §10 context and blocks when no corresponding ticket exists (checks
  `docs/dev-infra-audit/tickets/` for a matching ticket within the current session)
  - **SELECTED + IMPLEMENTED (this ticket's fix).**

- **C — Combined fix with DIA-061:** both are gate-enforcement failures — combine
  into a single "orchestrator gate discipline" fix that hardens both the pre-work
  ticket-creation gate and the post-work handoff gate

- **D — Structural fix:** modify the orchestrator's §10 entry point so that "create
  ticket" is a mandatory first step fused to the research dispatch — you cannot
  do one without the other

**§10 routing note (MANDATORY):** this fix touches `.opencode/` config → it MUST route
through §10 (AI Devtools Modernization Workflow): @ai-specialist gate → design → @coder →
@ai-specialist independent review → restart + smoke. Once DIA-059 is resolved (§10 gate
activated post-restart), this workflow will be mechanically enforced. - **Followed: the
fix was S10-routed; Phase-6 independent review corrected to @ai-auditor (DIA-076 m1).**

**Blocked by DIA-060-restart:** the orchestrator cannot currently read ticket files
directly (DIA-060). After restart (DIA-059 + DIA-060 fixes go live), the orchestrator
will have both the §10 gate active and direct ticket visibility — at which point
this ticket can be picked up with full tooling support. - **Cleared: DIA-059/DIA-060
VERIFIED (2026-08-10); gate live since.**

## Re-verify

> COMPLETE - closed per re-verify convention 2026-08-13.

1. **Post-fix acceptance (DIA-076 M3 + M4, 2026-08-10):** orchestrator
   autonomously routes S10-scoped dispatches against OPEN tickets with zero
   gate intervention across **2+ consecutive sessions** (M4 2-session
   durability - session ses_0157ee16cffegdBsSp9uGdasiy + close lane
   2026-08-10); C1 tri-state + B2 boot-gate exemption proven live; ticket IDs
   referenced in dispatches; no developer prompt needed to trigger the gate.
   `make test-config` exit 0; `scripts/test-ticket-gate.sh` 6/6 exit 0;
   ai-auditor Phase-6 review conforms.
2. **Independent closure verification (2026-08-13, this lane):** gate code
   re-confirmed live on disk - `scanTickets()` L425, tri-state correlation
   L495-504, hard-block throw "S10 TICKET GATE: No correlating DIA ticket
   found" L961-970, warn-not-throw L933-948; plugin registered in
   `.opencode/opencode.jsonc` L573; `delegation-observer.ts` committed (no
   working-tree diff). DIA-076 VERIFIED + archived. -> CLOSED.
