# DIA-261022-mho5 - handoff apoptosis dirty-check: whitespace-only status output is now classified DIRTY (delegation-observer:840)

---

id: DIA-261022-mho5
title: "handoff apoptosis dirty-check: whitespace-only status output is now classified DIRTY (delegation-observer:840)"
area: opencode-config
severity: Medium
status: CLOSED
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-10-22
source: inventory
date: 2026-10-22
created: 2026-10-22
updated: 2026-10-22

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

Commit 7c739f19 ("fix(handoff): require trusted runtime identity") silently
changed the apoptosis dirty-tree predicate at
`.opencode/plugins/delegation-observer.ts:841` (the re-review cited :840):

- before: `(probe.stdout ?? "").trim().length > 0`
- after: `(probe.stdout?.length ?? 0) > 0`

Consequence: a whitespace-only `git status --porcelain` stdout (e.g. a bare
"\n") is now classified DIRTY (tree kept); under the trim() predicate it was
CLEAN (tree eligible for removal at Case 3). Real porcelain output is empty
for a clean tree and never whitespace-only, so the change only bites on
anomalous output - but it silently changed an irreversible-adjacent decision
(worktree removal) with no comment or test pinning the intended semantics.

Decision needed: is whitespace-only probe output DIRTY (keep the tree) or
CLEAN (remove the tree)?

Recommended option: KEEP the current length>0 classify-DIRTY semantics and
document it with a comment at the predicate. It matches the Case-2 fail-safe
doctrine already in the block header ("Probe failure is treated as dirty
(fail-safe: when unsure, keep the tree)") and worktree removal is
irreversible, so anomalous output must err toward keep.

Alternative: restore the `.trim()` predicate if whitespace-only output is to
mean clean - risk: irreversible removal on anomalous output.

## Verification

- [ ] Decision recorded in the ticket (keep+comment or restore trim) with rationale
- [ ] If keep: a comment at delegation-observer.ts:841 states the fail-safe semantics; if restore: predicate reverted
- [ ] make test-shell and bun parallel-handoff suites stay green

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
> Closed as no-op: the live predicate at .opencode/plugins/delegation-observer.ts:841 is already fail-safe (keeps the worktree); this ticket would change zero lines.
