# DIA-260910-2ztf - pre-commit formatting gap - commit a415c2d landed 5 unformatted ticket files repaired in 3bc5810

---

id: DIA-260910-2ztf
title: "pre-commit formatting gap - commit a415c2d landed 5 unformatted ticket files repaired in 3bc5810"
area: git-hooks
severity: Medium
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-09-10
source: inventory
date: 2026-09-10
created: 2026-09-10
updated: 2026-09-10

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

Local commit a415c2d landed 5 unformatted Markdown ticket files, repaired in
3bc5810. Affected suffixes: 3blw, 1c3e, spu5, g7h8, nm7j. The edit-time
formatter intentionally skips the tickets dir, so lint-staged autofix on the
pre-commit path should have caught them but did not.

Suspected causes:

1. Commit bypassed the pre-commit path (incl. --no-verify or alternate commit
   path that skips hooks).
2. Autofix ran but its result was not staged into the final index (staged vs
   worktree drift: hook fixed worktree files while git committed the stale
   staged blob).

Required forensics:

- git show a415c2d --stat (confirm the 5 ticket files in that commit).
- Hook config for the tickets path (pre-commit config + lint-staged entry;
  confirm whether tickets dir is excluded or included).
- lint-staged staged-vs-worktree behavior (does the repo restage autofix
  output into the final index or leave worktree-only fixes behind).

## Verification

- [ ] Forensics recorded on this ticket (commit stat, hook config excerpt,
      staged-vs-worktree finding).
- [ ] Root cause identified (bypass path vs unstaged-autofix).
- [ ] Small regression test added that closes the gap (e.g. hook-config
      assertion or lint-staged restage check) and passes.

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
