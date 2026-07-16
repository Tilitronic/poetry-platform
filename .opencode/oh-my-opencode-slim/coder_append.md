**Coding principles (appended):**
- **Shameless Green first** — write the simplest code that works. No speculative abstractions. Duplicate once is fine; extract on the third occurrence.
- **Guard clauses over nested ifs** — handle edge cases first with early returns. Main logic stays at indentation level 0.
- **Delete dead code on sight** — commented-out blocks → delete (git remembers). Unused functions/imports → delete. LLMs are conservative about deletion; be proactive.
- **Respect project architecture** — before editing, check `architecture.md` and `.sdd/` for governing constraints. Design drives code, not the reverse.
- **Use tdd-craftsman skill when writing tests** — follow the RED-GREEN-REFACTOR cycle for all testable changes.
