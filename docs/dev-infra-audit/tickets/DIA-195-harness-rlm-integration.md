# DIA-195 - harness RLM integration: unify test harnesses + RLM data-reduction in assertions + workflow guard + observability

---

id: DIA-195
title: "harness RLM integration: unify test harnesses + RLM data-reduction in assertions + workflow guard + observability"
area: opencode-config
severity: Medium
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: "" # optional DIA-NNN parent epic ticket (DIA-125 keep-local extension; scripts/tickets emits this field always)

# DIA-104 grilling-gate markers (ai--7 validated design): fill at creation time

# with the defaults below (absent = legacy/skipped, grandfather precedent).

gate_state: "waived" # grilled | waived | bypassed | partial | skipped
gate_triggers: [cross-cutting, cross-boundary] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [spike-poc] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-15
source: developer-requirement
date: 2026-08-15
created: 2026-08-15
updated: 2026-08-15

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

TRACKING/PROPOSAL ticket (developer-approved 2026-08-15): open DIA-195 as a
candidate for harness improvement with RLM data-reduction integration
("improve harness, add RLM and something else"). This ticket records scope +
routing ONLY - no implementation happens here.

Context (verified by ana-1, knowledge/ana023-ticket-backlog-priority-plan/,
Candidate A):

- DIA-181 (data-reducer skill + RLM, CLOSED) landed
  `.opencode/skills/data-reducer/SKILL.md` + `scripts/data-reduce.sh` + 9 bats.
  The skill is registered in the system prompt's `available_skills`.
- DIA-155 (chokidar harness, CLOSED status-quo) recorded render-in-hook as the
  preferred future mechanism for derived-view regeneration.
- NO open follow-up exists for harness-side RLM integration - this ticket
  fills that gap (ana023 lines 83-91).

Scope (3 slices, from the ana023 Candidate A proposal):

- **Slice 1 - unify the plugin test harnesses**: the
  `.opencode/plugins/__tests__/parallel-handoff.test.mjs` and
  `needs-input-observer.dia189.test.mjs` are bun harnesses; the
  `batch-d-infra.test.mjs` is a node harness; the DIA-189 follow-up introduced
  a third harness flavor. Unify under one runner (bun or node) and wire all of
  them host-side into `make test-config` (precedent: DIA-085 wiring decision
  was "manual in-container", DIA-189 harness). Add an RLM data-reduce step to
  each harness so large fixture outputs are compressed before assertion (apply
  the DIA-181 pattern to test assertions).
- **Slice 2 - RLM workflow guard**: codify the threshold at which
  analyzer/conspecter lanes MUST invoke the data-reducer skill before reading
  source data (>100 KB / ~2000 lines). Currently advisory (skill-level
  wording only); candidate for a plugin-level warn guard (warn when an agent
  reads >100 KB raw). Routes through AGENTS.md 2.5 (config-surface change).
- **Slice 3 - harness observability**: emit a savings-line per test run
  (input KB -> result KB -> % saved) so the RLM value is measurable, not
  asserted.

Routing: dev-infra + AGENTS.md 2.5 (plugin guard in Slice 2). Effort: M
(1-2 days). Sequencing: file after Phase 0 of ana023 closes (recommended
order item 15).

## Verification

Acceptance criteria at fix time:

- [ ] `make test-config` exit 0 (host-side, includes the unified harnesses).
- [ ] Harness green: bun/node harness suites pass under the unified runner.
- [ ] Savings-line emitted per test run: input KB -> result KB -> % saved
      (Slice 3 observable).
- [ ] Plugin guard warn fires when an agent reads >100 KB raw source data
      (Slice 2, if implemented - routes via AGENTS.md 2.5).

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
