# DIA-084 — audit the artifacts folders — ensure proper order/structure, naming conventions, archive policies, index files, cross-references

<!-- Filed by the docs lane (code-executor re-route) 2026-08-10. -->

---

id: DIA-084
title: "audit the artifacts folders — ensure proper order/structure, naming conventions, archive policies, index files, cross-references"
area: docs
severity: Medium
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
discovered: 2026-08-10
source: inventory
date: 2026-08-10
created: 2026-08-10
updated: 2026-08-11

# --- Session Attribution (v2 schema, optional) ---

session_id: "ses_0133de7fdffeKc3ClhE6fqFy0X"
lane_id: "docs"
agent: "code-executor"
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: ""
files_touched: ["docs/dev-infra-audit/tickets/DIA-084-artifacts-folder-audit.md"]
artifacts: []
evidence: []

---

## Description

Audit the artifacts folders (knowledge/, .opencode/session/,
.opencode/memory/, docs/dev-infra-audit/, openspec/, .sdd/, .tss/) and ensure
proper order/structure. Verify naming conventions (<type><id>-<topic>),
archive policies, index files, and cross-references.

## Verification

- [ ] Enumerate the contents of each artifacts folder.
- [ ] Verify naming conventions (<type><id>-<topic>) across knowledge/ and other artifact dirs.
- [ ] Verify archive policies are applied (e.g., archived tickets in archive/, never deleted).
- [ ] Verify index files exist and cross-references resolve (no dangling links).

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.

## Scope extension (batch brief 2026-08-11)

Extended brief from the batch: audit ALL artifact folders and determine
whether the current structure provides proper organization. This extends the
original enumeration-focused scope into a full organization audit and, where
appropriate, applies a consistent organization strategy.

Checks to perform across every artifact folder:

- Misplaced files: artifacts living in the wrong folder for their type.
- Duplicate artifacts: same content stored in more than one place.
- Obsolete artifacts: superseded by newer content or by closed tickets.
- Inconsistent naming: violations of the <type><id>-<topic> convention or
  otherwise divergent naming patterns.
- Unclear ownership: artifacts with no stated owner lane or responsible
  agent.
- Temporary files mixed with permanent documentation: scratch files,
  drafts, and throwaway output inside folders that hold lasting records.
- Missing indexes: folders that lack an index or cross-reference listing
  their contents.
- Unclear lifecycle: artifacts with no lifecycle metadata (created,
  updated, archived, superseded) and no defined lifecycle policy.
- Artifacts that should be committed but are not (or are gitignored).
- Artifacts that should be ignored but are committed (generated output,
  session scratch, secrets).
- Artifacts that should be generated rather than manually maintained
  (derived indexes, rendered views, aggregated listings).

Folders explicitly in scope:

- knowledge/ (res*/ana*/tch\* naming convention: <type><id>-<topic>).
- .opencode/memory-shelf.yaml (central index - verify it points to real
  files and covers new content).
- .opencode/learnings/ (dynamic experience records).
- .opencode/session/ (gitignored - confirm gitignore status is correct and
  no committed duplicates exist elsewhere).
- openspec/ (change artifacts).
- .sdd/ (software design documents).
- .tss/ (technical specifications, if present).

Guardrails:

- Do NOT delete potentially useful material without establishing that it is
  obsolete or duplicated. Any proposed deletion must be recorded as a
  recommendation with evidence, not performed silently.

Deployment concern to flag (from post-rebase audit):

- teaching/, mermaid-diagramming/, and console-charting/ skills were flagged
  as dangling at PROJECT level (.opencode/skills/) but they resolve
  correctly at GLOBAL path (~/.config/opencode/skills/). Document this
  project-vs-global skill location convention: which skills live in each
  location, why, and how resolution works. Verify whether an OpenCode
  runtime outside this user home (different machine, CI, container without
  this home directory) would fail to resolve those skills, and record the
  risk and any mitigation.

## Verification (extended)

- [ ] Complete the check list above for each artifact folder in scope.
- [ ] Produce a findings list: misplaced, duplicate, obsolete, inconsistent, unowned.
- [ ] Apply a consistent organization strategy where appropriate; record what changed.
- [ ] Document the project-vs-global skill location convention and the resolution risk outside this user home.

## Session-11 dispositions (2026-08-11)

Audit report: `knowledge/ana010-artifacts-folder-audit/ana010-artifacts-folder-audit-report.md`.

Developer disposition: chose "research it deeper" for the skill-location risk
(project-vs-global skill resolution outside this user home). ai-specialist lane
to follow with the deeper research.

Status: OPEN.
