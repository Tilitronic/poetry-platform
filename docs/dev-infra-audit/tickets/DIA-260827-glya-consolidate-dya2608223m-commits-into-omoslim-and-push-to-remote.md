# DIA-260827-glya - Consolidate dya2608223M commits into omoslim and push to remote

---

id: DIA-260827-glya
title: "Consolidate dya2608223M commits into omoslim and push to remote"
area: scripts
severity: Medium
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-27
source: inventory
date: 2026-08-27
created: 2026-08-27
updated: 2026-08-27

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

Consolidate the commits identified as "dya2608223M" into the omo-slim-changes
branch and push the result to origin.

Reconstructed from title + current repo state; original reporter context not
recoverable.

## Problem

- The identifier `dya2608223M` resolves nowhere in the repository:
  `grep -rn "2608223"` matches only this ticket (plus its README rollup
  line), `git log --all --oneline --grep=dya2608223` returns 0 commits, and
  no branch or session file carries it. A fresh reader cannot tell which
  commits to consolidate; the owner must name them.
- What is verifiable today: two branches hold commits that are not on
  `omo-slim-changes` - `git rev-list --count omo-slim-changes..backup/pre-dia-message-rewrite-20260914`
  = 10 and `git rev-list --count omo-slim-changes..further-dev-infrastructure-development`
  = 4 (every other local branch = 0). Whether either is the "dya2608223M"
  work is NOT asserted here.
- The push half is verifiable: `git rev-list --left-right --count
origin/omo-slim-changes...HEAD` = `0 21`, i.e. 21 local commits not on
  origin. Pushing them is governed by the push-gate ticket DIA-261021-51pm
  ("re-review cycle 1/2 and push gate for the 5 unpushed omo-slim-changes
  commits"), so this ticket must not force anything.

## Verification

- [ ] The owner has named the dya2608223M commit SHAs and they are recorded
      in this ticket's Fix section (or the ticket is explicitly narrowed to
      the push half)
- [ ] Every named SHA is reachable from `omo-slim-changes`
- [ ] After the gated push, `origin/omo-slim-changes` contains them

## Fix

1. Record the owner-identified SHA list in this ticket (ask first; do not
   guess from the two candidate branches above).
2. Merge or cherry-pick any named commits that are not already on
   `omo-slim-changes`.
3. Push through the existing push gate (DIA-261021-51pm), never `--force`.
   Touch: this ticket and git history (push lane), no source files.

## Re-verify

```bash
grep -n "dya2608223M commits:" docs/dev-infra-audit/tickets/DIA-260827-glya-*.md
# -> SHA list recorded
git rev-list --count omo-slim-changes..<named-branch>        # 0 once consolidated
git rev-list --left-right --count origin/omo-slim-changes...omo-slim-changes
# -> "0 0" after the gated push
```

## References

- `git log --all --oneline --grep=dya2608223` (0 hits; identifier unrecoverable)
- `git rev-list --left-right --count origin/omo-slim-changes...HEAD` (0 / 21 at rewrite time)
- Commit `20a922bf` (ticket creation only; no consolidation commit found)
