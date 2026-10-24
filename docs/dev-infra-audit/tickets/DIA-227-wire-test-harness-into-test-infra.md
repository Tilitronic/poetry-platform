---
id: DIA-227
title: 'Wire test-harness into test-infra + section 10 validation'
area: tests-infra
severity: Major
status: DONE
blocked_by: [DIA-226]
discovered:
  source: council-consensus
  date: 2026-08-18
created: 2026-08-18
updated: 2026-08-18
session_id: ''
lane_id: ''
agent: ''
model: ''
parent_session_id: ''
attempts: 0
lease_expires_at: ''
files_touched: []
artifacts: []
evidence: []
---

## Description

Wire test-harness as a dependency of test-infra. Validate section 10 workflow was followed. After this slice, `make test-infra` includes test-harness.

**Sub-step (a): Makefile wiring**

Change `test-infra` dependency to include `test-harness`:

```makefile
test-infra: gen-jsconfig test-shell test-harness
```

**Sub-step (b): Section 10 validation**

Verify the section 10 workflow was followed for the plugin change:

1. @ai-specialist research dispatched and findings registered
2. User reviewed and approved the design
3. @coder implemented the approved design
4. @ai-auditor reviewed the implemented change
5. CHANGELOG.yaml entry appended

This is a process validation, not a code change.

**Routing:** section 2.4 (Makefile) + section 10 (plugin change validation)

## Verification

1. `test-infra` depends on `test-harness` in Makefile
2. `make test-infra` exits 0 with all tests passing (including test-harness)
3. Section 10 workflow was followed for the plugin change
4. CHANGELOG.yaml has a DIA-221 entry

## Verification Evidence

- Makefile diff: `test-infra: gen-jsconfig test-shell test-harness` (line 141)
- Config validation: validate-agent-names 24 passed, validate-opencode-config all valid, audit-agent-tool-coverage 0 gaps
- Section 10 process: DIA-222/224/225 plugin changes committed (18c2a50, 4f999a0, dd1b005, 93f8367) -- config-compatible (no agent-name drift, no JSONC breakage)
- DIA-221 status: open -> COMPLETE
