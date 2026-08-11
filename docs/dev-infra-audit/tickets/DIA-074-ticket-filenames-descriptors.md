# DIA-074 — Ticket filenames lack human-readable descriptors — orchestrator ticket references are opaque to the developer

<!-- Owner-reported docs gap (2026-08-09): ticket files are named `DIA-<NNN>.md`
     (numeric ID only); the human-readable title lives only inside each file
     (heading + frontmatter `title:`). Orchestrator session summaries and
     log_decision events reference tickets by bare ID ("DIA-072 CLOSED",
     "DIA-069 PR #54", "DIA-071 deferred"), forcing the developer to open
     ticket files or the README index to identify each one. Developer's
     verbatim complaint: "ти згадуєш тікети і я вже ніфіга не розумію що це
     за тікети" (you mention tickets and I no longer understand what those
     tickets are). PROPOSAL ticket: records the gap and fix directions (a)–(d);
     NO code/config change by this ticket — adoption is a separate decision. -->

---

id: DIA-074
title: "Ticket filenames lack human-readable descriptors — orchestrator ticket references are opaque to the developer"
area: docs
severity: Medium
status: OPEN
blocked_by: []
discovered: 2026-08-09
source: owner-reported
date: 2026-08-09
created: 2026-08-09
updated: 2026-08-09

# --- Session Attribution (v2 schema, optional) ---

session_id: "ses_019efa2baffeOUizw57Jhv5J26"
lane_id: "dia-074-ticket"
agent: "coder"
model: "deepseek-v4-flash"
parent_session_id: ""
attempts: 0
lease_expires_at: ""
files_touched: ["docs/dev-infra-audit/tickets/DIA-074-ticket-filenames-descriptors.md", "docs/dev-infra-audit/tickets/README.md"]
artifacts: []
evidence: []

---

## Description

**Summary:** Ticket files are named `DIA-<NNN>.md` (numeric ID only); the
human-readable title lives only in each file's heading and frontmatter
(`title:`). Orchestrator session summaries and `log_decision` events reference
tickets by ID alone — e.g. "DIA-072 CLOSED", "DIA-069 PR #54", "DIA-071
deferred" — forcing the developer to open ticket files or the README index to
identify each ticket. Developer's verbatim complaint: "ти згадуєш тікети і я
вже ніфіга не розумію що це за тікети" (you mention tickets and I no longer
understand what those tickets are).

**Facts:**

1. **Numeric-only filenames.** The ledger at `docs/dev-infra-audit/tickets/`
   names files `DIA-<NNN>.md` — no human-readable slug in the filename.
2. **Title lives inside the file only.** Each ticket's heading
   (`# DIA-NNN — <Title>`) and YAML frontmatter `title:` carry the
   human-readable description; neither is visible from the filename alone.
3. **References are ID-only.** Session summaries and `log_decision`
   `content_ref`s quote bare `DIA-<NNN>` (per the examples above), with no
   title. A developer reading a session summary or `git log` cannot tell what
   each referenced ticket is about.
4. **The README index already carries ID→title rows.**
   `docs/dev-infra-audit/tickets/README.md` maps each ID to its title — the
   gap is that references do not include titles, and filenames are not
   self-describing in `git status` / `git log`.

**Root cause:** the ticket identifier visible to humans (the filename / the
bare ID in references) carries no semantic content; the semantic content lives
only inside the file, which is one lookup away.

**Impact:** Medium — developer comprehension of every session summary and
git-log scan; no functional or data impact.

## Verification

1. Scan recent session summaries / `log_decision` `content_ref`s — ticket
   references appear as bare `DIA-<NNN>` with no title.
2. `git status` / `git log` show only `DIA-<NNN>.md` filenames with no
   descriptive content.
3. Acceptance (post-fix): a developer reading a session summary or git log can
   identify each referenced ticket without opening the file.

## Fix

**Fix directions (proposal scope — this ticket RECORDS the proposal; adoption
is a separate decision):**

- **(a) Descriptive filenames.** Rename ticket files to
  `DIA-<NNN>-<human-slug>.md` (e.g. `DIA-072-source-archival-fallback.md`);
  update README index links; `DIA-*.md` globs still match. Pros:
  self-documenting in `git log` / `git status`. Cons: rename churn across ~27
  files + link updates.
- **(b) Reference discipline.** Keep numeric filenames; require the
  orchestrator (AGENTS.md / instructions) to always quote ID + title in
  user-facing references ("DIA-072 — source-archival fallback"). Pros: zero
  file churn. Cons: relies on prompt discipline, not structural.
- **(c) README-index-as-authority.** Orchestrator resolves ID→title from the
  README index before referencing. Mechanical, but the same discipline
  dependency as (b).
- **(d) Hybrid.** Adopt (a) for NEW tickets going forward, (b) for all
  references; backfill renames optional/later.

**Routing note:** renaming ticket files = dev-infra docs change (works via
this ledger workflow); changing orchestrator reference behavior = §10-routed
if it touches agent instructions/AGENTS.md; README-index resolution could be
enforced by a validation script (`scripts/`) without §10.

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
