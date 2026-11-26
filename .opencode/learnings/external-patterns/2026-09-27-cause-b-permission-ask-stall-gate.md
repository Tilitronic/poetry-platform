---
title: CAUSE B unanswered permission ask stall gate (DIA-260926-5vin)
date: 2026-09-27
ticket: DIA-260926-5vin
source: ai-specialist / ses_f1b1d0e5fffeBABPydKiZkBtfa (read-only, AGENTS.md 2.5 step 1)
verdict: GO-with-conditions
tags: permissions, coder-lane, early-termination, ask-stall, scratch-cleanup, opencode-config
---

## Problem

CAUSE B of the chronic coder-lane early-termination defect: an UNANSWERED
permission ask kills the child. Four-arm matrix (Tier-1:
.opencode/session/coder-lane-early-termination-synthesis.md:45): cod-8 (`rm`
cleanup, NO ANSWER, 300.018 s) died with a 98-character empty envelope and is
the ONLY arm carrying a `permission_auto_rejected` row; cod-9 (same class,
human ALLOW 3.9 s), cod-12 (rmdir, human REJECT 28.2 s) and cod-11 (no ask,
earlier Always Allow covered it) ALL SURVIVED. Killer = the unanswered ask
window, not rejection.

## Confirmed config ground truth (2026-09-27)

- Global ask rules that trap the cleanup: .opencode/opencode.jsonc:112
  `"rm -rf *": "ask"`, :113 `"rm *": "ask"`, :114 `"rmdir *": "ask"` (global
  bash block opens :25, catch-all `"*": "allow"` at :28, edit allow :26).
- Coder lane allow-list: agent.coder.permission.bash at
  .opencode/opencode.jsonc:328-399 - NO rm/rmdir entry (allow examples
  :348-356; deny examples :364-398). Coder-escalated mirror at :411-477.
- Creation mandate: .opencode/oh-my-opencode-slim/coder_append.md:8 (scratch
  artifacts go under `.scratch/`, never /tmp, because external-dir writes
  prompt).
- Deletion mandate reached through the coder's skill chain:
  .opencode/skills/debugging-workflow/SKILL.md:323 (throwaway prototypes
  deleted). NOTE: the claim "the coder's own system prompt mandates .scratch
  cleanup" could NOT be verified verbatim in coder.md / coder_append.md -
  record this as an unresolved wording gap, not as fact.
- Auto-reject timer is OURS, not core:
  .opencode/plugins/needs-input-observer.ts:316-323
  (`PERMISSION_STALL_TIMEOUT_MINUTES`, default 5 * 60_000 ms); expiry path
  autoRejectPermission at :411-479 (:436-439, :452-458) posts
  `{response:"reject"}` and writes the `permission_auto_rejected` row. NOT
  settable from opencode.jsonc.

## Candidates (narrowest first)

a) Anchored exact-path allows in agent.coder.permission.bash (mirror to
   coder-escalated) - RECOMMENDED, matches the developer's chosen variant (i):

   ```
   "rm -rf /workspace/.scratch/*": "allow",
   "rm -rf .scratch/*": "allow",
   "rmdir /workspace/.scratch/*": "allow",
   "rmdir .scratch/*": "allow"
   ```

   Blast radius: only rm/rmdir whose target is a .scratch path; rm/rmdir
   anywhere else still asks. `*` crosses path separators (matcher anchored on
   the leading path).
b) Scratch-cleanup wrapper script called by the lanes - existing
   `"scripts/*": "allow"` (:356) already covers it, zero new permission rules,
   preserves the overnight rm deny; costs a new script + mandate change.
c) Broad `"rm *": "allow"` - REJECTED: grants all deletions anywhere
   (`rm -rf ~`, `rm -rf /`), and agent-level rules take precedence over the
   global ask AND over the overnight deny.

## Key risks recorded

- Overnight interaction: adding the anchored allows to the coder map WILL
  override .opencode/opencode-overnight.jsonc's global `rm *` deny for
  .scratch paths, and scripts/overnight.sh validates only the global payload
  (overnight.jsonc:10-15) so it will not catch that. Decide: accept the narrow
  softening, use wrapper (b), or bump the DIA-134 baseline.
- Worktree (batch D) cwd: relative `.scratch/*` covers it; absolute worktree
  paths under .slim/worktrees/... are NOT covered by /workspace/.scratch/*.
- Config comment at .opencode/opencode.jsonc:374-376 claims the agent map
  "does NOT inherit global denies" - factually incorrect for 1.18.32 (merge +
  findLast; see the sibling gate file at :21-24).
- Upstream variant (ii): denying permission ending the turn is an
  upstream-known defect (anomalyco/opencode issues #44255, #36413, #44267,
  fetched 2026-09-27) and #31108 reports `continue_loop_on_deny` does NOT
  apply to task/subagent permissions (`Effect.orDie` at
  packages/opencode/src/session/prompt.ts ~614-621). Not verified against the
  pinned 1.18.32 binary.
- Pin: OpenCode 1.18.32 (Dockerfile.dev:30, .mise.toml:12), OMO plugin pin
  oh-my-opencode-slim@2.2.19 (.opencode/opencode.jsonc:724).
- Doc references fetched 2026-09-27: https://opencode.ai/docs/permissions/
  (last updated Sep 26, 2026).
- Pre-implementation condition from the sibling gate: run
  `opencode debug agent coder` FIRST to confirm merge semantics and rule count
  before editing.

## Open questions for implementation

1. Exact emitted command form (absolute vs relative, rm -rf vs rmdir, subpath
   vs whole dir).
2. Overnight interaction decision (above).
3. Whether whole-dir `rm -rf .scratch` (no trailing segment) needs an extra
   pattern.
4. Worktree anchoring decision.
5. Lockstep: coder and coder-escalated maps must stay byte-identical (make
   test-config validators).

## Sources

- Tier-1: .opencode/session/coder-lane-early-termination-synthesis.md:45
- Sibling gate: .opencode/learnings/external-patterns/2026-09-27-permission-asks-unattended-gate.md:21-24
- https://opencode.ai/docs/permissions/ (fetched 2026-09-27)
- anomalyco/opencode issues #44255, #36413, #44267, #31108 (fetched 2026-09-27)

## Outcome

- IMPLEMENTED: variant (i) landed in commit
  f6c84a527a9afd9582fb27b439764f4ecf43526d (anchored .scratch rm/rmdir allows
  in agent.coder.permission.bash, mirrored to coder-escalated). Independent
  audit verdict: SOUND-with-conditions; conditions C1-C3 enacted (stale
  merge-semantics comment corrected, overnight decision recorded in the ticket,
  changelog registration). The narrow overnight softening was ACCEPTED by the
  developer (all other rm stays denied); the worktree residual is DEFERRED to
  its own ticket. Functional restart smoke still pending.
