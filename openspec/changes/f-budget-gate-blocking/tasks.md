# Tasks: F budget gate - report-only to blocking

Design reports no Open Questions; all spec-shaping decisions resolved in the
interview transcript (Q1-Q6). Task order below is dependency order; the
blocking edge of each task is stated inline.

## 1. Baseline manifest and scope resolution

- [ ] 1.1 Author the ticket-bound baseline manifest with seeded ceilings and pattern entries (no blockers; .sdd/opencode-config governs the plugin surface measured). Done when: jq validates the manifest; ceilings read 5900/4037; every entry names its approving DIA ticket; per-pattern counts are freshly measured from the post-D4 tree.
- [ ] 1.2 Implement scope-trailer parsing and manifest-backed scope resolution with fail-closed verdicts (blocks: 1.1). Done when: a refactor claim without a matching campaign entry is refused, a missing or malformed manifest is refused for any commit touching scoped paths, and trailer-less commits resolve to feature scope.

## 2. Budget measurement

- [ ] 2.1 Measure production and shell LOC from staged content against the manifest ceilings (blocks: 1.2). Done when: from a developer's view, a manifest-backed refactor commit that grows production LOC is refused with a FAIL line naming the ceiling (fixture a), while a feature commit with the same growth is allowed with a printed report (fixture b), and unstaged working-tree drift changes no verdict.
- [ ] 2.2 Detect newly-introduced scaffold duplication by normalize-then-fixed-string matching (blocks: 1.1). Done when: a third copy of a known scaffold is refused even on a feature commit, a re-indented quote-flipped line-split copy is still counted and refused (fixture d), counts exactly at baseline pass, and the authorized helper site never counts.

## 3. Exception flow

- [ ] 3.1 Validate exception trailers against approval records after scope and manifest resolve (blocks: 1.2). Done when: a complete approval record (reason, delta, paths, applicability) lets its commit through with an exception report line (fixture c), while an exception without a scope trailer, with any record field missing, or stacked on broken scope/manifest state is refused (no rescue); manifest edits demand the normal refactor trailer and never accept an exception as bootstrap.

## 4. Hook wiring and defense-in-depth

- [ ] 4.1 Enforce blocking in the commit-msg hook, leaving pre-commit and test-config untouched (blocks: 2.1, 2.2, 3.1). Done when: real commits driven through the hook are refused or allowed exactly per the spec verdicts, and the hook follows the sibling-hook sourcing convention.
- [ ] 4.2 Re-check pushed ranges in always-blocking mode that ignores the kill-switch (blocks: 4.1). Done when: a budget-violating commit created with hook bypass is refused at push time even with report-only mode set locally.
- [ ] 4.3 Propagate the commit-msg hook into fresh worktrees (blocks: 4.1; .sdd/dev-infra governs hook distribution). Done when: a newly created worktree contains the hook so the gate cannot be silently lost.

## 5. Test battery, kill-switch, and rollout

- [ ] 5.1 Prove every sub-gate in both directions with the hermetic bats battery plus wiring assertions (blocks: 4.2). Done when: the suite drives real fixture-repo commits through the hook, each sub-gate has an injected-FAIL and a real-PASS case, hook wiring and hook-copy coverage are asserted, and the full shell suite passes.
- [ ] 5.2 Downgrade locally to report-only without ever switching the gate off (blocks: 4.1). Done when: with the switch set, a violating commit is allowed but its output carries both the violation report and an explicit warning naming the switch; range mode and CI are unaffected.
- [ ] 5.3 Land inert-first, then wire, then review (blocks: 5.1, 5.2). Done when: manifest plus gate plus tests land before the hook wiring, shell and config gates are green, the reviewer verdict is recorded, and the DIA ticket carries the outcome.
