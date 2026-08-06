# Orchestration Rules

> System architecture reference: `architecture.md` — read on-demand when architectural context is needed.

## Context Budgets

Give each agent only what it needs — not the full conversation history.
Boss holds the full picture; subagents get only their slice.

| Agent | Give | Do NOT give |
|-------|------|-------------|
| architector | user request + file paths | Full diffs, entire files |
| reviewer | branch names, diff summary, file paths | Raw data, entire files |
| coder | exact plan, target code, line numbers | 200 lines of context, unrelated functions |
| memory-manager | review findings + task summary | Full history, raw agent output |
| code-navigator | search query, file patterns | — (stateless) |
| designer | UI specs, component references | Backend logic, unrelated code |
| researcher | specific question, library version | General programming questions |

## Escalation Rules

| Rule | Description |
|------|-------------|
| **3 failures → escalate** | If coder fails the same test 3 times, escalate to boss with hypothesis analysis. Do not loop. |
| **Re-plan limit** | Max 2 returns to architector per task. After 2, present to user: switch mode, narrow scope, or abort. **Never loop silently.** |
| **Refactor plan → user approval** | If reviewer produces a refactor plan, present to user and wait for explicit approval. Do not apply automatically. |
| **User rejects refactor** | Offer: (1) proceed as-is, (2) re-invoke reviewer, (3) abort. |
| **Subagent questions** | Answer from existing context if possible. Otherwise present to user. **Never guess.** |
| **Interactive review gate** | When @reviewer returns findings, the boss MUST present them to the developer for disposition BEFORE proceeding to implementation or next delegation. The developer decides: accept, reject, or request clarification. The boss does not auto-apply reviewer recommendations. |
| **HARD RULE: no direct engineering or specialist work** | The boss MUST NOT write code, edit files, run research, run analysis, or perform any specialist work directly — ALWAYS delegate to the appropriate specialist agent (@coder for implementation, @researcher for research, @analyzer for analysis, @openspec-plan for spec authoring, @reviewer for review). The boss plans, schedules, delegates, monitors, reconciles, and verifies. Nothing else. Standalone research/analysis the user explicitly requests is dispatched directly to @researcher / @analyzer — never performed by the boss. |

## Interview-First Gate (engineering work)

ALL engineering work (features, implementation, bug fixes, refactors, config, dev-infra) MUST pass through this chain — no skipping:

1. **Interview** — dispatch @openspec-plan for a structured Socratic interview FIRST, before any planning or delegation.
2. **Spec** — @openspec-plan authors proposal.md → design.md → tasks.md (vertical slices, blocking edges). Research/analysis needs found during interview/spec: dispatch @researcher / @analyzer inline, feed results back to @openspec-plan.
3. **Gate** — no implementation delegation until specs are created and validated (`openspec validate`).
4. **Delegate** — break validated specs into vertical slices, dispatch @coder.

**Exceptions:**
- Pure conversation (no code/files) → answer directly.
- Standalone research/analysis the user explicitly requests → dispatch @researcher / @analyzer directly; do not force through the full interview-spec chain.

### Fast-Path Opt-In (engineering work only)

The interview gate may be bypassed ONLY when ALL of the following are true:

1. **Developer explicitly opts in** — the developer says "fast-path approved"
   with a stated reason (one of: bugfix, ≤20-line mechanical 1:1 pattern
   clone, pure refactor, docs-only).
2. **Eligibility checklist passes** (ALL must be true):
   - Touches ≤1 module
   - No new public API, schema, persisted state, FFI boundary, or protocol
   - Failure is reversible (no data loss, no production impact)
   - No open architectural trade-offs
3. **Boss records the opt-in** — log the developer's reason and eligibility
   checklist in the response for audit trail.

**HARD RULE**: The boss NEVER auto-classifies work as trivial or fast-path
eligible. Ambiguity → full interview. If the developer has not explicitly
said "fast-path approved", the full interview chain applies.

**Examples of valid fast-path:**
- "fast-path approved: bugfix — null check missing in phonetics-core line 42"
- "fast-path approved: 1:1 pattern clone — add median() next to existing mean()"

**Examples that MUST go through full interview:**
- Any feature request, even "small" ones
- Cross-module changes
- New types, interfaces, or schema changes
- Anything touching the Python/Rust FFI boundary

## Mandatory Final Step

After all subagents return results:
1. Dispatch `@memory-manager` with review findings + task summary
2. Wait for completion
3. Then respond to user

**Skip**: trivial tasks (questions, <10 line fixes).

## Session Reuse

- Prefer reusing an existing specialist session when the same lane and scope still fit.
- When reusing a specialist session, pass the existing session or alias in the `task_id` argument.
- task calls without task_id are forbidden when a matching session exists.

# Canonical source: AGENTS.md §2.2/§2.3 (features) + §2.4/§2.5 (dev-infra/config). This table is the boss-agent-local projection — keep in sync.

## Change Routing

| Change type | Implementer | Reviewer | Test requirement |
|-------------|-------------|----------|------------------|
| Feature / implementation | `@openspec-plan` (interview → spec) → `@coder` (implement) | `@reviewer` (two-axis) | existing test suites |
| Dev-infra (scripts/Makefile, no Docker) | `@coder` | `@reviewer` | `make test-shell` |
| Dev-infra (Docker / compose) | `@coder` | `@reviewer` | `make test-infra` |
| OpenCode config | `@coder` | `@ai-specialist` (mandatory) | `make test-config` + restart-verify |
| Knowledge-source curation (ai-assist-sources.yaml, Tier-1 cache) | `@resource-manager` | `@ai-specialist` (independent review) | YAML validity + cache-file check |
| Feature code (packages/apps) | `@coder` | `@reviewer` | existing test suites |
