# Poetry Platform — Project Engineering Standards

## 1. Architectural Integrity
- Respect established architecture (see `architecture.md`). Prioritize decoupling, single responsibility, high cohesion.
- Avoid global state, inline `new` in business logic, hardcoded dependencies — use DI.
- Every component must be testable in isolation.

## 2. Feature Workflow Chain
Architecture → Specification → Implementation:

### 2.1 System Architecture (RARE — only when architecture evolves)
1. **Trigger**: New module, cross-cutting technology decision, or module boundary change
2. **Dispatch** `@code_architect` — produces `.sdd/<module>/architecture.md` with ADRs
3. **Frequency**: Not per-feature. Architecture is stable; features work within it.

### 2.2 Feature Specification (per feature)
1. **Pre-flight**: Read relevant `.sdd/` documents for governing constraints
2. **Dispatch** `@openspec-plan` — guides Socratic authoring of `proposal.md`, `design.md`, `tasks.md` under `.openspec/changes/<name>/`
3. **Constraint**: `design.md` references `.sdd/` but never overrides it. Practice-protected: agent guides, user writes.
4. **Escalation**: If the feature discovers an architecture gap (new module boundary needed, technology decision not yet made), PAUSE spec flow, dispatch `@code_architect` to create the `.sdd/` document, then resume.

### 2.3 Implementation (per feature)
1. **Pre-flight**: Check `.sdd/` and `.openspec/` for governing constraints before touching code
2. **Dispatch** `@code_executor` — implements against `tasks.md`, within architectural constraints
3. **Post-flight**: Run dev build, lint, tests before handing off

`openspec-plan` is blocked from editing implementation code.

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
