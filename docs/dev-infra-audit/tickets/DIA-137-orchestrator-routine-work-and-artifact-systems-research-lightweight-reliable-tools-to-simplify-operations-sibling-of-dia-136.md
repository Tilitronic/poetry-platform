# DIA-137 - orchestrator routine work and artifact systems: research lightweight reliable tools to simplify operations (sibling of DIA-136)

---

id: DIA-137
title: "orchestrator routine work and artifact systems: research lightweight reliable tools to simplify operations (sibling of DIA-136)"
area: opencode-config
severity: Medium
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
discovered: 2026-08-13
source: inventory
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
lease_expires_at: "" # ISO-8601; set on DISPATCHED, cleared on COMPLETE
files_touched: []
artifacts: []
evidence: []

---

## Description

Developer-raised research request (2026-08-13). SIBLING of DIA-136: DIA-136
researches replacing/supplementing direct JSON file writes with a JSON-DB /
API layer for SESSION RECORDS (lowdb / json-server / nedb / tinydb + baseline).
This ticket broadens the same question to the WHOLE orchestrator routine:
the infrastructure around it, the artifact systems it produces, and the
generation methods behind them - looking for LIGHTWEIGHT, RELIABLE tools
that simplify the orchestrator's work, by analogy with the DIA-136
logging/lowdb idea. Coordinate with DIA-136 research to avoid double
evaluation of the same candidates.

### Layer 1: orchestrator routine work (per-session, recurring)

- Boot gate: get-my-session-id, HANDOFF.md prognosis presentation
  (NEXT-RUN.md section 7.3 hard gate), DIA-061 handoff-checksum verification
  delegated as lane-0 (checksum computed by a coder lane, never by the
  orchestrator)
- Pure-dispatch delegation: every task() call is the SOLE tool call in its
  message (enforced by delegation-observer A1 hook); lane dispatch by
  severity/signal table; ticket claiming per COORDINATION.md lease convention
- Recall/resume subagents via session.prompt({path:{id}}) using session_id
  looked up from registry.jsonl (never re-invoke task())
- Self-rerun handoff at >=50% context (compress + handoff files)
- Semantic event logging via log_decision; session ticker maintenance
  (ticker.json/.md by needs-input-observer); gate-tokens/ bookkeeping
- Ticket creation/rollup via scripts/tickets; research-pipeline dispatch
  (researcher -> conspecter -> analyzer); section-10 routing; review gates

### Layer 2: artifact systems and their generation methods

- `.opencode/session/` (gitignored): registry.jsonl (delegation lifecycle),
  messages.jsonl (semantic events), messages.md (DERIVED VIEW - regenerated
  by `scripts/session-log render`, never hand-edited), current-handoff.json /
  HANDOFF.md (atomic tmp+fsync+rename write), ticker.json/.md, gate-tokens/
- `docs/dev-infra-audit/tickets/`: .md ledger (YAML frontmatter), README.md
  index (DERIVED - recomputed by `scripts/tickets rollup`), COORDINATION.md,
  archive/; managed by scripts/tickets (new/rollup/frontier)
- `docs/dev-infra-audit/NEXT-RUN.md`: orchestrator operating handbook
- `knowledge/`: res<NNN>-<topic>/ (conspect + sources/ + .source-urls.txt
  manifest), ana<NNN>-<topic>/ (analysis reports); registered in
  .opencode/memory-shelf.yaml
- `.opencode/learnings/`: external-patterns/, memory/ (experience store)
- Generation methods today: mostly agent hand-written .md files + derived
  views via bash scripts (scripts/session-log render/stats/tail,
  scripts/tickets rollup, scripts/jsonl-stats.sh) using jq/awk. No rendering
  framework, no scheduler, no structured store beyond raw JSONL + md.

### The ask: lightweight reliable tools, by analogy with DIA-136

Survey the artifact/infra landscape above and identify lightweight, reliable,
low-dependency tools that simplify each routine. Candidate CATEGORIES to
explore (not exhaustive - research proposes the final list):

1. **Structured stores** - JSON DBs (lowdb etc., shared with DIA-136 - do NOT
   re-evaluate; reference DIA-136 outcomes), SQLite (better-sqlite3),
   YAML/JSON registries for machine-readable state
2. **Rendering/templating** - markdown/view generation for derived artifacts
   (messages.md, README rollup, ticket views) - template engines vs jq/awk
   status-quo
3. **Scheduling/monitoring** - lightweight timers/daemons for ticker,
   gate-token expiry, lease reaping; file watchers (chokidar) for
   state-change hooks
4. **Data processing** - jq/duckdb for knowledge/stat rollups; jsonl-stats
   improvements
5. **CLI ergonomics** - task runners (mise, just), project-scoped helper
   commands that compress orchestrator delegation chains

Per-candidate evaluation axes (analogous to DIA-136): lightweight footprint,
reliability, maintenance status, dependency weight (must fit the docker dev
container and/or the in-process Node plugin), TOKEN ECONOMY (reduce
orchestrator read/render cost), determinism, fit with existing toolchain
(bash + jq + Node plugin + scripts).

### Verified constraints

- Runtime is the docker dev container (`poetry-dev`); any new tool must
  install inside it without a new heavy service (that is a dev-infra change
  with its own gate). No new always-on server without explicit developer
  approval.
- The delegation-observer plugin runs in-process (Node): TS/Node libs can be
  imported directly; bash scripts use jq/awk.
- Orchestrator read scope is path-locked (`.opencode/session/*`,
  docs/dev-infra-audit/NEXT-RUN.md, tickets/\* + archive, AGENTS.md,
  practice-protected.md); any new store must stay inside readable paths or
  extend the read scope (itself a section-10 change).
- ASCII-only protocol (DIA-079); gates make test-config / test-shell /
  test-infra apply to any new script/tool.
- Routing: agent/config/plugin changes -> section-10 chain (ai-specialist
  gate -> developer decide -> design -> coder -> validate -> ai-auditor);
  tooling-only changes (scripts) -> dev-infra chain (spec -> coder -> test ->
  review). Flag each recommendation with its route.
- DIA-136 is the sibling: share candidate evaluation (lowdb etc.), do not
  duplicate.

### Planned artifacts (research-pipeline output)

- Inventory table: orchestrator routine steps + artifact systems with their
  generation methods (writer / mechanism / consumer)
- Candidate tool shortlist per category with EBDV-style scoring on the axes
  above, Tier-1/Tier-2 evidence
- Token-economy analysis of orchestrator read paths (which artifacts cost the
  most context, what a tool would save)
- Recommendation per category (adopt / adapt / status-quo) + routing flag
- Research artifacts registered in the memory shelf (cf. res024/ana018)

## Verification

- [ ] Inventory of orchestrator routine-work steps + artifact systems with
      generation methods documented in the ticket (writer / mechanism /
      consumer table).
- [ ] Candidate tool shortlist per category (stores / rendering / scheduling /
      data processing / CLI), each scored EBDV-style on lightweight footprint,
      reliability, dependency weight, token economy, determinism, toolchain
      fit, with Tier-1/Tier-2 evidence.
- [ ] Token-economy analysis: orchestrator read paths ranked by context cost,
      with the measured/estimated savings each tool would deliver.
- [ ] Container/plugin fit verified per candidate (installs in poetry-dev,
      in-process Node OK, no new always-on service without approval).
- [ ] Cross-reference with DIA-136: no duplicate evaluation of shared
      candidates (lowdb etc.); DIA-136 outcomes referenced, not re-derived.
- [ ] Recommendation per category (adopt / adapt / status-quo) + routing flag
      (section-10 vs dev-infra vs N/A).
- [ ] Research artifacts registered in the memory shelf.

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
