# DIA-178 — Memory shelf hygiene audit: duplicate/stale/irrelevant lessons, conspects, analyses

<!-- RENUMBERED 2026-08-14 (phase 1, remote lineage canonical, DIA-153): local DIA-138 collided with origin/omo-slim-changes ticket DIA-138-agent-instruction-files-audit.md (different ticket). Renumbered to DIA-178. -->

---

id: DIA-178
title: "Memory shelf hygiene audit: duplicate/stale/irrelevant lessons, conspects, analyses"
area: docs
severity: Medium
status: DONE
blocked_by: [] # DIA-NNN refs, or empty
discovered: 2026-08-14
source: baseline
date: 2026-08-14
created: 2026-08-14
updated: 2026-08-14

# --- Session Attribution (v2 schema, optional) ---

session_id: "ses_ffff689d1ffeoWG0q8HPknkBiM" # OpenCode session ID that owned this ticket
lane_id: "" # e.g. cod-1, ai--3
agent: "" # agent name (coder, reviewer, etc.)
model: "" # model ID used
parent_session_id: "ses_ffff689d1ffeoWG0q8HPknkBiM" # orchestrator's session ID
attempts: 0 # how many delegations attempted
lease_expires_at: "" # ISO-8601; set on DISPATCHED, cleared on COMPLETE
files_touched: [] # list of file paths modified
artifacts: [] # list of artifact references (commits, test outputs)
evidence: [] # list of evidence URIs (messages.md#row, registry.jsonl#seq)

---

## Description

The Memory Shelf (.opencode/memory-shelf.yaml) is the project's knowledge
index: 21 conspects (res001..res021), 19 analyses (ana001..ana017 + ana01 +
ana-post-_), 11 specs, 2 ADRs, 1 architecture, plus the lessons/adr/failures
memory files (.opencode/memory/_.md) and the knowledge/ directory contents.
The user asked for a hygiene audit: are there duplicate, irrelevant, or stale
lessons/memories/conspects/analyses worth deleting, merging, or archiving?

Known recent context (DIA-176): duplicate shelf IDs res014/ana013/ana014 were
already renumbered to res021/ana016/ana017, and res020 path was fixed. This
audit should go deeper: content-level duplication, superseded lessons,
irrelevant entries, merge candidates, and integrity issues (paths, orphaned
dirs, empty rag_bases).

## Verification

- `ls knowledge/` vs shelf entries - find orphaned dirs / missing entries
- Read .opencode/memory-shelf.yaml sections (conspects, analyses, specs, adrs, architectures, rag_bases)
- Read .opencode/memory/lessons.md, adr.md, failures.md - duplicate/superseded lessons
- Compare conspect/analysis topics for overlap (e.g. multiple agent-alignment
  audits, telemetry audits, model-evaluation analyses)
- Check entry path resolution; check YAML parse; check `rag_bases: []` emptiness
- Produce knowledge/ana018-memory-shelf-hygiene/ana018-memory-shelf-hygiene-report.md
  with categorized findings: DELETE / MERGE / ARCHIVE / KEEP + rationale each

## Fix

Applied 2026-08-14:

- Analyzer ana018: knowledge/ana018-memory-shelf-hygiene/ana018-memory-shelf-hygiene-report.md (346 lines) - 54 entries audited, all paths resolve, 0 DUP/MERGE candidates, 0 DELETEs.
- Coder b6c5d1c: archived ana014-rung3-benchmark-protocol -> knowledge/archive/; renumbered duplicate lesson ID L20260812-003 (2nd instance, line 704) -> L20260812-005; renamed ana01-tests-ponytail-audit -> ana003 (fills gap), ana-post-cherry-pick-audit -> ana019, ana-post-rebase-audit -> ana020; updated non-shelf references.
- Memory-manager (sole shelf writer): updated shelf paths for ana003/ana019/ana020/archived ana014 (+ status: archived), registered dev-infra-stack-hardening in shelf.specs (11->12), reworded ana018 description (L20260812-003 -> -005).

## Re-verify

- All 12 test-config sub-gates exit 0 (test-interview, test-skills, compose config, validate-opencode-config, validate-agent-names, validate-output-contracts, validate-reviewer-sections, validate-handoff, ticket-gate, audit-agent-tool-coverage x2, batch-d-infra 43/43).
- Shelf YAML parse OK; all rewritten paths resolve; counts: conspects 21, analyses 20, adrs 2, specs 12, architectures 1, rag_bases 0.
- Zero stale references in live tree (remaining matches are historical prose in ana010 report + .worktrees/ batch-D checkouts, intentionally untouched).
- Pre-commit hook passed via poetry-dev container (no --no-verify). Commit b6c5d1c.
