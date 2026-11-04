# DIA-260826-ft3q - audit prompt injection vectors and plugin trust boundaries

---

id: DIA-260826-ft3q
title: "audit prompt injection vectors and plugin trust boundaries"
area: opencode-config
severity: Major
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: DIA-260821-bqy7
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-26
source: inventory
date: 2026-08-26
created: 2026-08-26
updated: 2026-08-26

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

Register the completed prompt-injection audit report on the memory shelf and
disposition its Blocker-class findings.

## Problem

- The audit itself is done:
  `knowledge/ana001-prompt-injection-plugin-trust/ana001-prompt-injection-plugin-trust-report.md`
  (generated 2026-08-31, campaign DIA-260826-ft3q, every vector cites
  file:line; Blocker V-05 at `:151`), but its own stated next step never
  happened: `grep -c "prompt-injection" .opencode/memory-shelf.yaml` returns
  0, so the report is unreachable from the shelf index.
- No remediation of the findings is recorded anywhere:
  `grep -in "injection" .opencode/CHANGELOG.yaml` returns 0 matches, and the
  later triage still lists the audit as open
  (`knowledge/ana-260921-z1g8-repo-risk-triage/ana-260921-z1g8-repo-risk-triage-report.md:50`,
  "Open audit: injection surface across plugins unmapped").

## Verification

- [ ] `memory-shelf.yaml` contains an entry pointing at the report and
      `bash scripts/validate-memory-shelf.sh` exits 0
- [ ] Each Blocker/High vector (V-01..V-05) has a disposition in this ticket:
      fixed (with CHANGELOG entry) or accepted risk (with rationale)
- [ ] `make test-config` exit 0

## Fix

Add the `shelf.analyses` entry for the report (memory-manager step under
AGENTS.md section 2.5), then append a finding-disposition table to this
ticket; any fix that changes plugin/config behavior goes through the section
2.5 gate (ai-specialist research, coder implementation, ai-auditor review,
CHANGELOG registration). Touch: `.opencode/memory-shelf.yaml` and this
ticket.

## Re-verify

```bash
grep -n "ana001-prompt-injection" .opencode/memory-shelf.yaml   # non-empty
bash scripts/validate-memory-shelf.sh                           # exit 0
grep -n "V-01\|V-05" docs/dev-infra-audit/tickets/DIA-260826-ft3q-*.md
grep -in "injection" .opencode/CHANGELOG.yaml                   # non-empty once a fix lands
make test-config                                                # exit 0
```

## References

- `knowledge/ana001-prompt-injection-plugin-trust/ana001-prompt-injection-plugin-trust-report.md:12,151,278` (scope, V-05, stated next step)
- `knowledge/ana-260921-z1g8-repo-risk-triage/ana-260921-z1g8-repo-risk-triage-report.md:50` (still-open triage row)
- Commit `2c19f31f` (ana001 report committed under this campaign)
