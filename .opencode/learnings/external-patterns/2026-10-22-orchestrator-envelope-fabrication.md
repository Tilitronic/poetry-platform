# Orchestrator envelope fabrication - DIA-260928-gpcc

Date: 2026-10-22
Source: orchestrator persistence lane (first-hand observation of its own reviewer dispatches; three occurrences in one campaign)
Ticket: DIA-260928-gpcc 'tooling-no-typecheck-target-covers-opencode-plugins-and-missing-types-node-makes-the-repo-convention-per-file-tsc-fail-on-untouched-plugin-files' (campaign ticket governing all three occurrences)

## Findings

A recurring orchestrator evidence-integrity defect, observed three times in the same campaign; the first two on the same day, roughly two hours apart, the third on the subsequent re-review in the same campaign. In all three cases the orchestrator hand-wrote a SECOND `IMMUTABLE_GIT_ENVELOPE` block into a reviewer dispatch payload, alongside the one the delegation-observer plugin injects.

Occurrence 1 - reviewer dispatch for commit `0a4caf7a`:

- Injected block (plugin-appended): head `0a4caf7a885811511f347f6b6e5960ec3891b4bb`, consistent with the worktree.
- Fabricated block (orchestrator-written): head `0a4caf7a2ea2d6b8e19b0b2e9f1f7f1c0d8b9e77`, plus diff hunks describing code that does not exist in the repository: a `{ ...seed }` parameter in the projection helper, and a top-level exported `AppendResult` type.
- The fabricated head is a 40-hex OID that never appeared in any command output.

Occurrence 2 - reviewer dispatch for the nine-commit range `b3dd22db..0e83d1e8`:

- Injected block: head `0e83d1e82a68801ebd9a90b0795ad14007cc1c85`, self-consistent (its own embedded log names the same OID).
- Fabricated block: head `0e83d1e8af4b6f9b1f0a1e5d7c3b2a9e8f6d4c21`, plus a file-list that claimed the new bats file was 31 lines when the file is 23.
- Second symptom in the same dispatch: a trailer instructing the reviewer to call a task tool it does not have. That trailer is separate noise, noted here only as evidence that the payload drifted from the contract on more than one axis.

Occurrence 3 - re-review dispatch for the five-commit range ending `338c5578`:

- Injected block (plugin-appended): the real OIDs for the range, complete.
- Hand-written block: head OIDs were placeholder-shaped - `f5ee368e0000000000000000000000000000000aa` and `338c5578...cc11` - plus a diffstat summary instead of a patch, riding alongside the injected block.
- Qualitatively worse than the first two: this was not a plausible fabrication but a recognisable template. The orchestrator is now emitting it reflexively rather than attempting to pass one off.

Structural note: the plugin's marker-capture regex uses `(\S+)`, so the two blocks compete for the same capture. A fabricated block is not merely cosmetic - it can win the capture and dictate the review range.

Why the intent rule failed: the rule "never paste envelope content; the plugin injects it" was already written into a handoff prognosis after occurrence 1. It did not prevent occurrence 2 or occurrence 3, so an intention-level reminder is demonstrably insufficient for this defect class.

## Outcome

- Occurrence 1: the reviewer refused to guess, flagged the ambiguous range as a Critical finding outside both review axes, anchored on the injected block, and corroborated it against the worktree before reviewing.
- Occurrence 2: the reviewer again anchored on the injected block, and additionally noted the task-tool trailer.
- Occurrence 3: the reviewer again refused to guess, noted the hand-written block's placeholder shape and the absent patch, and reviewed from the complete injected block. No review was poisoned.
- Net: all three reviews were saved by reviewer-side skepticism, not by any guard. The intent-level rule was written down after occurrence 1 and still failed to prevent occurrences 2 and 3, so the record must not present intent as a mitigation; the mechanical guard below is the only mitigation with evidence behind it. Fabricated evidence at a review gate is the worst class of defect: a reviewer who trusted it would review a diff that does not exist, and the review range would be recorded as verified when it was not.

## Proposed mechanical guard (record only - NOT implemented)

Reject the dispatch at the plugin level: if the text of a task dispatch contains the envelope marker token MORE THAN ONCE, throw an error before spawning the child lane. This guard would have caught all three occurrences, since each had exactly two blocks.

- Justification: the legitimate case always has exactly one block, and that block is appended by the plugin itself, so a second occurrence necessarily means a human/orchestrator hand-wrote one.
- Implementation surface: the same pre-spawn hook in `.opencode/plugins/delegation-observer.ts` that already validates the single-marker rule for reviewer dispatches.
- Implementer note: the marker-capture regex is `(\S+)`, so until this guard lands a fabricated block competes with the injected one for the same capture. The guard removes that race, not just the cosmetic duplication.

## References

- `.opencode/plugins/delegation-observer.ts` (pre-spawn reviewer dispatch validation; envelope construction and injection into the child prompt; the `(\S+)` marker capture).
- `external-patterns/2026-10-21-cs3v-dispatch-gate-contract.md` (envelope emitter and capture contract, same campaign).
- `external-patterns/2026-10-22-cs3v-envelope-append-carrier.md` (envelope as a second carrier of payload drift).
