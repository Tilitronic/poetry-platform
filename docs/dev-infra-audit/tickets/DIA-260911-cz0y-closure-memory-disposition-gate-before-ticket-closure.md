# DIA-260911-cz0y - Closure memory-disposition gate before ticket closure

---

id: DIA-260911-cz0y
title: "Closure memory-disposition gate before ticket closure"
area: opencode-config
severity: Major
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-09-11
source: inventory
date: 2026-09-11
created: 2026-09-11
updated: 2026-09-11

# --- Session Attribution (v2 schema, optional) ---

session_id: ""
lane_id: ""
agent: ""
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: "" # ISO-8601; set on DISPATCHED, cleared on COMPLETE
files_touched: []
artifacts: []
evidence: []

---

## Description

Tickets can currently close before the workflow records whether the completed
work produced durable, non-recoverable knowledge. After closure, the ticket gate
may block a memory-manager dispatch, leaving lessons or failures uncommitted and
making the ledger claim of completion incomplete. Conversely, forcing a memory
write for every ticket would create noise because many changes are fully
recoverable from git, tests, and the ticket itself.

Introduce a closure-memory-disposition gate owned by the ticket/workflow layer,
not by memory-manager. Before a ticket reaches CLOSED, its closure record must
contain exactly one explicit disposition:

- persisted: memory-manager wrote durable knowledge, with modified paths and
  entry identifiers;
- not-needed: the closer records why the result is recoverable from canonical
  repository evidence and therefore must not be stored;
- deferred: a named OPEN follow-up ticket owns the pending persistence, with a
  concise reason and handoff reference.

Memory-manager remains the sole writer for memory-shelf and memory artifacts. It
does not receive authority to close tickets, decide whether knowledge is worth
retaining, or mutate the ticket ledger status. The orchestrator/closer owns the
decision and must invoke memory-manager before closure whenever persisted is the
chosen disposition.

This is a policy-class OpenCode configuration/workflow change. Its design must
use EBDV: compare at least a mandatory disposition gate, an advisory-only
approach, and the current status quo; include evidence, tradeoffs, effort, and
an explicit developer decision. Preserve a narrow escape hatch for purely
procedural/ledger-only closures, but require an explicit not-needed disposition
rather than silently bypassing the rule.

## Verification

- [ ] Define a machine-readable, validator-friendly representation of the three
      dispositions without breaking existing tickets or their historical records.
- [ ] A new closure attempt without a disposition hard-fails before status is
      changed; the diagnostic identifies the ticket and missing field.
- [ ] persisted requires a verifiable receipt containing memory paths and at
      least one entry or lesson identifier; malformed receipts fail deterministically.
- [ ] not-needed requires a non-empty recoverability rationale; it must not
      trigger a memory write.
- [ ] deferred requires a resolvable OPEN follow-up ticket and must not permit
      circular self-deferral.
- [ ] The normal sequence is memory-manager persistence first, ticket closure
      second. A memory-manager failure leaves the ticket non-terminal and reports a
      recoverable failure state.
- [ ] Existing CLOSED tickets remain readable and are exempt from retroactive
      hard failure; migration, if any, is additive and documented.
- [ ] Add hermetic tests for all three valid dispositions, missing/malformed
      fields, unresolved/circular deferrals, a memory-manager failure, and a
      ledger-only closure.
- [ ] Run make test-config, JSONC/schema validation, and an independent
      ai-auditor review before enabling the gate.

## Non-goals

- No automatic content summarization or automatic memory writes.
- No authority for memory-manager to close tickets or edit arbitrary ticket
  sections.
- No retrospective rewrite of closed-ticket evidence.
- No broad cleanup of stale knowledge; that work is owned by DIA-260911-4y5v.

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
