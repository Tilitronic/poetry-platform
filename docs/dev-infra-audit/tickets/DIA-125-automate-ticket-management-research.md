# DIA-125 - automate ticket creation & management - evaluate ready-made local solutions (MCP/self-hosted) vs manual ledger

<!-- UPDATE 2026-08-13 (IMPLEMENTED + REVIEWED + RE-VERIFIED - TICKET CLOSED): keep-local ticket automation + remote coordination convention IMPLEMENTED per developer approval. Deliverables: (1) scripts/tickets CLI - `new "<title>" [--area --severity --blocked-by --parent-epic --source]` (allocates next free DIA-NNN from filename+README scan, generates DIA-NNN-<slug>.md from _TEMPLATE.md conventions, inserts README row in sort position, recomputes counts, ASCII guard DIA-079, collision guard, NO auto-claim, parent_epic always emitted); `rollup [--check]` (recompute README severity/status counts from FILE frontmatter as source of truth; --check exits 1 when stale, never writes); `frontier` (unblocked OPEN tickets sorted severity-then-DIA + blocker graph + live-lease notes); `help`; (2) scripts/__tests__/tickets.bats 19 tests (temp fixtures, real ledger never touched); (3) docs/dev-infra-audit/tickets/COORDINATION.md - multi-device protocol: shared git remote, claim convention (session_id + lease_expires_at in frontmatter = single-writer token), fetch-before-take discipline, ASCII-only; (4) _TEMPLATE.md gained parent_epic field; (5) README status table gained DISPATCHED/RUNNING/COMPLETE rows (format). Validation: make test-shell exit 0 (251 tests), bats 19/19, bash -n clean, real frontier exit 0 (20 startable / 3 blocked), rollup --check delta found and applied at closure (see Re-verify). Review: rev-1 11 findings, developer ACCEPT ALL, all fixed, re-review cycle 1/2 all 11 verified-closed, 0 regressions. Design authority: res-1/res021 landscape (gate mechanics: scanTickets reads local .md, /DIA-\d+/gi format-agnostic) + res-2 verdict (keep-local .md ledger + shared git remote + claim convention; GitHub epics viable only as human-facing mirror; Forgejo git-synced binary DB not-viable). Developer decided 2026-08-13: persistence SKIPPED for res-2 (findings in ticket only, no conspect). Ticket CLOSED per Re-verify convention; commit deferred to end-of-session.

     UPDATE 2026-08-13 (IDEA A/B RESEARCH COMPLETE - res-2, ses_003da83e8ffekP32ZJm2To7tVc, 10+ sources): IDEA A (GitHub epics + local vertical tickets) VIABLE-WITH-MODIFICATIONS: the /DIA-\d+/gi gate regex (delegation-observer.ts L921) does NOT match "GH-42"/"epic #42" - a GitHub-only citation soft-passes (ticket_gate_weak_correlation warn+allow, L933-947), never hard-blocks; the hard block fires only when a cited DIA-id resolves to a local ticket that is absent or CLOSED. Cleanest model: local `parent_epic: DIA-NNN` frontmatter on vertical tickets as single source of truth (gate reads local .md), GitHub issue carries only an `epic:<DIA-NNN>` label + child tasklist as the remote human-facing mirror. GitHub Free has NO structured custom fields - the ledger's session_id/evidence/attempts/lease_expires_at/files_touched/artifacts have no native home (degrade to body prose). Two-tier adds cognitive overhead vs a flat list with a parent_epic field for a ~133-ticket single-team ledger. IDEA B (local Forgejo + git-synced DB) NOT-VIABLE AS PROPOSED: Forgejo DB is SQLite BINARY (DB_TYPE=sqlite3, PATH=data/forgejo.db), not text - git cannot merge two divergent binary DB files (unresolvable binary conflict / lost updates / corruption; WAL adds -wal/-shm sidecars). The valid kernel (git-fetch-before-take claim protocol) works ONLY on text - which is exactly the existing .md ledger (git-bug proves text/object-based trackers with CRDT + Lamport clocks are the git-native pattern). Idea B collapses into Idea A on the remote axis: a teammate still needs a shared git remote (same GitHub), plus gets the binary-merge problem. RECOMMENDED ARCHITECTURE: (iv) keep-local text .md ledger + shared git remote (free private GitHub repo used PURELY as a git remote, or bare repo on tiny VPS) + per-ticket claim convention (lease_expires_at/session_id in frontmatter as single-writer token) + fetch-before-take discipline; optional GitHub epic mirror for human browsing. Gate unchanged, ASCII-safe, text merges cleanly. Developer decision 2026-08-13: persistence SKIPPED for res-2 (findings recorded in this ticket only; no conspect).

     UPDATE 2026-08-13 (RESEARCH DIRECTION SUPERSEDED - TWO NEW DEVELOPER IDEAS): after res-1 research + res021 conspect (keep-local preliminary), the developer engaged in a strategic design conversation. Real requirement clarified: (1) teammates on OTHER devices must access tickets from anywhere; (2) parallel opencode sessions must coordinate ticket-taking without clobbering each other; (3) free is strongly preferred. The developer proposed TWO NEW research directions that supersede the simple keep-vs-adopt framing:

     IDEA A - TWO-TIER SPLIT (GitHub Issues for epics + local bash scripts for vertical tickets): use GitHub Issues (free private repos) as the home for HIGHER-RANK tickets (epics): bugs, features, cross-cutting items. Keep LOCAL vertical tickets (per-epic implementation slices, the DIA ledger) generated via bash scripts (number allocator, template generator, README rollup, blocker/frontier view). Research questions: (a) does the delegation-observer gate keep working if only epics live on GitHub (the /DIA-\d+/gi regex + scanTickets only see local files - what happens to the gate when a dispatch cites a GitHub-hosted epic ID vs a local DIA-NNN?); (b) how to map epic <-> vertical-ticket edges across the boundary; (c) what GitHub-native fields map to the ledger's frontmatter (session_id, evidence, attempts, lease_expires_at); (d) is the two-tier model actually simpler than one flat list, or does it add cognitive overhead.

     IDEA B - LOCAL FORGEJO WITH GIT-SYNCED DATABASE: run Forgejo locally (single Go binary) but PUSH ITS DATABASE TO GIT; every ticket-taking procedure does a `git fetch` first to detect whether a teammate already took the ticket. Developer hypothesis: "you can reliably sync a database through git if it is just a text file". Research questions: (a) what IS the Forgejo database format (SQLite binary vs text) and is git-sync of it actually feasible/reliable (binary diff bloat, lock contention, concurrent-write corruption risk, WAL mode); (b) is there an existing tool/pattern for git-synced issue trackers (e.g. git-bug stores issues as git OBJECTS - text-based by construction - how does its conflict handling compare); (c) does the git-fetch-before-take protocol close the parallel-session clobbering hole, and what are its failure modes (fetch-then-take race); (d) WSL2 dev-container restart coupling of a local Forgejo vs the existing needs-input-observer/delegation-observer plugins.

     Both ideas are RESEARCH-SPACE per the developer ("I see research space here"). The DIA-125 Verification checklist is updated below to fold in these two directions. Status stays OPEN. Prior res-1 research remains valid context (gate mechanics: scanTickets reads docs/dev-infra-audit/tickets/ dir, /DIA-\d+/gi regex format-agnostic, any external tracker needs a file-mirror bridge or gate rework).

     Feature request filed 2026-08-13 from developer session observation.
     Developer verbatim: "request for improving ticket creating and management
     system, Research needed. Current approach forces agent to count tickets
     every time, track blockers manually, format and check a lot of things.
     Maybe there are ready to use solutions for local agent tickets systems or
     programs I can add as mcp or in dev container, maybe even jira or
     something like that."
     Developer disposition 2026-08-13: severity Medium; scope = research +
     proof-of-concept (stand up the top candidate to validate fit before
     deciding); keep-local automation over the existing file ledger stays in
     scope as the comparison baseline.
     Planning ticket - no implementation performed yet. -->

---

id: DIA-125
title: "automate ticket creation & management - evaluate ready-made local solutions (MCP/self-hosted) vs manual ledger"
area: opencode-config
severity: Medium
status: CLOSED
blocked_by: [] # no blockers
discovered: 2026-08-13
source: session-observation (feature request, developer, 2026-08-13)
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
lease_expires_at: ""
files_touched: []
artifacts: []
evidence: []

---

## Description

2026-08-13: renumbered DIA-124 -> DIA-125 to resolve a duplicate-ID collision with DIA-124-handoff-before-session-end.md (developer decision).

**Feature request (developer, 2026-08-13):** the current DIA ticket workflow
(file ledger at docs/dev-infra-audit/tickets/ + to-tickets skill +
delegation-observer ticket gate) forces the agent to do manual bookkeeping at
every creation and reference:

1. **Counting tickets every time** - the agent must list the tickets
   directory and compute the next DIA-NNN number by hand before every
   creation; there is no automated number allocator.
2. **Tracking blockers manually** - `blocked_by` edges are maintained by
   hand in frontmatter; there is no graph or frontier view, so reasoning
   about what can start next (to-tickets "work the frontier" step) is
   prose, not tooling.
3. **Format and check overhead** - creating a ticket requires matching the
   \_TEMPLATE.md frontmatter schema, an ASCII-only body (DIA-079), a slugged
   filename (DIA-110), a README.md index row, and hand-recomputed
   status/severity rollup counts; the delegation-observer ticket gate then
   re-checks correlation (DIA-063/112 history).

**Research direction requested by the developer:** before building more
in-house tooling, evaluate READY-MADE solutions - local agent ticket systems
and issue trackers that can run locally (host or dev container) and be
exposed to the agent as an MCP server or a dev-container program. Candidate
families to investigate (non-exhaustive):

- **Self-hosted web trackers:** Jira (Data Center / Server), Linear, Plane,
  Vikunja, OpenProject, Redmine, Gitea/Forgejo issues, GitLab issues.
- **Local-first CLIs:** `gh` against a private repo, git-bug, taskwarrior,
  org-mode agenda.
- **MCP servers:** GitHub/Linear/Jira/Plane/OpenProject MCP servers, or an
  MCP wrapping the existing file ledger.
- **Keep-local baseline:** scripted automation over the current file ledger -
  number allocator, template generator, README index/rollup updater, and a
  blocker-graph/frontier renderer. Included per developer disposition as the
  lowest-risk baseline to compare everything else against.

**Constraints to respect in the recommendation:**

- DIA-079 ASCII-only protocol: agent payloads and ticket bodies must stay
  ASCII-safe (no em-dashes, no smart quotes) - a remote tracker's API layer
  must not reintroduce non-ASCII friction.
- The ticket gate lives in `.opencode/plugins/delegation-observer.ts` and
  regex-matches the DIA-NNN citation format; any migration must keep the
  gate working or explicitly rework it (DIA-063/112).
- Local-first: environment is WSL2 + Docker dev container; the tracker must
  run locally (host or container) with no mandatory SaaS dependency.
- Section-10 AI-Devtools Modernization Workflow applies if the chosen
  solution lands as .opencode/ tooling (MCP registration or plugin) - gate
  research via @ai-specialist, developer review, design, coder, ai-auditor,
  validate, register.
- Scope per developer disposition: research + proof-of-concept. The PoC
  stands up the top candidate (e.g. one MCP server in the dev container) and
  validates an end-to-end ticket create/read/update round-trip from an agent
  session before any adoption decision.

**Outcome:** a written recommendation (research report per the
research-pipeline, registered in the memory shelf) comparing candidates on
fit, effort, and risk for THIS project, with an explicit keep-vs-adopt
recommendation and, if adopting, a migration plan that preserves ticket-gate
and ledger continuity.

## Verification

Research + PoC ticket - acceptance is a written deliverable plus a working
validation, not production code:

- [ ] Research report comparing >= 4 candidate solutions (>= 1 self-hosted
      tracker, >= 1 MCP server, >= 1 local-first CLI, plus the keep-local
      automation baseline) on fit/effort/risk against this project's
      constraints (ASCII-only DIA-079, local-first WSL2/dev-container,
      delegation-observer ticket-gate compat).
- [ ] PoC of the top candidate stood up and validated: a ticket
      create/read/update round-trip from an agent session succeeds; blocker
      or frontier query returns correct results; ASCII-safety holds; ticket
      gate interaction is characterized (no false correlation with DIA-NNN
      citations).
- [ ] Explicit keep-vs-adopt recommendation with rationale and, if adopt, a
      migration plan (existing DIA-001..123 tickets data migration, ticket
      gate rework in delegation-observer.ts, README ledger retirement or
      bridge, section-10 routing for MCP/plugin registration).
- [ ] If keep-local: concrete automation spec (number allocator, template
      generator, README rollup updater, blocker-graph/frontier view) with a
      test strategy (bats for shell, per existing conventions).
- [ ] Decision recorded in this ticket's Fix section and in learnings
      (memory-manager).
- [ ] Idea A feasibility: GitHub-epics + local-vertical split - gate interaction characterized (epic citations vs /DIA-\d+/gi), epic<->vertical mapping design, frontmatter field mapping, simplicity verdict vs flat list.
- [ ] Idea B feasibility: Forgejo DB format identified (SQLite/text), git-sync reliability assessed (binary bloat, WAL, concurrent-write corruption), git-fetch-before-take protocol failure modes enumerated, existing git-native trackers compared (git-bug et al).
- [x] Idea B feasibility: Forgejo DB identified as SQLite binary (not text); git-sync of binary DB assessed NOT-VIABLE (unresolvable binary merge, WAL sidecars, lost updates); git-fetch-before-take protocol valid only on text; git-bug CRDT compared. (res-2, 2026-08-13)

## Fix

> FIX COMPLETE 2026-08-13 - keep-local ticket automation + remote coordination convention delivered (was planning/research ticket).
>
> Update 2026-08-13: res-1 research complete + persisted as conspect res021
> (13/13 sources, keep-local preliminary); research direction superseded
> 2026-08-13 by developer Ideas A/B (see top UPDATE); fix/recommendation
> pending the Idea A/B research lane.
> Update 2026-08-13: res-2 Ideas A/B research complete (verdicts: Idea A viable-with-modifications as epic mirror, Idea B not-viable as proposed, recommended architecture = keep-local .md ledger + shared git remote + claim convention). Persistence skipped by developer (2026-08-13). Next step per developer: decide whether to implement the keep-local automation scripts + shared-remote coordination convention, or defer.
> Update 2026-08-13: IMPLEMENTED per developer approval (cod-13) - keep-local ticket automation + remote coordination convention, ~1000 lines bash-3:
>
> (1) `scripts/tickets` CLI:
>
> - `new "<title>" [--area --severity --blocked-by --parent-epic --source]` - allocates next free DIA-NNN (filename+README scan), generates DIA-NNN-<slug>.md from \_TEMPLATE.md conventions, inserts README row in DIA sort position, recomputes severity/status counts; ASCII guard (DIA-079), collision guard, NO auto-claim (lease stays empty), parent_epic always emitted.
> - `rollup [--check]` - recomputes README severity/status counts from FILE frontmatter as source of truth; --check exits 1 when stale, never writes.
> - `frontier` - unblocked OPEN tickets sorted severity-then-DIA + blocker-graph summary + live-lease notes.
> - `help` - usage.
>   (2) `scripts/__tests__/tickets.bats` - 19 tests (temp fixtures only; real ledger never touched).
>   (3) `docs/dev-infra-audit/tickets/COORDINATION.md` - multi-device protocol: shared git remote, claim convention (session_id + lease_expires_at in frontmatter = single-writer token), fetch-before-take discipline, ASCII-only.
>   (4) `_TEMPLATE.md` gained `parent_epic` field.
>   (5) README status table gained DISPATCHED/RUNNING/COMPLETE rows (format).
>
> Review history: rev-1 11 findings, developer ACCEPT ALL, all fixed by cod-13; re-review (rev-1 cycle 1/2) all 11 verified-closed, 0 regressions (see Re-verify). Validation: make test-shell exit 0 (251 tests), tickets.bats 19/19, bash -n clean, real frontier exit 0 (20 startable / 3 blocked), rollup --check delta found and applied at closure.

## Re-verify

> RE-VERIFY PASS 2026-08-13: all 11 rev-1 findings verified-closed (rev-1 cycle 1/2), 0 regressions; make test-shell exit 0 (251 tests), tickets.bats 19/19, overnight.bats 8/8; real frontier exit 0; rollup applied (write mode) at closure and README counts verified to match actual rows; README format + counts recomputed (DIA-125 row CLOSED, counts OPEN/CLOSED shifted accordingly).
