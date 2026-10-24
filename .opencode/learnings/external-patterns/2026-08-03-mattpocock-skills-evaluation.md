# Pattern: mattpocock/skills evaluation — fork+adapt candidates for OpenCode (2026-08-03)

> §10 config-change workflow record (global AGENTS.md §10 Phase 6 — orchestrator-registered GATE research finding).

## Source

- **mattpocock/skills**: 200,609 stars, MIT license, last push 2026-08-03, actively maintained, 22 skills (Engineering + Productivity tiers; user-invoked + model-invoked modes).
- **Pure-Markdown skills** — no MCP/shell/env dependencies → trivial OpenCode compatibility.

## Evaluation verdicts

- **ADOPT (5)**:
  - **grill-with-docs + domain-modeling + grilling** — MUST-HAVE: persistent CONTEXT.md glossary + inline ADR discipline; fills our biggest gap; pairs with @openspec-plan; addresses ana004 Phase-3 remediation "port AIHero grill protocol into @openspec-plan".
  - **to-tickets** — MUST-HAVE: tracer-bullet vertical slices + blocking edges + expand-contract pattern; bridges OpenSpec tasks.md → future ticket-system MCP.
  - **code-review** — Fowler 12-smell baseline (extract into @reviewer, S effort).
  - **diagnosing-bugs** — merge "build-feedback-loop-first" discipline into debugging-workflow, M effort.
  - **resolving-merge-conflicts** — new capability we lack, S effort.
- **SKIP (esp.)**:
  - **handoff** — our dia-redispatch-cycle HANDOFF.md is richer (5-subsection prognosis, crisis C1–C5, cycles budget, independent verification).
  - **to-spec** — anti-pattern (synthesizes spec without interview; exactly the ana004 bypass path we fight).
- **Others skipped**: ask-matt, setup-matt-pocock-skills (N/A); implement/tdd (we have tdd-craftsman+coder+reviewer); grill-me/grilling (we have @openspec-plan+openspec-explore); writing-great-skills (we have writing-skills); triage (overkill for 4-ticket ledger); wayfinder/prototype/improve-codebase-architecture/research/teach/codebase-design (defer or partial).

## Key decisions/insights

- **License MIT** → add NOTICE comment per forked file: `<!-- Forked from mattpocock/skills (MIT License, https://github.com/mattpocock/skills). Original Copyright (c) Matt Pocock. -->` + adapted-note on modified files.
- **Integration points**:
  - CONTEXT.md at repo root + docs/adr/ (compatible with .sdd/<module>/architecture.md three-layer model per res001 reconciliation).
  - to-tickets local mode maps to docs/dev-infra-audit/tickets/ ledger with new "Blocked by:" field + vertical-slice discipline in tasks.md + expand-contract section.
  - code-review baseline extends @reviewer Standards axis (documented standard overrides baseline; smells are labelled heuristics).
- **Practice-protected interaction**: grill-with-docs/domain-modeling must NOT write proposal/design substance without user draft — may challenge vocabulary against CONTEXT.md and propose ADRs (zone §1).
- **Risks**: §10 gate overhead per adoption (~1 cycle each); skill bloat 26→31 (mitigate: user-invoked vs model-invoked activation); fork drift (upstream active; we import only 5/22; optional re-sync); to-spec landmine (never import).
- **Effort**: ~8–9h total (grill-with-docs M, to-tickets M, code-review S, diagnosing-bugs M, merge-conflicts S).
- **Sequence**: 1 grill-with-docs → 2 to-tickets → 3 code-review baseline → 4 diagnosing-bugs → 5 resolving-merge-conflicts.

## Outcome

- **adopted** (2026-08-03, §10 Phases 1–6 complete: owner approved all 5, design arc-1, implementation cod-7/8, independent review approve-with-changes, fixes applied; uncommitted)

## Outcome notes

- 4 of 5 skills landed as forked project skills under `.opencode/skills/` (domain-grilling, to-tickets, code-review-fowler, resolving-merge-conflicts); the 5th (diagnosing-bugs) merged into the existing debugging-workflow skill.
- Fowler 12-smell baseline went to a separate skill (code-review-fowler) instead of extending @reviewer's prompt directly because the reviewer orchestratorPrompt was already over the ~2000ch soft budget.
- Project `debugging-workflow/SKILL.md` needed a parallel update — the project copy shadows the global merge, so both copies had to stay in sync.
- DIA-037 filed for the missing SKILL.md content-validation gate (frontmatter parse + 'Use when' convention checks).
