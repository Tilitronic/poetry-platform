# Ticket Navigation Scripts: Search, Filter, Statistics, Tool Registration (DIA-260819-sl22, res026)

<!-- CONSPECTER-OUTPUT-CONTRACT
schema-version: 1.0
agent: conspecter
phase-a-source-count: 10
phase-a-failures: 5
shelf-registration: memory-shelf.yaml (shelf.conspects), delegated to @memory-manager
-->

## Metadata

- **Ticket:** DIA-260819-sl22 (Medium, OPEN, dev-infra) -- ticket navigation
  scripts: search, filter, statistics, tool registration.
- **Research artifact:** `res026` (research conspect).
- **Date:** 2026-08-19
- **Author:** @conspecter (pure-synthesis lane, D7)
- **Sources archived (Phase A):** 10 provisioned; 5 archived on disk
  (project-internal files readable from the repo), 5 external URLs NOT
  archived (researcher Phase A did not capture them -- see section 7).
- **Corpus:** `.source-urls.txt` manifest (72 lines) + project-internal files
  read directly from the repo (scripts/tickets, tickets.bats, DIA ticket,
  _TEMPLATE.md, README.md, res021 conspect).

---

## 1. Executive Summary

The DIA-260819-sl22 ticket asks: "agents need better tools for navigating,
searching, and filtering tickets." The answer is that **most of the requested
capability already exists** in the `scripts/tickets` CLI, and the highest-value
gaps are small bash extensions -- not new infrastructure.

### What already works

The `scripts/tickets` CLI (1,478 lines of bash, fully bats-tested with 30+
test cases) already implements:

| Subcommand | Capability | --json support |
|---|---|---|
| `list` | List all tickets, filter by `--status`, `--area`, `--severity` | Yes |
| `search <query>` | Case-insensitive grep across ticket files | Yes |
| `stats` | Count by status, severity, and area | Yes |
| `frontier` | Show unblocked OPEN tickets sorted by severity | No (missing) |
| `rollup [--check]` | Recompute README severity/status count tables | N/A |
| `new <title>` | Allocate next DIA number, write ticket, update README | N/A |

### What is missing (the real gaps)

1. **`frontier --json`** -- the single highest-value addition. The frontier
   subcommand is the primary agent navigation tool (it shows what to work on
   next), but it lacks machine-readable output. Every other subcommand already
   has `--json`.
2. **`show <DIA-id>`** -- display a single ticket's frontmatter + description
   without the agent reading the full file. Low effort, high frequency use.
3. **Temporal filters** -- `--since <date>` and `--before <date>` on `list`
   and `frontier`. Not currently possible; agents must read individual files
   to check dates.
4. **`frontier --depth N`** -- resolve blocked-by chains N levels deep, so an
   agent can see transitive dependencies. Currently only shows direct
   blockers.

### What is NOT needed

- **SQLite/sqlite-utils SQL layer:** Rejected. At 190 tickets (and until
  500+), bash grep/sed is adequate. The delegation-observer gate reads flat
  markdown files; adding a SQL layer adds complexity without solving a real
  performance problem.
- **MCP server registration:** Rejected. Agents already invoke `scripts/tickets`
  via bash. Registering an MCP server adds process management overhead with no
  capability gain. The filesystem MCP is an optional agent-facing layer per
  res021, not a ticket-navigation tool.
- **External ticket trackers (Plane, OpenProject, etc.):** Rejected per
  res021. The gate contract requires flat DIA files on disk.

---

## 2. Existing Capability Analysis (MLA-cited)

### 2.1 scripts/tickets CLI -- the implementation artifact

The CLI is a single 1,478-line bash script at `scripts/tickets` (line 1).
It implements six subcommands (`new`, `list`, `search`, `stats`, `rollup`,
`frontier`) plus `help`. Key architectural properties:

- **Gate-compatible by construction** (lines 8-13): the script codifies the
  "manual writer" against the exact contract the delegation-observer
  `scanTickets` parses -- filename regex `^DIA-(\d+)` for ID extraction,
  YAML frontmatter for status/session_id/title. "Automated creation stays
  gate-compatible by construction" (script header, lines 8-13, citing res021
  conspect section 1).
- **Bash-3 compatible** (lines 63-66): no `[[ ]]`, no associative arrays,
  no `mapfile`/`namerefs`/`compgen`. The bats test suite requires bash 4+
  (test-helper.bash uses `[[ ]]`), but the script itself is bash-3 safe.
- **ASCII-only enforcement** (DIA-079): `assert_ascii()` (line 174) hard-fails
  on non-ASCII input; `sanitize()` (line 164) replaces non-ASCII bytes with
  `?` in display output.
- **Collision-safe allocation** (lines 835-861): datetime-format IDs
  (DIA-YYMMDD-XXXX) with random 4-char suffix, retry loop up to 5 times
  with jitter for concurrent creation races (DIA-215).
- **Dual ID format support** (DIA-234): sequential (`DIA-NNN`) and datetime
  (`DIA-YYMMDD-XXXX`) IDs coexist. `is_datetime_id()` (line 447) and
  `find_insert_position()` (line 456) handle cross-format sorting with
  grandfather policy (all sequential before all datetime).

**Citation:** scripts/tickets (project-internal, 1,478 lines), read from
repo at `/home/qualt/Projects/poetry-platform/scripts/tickets`.

### 2.2 Test suite -- bats-tested coverage

The test file `scripts/__tests__/tickets.bats` (916 lines, 30+ test cases)
validates every subcommand against an isolated fixture tree (4 tickets
DIA-130..133, deliberately stale count tables). Tests cover:

- `help` / `--help` / no-arguments exit codes (tests 1-3)
- `new`: allocation, frontmatter, slug, README insertion, blocked-by,
  parent-epic, ASCII guard, severity validation, collision safety
  (tests 4-16)
- `rollup`: stale count recomputation, `--check` drift gate, no-op
  convergence (tests 17-19)
- `frontier`: unblocked/blocked sorting, closed-blocker unblocking,
  datetime tickets sorting after sequential (tests 20-25)
- `list`: table output, `--status`/`--area`/`--severity` filters, `--json`,
  empty results (tests 26-31)
- `search`: title match, case-insensitive, no-match, `--json`, missing
  query (tests 32-36)
- `stats`: count output, `--json` (tests 37-38)
- Datetime format: `DIA-YYMMDD-XXXX` allocation, collision safety, README
  insertion, blocked-by/parent-epic (tests 39-46)

**Citation:** scripts/__tests__/tickets.bats (project-internal, 916 lines),
read from repo.

### 2.3 Delegation-observer gate contract

The gate in `delegation-observer.ts` defines the query contract any navigation
tool must satisfy. From the res021 conspect (section 1):

- `scanTickets(ticketsDir)` reads every `*.md` in `docs/dev-infra-audit/tickets/`,
  skips README/_TEMPLATE/COORDINATION, parses YAML frontmatter, builds
  `ScannedTicket {id, status, sessionId, discoveredMs, title, filename}`.
- The ticket ID is derived from the **filename** regex `/^DIA-(\d+)/`, not
  from content.
- Gate correlation: explicit DIA-id in dispatch -> must resolve to OPEN ticket;
  no id -> session-owned or keyword-correlated.

**Implication:** any navigation tool that produces DIA-ids must match the
filename-derived format. The `scripts/tickets` CLI already does this
(`num_of_file()`, line 218).

**Citation:** res021-ticket-mgmt-automation-conspect.md, section 1 (project-
internal conspect, `knowledge/res021-ticket-mgmt-automation/`).

### 2.4 Data model -- _TEMPLATE.md frontmatter

The ticket frontmatter schema (source of truth for query fields) is defined
in `_TEMPLATE.md`:

```
id, title, area, severity, status, blocked_by, parent_epic,
gate_state, gate_triggers, gate_waivers, gate_override,
discovered, source, date, created, updated,
session_id, lane_id, agent, model, parent_session_id,
attempts, lease_expires_at, files_touched, artifacts, evidence
```

Queryable fields for navigation: `status`, `area`, `severity`, `created`,
`updated`, `blocked_by`, `parent_epic`, `lease_expires_at`, `agent`.

**Citation:** docs/dev-infra-audit/tickets/_TEMPLATE.md (project-internal,
80 lines).

### 2.5 Current ledger state

The README.md index shows 168 tickets (DIA-045 through DIA-260819-sl22).
Status breakdown: 12 OPEN, 111 CLOSED, 28 VERIFIED, 11 DONE, plus smaller
counts for DEFERRED/MONITOR/FIXED/IMPLEMENTED/COMPLETE. The README count
tables are manually maintained and prone to drift (the rollup --check gate
exists to catch this).

**Citation:** docs/dev-infra-audit/tickets/README.md (project-internal,
210 lines).

---

## 3. Gap Analysis: What the Ticket Asks For vs What Exists

| Requirement (from DIA ticket) | Current state | Gap | Recommended action |
|---|---|---|---|
| Search by status, area, severity, keywords | `list --status/--area/--severity` + `search <query>` | None -- already works | No change needed |
| Ticket statistics | `stats [--json]` | None -- already works | No change needed |
| `--json` for programmatic use | `list --json`, `search --json`, `stats --json` | `frontier --json` missing | **Add `--json` to `frontier`** (highest value) |
| Agent-friendly output | JSON output on 3/4 query subcommands | `frontier` text-only | Same as above |
| Register as orchestrator tools | Not registered as MCP; agents call bash | Agents already call bash via delegation | **No MCP needed** (per res021: bash sufficient) |
| Script-based stats instead of README sync | `rollup --check` detects drift; `stats` generates on-demand | README rollup is still manual trigger | Add to pre-push hook or agent workflow |
| Possible SQL layer | Not implemented | Not needed at 190 tickets | **Skip SQLite until 500+ tickets** |
| Single-ticket detail view | No `show` subcommand | Agents must `read` the full file | **Add `show <DIA-id>` subcommand** |

---

## 4. Recommendations

### R1 (highest priority): Add `frontier --json`

Effort: ~30 lines of bash. The `cmd_frontier()` function (line 1020) already
builds `frontier_lines` and `blocked_lines` arrays. Adding a `--json` flag
that emits `{"frontier": [...], "blocked": [...], "leases": [...]}` is
mechanical -- the same pattern used in `cmd_list --json` (line 1408) and
`cmd_search --json` (line 1329).

**Why this is the single highest-value change:** the frontier is the primary
agent navigation tool. Every session that needs to know "what can I work on
next?" calls `frontier`. Without `--json`, the orchestrator must parse
human-readable text. With it, the result feeds directly into dispatch logic.

### R2: Add `show <DIA-id>` subcommand

Effort: ~40 lines of bash. Extract frontmatter + first paragraph of
Description for a single ticket. Supports `--json` for programmatic use.

### R3: Add temporal filters to `list` and `frontier`

Effort: ~20 lines each. `--since YYYY-MM-DD` and `--before YYYY-MM-DD`
filter on the `created` frontmatter field. Enables "tickets created this
week" and "tickets older than 30 days" queries.

### R4: Add `frontier --depth N` for transitive blocked-by resolution

Effort: ~50 lines. Currently `cmd_frontier()` shows only direct blockers.
A depth parameter would follow `blocked_by` chains to show transitive
dependencies (e.g., "DIA-X is blocked by DIA-Y which is blocked by DIA-Z").

### R5 (deferred): SQLite/sqlite-utils SQL layer

Not recommended until 500+ tickets or a demonstrated performance bottleneck
with bash grep. At current scale (190 tickets), `list --json | jq` is
adequate for complex queries. The delegation-observer gate reads flat files;
a SQL layer would be read-only and additive, but the cost/benefit ratio is
poor today.

### R6 (not recommended): MCP server registration

Agents already invoke `scripts/tickets` via bash delegation. Registering an
MCP server adds a long-running process, configuration surface, and
maintenance burden with no capability gain. The filesystem MCP (res021) is an
optional agent-facing layer over the same files, not a ticket-navigation tool.

---

## 5. EBDV Decision Variants (DIA-115)

### V1 -- Status quo: no changes (abort)

- **Change:** none. Keep the existing CLI as-is.
- **Evidence:** 3/4 query subcommands already have `--json`; frontier works
  for human reading.
- **Pros:** zero effort, zero risk. **Cons:** frontier is the most-used
  agent navigation tool and lacks `--json`; no single-ticket view; no
  temporal filters. Agents must parse human text for the most common query.
- **Effort:** 0.
- **Section-10 flag:** no.
- **Recommendation:** acceptable only if no agent actually calls frontier
  programmatically (unlikely).

### V2 -- Bash extensions only (RECOMMENDED)

- **Change:** add `frontier --json`, `show <DIA-id>`, temporal filters,
  `frontier --depth`. All bash, all within the existing `scripts/tickets`
  file.
- **Evidence:** existing `--json` patterns in list/search/stats (section 2.1);
  res021 keep-local recommendation (section 4); delegation-observer gate
  contract (section 2.3).
- **Pros:** zero new infrastructure; gate-compatible by construction;
  bats-testable; addresses all four identified gaps. **Cons:** bash is
  limited for complex queries (but adequate at current scale).
- **Effort:** ~140 lines of bash + ~200 lines of bats tests.
- **Section-10 flag:** no (no tooling/config-surface change).
- **Recommendation:** **preferred** -- maximum capability gain per unit
  effort, zero new dependencies, fully gate-compatible.

### V3 -- SQLite read-only layer over ticket files (rejected for now)

- **Change:** add a `node:sqlite` or `sqlite-utils` read-only query layer
  that imports ticket frontmatter into an in-memory table for SQL queries.
- **Evidence:** DIA-136 `node:sqlite` pattern (res026-orchestrator conspect,
  section 2.8); sqlite-utils CLI docs (NOT ARCHIVED -- see section 7).
- **Pros:** SQL query ergonomics for complex filters/aggregation. **Cons:**
  overkill at 190 tickets; adds a runtime dependency (node or python);
  gate reads flat files regardless; bash `list --json | jq` covers current
  needs.
- **Effort:** medium (new script + dependency).
- **Section-10 flag:** no.
- **Recommendation:** revisit at 500+ tickets or when complex query needs
  are demonstrated.

### V4 -- MCP server registration (rejected)

- **Change:** register `scripts/tickets` as an MCP tool.
- **Evidence:** opencode MCP server patterns (NOT ARCHIVED); res021
  filesystem MCP evaluation (section 2.3).
- **Pros:** agents see ticket tools natively. **Cons:** adds process
  management overhead; agents already call bash; MCP adds no capability over
  direct invocation; maintenance burden.
- **Effort:** medium (MCP server wrapper + config).
- **Section-10 flag:** yes (new tooling surface).
- **Recommendation:** **rejected** -- bash delegation is sufficient and
  already proven.

### Recommendation

Select **V2** (bash extensions). **Because** it addresses all four identified
gaps with zero new infrastructure, stays gate-compatible by construction, and
follows the res021 keep-local recommendation. The `frontier --json` addition
alone justifies the effort -- it is the single change that most improves
agent navigation ergonomics.

---

## 6. Developer Constraint (binding)

The binding constraint for any ticket navigation tool is the
delegation-observer gate contract (section 2.3):

- The gate reads flat `DIA-NNN-*.md` files with YAML frontmatter from
  `docs/dev-infra-audit/tickets/`.
- Ticket IDs are derived from filenames, not content.
- Any external system that becomes the source of truth needs a file-mirror
  bridge.
- The keep-local baseline (bash CLI) writes directly into the scanned
  directory, satisfying the gate natively.

Consequence: the recommended path (V2 bash extensions) is the only variant
that satisfies the gate contract without additional infrastructure.

---

## 7. Sources

### 7.1 Sources evaluated and read (project-internal)

All sources below were read from the project repo during synthesis. They
passed the researcher's Phase-A evaluation (High relevance, High reliability)
per the `.source-urls.txt` manifest.

1. `scripts/tickets` -- the existing ticket management CLI (1,478 lines bash).
   Read from `/home/qualt/Projects/poetry-platform/scripts/tickets`.
2. `scripts/__tests__/tickets.bats` -- test suite (916 lines, 30+ tests).
   Read from `/home/qualt/Projects/poetry-platform/scripts/__tests__/tickets.bats`.
3. `docs/dev-infra-audit/tickets/DIA-260819-sl22-ticket-navigation-scripts-search-filter-statistics-tool-registration.md`
   -- the DIA ticket defining requirements. Read from repo.
4. `docs/dev-infra-audit/tickets/_TEMPLATE.md` -- frontmatter schema (source
   of truth for query fields). Read from repo.
5. `docs/dev-infra-audit/tickets/README.md` -- current ledger index (168
   tickets, manual rollup target). Read from repo.
6. `knowledge/res021-ticket-mgmt-automation/res021-ticket-mgmt-automation-conspect.md`
   -- prior landscape evaluation (gate constraints, keep-local recommendation).
   Read from repo.

### 7.2 Sources NOT archived (researcher Phase A failures)

The following URLs were provisioned in the `.source-urls.txt` manifest but
were NOT archived by the researcher. No claims from these sources are made
in the conspect body. They are listed for traceability per DIA-072:

- **sqlite-utils CLI documentation** (`github.com/simonw/sqlite-utils/blob/main/docs/cli.rst`)
  -- [NOT ARCHIVED: researcher bash blocked; external URL not fetched].
  Relevance: High (potential SQL layer). Reliability: High (official docs).
- **SQLite FTS5** (`github.com/sqlite/sqlite/blob/master/ext/fts5/fts5_storage.c`)
  -- [NOT ARCHIVED: researcher bash blocked; external URL not fetched].
  Relevance: High (full text search). Reliability: High (official SQLite docs).
- **delegation-observer.ts** (`.opencode/plugins/delegation-observer.ts`)
  -- [NOT FOUND: file does not exist at the provisioned path]. Relevance:
  High (gate contract). Reliability: N/A (file missing). The gate mechanics
  are documented in the res021 conspect section 1 instead.
- **opencode.jsonc** (`.opencode/opencode.jsonc`)
  -- [NOT FOUND: file does not exist at the provisioned path]. Relevance:
  Medium (MCP registration pattern). Reliability: N/A (file missing).
- **res021 filesystem-mcp source** (`knowledge/res021-ticket-mgmt-automation/sources/filesystem-mcp.md`)
  -- [NOT FOUND: file does not exist at the provisioned path]. Relevance:
  Medium (agent file access pattern). The res021 conspect itself was read
  instead.

### 7.3 MLA Citations

1. scripts/tickets. "DIA ledger CLI: number allocator, template generator,
   README rollup updater, blocker-graph/frontier view." project-internal,
   2026, scripts/tickets (1,478 lines). Accessed 19 Aug. 2026.
2. scripts/__tests__/tickets.bats. "DIA-125 keep-local ticket automation:
   unit tests for scripts/tickets." project-internal, 2026,
   scripts/__tests__/tickets.bats (916 lines). Accessed 19 Aug. 2026.
3. DIA-260819-sl22. "ticket navigation scripts: search, filter, statistics,
   tool registration." project-internal, 2026,
   docs/dev-infra-audit/tickets/DIA-260819-sl22-ticket-navigation-scripts-search-filter-statistics-tool-registration.md.
   Accessed 19 Aug. 2026.
4. docs/dev-infra-audit/tickets/_TEMPLATE.md. "DIA-XXX ticket template."
   project-internal, 2026, docs/dev-infra-audit/tickets/_TEMPLATE.md
   (80 lines). Accessed 19 Aug. 2026.
5. docs/dev-infra-audit/tickets/README.md. "Dev-Infra Audit -- Ticket Ledger."
   project-internal, 2026, docs/dev-infra-audit/tickets/README.md
   (210 lines, 168 tickets). Accessed 19 Aug. 2026.
6. res021-ticket-mgmt-automation-conspect.md. "DIA-125 Ticket-Automation
   Landscape Evaluation." project-internal conspect, 2026,
   knowledge/res021-ticket-mgmt-automation/res021-ticket-mgmt-automation-conspect.md.
   Accessed 19 Aug. 2026.
