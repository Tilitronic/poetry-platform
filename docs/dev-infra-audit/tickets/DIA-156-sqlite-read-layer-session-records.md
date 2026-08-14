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
date: 2026-08-15
created: 2026-08-14
updated: 2026-08-15

# --- Session Attribution (v2 schema, optional) ---

session_id: "ses_fff561f6bffe3vfzs4UU3LMq6L"
lane_id: "cod"
agent: "coder"
model: ""
parent_session_id: ""
attempts: 1
lease_expires_at: "" # ISO-8601; set on DISPATCHED, cleared on COMPLETE
files_touched: ["docs/dev-infra-audit/tickets/DIA-156-sqlite-read-layer-session-records.md", "scripts/session-query.mjs", "scripts/__tests__/session-query.bats", "Makefile"]
artifacts: []
evidence: ["knowledge/res026-orchestrator-session-records-json-db/res026-orchestrator-session-records-json-db-conspect.md", "make test-shell exit 0 (343 tests, 18 new session-query)", "make test-config host exit 2 (pre-existing DIA-134 ENOENT /workspace)", "make test-config container exit 0 (49/49)", "node v24.18.0 node:sqlite ok"]

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

Implemented 2026-08-15 (implementation lane, branch omo-slim-changes).

### What was built

`scripts/session-query.mjs` — a read-only query helper (plain Node ESM,
zero deps) that loads `.opencode/session/registry.jsonl` +
`messages.jsonl` into an in-memory `node:sqlite` database
(`new DatabaseSync(':memory:')`) and runs ONE filtered/aggregated query,
printing only the requested rows as JSONL to stdout. Nothing is ever
written back to the JSONL (fs.readFileSync only); no binary DB file is
created (`:memory:` is ephemeral). The delegation-observer plugin and its
write path are untouched.

Files:

- `scripts/session-query.mjs` — the helper (new)
- `scripts/__tests__/session-query.bats` — 18 hermetic bats tests (new)
- `Makefile` — `session-query` target (ARGS pass-through) + .PHONY/header
  (changed)

### CLI surface

```
node scripts/session-query.mjs [options]
  --registry <path>   registry.jsonl path (default: .opencode/session/registry.jsonl)
  --messages <path>   messages.jsonl path (default: .opencode/session/messages.jsonl)
  --session <id>      recall: every registry row with session_id=<id> plus
                      every messages row with gen_ai.agent.id=<id>
  --count-by <field>  aggregate: { "<field>": value, "count": N } per
                      distinct non-NULL value of <field> in --table
  --table <t>         table for --count-by: registry | messages (required)
  --where <k=v>       equality filter, repeatable (json_extract(data,'$.k')=v)
  --limit <n>         max rows printed (default 100; 0 = unlimited)
  --json              print a single JSON array instead of JSONL
  --help              show help and exit
```

One query mode is required: `--session <id>` OR `--count-by <field>` (not
both). Exit codes: 0 ok (empty result ok), 2 usage error or missing file.

### Key design notes (WHY)

- **messages recall key:** messages.jsonl has NO `session_id` field; rows
  are correlated to sessions via the semconv key `gen_ai.agent.id`
  (verified overlap ~1181/2217 on live records). `--session` matches
  registry.session_id + messages.gen_ai.agent.id.
- **Dotted-key JSON path quoting:** SQLite JSON1 treats unquoted dots as
  nesting separators — `json_extract(data, '$.gen_ai.agent.id')` silently
  resolves to NULL. Dotted field names are quoted (`$."gen_ai.agent.id"`);
  field names are whitelisted `[A-Za-z0-9_.-]` so values can never inject
  SQL (verified on Node v24.18.0).
- **readOnly:true deviation (documented):** the ticket/conspec text cites
  `new DatabaseSync(':memory:')` + `readOnly: true`, but SQLite's
  read-only mode rejects even in-memory DDL/DML, which the JSONL->table
  import requires (verified: "attempt to write a readonly database").
  The binding intent — never write a session record, never commit a
  binary — is preserved by `:memory:` (no file backing, dies with the
  process) plus read-only opens of the JSONL inputs. Read-only semantics
  are enforced at the file level, not the sqlite level.
- **Malformed-line policy:** warn-and-skip (stderr warning, counted,
  query proceeds) — mirrors jsonl-cross-check.sh precedent. Missing file
  = exit 2 INFRA error. Blank lines ignored.
- **Scope guard (DIA-086):** no ORM, no migration framework, no CLI
  framework — ~30 lines of hand-rolled arg parsing. Supplements
  session-log / jsonl-stats.sh; replaces neither.

### Test results

- `make test-shell` (host): **exit 0** — 343 tests (325 baseline + 18
  new session-query tests). New tests: recall-single-session (only that
  session's rows), recall-unknown (0 rows, exit 0), count-by-status,
  count-by-event_type, count-by+--where, --session+--where, empty files
  (exit 0, no crash), empty-registry+messages-only recall, malformed-line
  warn-and-skip (aggregate + recall), missing-file exit 2, count-by
  without --table exit 2, session+count-by mutual exclusion exit 2, bare
  --where no-query-mode exit 2, unknown flag exit 2, --help exit 0,
  node --check, Makefile seam guard.
- `make test-config` (host): **exit 2** — pre-existing DIA-134
  batch-d-infra.test.mjs container-path bug (ENOENT /workspace/
  .opencode/opencode.jsonc). NOT fixed (out of scope; documented).
- `make test-config` (container, `docker compose exec dev make
test-config`): **exit 0** — 49/49 pass.
- node:sqlite built-in: `node -e "const {DatabaseSync}=require('node:sqlite'); console.log('ok')"` — exit 0 on Node v24.18.0 (host and container).

### Demo (real records, read-only)

Full files: 16,525 registry + 15,778 messages = 32,303 lines.

```
$ node scripts/session-query.mjs --session ses_0337b99dcffeYa4fEbErfqpTac
{"seq":1,...,"event":"session_spawn","session_id":"ses_0337b99dcffeYa4fEbErfqpTac",...,"status":"RUNNING",...}
{"seq":2,...,"event":"session_complete","session_id":"ses_0337b99dcffeYa4fEbErfqpTac",...,"status":"COMPLETE",...}
{"timestamp":"2026-08-04T23:15:00Z","gen_ai.agent.id":"ses_0337b99dcffeYa4fEbErfqpTac","event_type":"delegation",...}
(3 rows returned, not 32,303 — the token-economy win)
```

```
$ node scripts/session-query.mjs --count-by status --table registry
{"status":"COMPLETE","count":1130}
{"status":"RUNNING","count":1128}
{"status":"DISPATCHED","count":1125}
{"status":"FORMATTED","count":126}
{"status":"FAILED","count":58}
{"status":"SILENT_FAILURE","count":40}
```

```
$ make session-query ARGS="--count-by status --table registry --limit 8"
note: imported registry=16525 messages=15778 malformed-skipped=0
{"status":"COMPLETE","count":1130}
... (exit 0)
```

### Verification checklist (ticket)

1. Script + bats wired into make test-shell (bats-wrapper auto-discovers
   scripts/**tests**/\*.bats): PASS — 18 tests, exit 0.
2. Zero new runtime deps: PASS — node:sqlite built-in, no package.json
   change.
3. Demo query returns filtered rows only: PASS (3 rows from 32,303).
4. make test-config: host exit 2 (pre-existing DIA-134, not caused by
   this change), container exit 0.

## Re-verify

> To be filled at re-verify time.
