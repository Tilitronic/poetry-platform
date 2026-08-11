# DIA-100 - git worktrees for parallel dev sessions: isolation, branch management, merge/conflict handling, cleanup, OpenCode interaction

<!-- Analyzer-authored manifest transcribed by the coder lane (2026-08-11).
     Parallel dev infra batch ticket. OpenCode-config-adjacent but lives in
     dev-infra: worktree lifecycle scripts, branch/merge conventions,
     conflict handling, cleanup policy, OpenCode interaction model. -->

---

id: DIA-100
title: "git worktrees for parallel dev sessions: isolation, branch management, merge/conflict handling, cleanup, OpenCode interaction"
area: dev-infra
severity: Medium
status: OPEN
blocked_by: ["DIA-096"]
discovered: 2026-08-11
source: inventory
date: 2026-08-11
created: 2026-08-11
updated: 2026-08-11

# --- Session Attribution (v2 schema, optional) ---

session_id: "" # OpenCode session ID that owned this ticket
lane_id: "" # e.g. cod-1, ai--3
agent: "" # agent name (coder, reviewer, etc.)
model: "" # model ID used
parent_session_id: "" # orchestrator's session ID (populated via get-my-session-id tool)
attempts: 0 # how many delegations attempted
lease_expires_at: "" # ISO-8601; set on DISPATCHED, cleared on COMPLETE
files_touched: [] # list of file paths modified
artifacts: [] # list of artifact references (commits, test outputs)
evidence: [] # list of evidence URIs (messages.md#row, registry.jsonl#seq)

---

## Description

Implement the worktrees-only parallel model (DIA-073 option d, adopted by
developer decision 2026-08-09). Covers: (a) worktree creation/teardown scripts
(orchestrator-managed); (b) branch naming convention
(feature/<ticket>-<short-name>); (c) merge strategy (squash-merge to main
after review, or rebase-merge); (d) conflict handling (lane resolves if
simple, escalate to developer if complex); (e) cleanup policy (auto-delete
worktree after merge, keep branch for rollback window); (f) OpenCode
interaction (each worktree = separate .opencode/session/ dir, zero handoff
coordination needed); (g) orchestrator-managed worktrees (orchestrator
dispatches @coder to create/teardown). Note: worktrees skill exists at
~/.config/opencode/skills/worktrees/SKILL.md - verify and reuse.

### Investigation requirements

1. Verify worktrees skill covers creation/teardown/merge.
2. Define branch naming convention aligned with DIA-074 (human-readable names).
3. Design merge workflow (lane completes -> reviewer -> squash-merge).
4. Define conflict escalation criteria.
5. Verify each worktree gets its own .opencode/session/ dir (zero coordination).

### Deliverables

- Worktree lifecycle script (create/teardown/list).
- Branch naming convention documented.
- Merge workflow documented (with worked example).
- Conflict escalation criteria.
- Orchestrator dispatch pattern for worktree creation.

## Verification

- [ ] (a) Worktree created via orchestrator-dispatched coder lane.
- [ ] (b) Feature branch pushed from worktree (DIA-096 safe-push).
- [ ] (c) Reviewer runs in worktree context.
- [ ] (d) Squash-merge to main succeeds.
- [ ] (e) Worktree auto-cleaned after merge.
- [ ] (f) Each worktree has separate .opencode/session/ (verified).

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
