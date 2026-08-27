# DIA-125 Ticket-Automation Landscape Evaluation - Conspect (res021)

<!-- CONSPECTER-OUTPUT-CONTRACT
schema-version: 1.0
agent: conspecter
phase-a-source-count: 13
phase-a-failures: 0
shelf-registration: .opencode/memory-shelf.yaml (shelf.conspects)
-->

Conspect for DIA-125 (OPEN research ticket): "automate ticket creation & management - evaluate ready-made local solutions (MCP/self-hosted) vs manual ledger". This is the follow-on landscape evaluation to res018 (DIA-125 first pass, 22 archived sources) and archives the decision-support findings of the DIA-125 res-1 researcher for the ticket-automation landscape (13 external URLs, all archived locally in `sources/`). Every claim below is grounded either in a locally archived source file (Phase A output, archived 2026-08-13) or in project-internal source (delegation-observer plugin, res018 conspect, ana006 analysis); researcher-supplied figures that could NOT be confirmed in the archive are flagged per DIA-072 and listed in section 6.

## 1. Decision context: the delegation-observer ticket-gate mechanics (project-internal)

The binding constraint any ticket automation must satisfy is the plugin-side ticket gate in `.opencode/plugins/delegation-observer.ts` (DIA-063). The mechanics, grounded in the plugin source (lines cited):

- **scanTickets(ticketsDir)** (line 425): reads every `*.md` file in `docs/dev-infra-audit/tickets/`, skips `README.md` / `_TEMPLATE.md` and non-files, parses YAML frontmatter via `parseFrontmatterFields`, and builds a flat `ScannedTicket` model `{id, status, sessionId, discoveredMs, title, filename}`. The ticket id is derived from the FILENAME regex `/^DIA-(\d+)/` (line 436), not from content. `scanTickets` THROWS when the tickets directory is missing (lines 426-428).
- **Gate correlation** `evaluateTicketCorrelation` (line 468), three paths: (1) an explicit `DIA-id` in the dispatch must resolve to an OPEN ticket with that exact id - STRICT tri-state (DIA-076 C1): a referenced id matching no open ticket FAILS and never falls through to paths 2/3; (2) no DIA-id -> an open ticket owned by the current session; (3) no DIA-id and no session-owned -> a recent (<=24h) open ticket whose title keywords correlate. Otherwise the dispatch is BLOCKED.
- **The regex is format-agnostic**: the DIA-id extraction is `dispatchText.match(/DIA-\d+/gi)` (line 921) - case-insensitive, digit-based, no structure beyond `DIA-<digits>`. The filename gate regex is `/^DIA-(\d+)/` (line 436).
- **Exemptions** (lines 901-907): ticket-CREATION dispatches ("create ticket | new ticket | ticket creation | author ticket") and boot-gate checksum verification. A bare DIA-id mention is NOT an exemption - it is the correlation signal (finding A: the old `/DIA-\d+/` exemption was a direct bypass, line 889).
- **Fail-soft**: a `scanTickets` throw (e.g. missing directory) is converted by the caller's catch into warn + allow + `ticket_gate_scan_failed` row (lines 912-915) - "a broken gate is worse than no gate".

**Implication for any external tracker**: because the gate reads a flat directory of `DIA-<NNN>-<slug>.md` files with frontmatter `status`/`session_id`/`discovered`/`title`, ANY external tracker (self-hosted web app, cloud SaaS, or git-object store) needs a FILE-MIRROR BRIDGE that materializes DIA-NNN ticket files into `docs/dev-infra-audit/tickets/` (or a gate rework). This is the single most important architectural constraint for the candidate evaluation below.

## 2. Candidate families (13 archived sources)

### 2.1 Self-hosted web trackers

| Candidate | Archive evidence | Deployment weight | Fit notes |
|---|---|---|---|
| Plane (self-host) | plane-selfhost.md: Docker Compose OR Kubernetes deployment; "full ownership of your data"; data sovereignty for GDPR/HIPAA/SOC 2; "no vendor lock-in" - data in open formats, migrate/backup freely | Heavy (full container stack, K8s option) | Strongest self-hosted platform pair (see MCP below); Tier-3-at-scale candidate |
| OpenProject CE | openproject-ce-mcp.md (CE-targeting MCP); platform itself cross-referenced from res018 archive (opf-openproject.md: enterprise platform, GPL-3.0, "full control over their data") | Heavy (Rails enterprise platform; per res018 archive) | Rails-based enterprise breadth; now HAS a CE MCP server (section 2.2) - res018's "no MCP" rejection is superseded for CE |
| Redmine | redmine-mcp-search.md: 164 repo results - the largest MCP ecosystem in this evaluation; platform cross-referenced from res018 archive (redmine-redmine.md: Ruby on Rails, 19,622 commits) | Heavy (Rails app + DB) | Rails legacy; MCP ecosystem is real but fragmented (section 2.2) |
| Gitea / Forgejo | gitea-mcp-search.md (58 results), forgejo-mcp-search.md (46 results) - MCP ecosystem confirmed: a 103-tool Gitea/Forgejo MCP server, a fork of gitea/gitea-mcp, an mcp.ag2.ai-generated server, a "same architecture as mcp-github" server, a Forgejo "MIRROR ONLY" Codeberg MCP, and "Forgejo Self-Hosted Integration with Claude" | Single Go binary (researcher-supplied; platform repos NOT archived here - see section 6) | Per res-1 findings the most local-first-friendly family; the archived search pages confirm a healthy MCP ecosystem |
| Vikunja | vikunja-docs.md: Setup, API & Integrations, Development doc sections; Help Center covers "tasks, projects, sharing" | Self-hosted server (docs: install + config) | Todo/kanban semantics (tasks, projects, sharing) differ from the ledger's status-driven DIA ticket workflow - "todo semantics mismatch" per res-1; mature MCP ecosystem (section 2.2) |

### 2.2 MCP servers

| Candidate | Archive evidence (star counts marked V=verified in archive / R=researcher-supplied) | Transport / operation | Write capability |
|---|---|---|---|
| Plane MCP (official) | plane-mcp-server.md: MIT license; "100+ tools across 20 categories" (tool tables: projects, work items, cycles, modules, initiatives, milestones, labels, states, comments, links, types, relations, activities, work logs, pages, members, features); Node.js version DEPRECATED - Python+FastMCP rewrite is current | stdio via uvx (recommended, no install), SSE (legacy), streamable HTTP remote `mcp.plane.so`; `PLANE_BASE_URL` configurable (default `api.plane.so`) so it can target a self-hosted Plane; OAuth redirect-URI allowlist; structured JSON logs | Full CRUD across all 20 categories; Pydantic-typed tools |
| OpenProject CE MCP (jtauschl) | openproject-ce-mcp.md + openproject-mcp-search.md: 14 stars (V); "132 tools (106 without admin writes) covering the full v3 REST API" (V, search snippet); CE only - Enterprise has its own official MCP | stdio local subprocess (pipx install); no remote server, no persistent storage | Guarded preview-then-confirm writes ("no way to bypass"); `OPENPROJECT_READ_PROJECTS` / `OPENPROJECT_WRITE_PROJECTS` allowlists are the real gate; context-frugal (-86% to -99% tokens vs raw HAL); `<user-content>` prompt-injection tagging |
| Redmine mcp-redmine | redmine-mcp-search.md: runekaagaard/mcp-redmine 232 stars (V) - top of a 164-result ecosystem (yonaka15/mcp-server-redmine 78, jztan/redmine-mcp-server 65, aarondpn/redmine-cli 39, onozaty 21, 0xkillaflow/agama-redmine-mcp 20) | not stated in archive (search page only) | not stated in archive (search page only) |
| Vikunja MCP (community) | vikunja-mcp-search.md: democratize-technology/vikunja-mcp 100 stars (V); 0xK3vin/vikunja-mcp 13 stars (V; res018 archived it at 32 tools, MIT); 73-result ecosystem | not stated in archive (search page only); res018 archived npx-based stdio for 0xK3vin/shichao402 | res018 archived full CRUD (projects/tasks/kanban/labels/comments/relations) for 0xK3vin |
| Forgejo MCP | forgejo-mcp-search.md: 46-result ecosystem (Codeberg "MIRROR ONLY" server, 103-tool Forgejo/Gitea server, aaron/forgejo_mcp, EveniaAITeam/MCP-FORGEJO mirrors). goern 115 stars / raohwork 65 stars = RESEARCHER-SUPPLIED only, NOT in archive (tier-c extraction lost repo names/star counts) - excluded per DIA-072 | not stated in archive | not stated in archive |
| GitHub MCP (official) | github-mcp-server.md: MIT license; REMOTE server hosted by GitHub at `https://api.githubcopilot.com/mcp/`; LOCAL server via Docker (`ghcr.io/github/github-mcp-server`) or Go binary - but always talks to the GitHub API with a PAT; GitHub Enterprise Cloud can use the remote server; "GitHub Enterprise Server does not support remote server hosting" (line 125) - GHES must use the local server | remote Streamable HTTP + local stdio/Docker | toolsets: repos, issues, pull_requests, actions, code_security, stargazers, etc.; `issue_write` toolset (create/update); read-only mode not shown in this archive but toolsets are configurable |

### 2.3 Local CLIs and file-based options

| Candidate | Archive evidence | Storage / operation | Fit notes |
|---|---|---|---|
| git-bug | git-bug.md: GPLv3 or later; "distributed, offline-first issue management tool that embeds issues, comments, and more as objects in a git repository (*not files!*)"; push/pull to one or more remotes; bridges to GitHub and GitLab; CLI, TUI, web interfaces; "Lightning Fast" list/search | git objects in repo (not files); offline-first | Philosophically closest to a git ledger, but issues are NOT `DIA-NNN-*.md` files with YAML frontmatter - the gate's scanTickets cannot read them without a mirror bridge; no MCP server documented in archive |
| taskwarrior | taskwarrior-docs.md: complete CLI doc set - config (`.taskrc`), commands, JSON import/export format, User Defined Attributes (UDAs), Hooks API (v1/v2), syncing (3.0.0), Task Representation, External Scripts | single binary CLI (researcher-supplied); task data lives outside the repo (researcher-supplied; archive states the JSON/task representation and sync model, not the data path) | Todo-oriented semantics (priority, due dates, recurrence, context) - not a ticket/status workflow; scriptable via JSON + hooks; no MCP in archive |
| Keep-local baseline (number allocator + template generator + README rollup updater + blocker-graph/frontier renderer, bats-tested) | project-internal proposal (res-1 findings + res018 Tier-1 "codify the manual writer"); grounded in the ledger conventions res018 section 1 (DIA-NNN+slug files, YAML frontmatter v2, README index + counts, archive/) | files in repo, no runtime deps | Satisfies ALL three hard constraints natively (section 3); zero new infra |
| Filesystem MCP server (@modelcontextprotocol/server-filesystem) | filesystem-mcp.md: MIT license; npm package; Roots-based dynamic directory access control (server requires at least ONE allowed directory; roots/list_changed runtime updates); tools: read_text_file (head/tail), read_media_file, read_multiple_files, write_file, edit_file (git-style diff + dryRun, "Always use dryRun first"), create_directory, list_directory(_with_sizes), move_file, search, metadata; Docker build available | local Node.js process, directory-scoped | NOT a tracker - an optional agent-facing file layer over the ledger; every operation stays inside allowed directories |

## 3. Fit vs the three hard constraints

Constraints (project-internal, binding): (1) DIA-079 ASCII-only lane payloads and reports; (2) gate compat - the delegation-observer scanTickets contract (section 1); (3) local-first in WSL2/container - zero network dependency, zero auth surface (ana006 architecture decision).

| Candidate | (1) ASCII | (2) Gate compat | (3) Local-first WSL2/container | Verdict |
|---|---|---|---|---|
| Keep-local baseline | PASS (native) | PASS (writes DIA-NNN files directly into the scanned dir) | PASS (files in repo, no server) | NATIVE FIT |
| Filesystem MCP | PASS (tool layer) | PASS (edits the same files) | PASS (local Node process) | OPTIONAL LAYER |
| git-bug | PASS (CLI output ASCII-safe) | PARTIAL - issues in git objects, no DIA files; mirror bridge needed | PASS (offline-first, git-embedded) | CONDITIONAL |
| taskwarrior | PASS | FAIL - data outside repo, no DIA files, no file-mirror semantics | PARTIAL (single binary but data in ~/.task, needs sync) | WEAK |
| Plane + Plane MCP | PASS (API JSON ASCII-safe) | FAIL without bridge (Plane DB, not DIA files) | PARTIAL - self-host keeps data local but requires the full Docker Compose/K8s stack running in the container | TIER-3 ONLY |
| OpenProject CE + jtauschl MCP | PASS | FAIL without bridge | PARTIAL - Rails platform weight; the MCP itself is a thin local stdio client | TIER-3 ONLY |
| Redmine + mcp-redmine | PASS | FAIL without bridge | PARTIAL - Rails app + DB; MCP quality not in archive (search page only) | TIER-3 ONLY |
| Vikunja + community MCP | PASS | FAIL without bridge | PARTIAL - self-host server; todo semantics mismatch | TIER-3 ONLY |
| Gitea/Forgejo + MCP | PASS | FAIL without bridge | PARTIAL - single Go binary is the lightest platform (researcher-supplied) but still a server + DB; search archive confirms MCP ecosystem | TIER-3 CANDIDATE (needs platform-level archival) |
| GitHub MCP | PASS | FAIL without bridge | FAIL - cloud system of record; GHES requires an enterprise server; PAT auth surface; violates zero-network/zero-auth (ana006) | REJECTED for local-first |

## 4. Top-3 ranking (preliminary, developer decides)

1. **Keep-local baseline (recommended)** - number allocator, template generator, README rollup updater, blocker-graph/frontier renderer, bats-tested. The ONLY candidate that satisfies all three constraints natively: it writes the exact `DIA-NNN-<slug>.md` + frontmatter contract scanTickets already parses (section 1), stays ASCII-pure, and runs on the host/container with zero runtime dependencies. Optionally wrapped for agents by the official Filesystem MCP server (section 2.3) as a read/write layer over `docs/dev-infra-audit/tickets/` - the MCP adds directory-scoped tool access without changing the system of record.
2. **git-bug (CLI experiment)** - philosophically the closest ready-made tool to the ledger (git-embedded, offline-first, GPLv3+, CLI/TUI/web, GitHub/GitLab bridges). Ranked second because issues are stored as git OBJECTS, not DIA files: adopting it as the system of record requires a mirror bridge to keep the gate's directory populated, and its issue model (no YAML frontmatter session attribution) diverges from the ledger schema. Viable as a bounded experiment mirroring steviee/git-issues (res018 Tier 2) rather than a replacement.
3. **OpenProject CE + jtauschl/openproject-ce-mcp** - the strongest self-hosted MCP PAIR in this evaluation when a real platform is warranted: 132 tools (106 without admin writes) over the full v3 API, guarded preview-then-confirm writes, allowlist-scoped project access, context-frugal responses (-86% to -99% tokens), CE-only targeting, and a local stdio process. Ranked third (Tier-3-at-scale) because it drags the Rails platform weight and still needs a gate bridge.

Not ranked but tracked: Gitea/Forgejo (lightest platform family per res-1, thriving MCP ecosystem per search archives - 58/46 results - but platform repos themselves were not in the URL list; archive before deciding), Plane/Vikunja/Redmine platforms (Tier-3 alternatives with mature MCP ecosystems; Vikunja retains the todo-semantics mismatch, Plane the stack weight, Redmine the Rails legacy + fragmented MCP field), GitHub MCP (rejected: cloud system of record violates local-first).

## 5. Preliminary recommendation (keep-local, per res-1)

Adopt the keep-local baseline as the primary path: a thin bats-tested toolkit (number allocator, template generator, README rollup updater, blocker-graph/frontier renderer) that codifies the existing manual writer against the exact gate contract - DIA-NNN+slug filenames, frontmatter status/session_id/discovered/title, README index + counts, archive/ hygiene (ledger conventions per res018 section 1). This is res018's Tier-1 recommendation operationalized for the gate mechanics documented here; the Filesystem MCP server is an optional agent-facing layer, not a system-of-record change. No external tracker in this evaluation satisfies the gate contract without a file-mirror bridge, and none of the platform candidates clears the local-first bar at current scale - so the mirror-bridge requirement should be treated as a deliberate gate-compat decision: if a platform is ever adopted, the bridge that materializes DIA files from it is mandatory, not optional.

## 6. Unarchived / not-confirmed items (DIA-072 policy)

All 13 source URLs were archived (0 failures). The following researcher-supplied (res-1 findings) figures could NOT be confirmed in the archived sources and are EXCLUDED from the conspect body as claims; they are listed here for traceability:

- Forgejo MCP star counts (goern 115, raohwork 65) - [star counts not archived - excluded per DIA-072 policy]. The forgejo-mcp-search.md archive (tier-c curl+trafilatura) captured the 46-result structure and descriptions but lost per-repo names/star counts; the tier-d crwl passes for these two URLs were rate-limited and the curl retry succeeded only at description level.
- Plane MCP 286 stars, GitHub MCP 32.2k stars, git-bug 10k stars - [star counts not archived - excluded per DIA-072 policy]. The archived READMEs do not render star counts.
- Gitea/Forgejo "single Go binary, most local-first friendly" platform claim - [platform repos not archived - excluded per DIA-072 policy]. Only the MCP search pages for these platforms were archived; the platform claim comes from the res-1 findings and res018 discussion, not from an archived Gitea/Forgejo source.

## 7. Source URLs and MLA citations (all archived locally in sources/)

1. GitHub. "git-bug." GitHub, 2026, github.com/git-bug/git-bug. Accessed 13 Aug. 2026. [archived: sources/git-bug.md]
2. Plane. "Deploy Plane on your infrastructure (Self-hosting overview)." developers.plane.so, 2026, developers.plane.so/self-hosting/overview. Accessed 13 Aug. 2026. [archived: sources/plane-selfhost.md]
3. makeplane. "plane-mcp-server." GitHub, 2026, github.com/makeplane/plane-mcp-server. Accessed 13 Aug. 2026. [archived: sources/plane-mcp-server.md]
4. Vikunja. "Documentation." Vikunja Docs, 2026, vikunja.io/docs/. Accessed 13 Aug. 2026. [archived: sources/vikunja-docs.md]
5. GitHub. "Repositories search: openproject mcp." GitHub, 2026, github.com/search?q=openproject+mcp&type=repositories. Accessed 13 Aug. 2026. [archived: sources/openproject-mcp-search.md]
6. jtauschl. "openproject-ce-mcp." GitHub, 2026, github.com/jtauschl/openproject-ce-mcp. Accessed 13 Aug. 2026. [archived: sources/openproject-ce-mcp.md]
7. GitHub. "Repositories search: vikunja mcp." GitHub, 2026, github.com/search?q=vikunja+mcp&type=repositories. Accessed 13 Aug. 2026. [archived: sources/vikunja-mcp-search.md]
8. GitHub. "GitHub MCP Server." GitHub, 2026, github.com/github/github-mcp-server. Accessed 13 Aug. 2026. [archived: sources/github-mcp-server.md]
9. GitHub. "Repositories search: redmine mcp." GitHub, 2026, github.com/search?q=redmine+mcp&type=repositories. Accessed 13 Aug. 2026. [archived: sources/redmine-mcp-search.md]
10. modelcontextprotocol. "servers - src/filesystem." GitHub, 2026, github.com/modelcontextprotocol/servers/tree/main/src/filesystem. Accessed 13 Aug. 2026. [archived: sources/filesystem-mcp.md]
11. Taskwarrior. "Taskwarrior Documentation." Taskwarrior, 2026, taskwarrior.org/docs/. Accessed 13 Aug. 2026. [archived: sources/taskwarrior-docs.md]
12. GitHub. "Repositories search: gitea mcp." GitHub, 2026, github.com/search?q=gitea+mcp&type=repositories. Accessed 13 Aug. 2026. [archived: sources/gitea-mcp-search.md]
13. GitHub. "Repositories search: forgejo mcp." GitHub, 2026, github.com/search?q=forgejo+mcp&type=repositories. Accessed 13 Aug. 2026. [archived: sources/forgejo-mcp-search.md]

Project-internal references (not external sources): `.opencode/plugins/delegation-observer.ts` (gate mechanics, section 1), knowledge/res018-ticket-management-automation/ (DIA-125 first-pass conspect, ledger conventions), knowledge/ana006-issue-tracker-comparison/ (local-first architecture decision), knowledge/res008-source-archival-fallbacks/ (DIA-072 tiered archival strategy).

## 8. Claim-to-source mapping (key claims)

| Claim | Source |
|---|---|
| scanTickets scans docs/dev-infra-audit/tickets/, filename regex /^DIA-(\d+)/, THROWS on missing dir | delegation-observer.ts lines 425-447, 426-428 |
| /DIA-\d+/gi dispatch regex is case-insensitive and format-agnostic | delegation-observer.ts line 921 |
| Strict tri-state correlation (explicit DIA-id must match open ticket, no fall-through) | delegation-observer.ts lines 449-474 (DIA-076 C1 comment) |
| Ticket-creation and checksum-verification exemptions | delegation-observer.ts lines 901-907 |
| Fail-soft: scan error -> warn + allow + ticket_gate_scan_failed | delegation-observer.ts lines 912-915 |
| Plane self-host: Docker Compose/K8s, data sovereignty, open formats, no vendor lock-in | sources/plane-selfhost.md |
| Plane MCP: MIT, 100+ tools / 20 categories, stdio uvx + remote HTTP, PLANE_BASE_URL configurable, Node version deprecated | sources/plane-mcp-server.md |
| OpenProject CE MCP: 14 stars, 132 tools (106 without admin writes), guarded writes, allowlists, context-frugal, CE-only | sources/openproject-ce-mcp.md, sources/openproject-mcp-search.md |
| Redmine MCP ecosystem: 164 results, mcp-redmine 232 stars top | sources/redmine-mcp-search.md |
| Vikunja MCP ecosystem: 73 results, democratize-technology 100 stars, 0xK3vin 13 stars | sources/vikunja-mcp-search.md |
| Gitea/Forgejo MCP ecosystem: 58 / 46 results, 103-tool server, Codeberg mirror, Claude integration | sources/gitea-mcp-search.md, sources/forgejo-mcp-search.md |
| GitHub MCP: MIT, remote server api.githubcopilot.com/mcp, local Docker/Go binary, GHES no remote hosting | sources/github-mcp-server.md |
| git-bug: GPLv3+, git-object storage (not files), offline-first, CLI/TUI/web, GitHub/GitLab bridges, no MCP | sources/git-bug.md |
| Filesystem MCP: MIT, npm package, Roots access control, read/write/edit with dryRun, requires >=1 allowed dir | sources/filesystem-mcp.md |
| taskwarrior: CLI doc set, .taskrc, JSON import/export, UDAs, hooks API, sync | sources/taskwarrior-docs.md |
