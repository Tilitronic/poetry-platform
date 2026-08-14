# DIA-156 - implement V2 read-only query layer (node:sqlite :memory:) over orchestrator session records (DIA-136 follow-up)

<!-- Filed by the DIA-136 closure lane 2026-08-14 from the developer
     decision (binding) on the DIA-136 research (res026): V2 ADOPTED -
     node:sqlite :memory: read-only query layer over the existing JSONL
     session records. Research res-1 (ses_fff9d7005ffe1S8g6WRMRmmfYA) +
     conspect res026 (ses_fff7f6a91ffeyJfoQVNNlpHDjS) established the
     evidence. Developer rationale: token economy on reads (query returns
     only needed rows instead of full-file reads). JSONL stays the
     canonical committed source of truth; the sqlite DB exists ONLY in
     memory during a query (nothing new committed to git). -->

---

id: DIA-156
title: "implement V2 read-only query layer (node:sqlite :memory:) over orchestrator session records (DIA-136 follow-up)"
area: dev-infra
severity: Low
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
discovered: 2026-08-14
source: fix-lane
date: 2026-08-14
created: 2026-08-14
updated: 2026-08-14

# --- Session Attribution (v2 schema, optional) ---

session_id: "ses_fff561f6bffe3vfzs4UU3LMq6L"
lane_id: "cod"
agent: "coder"
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: "" # ISO-8601; set on DISPATCHED, cleared on COMPLETE
files_touched: ["docs/dev-infra-audit/tickets/DIA-156-sqlite-read-layer-session-records.md"]
artifacts: []
evidence: ["knowledge/res026-orchestrator-session-records-json-db/res026-orchestrator-session-records-json-db-conspect.md"]

---

## Description

Implement a small read-only query helper that loads
`.opencode/session/registry.jsonl` + `messages.jsonl` into an in-memory
`node:sqlite` database (Node built-in, zero deps, `:memory:`) and returns
only filtered/aggregated rows to the orchestrator - visibility + token
economy on reads.

Reference: DIA-136 (CLOSED 2026-08-14, V2 adopted) + conspect res026
(knowledge/res026-orchestrator-session-records-json-db/
res026-orchestrator-session-records-json-db-conspect.md, sections 2.8 +
4: V2 read-only query layer over JSONL, `node:sqlite` preferred engine,
`new DatabaseSync(':memory:')` + `readOnly: true`, stability 1.2 release
candidate).

### Design constraints (binding, from DIA-136 developer decision)

- **JSONL stays the canonical committed source of truth** - the query
  layer only READS the JSONL records; it never writes a session record
  and never replaces the delegation-observer write path.
- **NO binary DB files committed** - the sqlite database exists ONLY in
  memory during a query (`:memory:`); nothing new is committed to git.
- **Query layer is a script** (`scripts/` or a make target), NOT a plugin
  change, NOT a new process - the delegation-observer plugin is untouched.
- **Developer committability constraint honored** - sqlite binary files
  are NOT acceptable as source of truth; in-memory query-only is
  acceptable; simplest committable path preferred.

### Scope

- Read-only import of `.opencode/session/registry.jsonl` (delegation
  lifecycle rows) + `messages.jsonl` (semantic event rows) into in-memory
  tables.
- Filtered/aggregated queries: e.g. recall a single session_id without a
  full-file read; count rows by status; list sessions waiting on
  blockers - returning ONLY the needed rows (the token-economy win).
- Zero new runtime dependencies: `node:sqlite` is built into Node.
- DIA-086 SCOPE GUARD: keep it minimal and honest - at current scale jq
  covers queries, so this is a convenience/token-economy layer, NOT a
  correctness need.

### Out of scope

- Any write-path change, any plugin change, any new service/process.
- Replacing `scripts/session-log` / `scripts/jsonl-stats.sh` - the helper
  supplements them for ad-hoc SQL-style queries.
- The ticket-ledger analog (D9) - resolved separately in DIA-136 as
  read-only-on-top of the plain-text ledger.

## Verification

1. Script + bats test wired into `make test-shell` (or `make test-config`
   if appropriate) - hermetic fixture JSONL inputs, exit 0.
2. No new runtime dependencies: `node:sqlite` is a Node built-in (verify
   via `node -e "require('node:sqlite')"` or the import form; the helper
   must not add a package.json dep).
3. Demo query returns filtered rows: run the helper against a fixture or
   real `.opencode/session/` records; confirm only the requested rows are
   returned (not the full file).
4. `make test-config` exit 0 (no config-surface change, but the test
   wiring must not break the suite).

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
