# DIA-174 batch D infra hardening - worktree husky shim, persistent suite, branch-ownership payloads, dispatch tokens, merge gate (2026-08-13)

- **Date:** 2026-08-13
- **Source:** DIA-174 ticket (Major, dev-infra, DIA-172 retrospective 2026-08-14); OpenSpec change 'batch-d-infra-hardening' (proposal/design/tasks.md) implemented on 4 feature branches (shim/tests/prompts/process, base c9aaa33); this AGENTS.md section 2.5 close-out registration lane (S5).
- **Status:** IMPLEMENTED + REVIEWED + AUDIT-APPROVED + MERGED (4 serialized squash-merges 05c75fe..510e60b, 2026-08-14); ticket DIA-174 DONE.
- **Outcome:** all 6 retrospective items closed. (1) S1 scripts/worktrees.sh materializes the .husky/_ shim in new worktrees - pre-commit + verify-pre-commit.sh now fire on worktree commits (bats T17-T19). (2) S2 persistent gitignored behavioral suite scripts/__tests__/batch-d-infra.test.mjs (43 tests) wired into make test-config + .sdd/dev-infra ADR 9. (3) S3 coder_append.md branch-ownership model (5 required phrases: worktree base / sibling branches own / edit ONLY your assigned files / disjoint file sets / name the owned files). (4-6) S4 orchestrator_append.md R1-R3 + AGENTS.md section 2.3: literal ticket-ID token in every dispatch/resume prompt (DIA-063 gate), architector design persistence before implementation, merge-gate container evidence (docker compose ps recorded, dev service Up).

## Ticket

- **DIA-174** (Major, dev-infra, DONE) - "Batch D infra hardening: worktree hooks, test persistence, branch-ownership payloads, dispatch tokens (DIA-172 retrospective)".
- **Related:** DIA-172 (parent retrospective), DIA-094 (docker pre-commit gate), DIA-063 (ticket-ID gate), DIA-100 (git worktrees).

## Design (from design.md)

- **S1 shim:** scripts/worktrees.sh create copies the main tree's .husky/_ into each new worktree (real directory, not symlink); fails loud when the main tree has no .husky/_ (bats T18).
- **S2 persistent suite:** the DIA-172-era throwaway /tmp plugin/config behavioral tests (wiped by OS tmp-cleanup, counts drifted 10/10 -> 15/15 breaking the same-test contract) consolidated into one gitignored node ESM file scripts/__tests__/batch-d-infra.test.mjs, zero npm deps (esbuild invoked as subprocess only to bundle the REAL delegation-observer plugin); Makefile test-config wiring is the S2 GREEN phase (asserted RED in suite section 3). DD1 ADR + ADR 9 in .sdd/dev-infra/architecture.md.
- **S3 branch ownership:** batch D coder directive states the branch model explicitly - worktree base = <shared sha>, sibling branches own other slices' files, edit ONLY your assigned files, disjoint file sets, payloads name the owned files per slice.
- **S4 rules:** R1 ticket-ID token in every dispatch AND resume prompt (DIA-063 gate blocks prompts without it); R2 architector design text persisted to the DIA ticket or .sdd draft before implementation (reviewers diff verbatim claims); R3 merge phase starts only with recorded docker compose ps evidence showing dev service Up (commit gate output into the merge report).

## Slice breakdown (worktrees, base c9aaa33)

- **feature/dia134-shim @ 644c3a1:** scripts/worktrees.sh + scripts/__tests__/worktrees.bats (T17-T19) -> squash-merged 05c75fe.
- **feature/dia134-tests @ f810db5 + 7a96fab:** Makefile + .gitignore + .sdd/dev-infra/architecture.md (ADR 9) -> squash-merged aec1bd3. The suite file itself is GITIGNORED (DD2) and was copied to main manually at close-out (squash-merge cannot carry it).
- **feature/dia134-prompts @ 2a8ea4f + 9339b54:** .opencode/oh-my-opencode-slim/coder_append.md (branch-ownership model + grammar/prescriptive-owned-files fix) -> squash-merged 6a35466.
- **feature/dia134-process @ b732713 + fb7c0c4:** orchestrator_append.md (R1-R3) + AGENTS.md section 2.3 -> squash-merged 510e60b (merge-gate rule relocated to section 2.3 tail out of the re-review loop per review).

## Validation

- Post-merge full verification (2026-08-14, all exit 0): behavioral suite 43/43 PASS; bats 240 ok incl. T17-T19; validate-opencode-config.sh exit 0; validate-agent-names.sh 24/24; lockstep greps green ('two coders' zero; architector in batch A in 3 presets + A1; batch D clause in 3 presets; R1/R2/R3 phrases in orchestrator_append.md + AGENTS.md; 5 branch-ownership phrases in coder_append.md).
- Husky pre-commit hook PASSED on all 4 merge commits (DIA-094 docker gate respected; poetry-dev Up, evidence recorded before merge dispatch).
- S5 close-out: ticket DONE + README counts (OPEN 31->30, DONE 3->4) + CHANGELOG + learnings registration; ASCII-only (DIA-079); LOCAL-ONLY (no push, no remote ops).

## Outcome

- Implemented + reviewed + audit-approved + merged per AGENTS.md section 2.3: 4 feature branches, each in its own worktree, 4 serialized squash-merges on omo-slim-changes, post-merge verification green. Ticket DIA-174 DONE. The DIA-174 batch D run itself exercised the S3/S4 machinery it shipped: one-shot batch D reused sessions across RED/GREEN/fix loops (4 branches, no cross-branch file collisions, zero out-of-scope edits).

## Reusable lesson

- Worktree husky-shim gap (DIA-172 lesson) now FIXED: scripts/worktrees.sh create materializes .husky/_ in new worktrees (T17-T19), so pre-commit + verify-pre-commit.sh fire on worktree commits - the DIA-094 docker gate is enforced on worktree commits, not just main.
- Gitignored-suite materialization pattern: a gitignored test file cannot be carried by squash-merge - the merge step must copy it from the owning worktree into main after each merge, and fresh clones must re-copy it (documented in the ticket deferrals).
- DIA-174 one-shot batch D reused sessions across RED/GREEN/fix loops: the same session IDs persisted across the 4 branches' fix cycles (7a96fab/9339b54/fb7c0c4 are fix commits on top of the initial slices), which the batch-D plugin predicate D tolerated because each coder stayed in its own worktree with disjoint file sets.

## Tags

DIA-174, DIA-172, DIA-094, DIA-063, batch-d, worktree, husky-shim, verify-pre-commit, persistent-suite, gitignored-suite, test-config, ADR-9, branch-ownership, ticket-token, design-persistence, merge-gate, docker-compose-ps, serialized-squash-merge, openspec, .sdd, close-out
