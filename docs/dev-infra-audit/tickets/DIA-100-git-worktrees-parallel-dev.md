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
status: FIXED
blocked_by: ["DIA-096"]
discovered: 2026-08-11
source: inventory
date: 2026-08-11
created: 2026-08-11
updated: 2026-08-12

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
- [x] (f) Each worktree has separate .opencode/session/ (verified).

## Fix

> Filled at fix time (2026-08-12, coder lane, DIA-100 "first" decision from
> Session 15; blocker DIA-096 CLOSED - confirmed clear).

**Investigation findings** (ticket requirements 1-5):

1. **Worktrees skill** (`~/.config/opencode/skills/worktrees/SKILL.md`)
   covers the ORCHESTRATION protocol: pre-flight checklist, user-confirmation
   requirements, lane planning/ownership, integration and cleanup phases,
   `.slim/worktrees.json` metadata. It does NOT cover: project branch naming,
   project worktree location, executable lifecycle scripts, a merge strategy
   choice, conflict escalation criteria, the DIA-096 safe/destructive
   mapping, or an orchestrator dispatch template. Those deltas are built here
   (scripts + conventions doc); the skill protocol is referenced, not
   duplicated.
2. **Branch naming** aligned with DIA-074 (human-readable names):
   `feature/<ticket>-<short-name>` (e.g. `feature/DIA-100-worktree-lifecycle`).
3. **Merge workflow**: squash-merge to main after review (rationale in the
   conventions doc: linear main, DIA-096 main-push is developer-only anyway,
   rebase-merge would need lane force-push which is denied).
4. **Conflict escalation**: lane resolves when hunks are its own +
   non-overlapping + <=3 hunks + both intents understood; escalates to the
   developer on semantic overlap, generated/derived artifacts (lockfiles,
   .mise.toml, Dockerfile ARGs), >3 hunks, or unknown other-side intent.
5. **.opencode/session isolation** verified: git worktree produces a separate
   working directory, `.opencode/session/` is git-ignored, OpenCode writes
   session state per cwd; `create` materializes the dir and asserts it is a
   real dir (not a symlink). End-to-end verified on a throwaway worktree.

**Deliverables**:

- `scripts/worktrees.sh` — lifecycle CLI (`create` / `remove` / `list`).
  `remove` keeps the branch (rollback window), refuses dirty worktrees
  unless `--force`, and `--force` requires `WORKTREES_FORCE=1`
  (developer-only; lanes never set it — DIA-096 mapping documented).
- `scripts/__tests__/worktrees.bats` — 11 bats cases (real isolated git repo
  fixture under `$BATS_TEST_TMPDIR`; FAKE-mock invariant preserved).
- `scripts/__tests__/bats-wrapper.sh` — added `worktrees.sh` to the bash -n
  syntax list.
- `.gitignore` — added `.worktrees/` (DIA-100 section).
- `docs/dev-infra-audit/worktree-conventions.md` — branch naming, worktree
  location, lifecycle CLI, squash-merge workflow with worked example,
  conflict escalation criteria, cleanup policy, DIA-096 mapping, session
  isolation mechanism, orchestrator dispatch templates.
- This ticket: status OPEN -> FIXED.

**Verification evidence**:

- Implementation commit: `a387f72`
  (feat(dev-infra): worktree lifecycle CLI + conventions for parallel dev
  model, DIA-100); ticket-evidence follow-up: see git log for DIA-100.
- `make test-shell` exit 0 (worktrees.bats T1-T11 all ok, suite 204 ok).
- End-to-end trace (origin-safe throwaway branches, never pushed, removed
  before close): create -> list -> .opencode/session isolation check ->
  remove; both throwaway branches deleted with the safe `git branch -d`
  (never pushed).
- Verification item (b) not exercised: throwaway branches were never
  pushed; first-worktree adoption will validate the safe-push path.
- Verification items (a)-(e) deferred to workflow-adoption time: they
  require an active worktree lane in the adopted parallel-dev workflow
  (orchestrator-dispatched creation, safe-push from a worktree,
  reviewer-in-worktree, squash-merge, post-merge cleanup). Item (f) is
  verified by the throwaway-worktree trace above and by bats T1.
- Note: worktrees created from `main` currently print the
  "not git-ignored in the worktree" warning because the `.opencode/session/`
  and `.worktrees/` gitignore entries are committed on omo-slim-changes but
  not yet on main; they land on main when omo-slim-changes is merged. The
  isolation mechanism itself holds regardless.
- Deferred: tickets/README.md DIA-100 row + counts update (the file carries
  uncommitted DIA-115 edits from another lane; not committed per
  no-other-lane-files rule).

## Re-verify

> To be filled at re-verify time.
