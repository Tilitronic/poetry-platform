# Poetry Platform — Project Engineering Standards

## 1. Architectural Integrity

- Respect established architecture (see `architecture.md`). Prioritize decoupling, single responsibility, high cohesion.
- Avoid global state, inline `new` in business logic, hardcoded dependencies — use DI.
- Every component must be testable in isolation.

## 2. Feature Workflow Chain

Architecture → Specification → Implementation:

### 2.1 System Architecture (RARE — only when architecture evolves)

1. **Trigger**: New module, cross-cutting technology decision, or module boundary change
2. **Dispatch** `@architector` — produces `.sdd/<module>/architecture.md` with ADRs
3. **Frequency**: Not per-feature. Architecture is stable; features work within it.

### 2.2 Feature Specification (per feature)

1. **Pre-flight**: Read relevant `.sdd/` documents for governing constraints
2. **Dispatch** `@openspec-plan` — guides Socratic authoring of `proposal.md`, `design.md`, `tasks.md` under `openspec/changes/<name>/`
3. **Constraint**: `design.md` references `.sdd/` but never overrides it. Practice-protected: agent guides, user writes.
4. **Escalation**: If the feature discovers an architecture gap (new module boundary needed, technology decision not yet made), PAUSE spec flow, dispatch `@architector` to create the `.sdd/` document, then resume.

### 2.3 Implementation (per feature)

1. **Pre-flight**: Check `.sdd/` and `openspec/` for governing constraints before touching code
2. **Dispatch** `@coder` — implements against `tasks.md`, within architectural constraints
   - Optionally run `to-tickets` first to publish the tasks as DIA tickets in `docs/dev-infra-audit/tickets/`
3. **Post-flight**: Run dev build, lint, tests before handing off. Coder MUST include verification evidence (exit codes + summary lines) — see §2.3.1
4. **Review**: Dispatch `@reviewer` (two-axis: Standards + Spec fidelity)
5. **Fix → Re-review loop** (§2.3.1): after developer disposition and coder fixes, re-dispatch `@reviewer` for targeted re-verification (max 2 cycles)
6. **Persist**: After feature completion or ≥2 failed loops, dispatch `@memory-manager` to capture ADRs, lessons, and failure patterns in `.opencode/memory/`

#### 2.3.1 Re-Review Loop (fix → re-verify → re-review)

After the developer disposes review findings (accept/reject per practice-protected §4) and `@coder` applies accepted fixes:

1. **Coder handoff** must include verification evidence: test/lint/typecheck exit codes + summary lines for each fix applied.
2. **Orchestrator re-dispatches `@reviewer`** with:
   - Same fixed point (commit/branch/tag)
   - Prior findings list (only the developer-accepted ones)
   - Coder's fixes-applied summary + verification evidence
   - Cycle counter: `re-review cycle N/2`
3. **Reviewer conducts targeted re-review** (see `review-re-verify` skill):
   - For each prior finding: `verified-closed` | `still-open` | `partial` + evidence
   - No full re-review; only confirms resolution of prior findings
   - New observations (e.g., fix introduced regressions) noted separately as "re-review observations" — these enter the normal practice-protected §4 disposition flow
4. **All findings verified-closed** → proceed to step 6 (Persist)
5. **Any still-open or partial** → present findings-resolution table to developer for disposition (practice-protected §4 applies)
6. **Cycle cap**: max 2 fix→re-review cycles. If findings persist after cycle 2 → escalate to developer with full findings-resolution history. Developer decides: accept residual risk, manual fix, or abort.

`openspec-plan` is blocked from editing implementation code.

### 2.4 Dev-Infrastructure Changes (scripts/, Docker, Makefile, CI)

- **Scope**: shell scripts (`scripts/*.sh`), Docker (`docker-compose.yml`, `Dockerfile.dev`, `dev-entrypoint.sh`), Makefile, `.devcontainer/`, CI config.
- **Workflow**: same chain as features:
  1. **Spec** — for changes >~20 lines dispatch `@openspec-plan` to author `openspec/changes/<name>/{proposal,design,tasks}.md`; `design.md` must include test strategy + rollback plan. Practice-protected: user writes substance.
  2. **Implement** — dispatch `@coder`, tests written alongside (tdd-craftsman), test infra created if missing for the artifact type (bats for shell, pytest for python, smoke-test for docker).
  3. **Test gate** — tests must exist and pass (`make test-shell` / `make test-infra` / `make test-config`).
  4. **Review** — dispatch `@reviewer` (two-axis: Standards + Spec fidelity).
  5. **Persist** — `@memory-manager`.
- **Escalation**: if change reveals an architecture gap, dispatch `@architector` and pause.

### 2.5 OpenCode Configuration Changes

- **Scope**: `.opencode/*` (opencode.jsonc, oh-my-opencode-slim.jsonc, `agents/*.md`, `skills/*/SKILL.md`, `commands/`, dcp.jsonc), AGENTS.md edits, practice-protected.md.
- **Workflow**: routed through the AI Devtools Modernization Workflow (global AGENTS.md §10):
  1. **Gate** — dispatch `@ai-specialist` (read-only research); the orchestrator registers its findings in `.opencode/learnings/external-patterns/`.
  2. **User reviews & decides** (practice-protected — orchestrator does not silently apply).
  3. **Design** — if non-trivial, `@architector`; every decision traces to a best-practice rule.
  4. **Implement** — `@coder` applies approved design.
  5. **Validate** — config validation (`make test-config`), schema/JSONC validity, restart OpenCode + functional smoke test.
  6. **Independent review** — `@ai-specialist` reviews the implemented change against best practices + AIHero patterns. ai-specialist is THE independent reviewer for config changes.
  7. **Register** — update CHANGELOG + learnings outcome field.
- **Review matrix**: dev-infra → `@reviewer`; opencode config → `@ai-specialist`.

## 3. Design Authority

Before any code change, check these files for governing constraints (in order):

1. `architecture.md` — authoritative system architecture and data flow
2. `.sdd/` — software design documents (module-level; currently only `.sdd/README.md` exists — no module docs authored yet)
3. `.tss/` — technical specifications (planned future layer — not yet created)
4. `openspec/` — OpenSpec artifacts (if present)
5. `CONTEXT.md` — domain glossary (the domain-vocabulary layer; maintained by `domain-grilling`)

**Key principle:** Design drives code, not the reverse. If no design document exists for a module, flag it as a gap before implementing.

## 4. Practice-Protected Zones

See `.opencode/practice-protected.md` for zones where agents must ask guiding questions and wait for user input rather than silently implementing:

- OpenSpec proposal.md / design.md authoring
- TDD edge-case identification
- Architectural decisions flagged by @architector

## 5. Skill Integration

- When writing tests: invoke the `tdd-craftsman` skill at the start of the workflow.
- For new features: dispatch `@openspec-plan` to gather specs and author the OpenSpec change (`openspec/changes/<name>/{proposal,design,tasks}.md`). It is the spec-interview role.
