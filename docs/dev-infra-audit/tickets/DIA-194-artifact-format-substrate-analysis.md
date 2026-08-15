# DIA-194 - artifact format substrate analysis (DIA-180 Deliverable B): YAML vs Markdown EBDV matrix with token-economy evidence

---

id: DIA-194
title: "artifact format substrate analysis (DIA-180 Deliverable B): YAML vs Markdown EBDV matrix with token-economy evidence"
area: docs
severity: Medium
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: DIA-180
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-15
source: follow-up
date: 2026-08-15
created: 2026-08-15
updated: 2026-08-15

# --- Session Attribution (v2 schema, optional) ---

session_id: "ses_ffb255042ffegBdcwTI62usRSS"
lane_id: "docs"
agent: "coder"
model: ""
parent_session_id: "ses_ffd538953ffeHi5JxeN4RF1aAp"
attempts: 0
lease_expires_at: "" # ISO-8601; set on DISPATCHED, cleared on COMPLETE
files_touched: ["docs/dev-infra-audit/tickets/DIA-194-artifact-format-substrate-analysis.md", "docs/dev-infra-audit/tickets/README.md"]
artifacts: []
evidence: []

---

## Description

Follow-up ticket for DIA-180 (artifact format substrate review, CLOSED
2026-08-15 by the merge lane). DIA-180 split into an ENABLER (Deliverable A:
yaml-language-server pin + memory-shelf JSON Schema gate, squash-merged as
commit bcb8379) and an ANALYSIS (Deliverable B). Deliverable B was explicitly
deferred to a separate analysis lane per the DIA-180 Routing section
("Analysis (B): docs lane"); the analyzer dispatch for B was
section-10-gate-blocked because DIA-180 is CLOSED and the DIA-063 correlation
resolves no OPEN ticket. THIS ticket restores the gate correlation for the
deferred analysis and tracks it as section-10-visible work.

Scope (Deliverable B, per DIA-180 lines 83-91 and Verification items B1-B7):

- B1: Inventory table completed with real sizes and consumers (the inventory
  in DIA-180 is already filled; the analysis confirms/extends it).
- B2: Data-vs-prose classification per artifact with rationale: machine-first
  already-structured -> stay YAML (memory-shelf.yaml, ai-assist-sources.yaml,
  ticket frontmatter); machine-first append-only stream -> OUT OF SCOPE
  (session/\*.jsonl, belongs to DIA-136); narrative/instructions/human-rendered
  -> stay MD (openspec/, knowledge/, AGENTS.md, practice-protected.md,
  NEXT-RUN.md, .sdd/); FLAGSHIP conversion candidate -> .opencode/CHANGELOG.md
  (convert to YAML ledger + derived MD view).
- B3: Token-economy measurement for top-3 candidates (CHANGELOG first):
  context cost to read today vs equivalent YAML ledger, via wc/context_usage
  on read paths.
- B4: Agent YAML write-error risk analysis: in-repo precedents (DIA-079 JSON
  parse error, DIA-075 snip-jq loop) + external evidence on LLM YAML error
  rates; mitigation = schema + LSP + gates. The analysis MUST leverage the
  already-merged enabler (Deliverable A: yaml-language-server + memory-shelf
  JSON Schema gate in make test-config) as the mitigation layer - it is the
  reason the YAML premise is now viable.
- B5: EBDV-style recommendation matrix per artifact (>=2 genuine variants,
  evidence per variant, abort/status-quo variant, explicit recommendation
  with because, routing flag dev-infra vs section-10 vs N/A) per DIA-115.
- B6: Cross-referenced with DIA-136/DIA-137 - their candidates are NOT
  re-evaluated here; their outcomes referenced not re-derived.
- B7: Output registered in the memory shelf (ana<NNN> report; escalate to
  .sdd ADR only if the review surfaces an architecture-level decision).

Guardrails (inherited from DIA-180 Boundaries and DIA-084): the analysis
RECOMMENDS ONLY - no silent conversions. Any conversion spawns a follow-up
ticket after developer approval. Session-records storage and JSON-DB
candidates stay with DIA-136; tool/renderer/scheduler candidates stay with
DIA-137; any config-surface change resulting from the analysis routes through
the section-10 chain.

This ticket tracks the analysis as section-10-visible work; the analyzer lane
produces the report (ana<NNN> in memory shelf) and this ticket's Fix section
records its findings. The ticket itself is a docs/analysis artifact, not an
implementation change.

## Verification

Checklist copied verbatim from DIA-180 Verification items B1-B7 (the analysis
ticket's acceptance criteria):

- [ ] B1: Inventory table completed with real sizes and consumers (above,
      filled).
- [ ] B2: Data-vs-prose classification per artifact with rationale.
- [ ] B3: Token-economy measurement for top-3 candidates (CHANGELOG first):
      context cost to read today vs equivalent YAML ledger.
- [ ] B4: Agent YAML write-error risk analysis: in-repo precedents (DIA-079
      JSON parse error, DIA-075 snip-jq loop) + external evidence on LLM YAML
      error rates; mitigation = schema + LSP + gates.
- [ ] B5: EBDV-style recommendation matrix per artifact (>=2 genuine variants,
      evidence per variant, abort/status-quo variant, explicit recommendation
      with because) + routing flag (dev-infra vs section-10 vs N/A).
- [ ] B6: Cross-referenced with DIA-136/DIA-137 - no duplicate evaluation of
      shared candidates; their outcomes referenced not re-derived.
- [ ] B7: Output registered in the memory shelf (ana<NNN> report; escalate to
      .sdd ADR only if the review surfaces an architecture-level decision).

Gate evidence at fix time: memory-shelf entry ana<NNN> registered in
.opencode/memory-shelf.yaml; make test-config exit 0 (shelf schema gate
validates the new entry); the EBDV matrix satisfies
scripts/validate-decision-variants.sh if run mechanically.

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
