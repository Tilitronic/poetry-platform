# DIA-260927-vw0o - permission: worktree .scratch cleanup still raises an ask (CAUSE B residual)

---

id: DIA-260927-vw0o
title: "permission: worktree .scratch cleanup still raises an ask (CAUSE B residual)"
area: scripts
severity: Medium
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-09-27
source: inventory
date: 2026-09-27
created: 2026-09-27
updated: 2026-09-27

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

### Context

- The CAUSE B fix (DIA-260926-5vin, commit f6c84a5) added anchored allows for
  `/workspace/.scratch/*` and `.scratch/*` in `agent.coder.permission.bash`
  (mirrored byte-identically into `agent.coder-escalated.permission.bash`), so
  the sanctioned scratch cleanup no longer raises a permission ask.
- A coder lane running in a git worktree (batch D) whose scratch path is
  ABSOLUTE under the worktree root (e.g.
  `/workspace/.slim/worktrees/<branch>/.scratch/...`) is NOT covered by either
  anchor and will raise the permission ask again.
- An unanswered ask is what kills the lane: 300 s auto-reject
  (`PERMISSION_STALL_TIMEOUT_MINUTES`, .opencode/plugins/needs-input-observer.ts
  ~:316-323) -> `permission_auto_rejected` -> empty envelope / lost report.

### Verified by

- Independent audit of commit f6c84a5 (axis 6, residual 2, moderate/latent).

### Deferred by

- The developer, until a real emitted command form is observed (YAGNI on a
  fifth rule). Do not add a speculative worktree anchor now.

## Verification

- [ ] the actual emitted worktree scratch command form is captured from a real
      lane (evidence: registry row + command string)
- [ ] an anchored allow for exactly that form is added to
      `agent.coder.permission.bash` and mirrored byte-identically into
      `agent.coder-escalated.permission.bash`
- [ ] `make test-config` exit 0 with the lockstep validator green
- [ ] a worktree coder lane performs its scratch cleanup with zero
      `permission_asked` / `permission_auto_rejected` rows

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
