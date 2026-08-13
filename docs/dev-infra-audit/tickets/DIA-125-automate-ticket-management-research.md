# DIA-125 - automate ticket creation & management - evaluate ready-made local solutions (MCP/self-hosted) vs manual ledger

<!-- Feature request filed 2026-08-13 from developer session observation.
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
status: OPEN
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

## Fix

> To be filled at fix time. Planning/research ticket - no implementation performed yet.

## Re-verify

> To be filled at re-verify time.
