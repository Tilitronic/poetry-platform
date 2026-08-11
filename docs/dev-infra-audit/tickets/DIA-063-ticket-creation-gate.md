# DIA-063 — Orchestrator starts §10 work without creating a ticket first — ticket-creation gate not enforced

<!-- Discovered 2026-08-07: When the developer flagged the orchestrator model misconfiguration
     (deepseek-v4-pro instead of deepseek-v4-flash), the orchestrator immediately dispatched
     @ai-specialist for §10 Phase 1 research WITHOUT creating a ticket first. The developer had
     to interrupt and correct: "you work incorrectly, you must create tickets." This is the
     second process-discipline failure in the same session (DIA-061: failed to write handoff;
     DIA-063: failed to create ticket before starting work). Both are gate failures — the
     orchestrator skips mandatory workflow steps. The ticket-creation gate is: before any §10
     engineering work begins, a DIA ticket must exist in docs/dev-infra-audit/tickets/ tracking
     the issue. -->

---

id: DIA-063
title: "Orchestrator starts §10 work without creating a ticket first — ticket-creation gate not enforced"
area: opencode-config
severity: Blocker
status: OPEN
blocked_by: ["DIA-060-restart"]
discovered: 2026-08-07
source: fix-lane
date: 2026-08-07
created: 2026-08-07
updated: 2026-08-10
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

> To be filled at fix time.

**Candidate approaches (to be evaluated during fix design):**

- **A — Prompt hardening:** add explicit language to the orchestrator system prompt
  that forces ticket creation before §10 Phase 1 research (e.g., "You MUST NOT dispatch
  @ai-specialist for §10 research without first creating a DIA ticket in
  docs/dev-infra-audit/tickets/")

- **B — Plugin enforcement:** a plugin hook that detects @ai-specialist dispatch
  in a §10 context and blocks when no corresponding ticket exists (checks
  `docs/dev-infra-audit/tickets/` for a matching ticket within the current session)

- **C — Combined fix with DIA-061:** both are gate-enforcement failures — combine
  into a single "orchestrator gate discipline" fix that hardens both the pre-work
  ticket-creation gate and the post-work handoff gate

- **D — Structural fix:** modify the orchestrator's §10 entry point so that "create
  ticket" is a mandatory first step fused to the research dispatch — you cannot
  do one without the other

**§10 routing note (MANDATORY):** this fix touches `.opencode/` config → it MUST route
through §10 (AI Devtools Modernization Workflow): @ai-specialist gate → design → @coder →
@ai-specialist independent review → restart + smoke. Once DIA-059 is resolved (§10 gate
activated post-restart), this workflow will be mechanically enforced.

**Blocked by DIA-060-restart:** the orchestrator cannot currently read ticket files
directly (DIA-060). After restart (DIA-059 + DIA-060 fixes go live), the orchestrator
will have both the §10 gate active and direct ticket visibility — at which point
this ticket can be picked up with full tooling support.

## Re-verify

> To be filled at re-verify time. Acceptance: orchestrator autonomously creates a DIA
> ticket before dispatching @ai-specialist for §10 Phase 1 research in 2+ consecutive
> sessions; ticket ID is referenced in the research dispatch; no developer intervention
> needed to prompt ticket creation; `make test-config` exit 0; @ai-specialist Phase 6
> review passes.
