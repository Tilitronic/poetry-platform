# DIA-102 - specification-document workflow: lifecycle, naming, commit policy, obsolete handling, spec-impl linkage, agent discovery

<!-- Analyzer-authored manifest transcribed by the coder lane (2026-08-11).
     Parallel dev infra batch ticket. docs: defines where module specs live,
     how they are named/committed/retired, how they link to implementations,
     and how agents discover the relevant spec for a task. Blocked by DIA-084
     (artifacts-folder audit). Draws from ana004 (spec-authoring-philosophy
     audit) and res001 (openspec/sdd reconciliation conspect). -->

---

id: DIA-102
title: "specification-document workflow: lifecycle, naming, commit policy, obsolete handling, spec-impl linkage, agent discovery"
area: docs
severity: Medium
status: OPEN
blocked_by: ["DIA-084"]
discovered: 2026-08-11
source: inventory
date: 2026-08-11
created: 2026-08-11
updated: 2026-08-11

# --- Session Attribution (v2 schema, optional) ---

session_id: "" # OpenCode session ID that owned this ticket
lane_id: "" # e.g. cod-1, ai--3
agent: "" # agent name (coder, reviewer, etc.)
model: "" # model ID used
parent_session_id: "" # orchestrator's session ID (populated via get-my-session-id tool)
attempts: 0 # how many delegations attempted
lease_expires_at: "" # ISO-8601; set on DISPATCHED, cleared on COMPLETE
files_touched: [] # list of file paths modified
artifacts: [] # list of artifact references (commits, test outputs)
evidence: [] # list of evidence URIs (messages.md#row, registry.jsonl#seq)

---

## Description

Define a concrete maintainable specification-document workflow: (a) where
module specs live (openspec/ vs .sdd/ vs .tss/); (b) naming convention
(aligned with DIA-074); (c) commit policy (specs committed with
implementation, or separate commit); (d) obsolete-spec handling (archive/ vs
delete/ vs mark-stale); (e) spec-implementation linkage (each spec references
tickets and commits that implement it); (f) agent discovery (how agents find
the relevant spec for their task); (g) lifecycle status metadata
(proposed/implemented/obsolete); (h) versioning (spec revisions tracked via
git history, or explicit version field). Draws from ana004
(spec-authoring-philosophy audit) and res001 (openspec/sdd reconciliation
conspect) - read knowledge/ana004*/ and knowledge/res001*/ if present.

### Investigation requirements

1. Map current spec storage (openspec/changes/\*/, .sdd/, memory-shelf specs).
2. Identify gaps: no status metadata, no obsolete handling, no spec-impl link.
3. Propose lifecycle states (proposed/implemented/obsolete).
4. Define agent discovery pattern (e.g., openspec CLI query, or file-path
   convention).
5. Align naming with DIA-074 (human-readable names).

### Deliverables

- Spec-workflow reference (storage, naming, lifecycle, commit policy).
- Agent discovery pattern documented.
- Obsolete-spec handling policy.
- Spec-impl linkage template (spec references commits/tickets).

## Verification

- [ ] (a) All 3 storage layers (openspec/, .sdd/, .tss/) mapped.
- [ ] (b) Lifecycle states defined with transition rules.
- [ ] (c) Agent discovery pattern tested (agent finds relevant spec for a
      task).
- [ ] (d) Naming convention aligned with DIA-074.
- [ ] (e) Obsolete-spec policy documented (archive vs delete).

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
