# JSON-DB + API Layer for Orchestrator Session Records (DIA-136, res026)

<!-- CONSPECTER-OUTPUT-CONTRACT
schema-version: 1.0
agent: conspecter
phase-a-source-count: 24
phase-a-failures: 1
shelf-registration: memory-shelf.yaml (shelf.conspects)
-->

## Metadata

- **Ticket:** DIA-136 (Medium, OPEN, opencode-config) — research a JSON-DB + API
  layer (lowdb / json-server / nedb / tinydb + credible alternatives) for
  orchestrator session records to improve visibility, reliability,
  determinism, token economy.
- **Research artifact:** `res026` (research conspect).
- **Date:** 2026-08-14
- **Author:** @conspecter (pure-synthesis lane, D7)
- **Sources archived (Phase A):** 24 captured, 1 partial-failure
  (duckdb-stable redirect, resolved via /docs/current). Excluded sources listed
  in section 7.
- **Corpus:** 36 files under `sources/` (npm/PyPI registry JSON, GitHub
  READMEs, official docs, npm page summaries).

---

## 1. Executive Summary (the honest verdict)

The DIA-136 premise — "adopt a JSON-DB + API layer for orchestrator session
records" — holds **only for reads**. The named candidate libraries
(lowdb, json-server, nedb family, tinydb) are, on the archived evidence, the
**wrong tools** for this use case, and each is eliminated for a specific,
evidence-backed reason:

1. **The data already lives in committable plain-text NDJSON/JSONL** (the
   delegation-observer registry + messages logs; see the DIA-136 developer
   constraint in section 5). JSONL is the canonical committed write path and is
   already git-friendly, deterministic, and grep/jq-queryable.
2. **The named write-oriented DB candidates add complexity, not value.** lowdb
   rewrites the whole file on every write (O(N) `JSON.stringify`); json-server
   is a full separate HTTP server process and still beta; nedb 1.8.0 is
   unmaintained; nedb2 is abandoned; tinydb is Python-only (language
   mismatch); @seald-io/nedb is the only actively maintained JS option but
   still file-based append-only with an in-memory full copy.
3. **The write path must stay JSONL/plain-text** to satisfy the binding
   committability requirement (developer constraint, 2026-08-14). None of the
   file-DB candidates improve on the current JSONL write; they would instead
   **compete** with it.
4. **The real gap is read-side query ergonomics** — visibility and determinism
   of the existing JSONL records. Two credible, zero-new-source-of-truth
   engines exist: `node:sqlite` (built-in, zero-dep, read-only in-memory
   import) and **DuckDB `read_json`** (read NDJSON directly). Either can sit
   **read-only on top of JSONL**, leaving JSONL as the sole source of truth.

**Recommendation (section 6):** keep JSONL as the canonical committed write
path, and add a **read-only query layer** over it (V2). Preferred engine:
`node:sqlite` in-memory import (zero dependency, built into Node). Simplest
acceptable fallback: keep the `jq` status-quo (V1) — do not migrate to an
embedded binary DB (V3) because the committable source-of-truth constraint
makes it structurally wrong.

---

## 2. Per-Library Findings (MLA-cited to archived sources)

### 2.1 lowdb 7.0.1 — whole-file rewrite O(N), no cluster, no HTTP

lowdb is an embedded, in-process JSON database; `db.data` is just a
JavaScript object, and every `db.write()` serializes the whole `db.data`
with `JSON.stringify` and writes it to storage
(typicode, "lowdb" GitHub README, lines 1-35, 145-152, 283-285). The npm
registry confirms `dist-tags.latest = 7.0.1` (npm registry, `lowdb-registry.json`;
npm pages summary line 17).

- **Limits (author-stated):** "Lowdb doesn't support Node's cluster module"
  and whole-object serialization "may hit some performance issues" at
  ~10-100 MB per write; "If you plan to scale, it's highly recommended to use
  databases like PostgreSQL or MongoDB instead" (typicode, "lowdb" GitHub
  README, lines 281-287; npm pages summary lines 25-26).
- **Adapters/presets:** JSONFile/JSONFileSync/Memory/TextFile/DataFile;
  JSONFilePreset, Memory, LocalStorage, SessionStorage (typicode, "lowdb"
  GitHub README, lines 109-130, 178-230).
- **No HTTP API** — embedded in-process only (npm pages summary line 26).
- **Verdict for DIA-136:** a file-DB whose write model rewrites the entire
  session-log file is a **regression** on the JSONL append-only write path;
  its author explicitly recommends SQL DBs for scale. **Rejected for the write
  path.**

### 2.2 json-server 1.0.0-beta.15 — full HTTP server, beta, not embedded

json-server is a **full REST HTTP server** (`npx json-server db.json` ->
`http://localhost:3000`), not an embedded library (npm pages summary line 14;
typicode, "json-server" GitHub README, lines 46-56). The npm registry confirms
`dist-tags.latest = 1.0.0-beta.15`, published ~5 months before 2026-08-14
(npm registry, `json-server-registry.json`; npm pages summary lines 3-5).

- **Beta status:** "Viewing beta v1 documentation - usable but expect breaking
  changes"; stable remains v0.17.4 on a separate branch (typicode,
  "json-server" GitHub README, lines 1-3; npm pages summary line 5).
- **Query surface (v1):** `field:operator=value` filters, `_sort`, `_page`/
  `_per_page` pagination, `_embed`, `_where` complex queries (typicode,
  "json-server" GitHub README, lines 69-153).
- **Verdict for DIA-136:** adds a long-running HTTP server process, still in
  beta, and re-implements REST semantics that the orchestrator does not need
  over a local log. **Rejected** — process infrastructure, not a query layer.

### 2.3 nedb 1.8.0 — unmaintained

nedb is an embedded, 100%-JS, MongoDB-subset database (append-only persistence
with compaction; indexes; in-memory full copy) (Chatriot, "nedb" README, lines
1-3, 74-82, 545-554). The npm registry confirms `latest = 1.8.0` (npm registry,
`nedb-registry.json`).

- **Unmaintained (author-stated):** "WARNING: this library is no longer
  maintained, and may have bugs and security issues" (Chatriot, "nedb" README,
  line 1).
- **Verdict:** functionally capable but abandoned; not a defensible new
  dependency in 2026. **Rejected** — maintenance risk. The maintained fork is
  @seald-io/nedb (section 2.4).

### 2.4 @seald-io/nedb 4.1.2 — active fork, still file/append-only + full-memory copy

@seald-io/nedb is the actively maintained fork of nedb, 100% JS, no binary
dependency, MongoDB-subset API, with Promise-based `Async` methods and
compound-index support (Rebours et al., "@seald-io/nedb" README, lines 5-13,
32-37, 693-748). The npm registry confirms `latest = 4.1.2` (npm registry,
`seald-nedb-registry.json`), and `package.json` pins `version: 4.1.2` with
TypeScript types and deps (`@seald-io/binary-search-tree`, `localforage`,
`util`) (Rebours et al., "package.json" `seald-nedb-package.json`, lines 2-3,
47-51).

- **Persistence model unchanged:** append-only format, auto-compacted on
  load; "a copy of the whole database is kept in memory"
  (Rebours et al., "@seald-io/nedb" README, lines 120-134, 863-866).
- **Verdict:** the only actively maintained JS file-DB of the named set, but
  still a write-oriented embedded store with an in-memory full copy. It does
  not improve on JSONL for the read-query goal. **Not recommended** for the
  DIA-136 write path.

### 2.5 nedb2 — abandoned (2018.12.30)

nedb2 is a zero-dependency "persistent, in-browser database" package; the npm
registry confirms `latest = 2018.12.30` with a single known release (npm
registry, `nedb2-registry.json`, description + dist-tags). Its date (2018) and
in-browser orientation make it a non-viable candidate for a Node orchestrator
log store. **Rejected** — abandoned, wrong target.

### 2.6 tinydb 4.9.0 — Python-only, language mismatch

tinydb is a pure-Python, zero-dependency document DB; PyPI confirms `4.9.0`
(2026-08-06), Python >= 3.10, MIT, and project status = maintenance mode
(PyPI JSON, `tinydb-pypi.json`, `info.classifiers` + `info.version`;
tinydb-pypi-page.md lines 3-8). The orchestrator pipeline is TypeScript/Node
(OpenCode, plugin-based); tinydb would introduce a Python process boundary for
a data layer that must serve a Node/plugin read path. **Rejected** — language
mismatch (no shared runtime with the OpenCode plugin layer).

### 2.7 better-sqlite3 13.0.3 — native binary dependency, synchronous

better-sqlite3 is "the fastest/simplest SQLite library for Node.js" with a
synchronous API, full transaction support, WAL, user-defined functions/
aggregates/virtual tables (WiseLibs, "better-sqlite3" API.md, lines 1-16,
41-77; npm pages summary lines 3-13). The npm registry confirms `latest =
13.0.3`, published ~9 days before 2026-08-14 (npm registry,
`better-sqlite3-registry.json`; npm pages summary line 3).

- **Native dependency:** requires a native C++ addon
  (`better_sqlite3.node`, prebuilt binaries) (WiseLibs, "better-sqlite3"
  API.md, lines 33, 318-327; npm pages summary line 12).
- **In-memory support:** `new Database(':memory:')` for ephemeral in-memory
  DBs (WiseLibs, "better-sqlite3" API.md, line 16).
- **Verdict:** excellent engine, but a native build dependency duplicates
  exactly what the Node built-in `node:sqlite` now provides with zero deps.
  Only worth choosing if prebuilt-binaries / WAL tuning were required, which
  a read-only query layer does not need. **Not the first choice** (prefer
  `node:sqlite`, section 2.8).

### 2.8 node:sqlite (Node built-in, zero-dep) — preferred read-side engine

`node:sqlite` is a built-in Node module (available only under the `node:`
scheme) exposing synchronous `DatabaseSync`/`StatementSync` classes with full
in-memory support (`new DatabaseSync(':memory:')`), prepared statements,
user-defined functions/aggregates, changesets, and authorizer hooks
(Node.js v26.7.0 docs, `node-sqlite.md`, lines 118-132, 153-168, 246-264,
416-447). Stability is "1.2 - Release candidate" (Node.js v26.7.0 docs,
`node-sqlite.md`, line 120).

- **Read-only / in-memory:** `readOnly: true` opens read-only; `:memory:`
  creates an ephemeral in-memory DB (Node.js v26.7.0 docs, `node-sqlite.md`,
  lines 159-167).
- **Verdict:** zero new dependencies, built into the runtime the orchestrator
  already runs, and can import the JSONL records into an in-memory table for
  ad-hoc SQL reads **without creating any committed binary file** (memory
  only) — satisfying the committability constraint. **Preferred engine for the
  V2 read-only query layer.**

### 2.9 DuckDB 1.5 — `read_json` over NDJSON, embedded analytics

DuckDB reads JSON directly via `read_json()` (or `SELECT * FROM 'file.json'`)
in the `FROM` clause, with `CREATE TABLE AS` / `INSERT INTO ... SELECT`
options; the `json` extension is shipped with most distributions and
auto-loaded (DuckDB, "JSON Overview", `duckdb-json-overview.md`, lines 12-14,
39-77; DuckDB, "JSON Import", `duckdb-json-import.md`, lines 11-32). Docs
confirm current major version **1.5** (DuckDB docs-current, lines 139, 154;
the npm dist-tag file shows the older published artifact `1.4.4` —
`duckdb-dist-tags.json` — a registry-vs-docs version delta; the docs
`/docs/current/` page is the authoritative "1.5 current" statement,
`duckdb-docs-current.md` lines 139, 154).

- **Key capability for DIA-136:** DuckDB can query NDJSON files **in place**
  (read-only over the committed JSONL), returning `filename` as a virtual
  column since v1.3.0 — well suited to analyzing multi-file session logs
  (DuckDB, "JSON Overview", `duckdb-json-overview.md`, lines 79-84).
- **Verdict:** a strong alternative engine for the V2 read layer, with native
  NDJSON support and zero need to rewrite the committed data. Costs an extra
  runtime dependency (a binary engine) versus `node:sqlite` (built-in). A
  **valid second choice**; not preferred solely on dependency weight.

---

## 3. Decision Summary Table

| Candidate | Version | Type | Read-query fit | Write-path fit | Committability | DIA-136 verdict |
|---|---|---|---|---|---|---|
| lowdb | 7.0.1 | embedded file DB | no HTTP | whole-file rewrite O(N) | file JSON (single file) | Rejected (write) |
| json-server | 1.0.0-beta.15 | HTTP server | REST over file | server process | reads db.json | Rejected (beta, process) |
| nedb | 1.8.0 | embedded Mongo-subset | query API | append-only file | file per datastore | Rejected (unmaintained) |
| @seald-io/nedb | 4.1.2 | embedded Mongo-subset | query API | append-only file | file per datastore | Not recommended |
| nedb2 | 2018.12.30 | in-browser DB | n/a | n/a | n/a | Rejected (abandoned) |
| tinydb | 4.9.0 | Python doc DB | query API | JSON file | file | Rejected (language) |
| better-sqlite3 | 13.0.3 | native SQLite | SQL, WAL | native dep | binary `.db` | Not first choice |
| **node:sqlite** | built-in | in-memory SQLite | **SQL, zero-dep** | n/a (read-only) | **none (memory)** | **Preferred (V2)** |
| **DuckDB** | 1.5 current | embedded analytics | **read_json over NDJSON** | n/a (read-only) | **none (reads committed JSONL)** | **Second choice (V2)** |

---

## 4. EBDV Decision Variants (DIA-115)

Each variant carries evidence (Tier-1 archived-conspec pointer, this conspect
section). Effort is relative to the simplest option.

### V1 — Status quo: JSONL canonical + `jq` reads (abort/status-quo)
- **Change:** none. Keep the delegation-observer JSONL writes; keep `jq`/
  grep for ad-hoc reads.
- **Evidence:** JSONL is already the committed source of truth (developer
  constraint, section 5); lowdb/json-server/nedb/tinydb all rejected in
  section 2.
- **Pros:** zero change, zero new deps, fully committable, trivially
  deterministic. **Cons:** limited query ergonomics for complex filters/
  aggregation; no SQL; visibility improvements only via tooling like `jq`.
- **Effort:** 0.
- **Section-10 flag:** no (no tooling/config-surface change).
- **Recommendation weighting:** acceptable fallback; loses the visibility
  upside the ticket seeks.

### V2 — Read-only query layer over JSONL (RECOMMENDED)
- **Change:** keep JSONL write path unchanged; add a read-only query layer.
  Preferred engine `node:sqlite` in-memory import (read JSONL -> in-memory
  table -> SQL reads; nothing written to disk). Second engine DuckDB
  `read_json` over the committed NDJSON (reads in place).
- **Evidence:** `node:sqlite` in-memory + read-only (section 2.8); DuckDB
  `read_json` (section 2.9). Both leave JSONL as sole source of truth.
- **Pros:** JSONL stays canonical + committable; SQL query ergonomics;
  zero committed binary state; deterministic (import-from-committed-data);
  token-economy gain from precise filtered reads vs full-file greps.
  **Cons:** one new mechanism (import/query script); node:sqlite stability is
  Release Candidate (1.2).
- **Effort:** small (single read-query helper + optional SQL view).
- **Section-10 flag:** no (no AI-tooling/config-surface change; new data read
  helper only).
- **Recommendation weighting:** **preferred** — meets the ticket's visibility/
  determinism goals while honoring the committability constraint.

### V3 — Migrate to an embedded binary DB as source of truth (rejected)
- **Change:** replace JSONL canonical store with a binary SQLite/nedb DB.
- **Evidence:** better-sqlite3 native binary (section 2.7); nedb family
  file/in-memory copy (sections 2.3-2.4); lowdb whole-file rewrite (2.1).
- **Pros:** single-file rich DB. **Cons:** binary DB is **not committable/
  diffable** — directly violates the binding developer constraint (section 5);
  loses the plain-text team-visible state; adds native/binary dependency;
  contradicts author guidance ("use PostgreSQL/MongoDB" for scale).
- **Effort:** highest; plus migration and dual-state risk.
- **Section-10 flag:** no, but **blocked by the developer constraint**.
- **Recommendation weighting:** **rejected** on the binding committability
  requirement.

### Recommendation
Select **V2** with `node:sqlite` as the preferred read engine (zero-dep,
built-in), DuckDB `read_json` as the second option, and V1 (`jq` status-quo)
as the simplest fallback if no read layer is needed immediately. **Because**
it delivers the ticket's visibility/determinism/token-economy upside while
keeping JSONL as the sole committable source of truth, which the developer
constraint (section 5) requires.

---

## 5. Developer Constraint (binding, 2026-08-14)

The developer constraint stated on 2026-08-14 governs all options:

- **Everything must stay committable/pushable plain text** so the teammate
  sees the same state before/after ticket processing.
- **SQLite binary files that cannot be committed are NOT acceptable as the
  source of truth.**
- **Query-on-demand (in-memory) is acceptable.**
- **Simplest committable path preferred.**

Consequence for this conspect: JSONL remains the canonical committed write
path; any query engine (V2) must be **read-only and/or in-memory** and must
never become the persisted source of truth; V3 (binary source of truth) is
disqualified outright.

---

## 6. Recommendation and D9 Ticket-Ledger Analog

**Recommended path (V2):** keep JSONL as the canonical committed write path;
add a read-only query layer over it. Preferred engine **`node:sqlite`**
in-memory import (read-only, zero new dependencies, SQL ergonomics); second
engine **DuckDB `read_json`** (native NDJSON reads, no data rewrite). Simplest
fallback: **V1 `jq` status-quo** — acceptable if the read-query layer is
deferred. Do **not** migrate to an embedded binary DB (V3): the committability
constraint makes it structurally wrong.

**D9 ticket-ledger analog:** this mirrors the DIA-125/res018/res021 ticket-ledger
decision: the markdown/git-backed plain-text ledger was kept as the canonical
state, and any external/store option was evaluated as a read/query enhancement
on top, never as a replacement source of truth. The JSONL session-record store
should follow the same pattern — plain text canonical, query layer optional and
read-only.

---

## 7. Sources Cited (passing evaluation)

All sources below passed the researcher's Phase-A evaluation (High/Med
relevance + High reliability) and are archived under
`sources/`. Citations reference the archived filenames.

1. Typicode. "lowdb." GitHub README, archived `sources/lowdb-github.md` (v7.0.1; whole-file rewrite, no cluster, adapters, presets).
2. npm registry. "lowdb." archived `sources/lowdb-registry.json` (dist-tags latest 7.0.1).
3. npm registry. "lowdb dist-tags." archived `sources/lowdb-dist-tags.json`.
4. npm registry. "json-server." archived `sources/json-server-registry.json` (dist-tags latest 1.0.0-beta.15).
5. npm registry. "json-server dist-tags." archived `sources/json-server-dist-tags.json`.
6. Typicode. "json-server." GitHub README, archived `sources/json-server-github.md` (v1 beta, REST, query operators).
7. npm package pages. archived `sources/npm-pages-summary.md` (json-server beta/400k downloads; lowdb 3yr/2.36M downloads/cluster+scale limits).
8. Chatriot, Louis. "nedb." README, archived `sources/nedb-readme.md` (unmaintained warning, Mongo-subset API, append-only, benchmarks).
9. npm registry. "nedb." archived `sources/nedb-registry.json` (latest 1.8.0).
10. npm registry. "nedb2." archived `sources/nedb2-registry.json` (latest 2018.12.30, abandoned).
11. Rebours, Timothee, et al. "@seald-io/nedb." README, archived `sources/seald-nedb-readme.md` (active fork, Promise API, compound indexes, append-only + full-memory copy).
12. npm registry. "@seald-io/nedb." archived `sources/seald-nedb-registry.json` (latest 4.1.2).
13. Rebours, Timothee, et al. "package.json." archived `sources/seald-nedb-package.json` (v4.1.2, TS types, deps).
14. PyPI. "tinydb project metadata." archived `sources/tinydb-pypi.json` (4.9.0, Python 3.10+, MIT).
15. PyPI. "tinydb project page." archived `sources/tinydb-pypi-page.md` (maintenance-mode note, release dates).
16. WiseLibs. "better-sqlite3 API." archived `sources/better-sqlite3-api.md` (synchronous API, WAL, transactions, in-memory, native addon).
17. WiseLibs. "better-sqlite3 npm page." archived `sources/better-sqlite3-npm-page.md` (13.0.3, 8.5M downloads, WAL, native deps).
18. npm registry. "better-sqlite3." archived `sources/better-sqlite3-registry.json` (latest 13.0.3).
19. Node.js Foundation. "Node.js v26.7.0 - SQLite (node:sqlite)." archived `sources/node-sqlite.md` (DatabaseSync/StatementSync, in-memory, read-only, release-candidate stability).
20. DuckDB. "JSON Overview." archived `sources/duckdb-json-overview.md` (read_json, SELECT FROM file, filename virtual column since v1.3).
21. DuckDB. "JSON Import." archived `sources/duckdb-json-import.md` (read_json / COPY JSON import).
22. DuckDB. "Documentation (docs/current)." archived `sources/duckdb-docs-current.md` (current major version 1.5).

**Excluded (not cited):**
- `github.com/Scille/umongo-nedb` — EXCLUDED by researcher: wrong repo guess,
  returned empty; correct repo is github.com/seald/nedb (archived above).
- `duckdb.org/docs/stable/` — EXCLUDED: redirect-only stub; resolved via
  `/docs/current/` (archived above). (This is the single Phase-A
  partial-failure.)
- `@typicode/lowdb` scoped alias — Low relevance (duplicate of lowdb); not
  cited in body (archived `sources/typicode-lowdb-registry.json`).
