# 2026-09-10 - Reviewer immutable git envelope (DIA-260827-4q3h)

Ticket: DIA-260827-4q3h (section-2.5 step 1 learnings registration).
Status: developer APPROVED implement. Variant A selected.

## Interview Q1-Q4 (agreed)

- Q1 hook envelope: reviewer branch setup runs as a hook after
  taskSubagent, not inline in agent prompts. Envelope carries worktree
  path + fixed point so the reviewer never guesses the diff range.
- Q2 approved command contract: narrow allowlist of git commands the
  reviewer may run (rev-parse, diff, log, show, status on the pinned
  range). Everything else denied. No push, no checkout of unpinned refs,
  no mutable ref resolution at review time.
- Q3 inert + revert: setup step is inert (creates branch + marker only,
  touches no working tree content) and revertible (delete branch +
  marker restores prior state). No side effects on coder output.
- Q4 acceptance tests: gate on (a) bad-range hard block, (b) marker
  presence, (c) OID immutability, (d) fenced envelope parse. All four
  must pass before implement proceeds.

## Seam

Review hallucinates its diff range: mutable refs (HEAD, main) drift
between author and review time, so findings cite lines the author never
wrote. Root seam is late binding of the review range.

## Evidence (ai-specialist recommendation)

Variant A: reviewer-only branch created after taskSubagent.

- ctx.worktree: branch is created in the lane worktree, never in the
  shared tree, so parallel lanes cannot collide.
- FIXED_POINT marker: setup writes an explicit marker file holding the
  pinned commit OID + parent OID. Reviewer reads the marker; no ref
  lookup at review time.
- Immutable OIDs: diff/log/show run against recorded OIDs only. Mutable
  names (HEAD, branch heads, tags) are rejected by the command contract.
- Fenced envelope: hook output is a fenced block (worktree, branch,
  base OID, head OID, marker path). Orchestrator passes it verbatim to
  the reviewer lane. Unparseable envelope = lane fails closed.
- Hard-block bad ranges: empty range, reversed range, range spanning
  unrelated history, or OID mismatch vs marker all hard-block before
  review starts.

Why Variant A over inline-prompt pinning: inline text cannot enforce;
only the hook ordering (setup completes before reviewer dispatches) plus
the deny-by-default command contract makes the range tamper-proof.

## Recommendation (approved)

Implement Variant A as the section-2.5 step 2 design input:

1. Hook after taskSubagent creates reviewer-only branch + FIXED_POINT
   marker in ctx.worktree.
2. Approved git command contract enforced at the permission layer.
3. Reviewer consumes the fenced envelope only; bad ranges hard-block.
4. Step 2 design must include the four acceptance tests from Q4 and the
   revert procedure from Q3.

## Carryover

- No new runtime dependency; hook + git CLI only.
- ASCII-only per DIA-079. Single-file registration; no code touched.

## Outcome

Implemented as Variant A (hook pre-dispatch reviewer-only branch +
FIXED_POINT marker + deny-by-default git command contract + fenced
envelope). ai-auditor VERIFIED CLOSED (APPROVE: F4+F5 verified-closed;
F3 accepted as intentional contract per developer; residual
orchestratorPrompt drift non-blocking under DIA-128). Evidence:
harness 12 pass / 81 expects, test-config EXIT 0, reviewer-sections
1 passed, reviewer bash-deny intact, rollback-by-removal. Registered
in .opencode/CHANGELOG.yaml under DIA-260827-4q3h (section-2.5 step 7).
