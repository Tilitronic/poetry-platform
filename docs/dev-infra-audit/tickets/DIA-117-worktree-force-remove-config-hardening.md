# DIA-117 - git worktree remove --force missing from DIA-096 permission deny list - config hardening (DIA-100 FALSIFICATION-1)

<!-- Follow-up ticket to DIA-100 (FIXED), filed from the DIA-100 two-axis
     review (reviewer report, FALSIFICATION-1, 2026-08-12). Child work of
     DIA-100: the worktree lifecycle work is done, but a defense-in-depth gap
     in the OpenCode permission config survived review. This ticket hardens the
     config layer; the script-side guard (scripts/worktrees.sh WORKTREES_FORCE
     env barrier) stays as-is. OpenCode-config change -> routes through the
     section-10 chain (ai-specialist gate -> owner decision -> design ->
     coder -> make test-config exit 0 -> restart-verify -> ai-auditor ->
     CHANGELOG) when implementation starts. -->

---

id: DIA-117
title: "git worktree remove --force missing from DIA-096 permission deny list - config hardening (DIA-100 FALSIFICATION-1)"
area: opencode-config
severity: Major
status: OPEN
blocked_by: [] # DIA-100 is FIXED, not blocking; child of DIA-100 (see Description)
discovered: 2026-08-12
source: reviewer-report
date: 2026-08-12
created: 2026-08-12
updated: 2026-08-12

# --- Session Attribution (v2 schema, optional) ---

session_id: "ses_00a25a978ffeWyL5TCY3rDkmnN"
lane_id: ""
agent: "coder"
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: ""
files_touched: ["docs/dev-infra-audit/tickets/DIA-117-worktree-force-remove-config-hardening.md", "docs/dev-infra-audit/tickets/README.md"]
artifacts: []
evidence: []

---

## Description

**Reviewer finding F1 (DIA-100 two-axis review, FALSIFICATION-1, quoted):**
the `WORKTREES_FORCE=1` env-var barrier in `scripts/worktrees.sh` `cmd_remove`
is convention-only — a lane invoking `git worktree remove --force` directly
bypasses the guard because the DIA-096 OpenCode permission deny list covers
`git clean -f*` and `git branch -D *` but NOT `git worktree remove --force`.

**Why it matters:** DIA-100's force-remove path (used to evict a dirty
worktree) maps semantically to DIA-096-denied destructive operations — forced
removal discards uncommitted work inside the worktree the same way `git clean
-f*` / `git branch -D` do. The script-side barrier only gates agents that go
through the script; the OpenCode permission layer is the only enforcement
surface that gates ALL agent bash calls. Today a lane can run
`git worktree remove --force <path>` directly and discard another lane's
uncommitted changes — a real parallel-dev isolation risk, not an active
exploit (lanes are expected to follow the script, so severity is Major config
hardening, defense-in-depth, not Blocker).

**Developer decision (2026-08-12):** HARDEN via config — add
`git worktree remove --force` (and force variants) to the DIA-096 deny list
(defense-in-depth), keep the script-side guard in `scripts/worktrees.sh`
as-is. No script change.

**KEY RISK to resolve during section-10 Phase 1 (ai-specialist gate):** the
config deny must NOT block `worktrees.sh`'s OWN legit force-remove path — the
script itself runs `git worktree remove --force "$path"` inside `cmd_remove`
when `WORKTREES_FORCE=1` (scripts/worktrees.sh line 250). The section-10
research lane must determine the correct scoping before implementation:
agent-level deny vs global deny, and the allow-list for the
developer/orchestrator path (who may legitimately set `WORKTREES_FORCE=1` and
run the script's force-remove). A naive blanket deny would either (a) break
the developer's own scripted force-remove, or (b) be bypassable by invoking
git directly. DIA-096's push-policy precedent (global blanket deny + project
allow-list, agent-tool-call-only enforcement) is the reference pattern.

**Scope of the deny (candidate, refine at fix time):**

- `git worktree remove --force *`
- `git worktree remove -f *`
- Option-order variants (`git worktree remove <path> --force`), mirroring the
  DIA-096 option-order lesson
- Keep `git worktree remove <path>` (non-force) allowed — it refuses dirty
  worktrees and is the script's normal path

**Reference files:** `scripts/worktrees.sh` lines 242-254 (force-remove
branch; comment at lines 243-245 explicitly notes the DIA-096 deny-list gap);
`.opencode/opencode.jsonc` DIA-096 deny section (git clean -f* / git branch
-D * present, `git worktree remove --force` absent);
`.opencode/skills/git-permissions/SKILL.md` (safe vs destructive split —
needs the worktree-force entry added to the destructive list);
`docs/dev-infra-audit/worktree-conventions.md` (DIA-096 mapping section).

## Verification

- Reproduce the gap: grep the OpenCode permission config for the DIA-096 deny
  list and confirm `git worktree remove --force` is absent while `git clean
-f*` and `git branch -D *` are present.
- After fix:
  1. From a lane session, attempt `git worktree remove --force <path>` and
     `<path> --force` - expect permission deny (defense-in-depth enforced at
     the config layer, not just the script guard).
  2. The developer's legit scripted force-remove still works: with
     `WORKTREES_FORCE=1`, `scripts/worktrees.sh remove --force <path>` exits 0
     (the allow path resolved per the section-10 scoping decision).
  3. Non-force `git worktree remove <path>` (and `scripts/worktrees.sh remove`)
     still allowed.
  4. `make test-config` exits 0; schema/JSONC validity.
  5. No regression in existing DIA-096 deny rules.
  6. ai-auditor review (section-10 Phase 6) + CHANGELOG registration
     (Phase 7).

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
