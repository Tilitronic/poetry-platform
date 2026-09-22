# Pattern: Orchestrator coordination + ticket format — §10 GATE follow-ups (2026-08-03)

> §10 config-change workflow record (global AGENTS.md §10 Phase 1 — orchestrator-registered GATE research finding; §10 Phase 2 owner decision pending).

## Source

- **ai-specialist lane ai--3** (session `ses_038c103c3ffeq0cD7ho9WjqBjO`); full report in session log rows 110.
- Three follow-up topics registered from §10 Phase 1 GATE research: T1 OTel GenAI logging convention, T2 file-mediated agent coordination, T3 ticket format standardization.

## T1 — Orchestrator logging → OTel GenAI JSON convention

- **Current state**: orchestrator logging = markdown table in `.opencode/session/messages.md` (legacy 7-column + VP 9-column rows coexist); no machine-readable consumer exists; sentinel validates lane reconciliation on the markdown.
- **OTel GenAI semconv**: repository moved to open-telemetry/semantic-conventions-genai (v1.42.0, June 2026); ALL `gen_ai.*` attributes are **Development status** (schema can change); span types `invoke_agent` / `invoke_workflow` / `execute_tool` / `plan` / `chat`; key attributes `gen_ai.agent.name`/`id`, `gen_ai.operation.name` (Required), `gen_ai.workflow.name`, `gen_ai.provider.name`, `gen_ai.request.model`, `gen_ai.usage.input`/`output_tokens`; task spans only proposed (issue #55).
- **Recommendation**: JSONL sidecar `.opencode/session/messages.jsonl` — additive, `messages.md` + sentinel unchanged; one JSON object per delegation event carrying `gen_ai` attribute names plus `lane_id` and `cycle_id`; pin convention version/date; no consumer today (opencode-telemetry SQLite + token-monitor do not read JSONL).
- **Risks**: Development-status schema (HIGH), dual-write sync, no consumer, per-lane token counts unavailable (populate at cycle boundaries/handoff only).

## T2 — File-mediated agent coordination

- **Current state**: ALREADY DONE — mature file-mediated system: `messages.md` (append-only log) + `HANDOFF.md` (5-subsection prognosis) + `NEXT-RUN.md` §7 redispatch protocol + sentinel (lane reconciliation) + DIA ticket ledger + `c-YYYYMMDD-HHMMss` cycle ids + C1–C5 crisis triggers + practice-protected zones. Owner intuition confirmed.
- **Non-gaps**: agent-to-agent direct handoff (by design — single delegating orchestrator); outbox/inbox (HANDOFF = outbox, messages.md = inbox).
- **Recommendation**: do NOT redesign. Optional micros: (a) auto-regenerate ledger rollup script (addresses manual rollup drift seen in DIA-006 cleanup), (b) token-aware dispatch rule in `NEXT-RUN.md` §2.

## T3 — Ticket format standardization (markdown+YAML, kanban, archiving)

- **Current state**: `_TEMPLATE.md` uses markdown bullet-list metadata (NOT YAML frontmatter); status/severity vocabulary drift in practice (DEFERRED/MONITOR/IMPLEMENTED/Medium used but not in template enum); archiving = deletion (32 tickets deleted in commit 23b1e22).
- **Ecosystem consensus (2026)**: YAML frontmatter metadata + per-status folders + generated BOARD.md index + `archive/` (or `done/`) folder + markdown body (Kanbania, mdboard, tickets.md, kanban-md, backlog-as-data, Lytos issue-board).
- **Recommendation Phase 1 (immediate)**: harmonize status enum (add DEFERRED/MONITOR/IMPLEMENTED) + severity enum (add Medium); convert `_TEMPLATE.md` to YAML frontmatter (id/title/area/severity/status/blocked_by/discovered/created/updated); archive = move to `tickets/archive/` instead of deletion; update to-tickets skill (~10 lines). **Phase 2 (defer)**: per-status folders + forkflows/worktrees to ticket-system MCP.
- "darkmatter" interpreted as YAML frontmatter — flagged for owner confirmation.

## Env check

- All 4 new skills exist with valid frontmatter + MIT NOTICE (domain-grilling 95L, to-tickets 99L, code-review-fowler 34L, resolving-merge-conflicts 29L); debugging-workflow project copy = 324L updated; code-review-fowler in all 3 reviewer arrays (L115/258/437). Absence from session registry = RESTART-PENDING, not a registration defect.

## Outcome

- **adopted** (2026-08-03) — §10 Phase 2 owner decision; designed (arc-2); implemented (cod-11/cod-12); independent review APPROVE-WITH-CHANGES (ai--4: 1 Minor + 1 Suggestion, both applied); registered 2026-08-03.
