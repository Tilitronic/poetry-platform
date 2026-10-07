# DIA-172 batch D parallel coders - worktree-gated parallel @coder dispatch, F1-F7 closures, merge pending (2026-08-13)

- **Date:** 2026-08-13
- **Source:** DIA-172 ticket (Medium, opencode-config, developer-request follow-up to DIA-159/DIA-162/DIA-163); OpenSpec change 'batch-d-parallel-coders' (proposal/design/tasks.md) implemented on 5 feature branches (prompts/plugin/drift/docs/append); this AGENTS.md section 2.5 close-out registration lane (docs lane).
- **Status:** IMPLEMENTED + REVIEWED + AUDIT-APPROVED (F1-F7 closed); MERGE PENDING - serialized squash-merges deferred (DIA-094: docker container down, no --no-verify).
- **Outcome:** BATCH-DISPATCH rule extended with batch D (parallel coders on separate git worktrees gated by WORKTREE: payload assertions); architector added to batch A (5 lockstep surfaces); F1-F5 config-drift fixes (analyzer-escalated sole-writer closure, code-navigator/observer bash deny, conspecter doc alignment, F4 singleton-batch A1 exemption); .sdd/opencode-config/architecture.md with 2 Accepted ADRs; coder worktree-confinement directive; A6 item 6 (per-worktree fixed-point reviews + serialized squash-merges). Implemented on 5 feature branches, each in its own worktree; merge pending.

## Ticket

- **DIA-172** (Medium, opencode-config, OPEN) - "Parallel coders (batch D) + read-only batch expansion - DIA-159 follow-up review and design".
- **Related:** DIA-159 (task-parallelization analysis, parent), DIA-162 (BATCH-DISPATCH rule), DIA-163 (batch-aware A1 plugin), DIA-100 (git worktrees), DIA-094 (docker gate).

## Design: batch D (implemented 2026-08-13, 5 feature branches)

- **Batch D rule (3 preset orchestrator prompts):** parallel @coder lanes allowed ONLY IF each uses a separate git worktree AND the dispatch payload asserts WORKTREE: <path> per coder, with disjoint file sets (plus any read-only lanes). NEVER-batch list drops "two coders" (batch D legalizes them); still NEVER: two analyzers, coder+reviewer (reviewer needs a committed fixed point), any pair that both write memory-shelf.yaml.
- **Plugin predicate D (delegation-observer.ts):** isSafeTaskBatch now classifies Array<{agent, worktree?}>; batch D = coders > 1, every non-coder lane in READ_ONLY_LANES, and every coder carries a DISTINCT non-empty worktree assertion (Set size == coder count); missing or duplicate worktree fails loud (warn). WORKTREE: marker extracted from the task description+prompt via /WORKTREE:\s*(\S+)/i - exactly ONE marker is the contract; zero or multiple markers yield undefined (malformed -> batch D fails loud for that coder).
- **One worktree per task:** each parallel coder is dispatched to its own git worktree (feature/dia132-* branches, .worktrees/feature-dia132-*), never two coders on the same worktree or same ticket.
- **Per-worktree reviewer on committed fixed points:** A6 item 6 - reviewer MUST operate on committed fixed points INSIDE that worktree (batch C semantics preserved per worktree).
- **Orchestrator-managed serialized squash-merges:** merges to the main branch MUST happen one at a time (git index lock / file-contention avoidance); one memory-manager pass runs after the merges.
- **F5 architector batch A (5 lockstep surfaces):** plugin READ_ONLY_LANES + 3 preset BATCH-DISPATCH texts + orchestrator_append A1.
- **ADR home:** .sdd/opencode-config/architecture.md (NEW) - ADR 1 Batch Pattern D (worktree-gated parallel coders), ADR 2 Singleton-Batch Semantic Exemption (single task() call = safe; no false A1 warnings for task()+log_decision turns).

## Config drift closures (F1-F5)

- **F1 (analyzer-escalated sole-writer closure):** opencode.jsonc analyzer-escalated edit block = knowledge/* only (".opencode/memory-shelf.yaml": "allow" removed per the DIA-162 sole-writer invariant) + adjacent comment fixed; analyzer-escalated.md self-registration instruction replaced with Do-Not-Register (report artifact paths in the return message; @memory-manager registers).
- **F2 (strict read-only):** bash:deny added to code-navigator + observer permission blocks (opencode.jsonc) - they were classified read-only but write-capable via the inherited global bash allow.
- **F3 (conspecter doc drift):** conspecter.md edit allow list = knowledge/* only (shelf registration delegated to @memory-manager), matching the actual opencode.jsonc block.
- **F4 (singleton-batch semantics):** A1 fires only when the turn holds MORE than one task() call - a single task() alongside semantic tools (log_decision) is a lone delegation, not a parallel batch (eliminates false positives).
- **F5 (architector read-only):** architector added to READ_ONLY_LANES + batch A on all 5 lockstep surfaces (safe by config: edit/bash/task deny).
- **F6 + F7 (audit follow-ups, append branch):** A1 NEVER-batch clause aligned with preset texts ("two coders" removed from the NEVER list); out-of-scope preset edit reverted.

## Validation

- Fix-phase gates ran per-worktree during implementation (reviewer resumed drift + plugin reviews 21:53Z, ai-auditor independent audit 22:04Z; behavioral batch-D test evidence recorded in the worktree sessions; not re-run in this registration lane).
- Merge-pending: post-merge gates (make test-config incl. validate-agent-names, node --check delegation-observer.ts, behavioral batch-D cases) deferred to the serialized squash-merge step - DIA-094 docker container down, commits blocked by the main-tree husky pre-commit hard-fail (no --no-verify).
- This registration lane: CHANGELOG entry + this learnings entry + index pointer row; ASCII-only (DIA-079).

## Outcome

- Implemented + reviewed + audit-approved (F1-F7 closed) per AGENTS.md section 2.5: 5 feature branches (feature/dia132-prompts, -plugin, -drift, -docs, -append), each in its own worktree, MERGE PENDING. Ticket DIA-172 stays OPEN until the serialized squash-merges + post-merge test-config complete (recorded honestly - no fabricated merge or restart evidence).
- The batch D machinery was exercised by this change itself: 5 coders ran in parallel, one per worktree, with per-worktree reviews and the serialized merge step pending.

## Reusable lesson

- Worktree husky-shim gap: the DIA-094 docker gate is NOT enforced on worktree commits - the main-tree husky pre-commit hook hard-fails when the container is down, but commits inside git worktrees do not hit that hard-fail path, so parallel worktree coders can commit while the docker gate is unmet. The orchestrator must enforce the docker gate at dispatch and merge time, not rely on the pre-commit hook alone.
- Batch D payload must state the branch model explicitly: WORKTREE: <path> alone is ambiguous (worktree path vs branch name); the dispatch payload should assert both the worktree path and the branch name so the coder, the per-worktree reviewer, and the merge step all resolve the same identity.
- Ticket ID token required in dispatch/resume prompts (DIA-063): parallel dispatch multiplies the risk of orphaned or misattributed work - every dispatch and resume prompt must carry the DIA-NNN ticket token so worktrees, tickets, and branches stay correlated.

## Tags

DIA-172, DIA-159, DIA-162, DIA-163, DIA-100, DIA-094, batch-d, parallel-coders, worktree, WORKTREE-assertion, delegation-observer, isSafeTaskBatch, READ_ONLY_LANES, architector, F1-F7, sole-writer, bash-deny, singleton-batch, openspec, .sdd, ADR, serialized-squash-merge, per-worktree-review, husky-shim, ticket-token, config-fix-workflow
