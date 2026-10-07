# Hygiene Decision Register (planning only)

Campaign ticket: DIA-260911-4y5v.
OpenSpec change: dia-260911-4y5v-hygiene-decision-register.

This document is a PLANNING-ONLY register. It authorizes no cleanup itself.
No file is edited, deleted, moved, merged, archived, registered, or renamed
by this document. No ticket status, OpenCode configuration, agent
instruction, memory-shelf entry, or archive changes as a result of writing
this register. Every non-preserve action requires the per-row safety gates
and explicit developer approval in a later, row-by-row follow-up.

## Evidence and authority order

Source inventories (read-only audits, no files edited by any of them):

1. Architect session `ses_f6d68b31cffe4vSDgqyX7kY1dl` (authoritative).
2. AI-specialist session `ses_f6b1bae72ffeQC1XRgX6Sp1yjf`.
3. Analyzer session `ses_f6b1badc9ffeX3HtV69RY0fu0N`.

Authority rule: architect first, then AI-specialist, then analyzer. The
architect's FAIL-for-hygiene / PASS-for-preservation verdict is preserved as
the primary decision when findings disagree. Any disagreement with an
architect preservation decision, and any claim whose exact path or exact edit
cannot be traced to an audit record, is recorded as `preserve/pending` until
the developer resolves it. Lower-priority disagreements are preserved below,
never averaged into a destructive action.

Retrieval note (2026-09-12): the three sessions' row-level inventories were
not retrievable as files at register composition time (no partial-result
artifacts found for these session IDs; only summaries and the design
reconciliation constraints were available). Per the design risk rule, no
action target is reconstructed from a summary alone: every claim without a
verifiable exact path or exact edit is `preserve/pending`.

## Action register

Closed classification set: `delete`, `compress`, `fix`, `merge`, `archive`,
`preserve`. `preserve/pending` is a preserve status, not a seventh class.
Status column allows only `planned` or `preserve/pending`.

| Path                                                                                                                                                                                     | Classification | Source verdict                                                                                                                                                                                                                | Priority | Exact action                                                                                                      | Safety gate                                                                                                                                                                                                            | Status           |
| ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- | ----------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------- |
| `.opencode/learnings/BOTTLENECK-ANALYSIS-2026-09-10.md`                                                                                                                                  | archive        | Architect archive candidates; bottleneck reports are archive candidates, not delete candidates                                                                                                                                | pending  | Archive to a verified destination; destination not specified in the retrievable record, so the move target is TBD | Full per-row gate: inverse-reference evidence; `scripts/tickets` proof of no related OPEN ticket; archive destination must exist before move; Git-tracked change for rollback; explicit developer approval before move | preserve/pending |
| `knowledge/res036-dcp-vs-headroom/res036-dcp-vs-headroom-conspect.md`                                                                                                                    | preserve       | AI-specialist constraint: res036-res038 stay pending while DIA-260821-8kpc is OPEN; live check 2026-09-12 shows DIA-260821-8kpc CLOSED, so the blocking condition cleared but reclassification still needs developer approval | pending  | Preserve; reason: prior ticket-linked constraint, reclassification pending developer decision                     | N/A (preserve); reclassification to any non-preserve class requires all five gates plus developer approval                                                                                                             | preserve/pending |
| `knowledge/res037-headroom-review-video-validation/res037-headroom-review-video-validation-conspect.md`                                                                                  | preserve       | AI-specialist constraint, same as res036 above                                                                                                                                                                                | pending  | Preserve; reason: same as res036 above                                                                            | N/A (preserve); same reclassification rule as res036 above                                                                                                                                                             | preserve/pending |
| `knowledge/res038-caveman-output-token-economy/res038-caveman-output-token-economy-conspect.md`                                                                                          | preserve       | AI-specialist constraint, same as res036 above                                                                                                                                                                                | pending  | Preserve; reason: same as res036 above                                                                            | N/A (preserve); same reclassification rule as res036 above                                                                                                                                                             | preserve/pending |
| Architect P0 light edits (exact paths pending retrieval from `ses_f6d68b31cffe4vSDgqyX7kY1dl`)                                                                                           | preserve       | Architect authoritative edits; exact paths/edits not available in the retrievable record                                                                                                                                      | pending  | Preserve; reason: exact paths and literal edits pending retrieval, nothing reconstructed from summary             | N/A (preserve); reclassification requires exact edit text plus all five gates plus developer approval                                                                                                                  | preserve/pending |
| Architect delete list incl. three mechanical delete candidates (exact paths pending retrieval from `ses_f6d68b31cffe4vSDgqyX7kY1dl` / `ses_f6b1bae72ffeQC1XRgX6Sp1yjf`)                  | preserve       | Architect delete list; AI-specialist mechanical delete candidates remain delete candidates ONLY if their exact paths are present in its audit, which is unverified here                                                       | pending  | Preserve; reason: exact paths unverified, so the delete-candidate condition is not met                            | N/A (preserve); reclassification to delete requires exact paths plus all five gates plus developer approval                                                                                                            | preserve/pending |
| Architect merge table (exact paths/targets pending retrieval from `ses_f6d68b31cffe4vSDgqyX7kY1dl`)                                                                                      | preserve       | Architect authoritative merges; exact merge targets not available in the retrievable record                                                                                                                                   | pending  | Preserve; reason: merge targets pending retrieval, no inferred target                                             | N/A (preserve); reclassification to merge requires exact target plus all five gates plus developer approval                                                                                                            | preserve/pending |
| Architect compress list, incl. memory-shelf/index compression (exact paths pending retrieval from `ses_f6d68b31cffe4vSDgqyX7kY1dl`)                                                      | preserve       | Architect authoritative compress list; exact paths not available in the retrievable record                                                                                                                                    | pending  | Preserve; reason: exact paths pending retrieval                                                                   | N/A (preserve); reclassification to compress requires exact paths plus all five gates plus developer approval                                                                                                          | preserve/pending |
| Architect shelf repairs and agent-document edits, incl. the incorrect permission-precedence comment (exact paths pending retrieval from `ses_f6d68b31cffe4vSDgqyX7kY1dl`)                | preserve       | Architect authoritative repairs/edits; exact paths and literal edits not available in the retrievable record                                                                                                                  | pending  | Preserve; reason: exact paths and literal edits pending retrieval                                                 | N/A (preserve); reclassification to fix requires exact edit text plus all five gates plus developer approval                                                                                                           | preserve/pending |
| Analyzer P0-P3 refresh/register/archive/merge plan, incl. stale analyzer-escalated model docs and routing registry (exact paths pending retrieval from `ses_f6b1badc9ffeX3HtV69RY0fu0N`) | preserve       | Analyzer plan reconciled against architect rows, not copied as unscoped work; exact paths not available in the retrievable record                                                                                             | pending  | Preserve; reason: reconciliation-only, exact paths pending retrieval                                              | N/A (preserve); reclassification requires exact paths plus all five gates plus developer approval                                                                                                                      | preserve/pending |
| Analyzer two unregistered live directory warnings (exact paths pending retrieval from `ses_f6b1badc9ffeX3HtV69RY0fu0N`)                                                                  | preserve       | Analyzer warnings; orphaned knowledge directories require an owner ticket, warnings alone are not closure evidence                                                                                                            | pending  | Preserve; reason: registration or explicit deferral needs an owner ticket first                                   | N/A (preserve); reclassification requires owner ticket plus exact paths plus all five gates plus developer approval                                                                                                    | preserve/pending |

Disagreements preserved (not resolved here): bottleneck reports stay archive
candidates rather than delete candidates; res036-res038 stay pending despite
the cleared ticket condition until the developer decides; the analyzer plan
is not adopted as unscoped work where it goes beyond architect rows.

## Per-row execution checklist (for later follow-up only)

For any row proposed to move from `preserve/pending` (or `planned`) to
execution, complete in order:

1. Inverse-reference gate: search for inbound references to the path; remove
   or update every result and record the evidence. Any unresolved reference
   blocks the action.
2. Ticket-status gate: run `scripts/tickets` (e.g. `scripts/tickets show`
   / `scripts/tickets search`) to prove no related ticket is OPEN. An OPEN
   ticket returns the row to `preserve/pending`.
3. Archive gate (archive actions only): verify the destination exists before
   moving the source.
4. Rollback gate: perform the approved action only as a Git-tracked change,
   so a revert restores the prior state.
5. Developer-approval gate: attach the evidence from gates 1-4 and obtain
   explicit developer approval for the row before any delete, move, merge,
   archive, or other non-preserve action.

Rollback rule: revert the Git-tracked action commit; restore a moved item to
its original path if required; then re-run the inverse-reference and
ticket-status checks and record the results on the row.

## Maintenance

Add rows only under the same authority and gate rules; never silently rewrite
a prior decision. If this register misstates an audit decision, roll back by
reverting its introducing commit. This register performs no destructive
operation itself.
