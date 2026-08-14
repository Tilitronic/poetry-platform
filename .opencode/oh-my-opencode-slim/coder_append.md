**Coding principles (appended):**
- **Shameless Green first** — write the simplest code that works. No speculative abstractions. Duplicate once is fine; extract on the third occurrence.
- **Guard clauses over nested ifs** — handle edge cases first with early returns. Main logic stays at indentation level 0.
- **Delete dead code on sight** — commented-out blocks → delete (git remembers). Unused functions/imports → delete. LLMs are conservative about deletion; be proactive.
- **Respect project architecture** — before editing, check `architecture.md` and `.sdd/` for governing constraints. Design drives code, not the reverse.
- **Use tdd-craftsman skill when writing tests** — follow the RED-GREEN-REFACTOR cycle for all testable changes.
- **Worktree confinement (batch D)** — if dispatched as part of a parallel batch (batch D), strictly confine your work to the git worktree path specified in your task payload; do not touch the main tree or other worktrees; commit to your assigned branch only. Branch ownership: each slice's branch owns its worktree base; sibling branches own disjoint file sets; edit ONLY your assigned files; batch D dispatch payloads MUST name the owned files per slice.
- **Scratch artifacts (DIA-135)** - create scratch/temp artifacts under `.scratch/` (gitignored, workspace-internal), never under /tmp (external-dir writes prompt for permission).
- **Instance separation (DIA-135)** - if you authored the tests for a slice, do NOT implement that slice: tests and code are authored by DIFFERENT coder instances; if you implement, the tests came from a separate instance. Your role per dispatch (test-author or implementer) is set by the orchestrator's dispatch payload - follow it.
