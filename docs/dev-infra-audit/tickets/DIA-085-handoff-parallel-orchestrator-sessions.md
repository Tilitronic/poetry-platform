# DIA-085 — investigate parallel orchestrator sessions — handoff coordination between them (session IDs, worktrees, handoff-file ownership)

<!-- Filed by the docs lane (code-executor re-route) 2026-08-10. DIA-073 (basic
     handoff parallel coordination) is closed; this ticket extends to real
     parallel orchestrator sessions with separate worktrees/checkouts. -->

---

id: DIA-085
title: "investigate parallel orchestrator sessions — handoff coordination between them (session IDs, worktrees, handoff-file ownership)"
area: docs
severity: Medium
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
discovered: 2026-08-10
source: inventory
date: 2026-08-10
created: 2026-08-10
updated: 2026-08-10

# --- Session Attribution (v2 schema, optional) ---

session_id: "ses_0133de7fdffeKc3ClhE6fqFy0X"
lane_id: "docs"
agent: "code-executor"
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: ""
files_touched: ["docs/dev-infra-audit/tickets/DIA-085-handoff-parallel-orchestrator-sessions.md"]
artifacts: []
evidence: []

---

## Description

Investigate how to run parallel orchestrator sessions effectively (if possible)
and how handoff coordination works between them (session IDs, worktrees,
handoff-file ownership). DIA-073 covered basic handoff parallel coordination and
is closed; this ticket extends to real parallel orchestrator sessions with
separate worktrees/checkouts.

## Verification

- [ ] Research/verify feasibility of running 2+ orchestrator sessions in parallel (separate worktrees/checkouts).
- [ ] Document handoff coordination mechanics: session IDs, worktrees, handoff-file ownership rules.
- [ ] Run a minimal two-session parallel smoke and confirm handoff files do not collide or clobber.

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
