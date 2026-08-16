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

## UPDATE (2026-08-16) - Phase-3 design approved (Variant B)

Architector arc-1 design (session ses_ff67dd822ffeU4Aee704j5ZFtu, resume lane
final message 2026-08-16), transcribed verbatim for the reviewer diff anchor
(DIA-174 R2 persistence). Developer approved the design; implementation is
tracked by DIA-196 (branch omo-slim-changes). Technical decisions below are
the architector's, unchanged:

# DIA-194 Design: CHANGELOG.md -> YAML-Ledger Conversion

## 1. SCHEMA DESIGN

File: `scripts/schemas/changelog.schema.json`
Follows the `memory-shelf.schema.json` strictness (additionalProperties: false).

**Fields:**

- `date`: string, required, pattern "^[0-9]{4}-[0-9]{2}-[0-9]{2}$"
- `ticket`: string, required (e.g., "DIA-183" or "DIA-190/192/193")
- `severity`: string, optional (e.g., "Major", "Minor")
- `status`: string, optional (e.g., "IMPLEMENTED", "CLOSED")
- `area`: string, optional (e.g., "opencode-config")
- `scope`: string, required (short descriptor)
- `route`: string, optional (e.g., "section-10", "section-2.5")
- `files`: array of strings, required (files touched)
- `summary`: string, required (combined Change + Reason)
- `verification`: string, required (Verification + Review details)

**YAML Structure Example:**

```yaml
- date: '2026-08-16'
  ticket: 'DIA-183'
  status: 'CLOSED'
  scope: 'ponytail-half closure (Variant B, doc-only)'
  route: 'section-10'
  files:
    - 'AGENTS.md'
    - 'docs/PONYTAIL-DEBT.md'
    - '.opencode/learnings/external-patterns/2026-08-15-ponytail-headroom-cache-economics.md'
    - 'docs/dev-infra-audit/tickets/DIA-183-ponytail-headroom-context-compression.md'
  summary: >
    Change: DIA-183 (ponytail half) closed via developer-approved Variant B.
    Reason: ponytail half was gate-verified at merge 47064d0.
  verification: >
    make test-config exit 0. Review: developer-approved Variant B.
```

## 2. RENDER SCRIPT DESIGN

File: `scripts/changelog-render`
Stack: bash + yq (per DIA-137 status-quo tooling).

**Layout:**
Reads `.opencode/CHANGELOG.yaml`, outputs formatted markdown to standard out or overwrites `.opencode/CHANGELOG.md`.
Header mapping preserves existing prose continuity:

```markdown
## <date> - <ticket> (<status>): <scope>

- **Change:** <summary>
- **Files:** <files array joined by " - ">
- **Verification:** <verification>
```

Block-scalar prose (`summary: >`) handled natively by yq. yq iterates the array and formats output using string interpolation.

## 3. MIGRATION STRATEGY

Coders will execute a one-time mechanical extraction of the 88 sections (plus the DIA-183 entry from 2026-08-16).

- **Ordering:** Reverse-chronological (newest first), matching the current MD file.
- **Extraction rules:**
  - Date and ticket parsed from `## <date> - <ticket>` headers.
  - `- **Change:**` and `- **Reason:**` blocks concatenated into the `summary` block-scalar.
  - `- **Files:**` block parsed into the `files` YAML array.
  - `- **Verification:**` and `- **Review:**` blocks concatenated into `verification`.
- **Validation:** Run the output through the new schema validator to catch missing required fields.

## 4. VALIDATOR + GATE

- **Validator Script:** `scripts/validate-changelog.sh` (direct clone of `validate-memory-shelf.sh`, swapping SHELF_FILE for CHANGELOG_FILE and schema path). Uses python jsonschema with structural fallback.
- **Bats Coverage:** `scripts/__tests__/validate-changelog.bats` covering valid entry, missing required field, malformed date, and extra property.
- **Makefile Wiring:** Add `bash scripts/validate-changelog.sh` to the `test-config` target, exactly alongside `validate-memory-shelf.sh`.

## 5. FILE MANIFEST

- **Create:** `.opencode/CHANGELOG.yaml` (source of truth)
- **Create:** `scripts/schemas/changelog.schema.json` (schema gate)
- **Create:** `scripts/validate-changelog.sh` (mechanical gate)
- **Create:** `scripts/changelog-render` (derived view generator)
- **Create:** `scripts/__tests__/validate-changelog.bats` (gate tests)
- **Modify:** `.opencode/CHANGELOG.md` (becomes the derived view, completely overwritten by render script, remains committed)
- **Modify:** `Makefile` (wiring `test-config`)

## 6. ROLLBACK PLAN

Single-commit migration on branch `omo-slim-changes` (or feature branch).
If the YAML workflow proves too high-friction or tooling breaks, executing `git revert <migration-commit>` will atomically restore the prose `.opencode/CHANGELOG.md`, delete the YAML ledger, and remove the schema/scripts.

## 7. PROMPT UPDATE INVENTORY

Agents need instructions to use `yq` for partial reads and writes.

- `.opencode/oh-my-opencode-slim/orchestrator_append.md`: Add a rule under documentation reading: "When referencing the CHANGELOG, use `yq '.[] | select(.ticket == \"DIA-NNN\")' .opencode/CHANGELOG.yaml`. Do not read the full file."
- `AGENTS.md`: Update Section 2.5 Phase 7 ("Register - update CHANGELOG") to specify appending to `CHANGELOG.yaml` using `yq -i`.
- `.opencode/opencode.jsonc`: Verify/add `yq *` or `yq -i *` to the coder bash allow-list to ensure DIA-186 overnight permissions do not block YAML updates.

## 8. RISK ASSESSMENT

| Risk                  | Mitigations                                                                                      |
| --------------------- | ------------------------------------------------------------------------------------------------ |
| Malformed YAML        | Deliverable A stack (JSON Schema gate via `test-config`, LSP).                                   |
| Schema evolution      | JSON Schema is additive; adding optional fields later breaks nothing.                            |
| Render drift          | `bats` testing on `changelog-render` ensures structural consistency.                             |
| Merge friction        | YAML line-based diffs are coarser, but derived MD is committed (preserves human readable diffs). |
| Partial-read adoption | Addressed via prompt updates pointing orchestrator to `yq` lookup pattern.                       |
| Permission blocks     | Explicit `yq` allow-list updates prevent unattended stalling (DIA-186).                          |

## 9. SEQUENCING

1. **Schema & Gates:** Create `changelog.schema.json`, `validate-changelog.sh`, and `.bats` tests. Wire into `Makefile`.
2. **Render Script:** Write `changelog-render` + tests.
3. **Migration:** Coder script/manual-assist to convert the 88+1 MD sections to `CHANGELOG.yaml`.
4. **Initial Render:** Run `changelog-render` to overwrite `.opencode/CHANGELOG.md`.
5. **Prompt/Permission Updates:** Update `orchestrator_append.md`, `AGENTS.md`, and `opencode.jsonc` (allow `yq`).
6. **Validation:** Run `make test-config` to ensure zero failures.

## 10. ADR-WORTHY DECISIONS

**ADR: Derived MD View Committed (Not Gitignored)**

- **Status:** Proposed
- **Context:** The CHANGELOG is moving to a YAML source of truth for agent token economy. Developers need a human-readable diff for PR reviews.
- **Decision:** The derived `.opencode/CHANGELOG.md` will remain tracked in Git and updated synchronously with the YAML ledger via the render script.
- **Consequences:** Slight duplication in Git storage. Excellent PR review ergonomics (human readable prose diffs are preserved).
- **Alternatives:** Gitignore the MD and render on-demand. Rejected because it destroys human visibility during git merge and code review.

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
