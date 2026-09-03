# DIA-110 - add human-readable descriptors to ALL DIA ticket filenames (critical)

<!-- Filed 2026-08-12. Developer escalation: "when you mention tickets I have
     no idea what issue it is related to. It is critical, it must be fixed."
     DIA-074 (OPEN, 2026-08-09) documented the gap and proposed fix directions
     (a)-(d); adoption was deferred. This ticket makes the fix MANDATORY at
     Critical severity: rename ALL remaining bare DIA-<NNN>.md filenames to
     DIA-<NNN>-<human-slug>.md and update every reference. -->

---

id: DIA-110
title: "add human-readable descriptors to ALL DIA ticket filenames (critical)"
area: docs
severity: Critical
status: CLOSED
blocked_by: []
discovered: 2026-08-12
source: owner-reported
date: 2026-08-12
created: 2026-08-12
updated: 2026-08-12

# --- Session Attribution (v2 schema, optional) ---

session_id: ""
lane_id: ""
agent: ""
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: ""
files_touched: ["docs/dev-infra-audit/tickets/DIA-110-unreadable-ticket-filenames.md", "docs/dev-infra-audit/tickets/README.md"]
artifacts: ["4ce939c docs(tickets): rename bare DIA-NNN.md files to slugged filenames (DIA-110)"]
evidence: ["41 bare DIA-NNN.md files renamed via git mv (25 active + 16 archive)", "all refs updated", "0 broken DIA-*.md links", "pushed to origin/omo-slim-changes"]

---

## Description

Developer escalation (2026-08-12): orchestrator session summaries and
log_decision events reference tickets by bare ID ("DIA-072 CLOSED", "DIA-071
deferred"), and many ticket FILES are still named DIA-<NNN>.md with no
human-readable slug. The developer cannot tell what issue a referenced ticket
is about without opening files. Verbatim requirement: "add human readable part
to DIA tickets... It is critical, it must be fixed."

DIA-074 (OPEN, 2026-08-09) proposed fix directions (a)-(d) and left adoption
as a separate decision. This ticket supersedes that deferral: the fix is now
MANDATORY.

Affected files (previously bare DIA-<NNN>.md names; renamed to slugged
filenames per this ticket, 2026-08-12):

ACTIVE tickets dir (25):
DIA-045-opencode-config-drift-backlog.md, DIA-050-mise-dockerfile-pin-sync-gap.md, DIA-051-jsonl-telemetry-leak-chat-ui.md, DIA-052-skill-dup-cleanup.md, DIA-053-ai-auditor-4-source-registration.md, DIA-054-council-budget-guard.md,
DIA-055-token-export-subagent-exposure.md, DIA-056-ai-auditor-token-tool-loop.md, DIA-057-knowledge-workflow-conspect-violation.md, DIA-058-research-persistence-gap.md, DIA-059-gate-plugin-not-activated.md, DIA-060-orchestrator-read-scope-tickets.md,
DIA-061-orchestrator-handoff-files-failure.md, DIA-062-orchestrator-model-misconfiguration.md, DIA-063-ticket-creation-gate.md, DIA-064-cebula-preset-flash-revert.md, DIA-066-tool-coverage-audit-script.md, DIA-067-docker-dev-tool-access-gap.md,
DIA-068-delegation-observer-persistence-trigger.md, DIA-069-telemetry-command-docs-home-paths.md, DIA-070-telemetry-reentrancy-guard-gaps.md, DIA-071-make-test-gates-exit-2.md, DIA-072-researcher-unarchived-facts.md, DIA-073-handoff-coordination-session-ids.md,
DIA-074-ticket-filenames-descriptors.md

ARCHIVE tickets dir (16):
DIA-003-skills-lock-pin-all-skills.md, DIA-006-api-server-production-dockerfile.md, DIA-030-dockerfile-dev-unverified-installs.md, DIA-034-pip-audit-ecdsa-vulnerability.md, DIA-037-make-test-skills-gap.md, DIA-038-makefile-gate-matrix-validation.md,
DIA-039-pnpm-verify-pipeline-audit.md, DIA-040-python-gates.md, DIA-041-docker-e2e-test-infra.md, DIA-042-browser-e2e-playwright-flows.md, DIA-043-husky-hooks-ci-enforcement.md, DIA-044-opencode-docker-makefile-gates.md,
DIA-046-prettier-format-failures.md, DIA-047-pnpm-audit-esbuild-advisory.md, DIA-048-pnpm-store-stale-volume.md, DIA-049-publishing-platform-stub.md

NOTE: DIA-052/DIA-053 are already DONE status but still bare-named; DIA-055/
DIA-056/DIA-057/DIA-058/DIA-059/DIA-060/DIA-061/DIA-062/DIA-064/DIA-066/
DIA-067 are VERIFIED but bare-named. Rename applies regardless of status.

## Fix

Fix directions adopted from DIA-074 (a)+(b) hybrid, now mandatory:

- (a) Rename every affected ticket file to DIA-<NNN>-<human-slug>.md where
  <human-slug> is derived from the ticket title (kebab-case, ASCII). Update
  the README index links and any cross-references (blocked_by, tickets/archive
  README, session logs are NOT retro-edited - only live files).
- (b) Orchestrator reference discipline: always quote ID + slug in
  user-facing references going forward.

Verification before close:

- [ ] No DIA-<NNN>.md (bare, numeric-only) filename remains in
      docs/dev-infra-audit/tickets/ or tickets/archive/.
- [ ] Every renamed file's frontmatter id: field matches the new filename ID.
- [ ] README.md index links all resolve (no 404 on DIA-\*.md links).
- [ ] No stale DIA-<NNN>.md references remain in any .md file under
      docs/dev-infra-audit/ (excluding git history and session logs).
- [ ] git mv used so history is preserved; commit via pre-commit hooks.

## Fix

RESOLVED (2026-08-12, commit 4ce939c): all 41 bare `DIA-<NNN>.md` files
renamed to slugged filenames via `git mv` (25 in the ACTIVE tickets dir +
16 in the ARCHIVE tickets dir), covering every status (OPEN, DONE, VERIFIED,
CLOSED). Commit message: "docs(tickets): rename bare DIA-NNN.md files to
slugged filenames (DIA-110)".

- README index links and the archive README updated to the slugged filenames.
- Cross-references in live files updated; git history preserves the prior
  bare names (rename detection: 41 R entries in 4ce939c).
- Commit pushed to origin/omo-slim-changes (no --no-verify; pre-commit and
  pre-push hooks passed).
- Orchestrator reference discipline (direction b) now in effect: quote
  ID + slug in user-facing references going forward.
- Reference discipline codified in NEXT-RUN.md section 7.3 step 3a and
  AGENTS.md section 2.3 step 2 (2026-08-12).

## Re-verify

Close-out evidence (2026-08-12):

- [x] No bare `DIA-<NNN>.md` filename remains in docs/dev-infra-audit/tickets/
      or tickets/archive/ (verified: 0 bare files in both dirs).
- [x] Every renamed file's frontmatter `id:` field matches the new filename ID.
- [x] README.md index links all resolve - 0 broken DIA-\*.md links under
      docs/dev-infra-audit/ (grep for bare DIA-<NNN>.md references: 0 hits
      outside git history and session logs).
- [x] `git mv` used (history preserved); commit 4ce939c contains 41 rename
      entries and is contained in origin/omo-slim-changes.
- [x] Committed via pre-commit hooks (no --no-verify).

---
