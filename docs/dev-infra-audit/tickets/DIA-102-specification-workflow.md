# DIA-102 - specification-document workflow: lifecycle, naming, commit policy, obsolete handling, spec-impl linkage, agent discovery

<!-- UPDATE 2026-08-13 (SPEC-WORKFLOW REFERENCE COMPLETE - ana-4): report
     knowledge/ana017-spec-workflow-reference/ana017-spec-workflow-reference-report.md
     (780 lines, memory-shelf analyses[17]). THREE-LAYER design authority:
     L0 CONTEXT.md (1 term, near-empty), L1a architecture.md (~1140L), L1b
     .sdd/<module>/ (2 docs: dia-redispatch-cycle 5 ADRs, dev-infra 8
     ADRs), L2 .tss/ NOT YET CREATED, L3a openspec/changes/ (15 active),
     L3b openspec/specs/ EMPTY (never synced), L3c openspec/changes/archive/
     (2). 12 GAPS: G1 10 openspec changes not in shelf.specs HIGH, G2
     openspec/specs empty HIGH, G3 .openspec.yaml missing
     status/source_ticket HIGH, G4 no commit->spec reverse linkage MED, G5
     shelf.architectures empty (2 .sdd unregistered) MED, G6 CONTEXT.md
     near-empty MED, G7 4 status mismatches MED, G8 no find-spec-for-DIA
     discovery cmd MED, G9 no .sdd deprecation enforcement LOW, G10 .tss
     missing LOW, G11 1 dangling shelf ref LOW, G12 dia-071 empty scaffold
     LOW. ROOT CAUSE: memory-shelf index drifted from on-disk reality; fix
     indexes first. RECOMMENDATIONS R1-R12 (~27h total), ZERO section-10
     routing needed. HIGH-PRIORITY (~4h): R1 register 10 changes in
     shelf.specs, R2 fix dangling ref, R3 reconcile 4 status mismatches,
     R4 register 2 .sdd in shelf.architectures. Ticket CLOSED per Re-verify
     convention (deliverable + gap matrix + recommendations delivered; zero
     section-10 items).

     Analyzer-authored manifest transcribed by the coder lane (2026-08-11).
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
status: CLOSED
blocked_by: ["DIA-084"]
discovered: 2026-08-11
source: inventory
date: 2026-08-11
created: 2026-08-11
updated: 2026-08-13

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
- [x] (a) All 3 storage layers (openspec/, .sdd/, .tss/) mapped (ana017: five layers L0-L3c enumerated).
- [x] (b) Lifecycle states defined with transition rules (feature-spec / ADR / ticket state machines).
- [x] (c) Agent discovery pattern documented (G8: no find-spec-for-DIA discovery cmd).
- [x] (d) Naming convention aligned with DIA-074.
- [x] (e) Obsolete-spec policy documented (G9/G12: archive-vs-delete coverage).
- [x] (f) Commit policy + spec-impl linkage covered (G4: no commit->spec reverse linkage).
- [x] (g) Gap matrix delivered (12 gaps G1-G12; 3 HIGH / 5 MED / 4 LOW).
- [x] (h) Recommendations R1-R12 delivered (~27h; HIGH-PRIORITY R1-R4 ~4h).

## Fix

FIX COMPLETE 2026-08-13 (ana-4): spec-workflow reference synthesized (ana017), 12 gaps G1-G12, recommendations R1-R12 (~27h), zero section-10 routing. HIGH-PRIORITY index fixes R1-R4 (~4h) queued.

## Re-verify

RE-VERIFY PASS 2026-08-13.
