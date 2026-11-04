# DIA-260917-2z0u - publish opencode infrastructure operational map

---

id: DIA-260917-2z0u
title: "publish opencode infrastructure operational map"
area: scripts
severity: Medium
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-09-17
source: inventory
date: 2026-09-17
created: 2026-09-17
updated: 2026-09-17

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

Make the published OpenCode infrastructure operational map discoverable from
the repo's entry docs and give this ticket a freshness/verification rule for
it.

## Problem

- The map is published: `docs/dev-infra-audit/opencode-infrastructure.md`
  (341 lines, commit `e78e68ea`) and is cited by the changelog and several
  learnings/tickets - but it is unreachable from every entry doc:
  `grep -c "opencode-infrastructure" AGENTS.md docs/onboarding.md docs/dev-infra-audit/NEXT-RUN.md`
  returns 0/0/0, `grep -c "opencode-infrastructure" .opencode/memory-shelf.yaml`
  returns 0, and no script or Makefile target reads it. Nothing points a new
  reader at it and nothing checks it for staleness.
- The handoff that opened this ticket left it as a skeleton:
  `.opencode/session/handoffs/archive/ses_f53226755ffeCmRnB5CF53UpaW.2026-09-17T11-03-47.863Z.*.json:16`
  - "Next: fill Description/Verification scope on jrph + 2z0u + ch3o + gv9i
    skeletons as their work proceeds"; `:13` records "map published, scope fill
    pending".

## Verification

- [ ] At least one entry doc links the map (`grep -n "opencode-infrastructure"
docs/onboarding.md` non-empty)
- [ ] This ticket's Verification carries a freshness rule (map's "Updated"
      header re-checked against the last commit touching the mapped surface
      whenever that surface changes)
- [ ] `make test-config` exit 0

## Fix

Add a one-line pointer to `docs/dev-infra-audit/opencode-infrastructure.md`
from `docs/onboarding.md` (smallest discoverable entry point), and record the
freshness rule in this ticket. Touch: `docs/onboarding.md` and this ticket.

## Re-verify

```bash
grep -n "opencode-infrastructure" docs/onboarding.md        # >= 1
grep -n "Updated:" docs/dev-infra-audit/opencode-infrastructure.md
git log -1 --format=%cs -- docs/dev-infra-audit/opencode-infrastructure.md
# header date vs last-touch date reviewed for drift
make test-config                                            # exit 0
```

## References

- Commit `e78e68ea` (docs(map): publish opencode infrastructure operational map)
- `.opencode/session/handoffs/archive/ses_f53226755ffeCmRnB5CF53UpaW.2026-09-17T11-03-47.863Z.*.json:13,16` (scope-fill pending, resume instruction)
