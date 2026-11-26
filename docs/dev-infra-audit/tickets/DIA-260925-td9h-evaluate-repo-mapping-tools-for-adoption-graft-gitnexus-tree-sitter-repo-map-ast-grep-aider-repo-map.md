# DIA-260925-td9h - evaluate repo-mapping tools for adoption (graft, gitnexus, tree-sitter repo map + ast-grep, aider repo map)

---

id: DIA-260925-td9h
title: "evaluate repo-mapping tools for adoption (graft, gitnexus, tree-sitter repo map + ast-grep, aider repo map)"
area: dev-infra
severity: Medium
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-09-25
source: inventory
date: 2026-09-25
created: 2026-09-25
updated: 2026-09-25

# --- Session Attribution (v2 schema, optional) ---

session_id: ""
lane_id: ""
agent: ""
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: "" # ISO-8601; set on DISPATCHED, cleared on COMPLETE
files_touched: []
artifacts: []
evidence: []

---

## Description

Record the developer's adoption decision for the repo-mapping tool evaluation
that this ticket commissioned, so the ledger stops showing an OPEN evaluation
whose study is already finished.

## Problem

- The evaluation itself is DONE and published: report at
  `knowledge/ana-260925-5v4r-repo-mapping-tools-evaluation/ana-260925-5v4r-repo-mapping-tools-evaluation-report.md`,
  shelf-registered in `.opencode/memory-shelf.yaml:1011-1013` with
  `task_ref: DIA-260925-td9h`, and committed in `96cb183a` ("docs: add
  repo-mapping tool evaluation conspects + DIA-260925-td9h and DIA-260926-kksa
  tickets").
- The report already carries a full EBDV decision set (section 8, lines 479-506)
  with **V1 status quo / adopt none** as the recommended variant and V2
  (time-boxed codebase-memory-mcp pilot) as the only sanctioned challenger.
- What is missing is the disposition: this ticket has no UPDATE/decision block,
  and `.opencode/CHANGELOG.yaml` contains zero entries citing `DIA-260925-td9h`
  (grep over the ledger returns nothing). A fresh reader cannot tell whether V1
  was accepted, V2 was authorized, or the study was never decided.
- Consequence: the "revisit triggers" in report section 8 (lines 513-524) have
  no owner and no recorded decision to be compared against.

## Verification

- [ ] `scripts/tickets show DIA-260925-td9h` returns a body that names the
      chosen variant (V1 status quo or V2 pilot) with the developer's rationale.
- [ ] If the choice triggers config work (V2 adds an MCP entry), a
      `.opencode/CHANGELOG.yaml` entry exists citing `DIA-260925-td9h`.
- [ ] If V1 is chosen, no config file changes at all (report line 488: "no
      config change").

## Fix

Proposed fix, smallest first:

1. Append a dated UPDATE block to this ticket recording the developer decision
   over the report's five variants (report lines 486-492); default reading if
   the developer has not spoken is to confirm V1 explicitly rather than leave
   it implicit.
2. Only if V2 is authorized: route it through AGENTS.md section 2.5 (MCP block +
   permission scoping + prompt guidance), then add the CHANGELOG entry.

No code, config, or script change is required for the V1 path.

## Re-verify

    scripts/tickets show DIA-260925-td9h        # body now carries the decision block
    grep -rn "DIA-260925-td9h" .opencode/CHANGELOG.yaml   # non-empty only if V2/config work happened
    grep -n "task_ref: DIA-260925-td9h" .opencode/memory-shelf.yaml   # study stays shelf-registered
