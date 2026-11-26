# DIA-063 §10 ticket-creation gate findings — orchestrator must ticket before §10 work (2026-08-09)

- **Date:** 2026-08-09
- **Source:** §10 Phase-1 gate research by @ai-specialist for DIA-063 (session `ses_01815b01cffenHHf3n35dSLC0F`). Registered per AGENTS.md §10 ("orchestrator registers the findings"); the docs lane persists them so they are recoverable beyond the git diffs. Follows the prior ticket-gate findings (`2026-08-03-orchestrator-coordination-tickets-gate.md` T3, ticket-format standardization).
- **Status:** DIA-063 OPEN (Blocker) — findings registered; §10 Phase-2 owner decision pending. RESOLVED 2026-08-10 — see 2026-08-10-dia063-ticket-gate-non-determinism.md; tri-state explicit-id fix, boot-gate exemption, configWorkHint narrowing, path-3 warn-not-throw; DIA-076 tracked; restart smoke pending.

## Ticket

- **DIA-063** (Blocker, OPEN) — "Orchestrator starts §10 work without creating a ticket first — ticket-creation gate not enforced."
- **Gate as defined:** before any §10 Phase-1 research dispatch, the orchestrator MUST create or confirm a DIA ticket in `docs/dev-infra-audit/tickets/` and reference the ticket ID in the dispatch.
- **Root cause:** convention only, no mechanical enforcement.
- **`blocked_by: DIA-060-restart`:** SATISFIABLE — see KEY VERIFIED FACT below.

## KEY VERIFIED FACT — DIA-060 is RESOLVED

- The orchestrator's path-scoped permission DOES include `docs/dev-infra-audit/tickets/*`:
  - `.opencode/opencode.jsonc` lines 86-94 read block: L90 `docs/dev-infra-audit/tickets/*` allow, L91 archive allow
  - glob block L99-104, L102-103
- Therefore the `blocked_by: DIA-060-restart` constraint on DIA-063 is satisfiable — the ticket-creation gate can be enforced mechanically without any permission change.

## Findings

- **Delegation-observer plugin:** `.opencode/plugins/delegation-observer.ts` (1261 lines, loaded at `.opencode/opencode.jsonc` L321). Key handlers:
  - `tool.execute.before` L493 — A1 pure-dispatch + §10 gate; ALREADY throws Error to block `.opencode/`/`AGENTS.md` edits when gate token invalid (L577-587) — the EXACT precedent for ticket-gate enforcement.
  - `tool.execute.after` L607
  - `event` L789
  - `experimental.session.compacting` L980
  - custom tools `log_decision` L1006, `context_usage` L1099
- **Registry:** append-only JSONL `.opencode/session/registry.jsonl`, `appendFileSync` L289, fail-soft via `console.warn` L290-294.
- **`output.args` accessible at runtime** (L528-530) — enables reading the dispatch description/prompt inside `tool.execute.before`.
- **Ticket creation rules:**
  - `docs/dev-infra-audit/tickets/README.md` L70-76 — copy `_TEMPLATE.md` → `DIA-<NNN>-<slug>.md`, fill fields, add index row, update counts
  - `.opencode/skills/to-tickets/SKILL.md` L104-106 — session-attribution fields are populated by delegation-observer at delegation time, NOT at creation

## Recommendation (primary finding)

**Option B — plugin enforcement extending delegation-observer:**
- Add a ticket-existence check in `tool.execute.before` when `input.tool === "task"`.
- **Logic:** parse `output.args` (description + prompt); exempt ticket-creation dispatches (heuristic: `/create\s+(a\s+)?ticket|DIA-\d+|ticket.*creation/i`); otherwise scan `docs/dev-infra-audit/tickets/` for a recent OPEN/IN-PROGRESS/DISPATCHED ticket (session_id match OR discovered within 24h); if none → throw `"§10 TICKET GATE"` Error blocking dispatch.
- **Fail-soft on scan errors** (broken gate worse than no gate).
- **Rollback:** `git checkout .opencode/plugins/delegation-observer.ts` + restart.

### Alternatives

| Option | Description | Effectiveness | Cost | Notes |
|--------|-------------|---------------|------|-------|
| A | Prompt hardening | ~50% | fast | model discipline only, weak |
| **B** | **Plugin enforcement (RECOMMENDED)** | **~95%** | **2-3h** | mechanical, extends delegation-observer |
| C | Structural fused create-and-dispatch | ~99% | heaviest | |
| D | Combined with DIA-060/DIA-061 | — | — | unnecessary — both already resolved |

### Delta

- Current: convention only.
- After B: mechanical gate.
- **High delta.**

## Test plan

- **Negative test:** block unticketed dispatch (throw `"§10 TICKET GATE"` Error).
- **Positive test:** allow ticketed dispatch.
- **Durability:** 2+ consecutive sessions.
- **Partial (not mechanically checkable):** "ticket ID referenced in dispatch" is content-level — cannot be verified by a plugin.

## Best-practice citations

- `opencode-best-practices.md` §1 — "Start with built-ins, extend" — plugins/hooks for mechanical enforcement over prompt-only.
- `opencode-best-practices.md` §2 — validation loops.
- `opencode-best-practices.md` §3 — non-inferable constraints in AGENTS.md + mechanical enforcement.
- OpenCode plugin docs https://opencode.ai/docs/plugins — `tool.execute.before` can throw Error to block (.env protection example); `output.args` accessible.
- ADR-004 (`.opencode/memory/adr.md` L209-231) — plugins-as-hooks canonical pattern for lifecycle observation.

## Confidence

| Item | Confidence |
|------|------------|
| DIA-060 resolved — tickets path allowed (L90-91 read, L102-103 glob) | HIGH |
| delegation-observer `tool.execute.before` throw precedent (L577-587) | HIGH |
| Option B mechanical effectiveness (~95%) | HIGH |
| Option B testability (negative/positive/durability) | HIGH |
| Content-level "ticket ID referenced in dispatch" check | PARTIAL |

## Sources

- `.opencode/opencode.jsonc` (L86-94 read block, L99-104 glob block, L321 plugin load)
- `.opencode/plugins/delegation-observer.ts` (L289-294, L493, L528-530, L577-587, L607, L789, L980, L1006, L1099)
- `.opencode/session/registry.jsonl`
- `docs/dev-infra-audit/tickets/README.md` (L70-76)
- `.opencode/skills/to-tickets/SKILL.md` (L104-106)
- `.opencode/oh-my-opencode-slim/knowledge/opencode-best-practices.md` (§1-3)
- `.opencode/memory/adr.md` (ADR-004, L209-231)
- OpenCode plugin docs https://opencode.ai/docs/plugins (live-fetched)
- Learnings: `2026-08-03-orchestrator-coordination-tickets-gate.md` (T3)

## Tags

§10-gate, ticket-gate, DIA-063, DIA-060-resolved, delegation-observer, plugin-enforcement, mechanical-gate, tickets, to-tickets
