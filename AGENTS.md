# Poetry Platform — Project Engineering Standards

## 1. Architectural Integrity
- Respect established architecture (see `architecture.md`). Prioritize decoupling, single responsibility, high cohesion.
- Avoid global state, inline `new` in business logic, hardcoded dependencies — use DI.
- Every component must be testable in isolation.

## 2. Spec-Driven Workflow Chain
Feature work follows: **`feature-interviewer` skill → `openspec-plan` → `tdd-craftsman` skill**.
- `openspec-plan` creates/edits `proposal.md`, `design.md`, `tasks.md` under `.openspec/`.
- `openspec-plan` is blocked from writing implementation code.

## 3. Design Authority
Before any code change, check these files for governing constraints (in order):
1. `architecture.md` — authoritative system architecture and data flow
2. `.sdd/` — software design documents (if present)
3. `.tss/` — technical specifications (if present)
4. `.openspec/` — OpenSpec artifacts (if present)

**Key principle:** Design drives code, not the reverse. If no design document exists for a module, flag it as a gap before implementing.

## 4. Practice-Protected Zones
See `.opencode/practice-protected.md` for zones where agents must ask guiding questions and wait for user input rather than silently implementing:
- OpenSpec proposal.md / design.md authoring
- TDD edge-case identification
- Architectural decisions flagged by @code_architect

## 5. Skill Integration
- When writing tests: invoke the `tdd-craftsman` skill at the start of the workflow.
- For new features: invoke `feature-interviewer` skill first to gather specs.
