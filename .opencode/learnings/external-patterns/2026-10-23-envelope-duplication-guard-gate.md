# Envelope-duplication guard gate: pre-spawn check is feasible with an off-by-one correction - DIA-261023-d6b9

Date: 2026-10-23
Source: ai-specialist gate research (read-only, AGENTS.md section 2.5 phase 1-2) for campaign ticket DIA-261023-d6b9
Ticket: DIA-261023-d6b9 'pre-spawn duplicate-envelope guard gate research'

## Findings

1. Seam located: delegation-observer.ts:1814-1937 (tool.execute.before).
   Marker capture :1833-1837 matchAll(/FIXED_POINT:\s*(\S+)/gi) over
   description+prompt; failEnvelope closure :1838-1853 (row
   reviewer_envelope_blocked + rollbackAdaptiveDispatch + throw prefixed
   "REVIEWER ENVELOPE:"); zero/multi :1854-1861; ref resolve + merge-base +
   diff/log + empty-range :1862-1913; injection :1914-1927, fence
   "```IMMUTABLE_GIT_ENVELOPE" :1915, written into taskArgRecord.prompt
   :1927 (the child prompt).
2. Scope: reviewer-only. Predicate :1826 (input.tool === "task" &&
   taskSubagent === "reviewer"); :1824 "Reviewer-only: every other lane
   skips this block (inert)". The token has no other code writer, so a
   non-reviewer payload never legitimately carries it. Guard stays
   reviewer-scoped; other lanes quote the token in doc/lesson prose.
3. Legitimate token count in authored parent dispatch text is 0 (the hook
   only writes it into the outgoing prompt at :1927); 1 in the final child
   prompt for reviewer, 0 for others. A parent-side occurrence is never
   legitimate.
4. Test seam: envelope logic is inline (failEnvelope is a local closure);
   the pure-helper precedent is lib/routing-gate.ts:118
   evaluateRoutingGate, imported at delegation-observer.ts:95-100 and
   tested by scripts/__tests__/routing-order-gate.test.mjs:30-37 (imports
   ../../.opencode/plugins/lib/routing-gate.ts directly, node:test,
   make test-config). A pure evaluateEnvelopeDuplication(dispatchText) is
   unit-testable without spawning a child. Constraint:
   validate-plugin-structure.bats Gate A (:81-99) requires new lib symbols
   to be referenced outside import. Envelope behaviour suite:
   __tests__/reviewer-immutable-git-envelope.test.mjs (real plugin via
   harness + real git temp repos).
5. Advisory rows are feasible at this phase: registry.ts:946 appendRow(row:
   Record<string, unknown>) is schemaless ({...row} + seq + timestamp);
   tool.execute.before already writes reviewer_envelope_blocked / a1_violation
   / gate_blocked / ROUTING_VIOLATION rows. But drop the count==1 warn: under
   pre-injection counting count==1 IS the defect (throw); under
   post-injection counting count==1 is the normal injected block (a warn
   would fire on every reviewer dispatch). Note: the live format_warn write
   appears dropped at :2656 (formatter result discarded) - do not cite it
   as a live precedent.
6. Performance: one bounded string/regex scan; the same hook already runs
   WORKTREE matchAll (:145-147), FIXED_POINT matchAll (:1833), ticket-gate
   matchAll+match (:2128-2144) and up to five spawnSync git calls
   (:1867-1901). Negligible.
7. Risks: (a) counting the bare token post-injection false-positives on any
   review range touching token-bearing files (delegation-observer.ts:1915,
   the envelope test, reviewer.md, lessons.md:3293-3301, learnings records)
   - same class as 2026-10-22-cs3v-envelope-append-carrier; (b) the proposal
   as worded ("more than once" over dispatch text) is off by one if counted
   pre-injection - occurrences 1-3 each had ONE authored block; (c) the
   (\S+) "capture competition" note in
   2026-10-22-orchestrator-envelope-fabrication.md is imprecise: a
   fabricated block cannot win the FIXED_POINT capture without containing
   "FIXED_POINT:", which the existing :1857 check would already block; the
   real (\S+) competitor is extractWorktreeMarker's case-insensitive
   /WORKTREE:\s*(\S+)/gi (:146) matching the envelope's own "worktree:"
   line (:1916) on the tool.execute.after re-scan (:2744-2752); (d) the
   ticket gate scans post-injection text (buildDispatchText :2127), so
   injected diff/log DIA-id literals can feed ticket inference (:2145-2154);
   (e) no test counts failEnvelope paths or pins error text beyond
   "REVIEWER ENVELOPE:" (reviewer-immutable-git-envelope.test.mjs:289 et
   al.) - a new failEnvelope throw breaks nothing.

## Verdict

GO, Variant A (recommended): pure evaluateEnvelopeDuplication counting
line-anchored fence openers over the AUTHORED description+prompt BEFORE
:1927; throw at count >= 1 via the existing failEnvelope closure (keeps
reviewer_envelope_blocked row + rollback + "REVIEWER ENVELOPE:" prefix);
reviewer-scoped only; drop the count==1 warn; tests = a node:test suite in
the routing-order-gate style plus one harness scenario in
reviewer-immutable-git-envelope.test.mjs. Equivalent to the record's
"more than once" (post-injection count == authored count + 1) but immune to
envelope-diff/log contamination. Record-only gate note: not implemented
here; implementation routes through the orchestrator (coder + ai-auditor
per AGENTS.md section 2.5), and the chosen variant goes in the ticket
UPDATE block (EBDV DIA-115).
