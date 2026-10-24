# DIA-125 Ticket Management Automation - Conspect (res018)

<!-- CONSPECTER-OUTPUT-CONTRACT
schema-version: 1.0
agent: conspecter
phase-a-source-count: 22
phase-a-failures: 0
shelf-registration: .opencode/memory-shelf.yaml (shelf.conspects)
-->

Conspect for DIA-125 (OPEN research ticket): "automate ticket creation & management - evaluate ready-made local solutions (MCP/self-hosted) vs manual ledger". This conspect archives the decision-support findings of the DIA-125 researcher (session ses_007bdf422ffeEmJ8f8gVFKK9n0; PERSISTENCE_RECOMMENDED: true, 15+ external sources) and grounds every claim in the 22 locally archived source files under `sources/` (Phase A output, archived 2026-08-13).

## 1. Decision context and constraint frame

The project maintains a manual git-backed ticket ledger at `docs/dev-infra-audit/tickets/` with the following binding conventions (project-internal, from project AGENTS.md and ledger structure; not external-source claims):

- **DIA-NNN + human-slug scheme**: tickets are named `DIA-NNN-<descriptor>.md`; user-facing references MUST quote the ID plus the human-readable slug (e.g. "DIA-100 'git worktrees for parallel dev sessions'"), never a bare ID (project AGENTS.md 2.3; DIA-125 itself is an OPEN ticket in this ledger).
- **YAML frontmatter v2 session-attribution block**: ticket templates carry a session-attribution block; the false-delegation audit (ana005) flagged the connectivity gaps (no session_id/lane_id/files_touched/research_artifacts) that the frontmatter v2 block addresses (memory-shelf ana005 entry).
- **README index + counts**: `docs/dev-infra-audit/tickets/` ships a README index with ticket counts and status summaries (project AGENTS.md 2.3 ticket ledger).
- **archive/ policy**: completed/superseded changes and tickets move to an archive area with context preserved (project convention; OpenSpec archive semantics in openspec-core-concepts.md).
- **make test-config ticket gate (DIA-063)**: "no engineering work starts without a DIA ticket" is a pre-work gate; `make test-config` runs on the host and validates config/lockstep contracts (project AGENTS.md 6, 2.5; DIA-063).

Any automation adopted for ticket creation/management must preserve these constraints: file-based tickets, human-slug references, structured frontmatter, README index maintenance, and archive hygiene - while remaining local-first (zero network dependency, zero auth surface; see ana006 architecture decision "GitHub Issues vs Local DIA Ledger").

## 2. Candidate table (DIA-125 evaluation universe)

Grounded only in archived sources. Cells marked "not stated in archive" mean the archived source does not state the value; cells marked "not archived" mean no source was archived for that candidate, so NO claims are made about it (DIA-072).

| Candidate | Category | License (archived) | Storage | MCP/API (archived) | Offline | Recency (archived evidence) | Fit for DIA-125 |
|---|---|---|---|---|---|---|---|
| github-mcp-server | MCP server (GitHub platform bridge) | not stated in archive | GitHub cloud (remote server) + local Docker/Go binary | MCP: remote `https://api.githubcopilot.com/mcp/` + local stdio/Docker; issues/PRs/discussions/gists toolsets | no (needs GitHub API) | active (current docs, toolsets incl. recent copilot_issue_intents) | write-capable but cloud-backed; violates local-first for ticket storage; heavy token cost (opencode-mcp-servers-docs caveat) |
| Linear official MCP | MCP server (Linear cloud bridge) | proprietary (not stated in archive) | Linear cloud (server "centrally hosted and managed") | MCP: remote Streamable HTTP `https://mcp.linear.app/mcp`; `/readonly` endpoint; OAuth 2.1 / API key | no | active | write-capable (issues, projects, comments) but cloud-only; violates local-first |
| plane-mcp-server | MCP server (Plane bridge) | MIT | Plane API (self-hostable backend) | MCP: stdio (uvx, local), SSE (legacy), streamable HTTP remote `mcp.plane.so`; 100+ tools / 20 categories, full CRUD | no (needs Plane API reachable; self-hosted keeps data local) | active (Python+FastMCP rewrite; Node version deprecated) | strongest self-hosted write-capable MCP pair; Tier 3 |
| Plane | Self-hosted project management platform | AGPL-3.0 | own servers (Docker/K8s); "full ownership of your data" | REST API (developers.plane.so) + MCP server (above) | no | active | Tier 3 self-host platform candidate |
| Vikunja | Self-hosted task manager | AGPL-3.0-or-later | own server ("The task manager you actually own") | REST API (OpenAPI v2) + 2 community MCP servers: 0xK3vin (32 tools, MIT), shichao402 (180 tools incl. 161 raw Swagger ops) | no | active (v2.5.0 install badge; roadmap hosted on Vikunja) | Tier 3 self-host platform candidate; mature MCP ecosystem |
| Focalboard | Self-hosted boards/project management | not stated in archive | self-hosted Personal Server/Desktop (SQLite) | Boards API docs (swagger) exist; no MCP in archive | desktop edition yes (standalone) | NOT MAINTAINED (explicit repo warning, issue #5038) | REJECTED - unmaintained |
| OpenProject | Self-hosted project management platform (enterprise) | GPL-3.0 | self-hosted; "full control over their data and infrastructure" | REST/integrations (Nextcloud, GitHub, GitLab); NO MCP server in archived source | no | active | REJECTED for this scope - heavy enterprise platform, no MCP documented |
| Redmine | Self-hosted project management web app (Ruby on Rails) | not stated in archive (LICENSE.txt present) | self-hosted | none documented in archive (REST API not mentioned in archived README) | no | active (19,622 commits) | legacy heavyweight; no MCP in archive; poor fit |
| Taiga | (self-hosted agile platform) | not archived | not archived | not archived | not archived | not archived | no archived source - EXCLUDED per DIA-072 (see section 6) |
| Leantime | Self-hosted project management | AGPLv3 | self-hosted (PHP 8.2+, MySQL/MariaDB, Docker) | json-rpc API (docs.leantime.io/api/usage); no MCP in archive | no | active | mid-weight alternative; no MCP; secondary Tier 3 candidate only |
| git-bug | Git-native distributed issue tracker (CLI/TUI/web) | GPLv3+ | git objects in repo ("not files") | CLI, TUI, web; bridges to GitHub/GitLab; no MCP in archive | YES (distributed, offline-first) | active (trunk docs) | philosophically closest to git ledger; CLI-based, not MCP-native; no YAML-frontmatter files |
| steviee/git-issues | Git-native file-backed issue tracker | MIT | Markdown files + YAML frontmatter in `.issues/` ("No database. No server. No accounts. Just files and git.") | CLI with `--format json` for agents; Claude Code skill (Iron Workflow); no server/MCP | YES (pure files + git) | recent/active (2026-03-04 example issue dates; active dev) | STRUCTURAL TWIN of the project ledger (markdown + YAML frontmatter, relations, worktree rules); Tier 2 experiment |
| timonburkard/git-issue | Git-native file-backed issue tracker | MIT | `.gitissues/` files: meta.yaml + description.md per issue | CLI (`git issue ...`), read-only web server (localhost:7878); auto-commit; no MCP | YES | recent/active (2026-02 due-date examples) | strong alternative to steviee/git-issues (YAML metadata, relationships, auto-commit); Tier 2 alternative |
| dspinellis/git-issue | (POSIX-shell git issue tracker) | not archived | not archived | not archived | not archived | not archived | no archived source - EXCLUDED per DIA-072 (see section 6) |
| OpenSpec tasks.md | Spec-driven change artifact (proposal/specs/design/tasks.md under openspec/changes/<name>/) | n/a (process) | markdown files in repo; archive to changes/archive/ on completion | openspec CLI + OPSX slash commands (/opsx:propose, /opsx:apply, /opsx:archive...) | YES | active (OPSX now the standard workflow) | this IS the project's spec/task workflow; the DIA ledger is the ticket layer that seeds tasks.md per change; keep as-is |
| opencode-ework | (researcher-referenced concept; no URL supplied) | not archived | not archived | not archived | not archived | not archived | no archived source - EXCLUDED per DIA-072 (see section 6) |

Supplementary archived candidates (not in the evaluation table but relevant to the recommendation):

| Candidate | Status (archived evidence) |
|---|---|
| gyfis/linear-local-mcp | read-only local-cache MCP (macOS-only, reads Linear.app IndexedDB; 9 read tools; MIT). Local-first but Linear-bound and read-only; informative precedent for local caching, not a ticket ledger |
| ch-raph/linear-cache-mcp | cache-first MCP for Linear (13 tools; local JSON cache; write-through safety; MIT). Local cache but still Linear API for writes |
| jackblanc/opencode-linear-agent | SUPERSEDED by opencode-event-bridge (repo banner) - not a viable integration path |

## 3. MCP-server maturity assessment

**Write-capable MCP servers (can create/update/close tickets):**
- github-mcp-server: `issue_write` (create/update with assignees/labels/milestone/state/type), `add_issue_comment`, PR tools, discussion writes, gist writes; toolsets configurable, `--read-only` mode available (sources/github-mcp-server.md).
- Linear official MCP: "tools available for finding, creating, and updating objects in Linear like issues, projects, and comments"; read-write endpoint `/mcp` vs read-only `/mcp/readonly` (sources/linear-mcp-docs.md).
- plane-mcp-server: 100+ tools across 20 categories with full CRUD on work items, cycles, modules, initiatives, milestones, labels, states, comments, relations, work logs (sources/makeplane-plane-mcp-server.md).
- Vikunja MCP servers: 0xK3vin 32 tools (full CRUD projects/tasks/kanban/labels/comments/relations; 86 tests, 90%+ coverage) (sources/0xk3vin-vikunja-mcp.md); shichao402 180 tools (19 ergonomic + 161 raw Swagger operations) (sources/shichao402-vikunja-mcp.md).

**Local-first MCP servers (process runs locally; data location varies):**
- plane-mcp-server stdio transport runs via uvx as a local process talking to a Plane API you can self-host (sources/makeplane-plane-mcp-server.md).
- Vikunja MCP servers run via npx against a self-hostable Vikunja instance (sources/0xk3vin-vikunja-mcp.md, sources/shichao402-vikunja-mcp.md).
- gyfis/linear-local-mcp: fully local reads from the macOS Linear cache, "Works offline: Yes" - but read-only and macOS-only (sources/gyfis-linear-local-mcp.md).
- ch-raph/linear-cache-mcp: local JSON cache serves reads at zero API cost, but writes still hit the Linear API (write-through) (sources/ch-raph-linear-cache-mcp.md).

**Assessment: no archived MCP server is file/git-backed.** Every MCP server in the universe writes to an external system of record (GitHub, Linear, Plane, Vikunja) over a network API. None writes Markdown + YAML-frontmatter ticket files into the repo. That is precisely the gap the hybrid recommendation fills with a thin local writer (Tier 1). The git-native trackers (git-bug, steviee/git-issues, timonburkard/git-issue) are CLIs, not MCP servers - which is fine, because OpenCode can shell out to a CLI, and steviee/git-issues ships `--format json` agent commands plus a Claude Code skill pattern that ports to OpenCode (sources/steviee-git-issues.md).

## 4. Hybrid recommendation (researcher decision-support findings)

Keep the git-backed markdown ledger and automate around it, in three tiers:

- **Tier 1 - codify the manual writer (do now):** the ledger already has the schema (DIA-NNN + human-slug filename, YAML frontmatter v2 with session attribution, README index + counts, archive/). Codify a thin local CLI/script that creates and updates tickets with the exact schema - replacing the manual file authoring while keeping the ledger as the system of record. Zero new runtime dependencies; it is the "thin local CLI/MCP writer" the ecosystem lacks (section 3 assessment). OpenSpec's own model is the precedent: artifacts are markdown files with a schema, driven by a CLI (openspec core-concepts: proposal/specs/design/tasks.md with dependency graph; OPSX: actions not phases, `tasks.md` checkbox progress) (sources/openspec-core-concepts.md, sources/openspec-opsx.md).
- **Tier 2 - steviee/git-issues experiment:** steviee/git-issues is the structural twin of the project ledger: issues are Markdown files with YAML frontmatter in `.issues/`, zero DB/server/accounts, `--format json` agent commands (`issues next`, `issues claim`, `issues done`, `issues check --fix`), relations, and explicit git-worktree rules ("New issues: only on main") (sources/steviee-git-issues.md). Run a bounded experiment in a scratch repo to compare its ergonomics against the codified Tier 1 writer before adopting. timonburkard/git-issue (`.gitissues/`, meta.yaml, relationships, auto-commit, read-only web view) is the fallback alternative if the experiment favors a more configurable metadata model (sources/timonburkard-git-issue.md).
- **Tier 3 - self-hosted platform (only if scale outgrows files):** Plane (AGPL-3.0, Docker/K8s self-host, full data ownership, 100+ tool MCP server, MIT) (sources/makeplane-plane.md, sources/plane-developers-docs.md, sources/makeplane-plane-mcp-server.md) or Vikunja (AGPL-3.0-or-later, "The task manager you actually own", two mature MCP servers) (sources/go-vikunja-vikunja.md, sources/0xk3vin-vikunja-mcp.md, sources/shichao402-vikunja-mcp.md). Only adopt when multi-user collaboration, web UI, or analytics needs exceed what a file ledger can provide.

## 5. Clear rejections

- **Focalboard - unmaintained:** the repository banner states "This repository is currently not maintained" with a maintainer call-to-action (issue #5038) (sources/mattermost-focalboard.md). Unmaintained = security/stability risk; rejected.
- **OpenProject - heavy, no MCP:** enterprise-grade platform (GPL-3.0) with portfolio/agile/time-tracking feature breadth and integrations (Nextcloud, GitHub, GitLab), but the archived source documents no MCP server (sources/opf-openproject.md). Operational overhead disproportionate to a file-ledger replacement; rejected for this scope. (Taiga was also flagged in the researcher brief as stale, but no Taiga source was archived - that claim is EXCLUDED per DIA-072, see section 6.)
- **Cloud-only GitHub/Linear violate local-first:** the GitHub MCP server's recommended deployment is the remotely hosted server (`https://api.githubcopilot.com/mcp/`); the local server still talks to the GitHub API (sources/github-mcp-server.md). Linear's MCP server is "centrally hosted and managed" by Linear (sources/linear-mcp-docs.md). Both require network access and an external auth surface - contradicting the project's local-first architecture decision (zero network dependency, zero auth surface, per ana006). They also add heavy context/token cost in OpenCode ("Certain MCP servers, like the GitHub MCP server, tend to add a lot of tokens and can easily exceed the context limit") (sources/opencode-mcp-servers-docs.md). Rejected as the ticket system of record; at most a read-only export path (per ana006 ruling).
- **jackblanc/opencode-linear-agent - superseded:** the repo banner declares it superseded by opencode-event-bridge (sources/jackblanc-opencode-linear-agent.md); not a viable integration path.

## 6. Unarchived Sources (DIA-072)

The following candidates were named in the DIA-125 research brief but NO source URL was provided for them, so they were not archived in Phase A. Claims about them (including the "Taiga stale" rejection rationale) are EXCLUDED from this conspect body per DIA-072 Archive-Before-Claim policy:

- Taiga (agile project management platform) - [source not archived - excluded per DIA-072 policy]
- dspinellis/git-issue (POSIX-shell git issue tracker) - [source not archived - excluded per DIA-072 policy]
- opencode-ework (researcher-referenced concept; no URL supplied) - [source not archived - excluded per DIA-072 policy]

## 7. Sources consulted (MLA; all archived locally in sources/)

1. GitHub. "GitHub MCP Server." GitHub, 2026, github.com/github/github-mcp-server. Accessed 13 Aug. 2026. [archived: sources/github-mcp-server.md]
2. GitHub Docs. "Set up the GitHub MCP server." GitHub Docs, 2026, docs.github.com/en/copilot/how-tos/provide-context/use-mcp-in-your-ide/set-up-the-github-mcp-server. Accessed 13 Aug. 2026. [archived: sources/github-mcp-setup-docs.md]
3. Linear. "MCP server." Linear Docs, 2026, linear.app/docs/mcp. Accessed 13 Aug. 2026. [archived: sources/linear-mcp-docs.md]
4. gyfis. "linear-local-mcp." GitHub, 2026, github.com/gyfis/linear-local-mcp. Accessed 13 Aug. 2026. [archived: sources/gyfis-linear-local-mcp.md]
5. ch-raph. "linear-cache-mcp." GitHub, 2026, github.com/ch-raph/linear-cache-mcp. Accessed 13 Aug. 2026. [archived: sources/ch-raph-linear-cache-mcp.md]
6. makeplane. "Plane." GitHub, 2026, github.com/makeplane/plane. Accessed 13 Aug. 2026. [archived: sources/makeplane-plane.md]
7. makeplane. "plane-mcp-server." GitHub, 2026, github.com/makeplane/plane-mcp-server. Accessed 13 Aug. 2026. [archived: sources/makeplane-plane-mcp-server.md]
8. Plane. "Developer docs / Self-hosting overview." developers.plane.so, 2026, developers.plane.so. Accessed 13 Aug. 2026. [archived: sources/plane-developers-docs.md]
9. go-vikunja. "Vikunja." GitHub, 2026, github.com/go-vikunja/vikunja. Accessed 13 Aug. 2026. [archived: sources/go-vikunja-vikunja.md]
10. 0xK3vin. "vikunja-mcp." GitHub, 2026, github.com/0xK3vin/vikunja-mcp. Accessed 13 Aug. 2026. [archived: sources/0xk3vin-vikunja-mcp.md]
11. shichao402. "vikunja-mcp." GitHub, 2026, github.com/shichao402/vikunja-mcp. Accessed 13 Aug. 2026. [archived: sources/shichao402-vikunja-mcp.md]
12. mattermost-community. "Focalboard." GitHub, 2026, github.com/mattermost-community/focalboard. Accessed 13 Aug. 2026. [archived: sources/mattermost-focalboard.md]
13. OpenProject. "OpenProject." GitHub, 2026, github.com/opf/openproject. Accessed 13 Aug. 2026. [archived: sources/opf-openproject.md]
14. Redmine. "Redmine." GitHub, 2026, github.com/redmine/redmine. Accessed 13 Aug. 2026. [archived: sources/redmine-redmine.md]
15. Leantime. "Leantime." GitHub, 2026, github.com/Leantime/leantime. Accessed 13 Aug. 2026. [archived: sources/leantime-leantime.md]
16. git-bug. "git-bug." GitHub, 2026, github.com/git-bug/git-bug. Accessed 13 Aug. 2026. [archived: sources/git-bug-git-bug.md]
17. steviee. "git-issues." GitHub, 2026, github.com/steviee/git-issues. Accessed 13 Aug. 2026. [archived: sources/steviee-git-issues.md]
18. timonburkard. "git-issue." GitHub, 2026, github.com/timonburkard/git-issue. Accessed 13 Aug. 2026. [archived: sources/timonburkard-git-issue.md]
19. OpenCode. "MCP servers." OpenCode Docs, 2026, opencode.ai/docs/mcp-servers/. Accessed 13 Aug. 2026. [archived: sources/opencode-mcp-servers-docs.md]
20. jackblanc. "opencode-linear-agent." GitHub, 2026, github.com/jackblanc/opencode-linear-agent. Accessed 13 Aug. 2026. [archived: sources/jackblanc-opencode-linear-agent.md]
21. OpenSpec. "Core Concepts." OpenSpec Docs, 2026, openspec.dev/docs/core-concepts. Accessed 13 Aug. 2026. [archived: sources/openspec-core-concepts.md]
22. OpenSpec. "OPSX." OpenSpec Docs, 2026, openspec.dev/docs/opsx. Accessed 13 Aug. 2026. [archived: sources/openspec-opsx.md]

## 8. Claim-to-source mapping (key claims)

- "GitHub MCP server is write-capable (issue_write create/update, comments, PRs) and ships a remote cloud endpoint plus a local Docker/Go server" -> sources/github-mcp-server.md
- "GitHub MCP server token cost caveat in OpenCode" -> sources/opencode-mcp-servers-docs.md
- "Linear MCP server is centrally hosted; read-write at /mcp, read-only at /mcp/readonly; OAuth 2.1; API-key bearer option" -> sources/linear-mcp-docs.md
- "plane-mcp-server: MIT, stdio/SSE/HTTP transports, 100+ tools, Python+FastMCP rewrite, Node version deprecated" -> sources/makeplane-plane-mcp-server.md
- "Plane: AGPL-3.0, Docker/K8s self-host, data sovereignty positioning" -> sources/makeplane-plane.md, sources/plane-developers-docs.md
- "Vikunja: AGPL-3.0-or-later, 'task manager you actually own'; two MCP servers (32-tool MIT; 180-tool with 161 raw Swagger ops)" -> sources/go-vikunja-vikunja.md, sources/0xk3vin-vikunja-mcp.md, sources/shichao402-vikunja-mcp.md
- "Focalboard: explicitly unmaintained" -> sources/mattermost-focalboard.md
- "OpenProject: GPL-3.0, enterprise feature breadth, no MCP documented" -> sources/opf-openproject.md
- "Leantime: AGPLv3, PHP/MySQL, json-rpc API, no MCP documented" -> sources/leantime-leantime.md
- "git-bug: GPLv3+, distributed offline-first, issues as git objects, CLI/TUI/web, GitHub/GitLab bridges" -> sources/git-bug-git-bug.md
- "steviee/git-issues: MIT, Markdown + YAML frontmatter in .issues/, zero DB/server/accounts, JSON agent commands, worktree rules, Claude Code skill" -> sources/steviee-git-issues.md
- "timonburkard/git-issue: MIT, .gitissues/ meta.yaml + description.md, relationships, auto-commit, read-only web view" -> sources/timonburkard-git-issue.md
- "gyfis/linear-local-mcp: read-only, macOS-only, offline-capable local cache reads" -> sources/gyfis-linear-local-mcp.md
- "ch-raph/linear-cache-mcp: cache-first, local JSON cache, write-through safety, 13 tools" -> sources/ch-raph-linear-cache-mcp.md
- "jackblanc/opencode-linear-agent: superseded by opencode-event-bridge" -> sources/jackblanc-opencode-linear-agent.md
- "OpenSpec: specs as source of truth, changes as folders, delta specs ADDED/MODIFIED/REMOVED, tasks.md checklist, archive with date prefix" -> sources/openspec-core-concepts.md
- "OPSX: actions not phases, schema-driven customization, /opsx commands, update-vs-new heuristics" -> sources/openspec-opsx.md
