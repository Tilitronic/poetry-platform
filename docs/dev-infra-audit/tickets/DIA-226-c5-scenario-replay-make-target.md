---
id: DIA-226
title: 'C5 scenario replay (bats) + make test-harness target'
area: tests-infra
severity: Major
status: CLOSED
blocked_by: [DIA-225]
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

Bats scenario replay file + Makefile target. After this slice, `make test-harness` exits 0 with all 5 contracts passing.

**Sub-step (a): C5 -- harness-scenario-replay.bats**

New file: `scripts/__tests__/harness-scenario-replay.bats` (~150 lines). 3 scenario replays from the ana026 incident corpus:

1. **Scenario 1 (DIA-130 class):** coder-escalated returns empty result. Assert SILENT_FAILURE row in registry.jsonl.
2. **Scenario 2 (DIA-085 F-1 class):** two parallel handoff writes within same millisecond. Assert both archive files exist (distinct UUIDs).
3. **Scenario 3 (DIA-085 F-3 class):** two pre-dispatch orchestrator sessions write handoffs. Assert two distinct slot files (not a single "unknown.json" clobber).

Each scenario sets up a fresh mkdtemp workspace, drives the plugin, and asserts the observable output.

**Sub-step (b): Makefile test-harness target**

Add to Makefile:

```makefile
test-harness:
	bash scripts/__tests__/bats-wrapper.sh --filter harness-scenario-replay
	docker compose exec -T dev bash -lc 'cd /workspace/.opencode/plugins/__tests__ && bun test'
```

**Routing:** section 2.4 (dev-infra) -> @coder implementation -> @reviewer review

## Verification

1. `make test-harness` exits 0
2. C5 bats tests pass (3 scenarios)
3. C1-C4 bun tests pass (4 test files)
4. Total: 5 contracts, all passing
