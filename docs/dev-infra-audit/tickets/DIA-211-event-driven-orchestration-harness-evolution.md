# DIA-211 - Event-driven orchestration harness evolution

---

id: DIA-211
title: "Event-driven orchestration harness evolution"
area: opencode-config
severity: Medium
status: OPEN
blocked_by: []
parent_epic: ""

# DIA-104 grilling-gate markers (ai--7 validated design): fill at creation time

# with the defaults below (absent = legacy/skipped, grandfather precedent).

gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered:
source: developer-requirement
date: 2026-08-17
created: 2026-08-17
updated: 2026-08-17

# --- Session Attribution (v2 schema, optional - GRANDFATHERED for DIA-001..049) ---

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

Evolutionary expansion of delegation-observer harness infrastructure based on
intercellular communication patterns, logical signal categories, and declarative
workflow routing.

Includes:

1. **Teaching conspect update** with event-driven orchestration section
2. **Research on biological signal taxonomy** -- paracrine/endocrine/juxtacrine
   analogies for agent-to-agent communication patterns
3. **Analysis of current harness signal mapping** -- how delegation-observer
   events map to orchestration decisions today
4. **Architectural plan for evolution phases** -- incremental phases from
   current imperative dispatch to declarative event-driven routing

This is a TRACKING/SCOPING ticket. No implementation happens here; it records
scope + routing only. Implementation slices will be spawned as separate tickets
once the architectural plan is approved.

## Verification

Acceptance criteria at fix time:

- [x] Teaching conspect updated with event-driven orchestration section
- [x] Biological signal taxonomy research artifact produced
- [x] Current harness signal mapping analysis completed
- [ ] Evolution phases architectural plan documented and reviewed
- [x] Architectural plan produced by @architector

## Fix

### Architectural Plan: Event-Driven Orchestration Harness Evolution

#### 1. Biological Signal Mapping

| Biological Pattern                   | Harness Component                   | Concrete Change                                                                                                                                               |
| :----------------------------------- | :---------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Juxtacrine** (direct contact)      | DIA-063 Ticket Gate & Boot Gate     | Hard-block subagent init if JSON payload lacks valid ticket_id via synchronous `dispatch.before` hook                                                         |
| **Negative Feedback** (control loop) | Tool Execution & Retry Loops        | 3-state Circuit Breaker (CLOSED/OPEN/HALF_OPEN) for tool.execute.after; 3 errors in rolling window of 5 calls → circuit OPEN → force fallback to orchestrator |
| **Apoptosis** (graceful shutdown)    | Truncated Subagent (DIA-099)        | Dual-key self-termination: fatal state AND session.idle → autonomous log_decision(handoff) + worktree cleanup + exit                                          |
| **Chemotaxis** (change detection)    | Context Usage Estimation            | Track velocity of context growth (+15% per cycle → early compaction/crisis), not just absolute threshold                                                      |
| **Paracrine** (local event bus)      | Semantic Event Log (messages.jsonl) | Emit discrete state changes (build.passed, tests.failed) for orchestrator to drive next dispatch                                                              |
| **Synapse** (saga/event chain)       | Batch-D Serialized Merge            | Compensating actions: post-merge test failure → auto-drop worktree + restore baseline                                                                         |

#### 2. Phased Evolution Plan

**Phase 1: Juxtacrine Ticket & Boot Gates**

- Harden DIA-063/DIA-061 via synchronous plugin hooks
- Modify delegation-observer to intercept dispatch.before
- Test: make test-config with mock dispatch lacking ticket → expect exit 1

**Phase 2: Negative Feedback Circuit Breakers**

- Stop infinite agent error loops
- CircuitBreaker module tracking tool.execute.error in sliding window
- Test: simulate 4 sequential bash errors → 4th call emits circuit.open

**Phase 3: Chemotaxis Context Velocity**

- Proactive context management via delta
- Enhance context_usage to return velocity_percent_per_cycle
- Test: feed 50K token read → assert crisis threshold tripped

**Phase 4: Apoptosis & Paracrine Handoffs**

- Clean shutdown of stranded worktrees/parallel coders
- Dual-key: circuit.open AND session.error → auto handoff + worktree remove
- Test: spawn Batch-D coder, force failure → verify worktree deleted + handoff written

#### 3. Priority Ranking

1. High value/low effort: Juxtacrine hooks (prevents wasted tokens)
2. High value/medium effort: Circuit Breaker (reduces agent looping)
3. Medium value/medium effort: Apoptosis + Chemotaxis
4. Low value (YAGNI risk): Saga for merges (use bash trap instead)

#### 4. Anti-Patterns Rejected

- **Endocrine (global brokers):** No Kafka/RabbitMQ — registry.jsonl is sufficient
- **Autocrine loops:** Self-prompting must have hard circuit breaker limits
- **Electrical (shared memory):** Agents communicate via narrow signals (JSON handoffs), not raw LLM context
- **Quorum sensing for trivial logic:** Council reserved for high-stakes irreversible actions only

## Re-verify

> To be filled at re-verify time.

---

## UPDATE 2026-08-18

Architectural plan has been produced by @architector. The plan maps biological
signal patterns (juxtacrine, negative feedback, apoptosis, chemotaxis,
paracrine, synapse) to concrete harness components and defines a 4-phase
evolution approach. Research artifacts (items 1-3) verified complete.
Architecture review (item 4) pending.
