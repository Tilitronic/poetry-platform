# DIA-096 - Git push permission policy - allow push, restrict destructive commands and main

<!-- Campaign c-20260809-residual-closure, session 7. Filed by the coder lane
     per the developer directive (2026-08-11): "I think we need to allow push,
     create git skill or rules, and restrict only destructive dangerous git
     commands and also restrict pushing to main." The immediate trigger: the
     OpenCode permission config hard-denies `git push *`, so coder lanes cannot
     push; the developer must push manually. This is an OpenCode-config change
     (S10-routed: ai-specialist gate -> design -> implement via coder ->
     make test-config -> ai-auditor review -> register) plus possible git
     skill/rules authoring. Related: DIA-094 (husky pre-commit / docker gate),
     DIA-063 (ticket gate), DIA-095 (S10-routed AGENTS.md/config change
     pattern). Status: OPEN, needs fix. -->

---

id: DIA-096
title: "Git push permission policy - allow push, restrict destructive commands and main"
area: opencode-config
severity: Major
priority: HIGH
status: OPEN
blocked_by: [] # cross-referenced in Description: DIA-094, DIA-063, DIA-095
discovered: 2026-08-11
source: developer-directive
date: 2026-08-11
created: 2026-08-11
updated: 2026-08-11

# --- Session Attribution (v2 schema, optional) ---

session_id: "ses_00f690090ffeu3JT7wh1hacWzV"
lane_id: "coder"
agent: "coder"
model: "deepseek-v4-flash"
parent_session_id: ""
attempts: 0
lease_expires_at: ""
files_touched: ["docs/dev-infra-audit/tickets/DIA-096-git-push-permission-policy.md"]
artifacts: []
evidence: ["OpenCode permission config hard-denies `git push *` (observed session 7: coder lane push of omo-slim-changes blocked, developer forced to push manually)", "current permission state allows destructive git commands by default unless denied elsewhere"]

---

## Description

**Summary:** the developer directive (2026-08-11) asks for a git push
permission policy: lanes should be able to push safely (non-main branches),
destructive/dangerous git commands should be restricted, and pushing to main
should be restricted to manual developer pushes only. The immediate trigger is
the OpenCode permission config hard-denying `git push *` (observed in session 7
on branch `omo-slim-changes`: the coder lane push was blocked and the developer
had to push manually). The current state also allows destructive git commands
by default unless denied elsewhere, so the policy must enumerate the safe vs
destructive split rather than relying on implicit defaults.

### Developer directive (2026-08-11)

"I think we need to allow push, create git skill or rules, and restrict only
destructive dangerous git commands and also restrict pushing to main."

### Problem

- OpenCode permission config hard-denies `git push *`, so coder lanes cannot
  push feature branches to origin; the developer must push manually (observed
  session 7, branch `omo-slim-changes`).
- Destructive git commands (force push / `push --force`, `reset --hard`,
  `branch -D`, etc.) are allowed by default unless denied elsewhere - no
  explicit deny list exists.
- Pushing to `main` is not separately restricted - there is no rule that only
  the developer may push to main manually and lanes may not.

### Goal

1. Lanes can push safely (feature branches, non-main branches) to origin.
2. Destructive dangerous git commands are denied for lanes.
3. Push to main is restricted: only developer manual push to main; no lane push
   to main.
4. The change routes through the S10 workflow (ai-specialist gate -> design ->
   implement via coder -> make test-config -> ai-auditor review -> register)
   because it edits OpenCode permission config / git skill or rules files.

## Scope

### (a) Allow git push for safe operations

- Update the OpenCode permission config (or provide a git skill/rules file)
  so `git push` of non-main branches is permitted for lanes.
- The exact mechanism (permission rule edit vs new git skill/rules file) is a
  design decision for the fix; both options are in scope.

### (b) Restrict destructive dangerous git commands

Enumerate the safe vs destructive split. Destructive commands to deny:

- `git push --force` / `git push -f` / force-with-lease variants (as lane
  operation)
- `git push origin main` / any push that would reach `main`
- `git reset --hard`
- `git branch -D` (force-delete branch)
- `git clean -fd` / `git clean -fdx`
- `git checkout -- .` / `git restore --staged .` (discard-work variants)
- `git rebase --continue`-adjacent destructive flows that rewrite history
- `git filter-branch` / `git filter-repo` (history rewrite)
- `git tag -d` / deleting remote tags (if exposed to lanes)
- `git push --delete` (remote branch/tag deletion)

Safe operations to allow:

- `git push` (feature branch to its own upstream)
- `git push -u origin <feature-branch>`
- `git pull` / `git fetch`
- `git commit` / `git add`
- `git status` / `git diff` / `git log` (read-only)
- `git merge` / `git rebase` on non-main branches (normal flow; force/rewrite
  variants stay denied)
- `git branch` (create/list, non-force)

### (c) Main-branch push restriction

- Only the developer may push to main (manual push).
- No lane may push to main - any push targeting `main` is denied at the
  permission/config level, not merely discouraged.

### (d) S10 route

This is an OpenCode-config change (permission config and/or git skill/rules
authoring), so it follows the AI Devtools Modernization Workflow (S10):

1. **Gate** - dispatch `@ai-specialist` (read-only research on the current
   permission config state and best-practice git-permission patterns).
2. **Review & decide** - user reviews findings (practice-protected).
3. **Design** - `@architector` if non-trivial; every decision traces to a
   best-practice rule.
4. **Implement** - `@coder` applies the approved design.
5. **Validate** - `make test-config` must exit 0; schema/JSONC validity.
6. **Independent review** - `@ai-auditor` reviews the change.
7. **Register** - update CHANGELOG + learnings outcome field.

## Dependencies

- **DIA-094** - husky pre-commit / docker gate: this policy change must not
  weaken the commit gate; the pre-commit hook still runs live (never
  --no-verify, hard rule DIA-094).
- **DIA-063** - ticket gate: no engineering work starts without a DIA ticket;
  this ticket satisfies that gate for the git push permission policy work.
- **DIA-095** - the S10-routed AGENTS.md/config change pattern this ticket
  follows (project-ops reference was filed and fixed through the same
  ai-specialist -> design -> implement -> validate -> audit -> register route).

## Impact

- Unblocks coder lanes from pushing feature branches (removes the manual
  developer-push bottleneck observed in session 7).
- Adds an explicit destructive-command deny list where today the behavior
  relies on implicit defaults.
- Protects `main` from lane pushes while keeping the developer's manual push
  path intact.
- Requires config/skill changes that must pass `make test-config` and the
  ai-auditor review before they are considered done.

## Acceptance criteria

- Coder lane can push a feature branch to origin (e.g. `git push -u origin
<feature-branch>` succeeds from a lane session).
- Force-push from lanes is denied (`git push --force` / `-f` blocked).
- Push-to-main from lanes is denied (`git push origin main` blocked).
- Developer manual push to main still works (the deny rules target lanes, not
  the developer's own terminal).
- `make test-config` exits 0 after the config change (validate-opencode-config
  passes).
- No regression in existing deny rules (other hard-denies remain intact).

## Verification

- Reproduce the gap: from a lane session, attempt `git push -u origin
<feature-branch>` and observe the permission deny (current state); confirm
  the developer cannot delegate push work to lanes.
- Confirm the current deny: grep the OpenCode permission config for
  `git push` and note the deny rule (observed session 7: `git push *` denied).
- After fix:
  1. From a lane session, push a feature branch to origin - expect success.
  2. From a lane session, attempt `git push --force` and `git push origin
main` - expect deny messages.
  3. From the developer terminal, push to main - expect success (manual path
     unaffected).
  4. Run `make test-config` - expect exit 0.

## Fix

> To be filled at fix time. Proposed options (from the coder lane, 2026-08-11):

### Option A - Edit the OpenCode permission config directly

Narrow the current `git push *` hard-deny in the OpenCode permission config
(allow safe push patterns, deny force push / push-to-main / destructive
commands explicitly).

- Pros: single source of truth; permission is enforced at the tool level with
  no extra boot-step dependency.
- Cons: config-only - no guidance file; permission rules can be hard to express
  precisely for argument-matched commands; config edits route through S10.

### Option B - Author a git skill/rules file (`.opencode/skills/git-permissions/`

or a rules file) plus minimal permission config

Create a git skill or rules file that documents the safe vs destructive split,
the main-push restriction, and the manual-push-only rule for main; pair it
with the permission config changes that enforce the denies.

- Pros: gives lanes (and the developer) an auditable reference for what is
  allowed/denied and why; the skill/rules file is the documentation layer while
  the config enforces it.
- Cons: two artifacts to keep in sync; skill files alone do not enforce -
  the permission config must still carry the actual denies.

### Recommendation

**Option A** (config edit) is the minimum viable fix for the immediate trigger
(unblock lane push + deny destructive/main-push). **Option B** (git skill or
rules file) is recommended as the companion documentation layer per the
developer directive ("create git skill or rules") - a small
`.opencode/skills/git-permissions/SKILL.md` (or rules file) that enumerates
the safe vs destructive split and the main-push rule, enforced by the config
deny rules. Whichever option is chosen, the S10 route applies and `make
test-config` must exit 0.

## Re-verify

> To be filled at re-verify time. Expected: a lane session can push a feature
> branch to origin; `git push --force` and `git push origin main` from lanes
> are denied; developer manual push to main works; `make test-config` exits 0;
> no existing deny rules regressed. Record the actual gate output/exit code.
