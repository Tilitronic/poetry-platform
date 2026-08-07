# Learnings Index

Last updated: 2026-08-07

> Historical entries pre-2026-08-02 use 'boss' — canonical name is now 'orchestrator'.

## Knowledge Sources

- **Dynamic experience:** This directory (`.opencode/learnings/`)
- **Static curated literature:** `book-rag` skill (`#rag` queries)

## External Patterns

- [2026-08-07](external-patterns/2026-08-07-cebula-preset-revert.md): cebula preset reverted 7 agents to pre-commit all-flash model assignments (DIA-064) — commit 2e0c4f3e changed flash→pro across the preset; lesson: preset model changes need explicit review before merge

- [2026-08-07](external-patterns/2026-08-07-research-persistence-pipeline.md): Research-to-persistence pipeline — two-level fix (orchestrator skill + researcher output contract) for the @researcher → @conspecter handoff gap

- [2026-08-07](external-patterns/2026-08-07-plugin-hook-args-contract.md): Plugin hook args contract — `tool.execute.before` reads **`output.args`**, NOT `input.args` (DIA-059). Reading `input.args` yields `undefined` at runtime → fail-open security gates. After-hooks DO read `input.args` — do not "fix" those.

See `external-patterns/` for findings from external research (Anthropic blog,
OpenCode docs, oh-my-opencode-slim best practices).

## Registration

Each entry should include:
- `date`: ISO date
- `source`: Which agent/skill/session produced it
- `finding`: What was discovered
- `status`: `confirmed` | `no-effect` | `regressed`

## Index

| Date | Source | Finding | Status |
|------|--------|---------|--------|
| 2026-08-01 | orchestrator + ai-specialist + coder | Restructured boss to AIHero-style strict chain: mandatory Interview Gate → Spec Generation → delegation for ALL engineering work; research/analysis phased into interview/spec but standalone user-requested research remains a valid direct lane; universal no-direct-engineering-work HARD RULE. Files: boss.ts (workflow restructure, escape-hatch removal, @researcher Standalone/Phased), boss_append.md (HARD RULE + Interview-First Gate + routing table), oh-my-opencode-slim.jsonc (openspec-plan research/analysis dispatch guidance). See `external-patterns/2026-08-01-boss-aihero-interview-delegation.md`. | applied |
| 2026-08-01 | orchestrator + ai-specialist | Aligned feature workflow with AIHero vertical-slice TDD: installed openspec CLI, rewired config.yaml (vertical-slice tasks + seams + apply guidance), removed tdd-craftsman REFACTOR phase (defer to reviewer), two-axis reviewer (Standards+Fowler/Spec), fixed dangling skills + /tdd-cycle. See `external-patterns/2026-08-01-aihero-vertical-slice-alignment.md`. | confirmed |
| 2026-08-01 | C4/C6 session | Global OMO (npm 2.2.8) uses native agent names `oracle/fixer/librarian/explorer`; the project fork uses `architector/coder/reviewer/code-navigator/researcher` with alias mapping. Renamed global config keys to canonical project names + disabled old natives; renamed project `ai-assist-specialist`→`ai-specialist` with `edit:deny`/`mode:subagent`. See `external-patterns/2026-08-01-agent-naming-permissions.md`. | confirmed |
| 2026-07-13 | ai-assist-specialist | `web: allow` is invalid — must be `webfetch: allow`. Fix applied to agents/ai-assist-specialist.md. | confirmed |
| 2026-07-13 | code-executor-design | Created agents/code-executor.md with inline writing guidelines (P1–P4, naming tables, smell checklist). Must be allowed in opencode.jsonc `build.task` permissions. | confirmed |
| 2026-08-02 | orchestrator + ai-specialist + architector + coder | Interview-first spec-authoring enforcement (Phase 1): rewrote openspec-propose skill + /opsx-propose,/opsx-new,/opsx-continue,/tdd-cycle to mandatory-interview-first; boss skills denylist ["*","!openspec-propose"] (3 presets); fast-path opt-in gate + interactive review gate in boss_append.md; grill protocol (depth modes + Q1–Q11) in @openspec-plan orchestratorPrompt; ownership tracking in practice-protected.md; validation script scripts/test-interview-enforcement.sh (5/5). Option C: no forks. See external-patterns/2026-08-02-interview-gate-enforcement.md. | applied |
| 2026-08-02 | ai-specialist | Gate research: OMO v2.2.8 running boss base prompt has NO Interview Gate (only vendored-fork boss.ts has it, never built); 52/100 score caused by 5 one-shot bypass paths funneling through openspec-propose skill; denylist syntax ["*","!name"] confirmed; boss.md full replacement rejected due to high drift risk. | applied |
| 2026-08-02 | orchestrator + ai-specialist (gate) + coder + ai-specialist (review) | Boss delegation enforcement (Phase 2): default_agent "boss" resolved to a BARE config agent (no prompt, no permissions) while 2.2.8 registers the delegating primary as `orchestrator` — its config hook only overrides default_agent when unset/subagent (dist:40216), so the bare boss ran and did engineering work itself → context overflow. Fixed: default_agent → orchestrator; `agent.orchestrator` with edit/write/bash/envsitter/webfetch deny (mechanical enforcement); new `orchestrator_append.md` (HARD RULE, Interview-First Gate, Verification Discipline — orchestrator only reviews specialist verification results, never runs them). NOTE: `boss_append.md` is dead config for 2.2.8 (loads `orchestrator_append.md`); two agents (ai-specialist gate + review) twice mis-cited fork source `src/agents/index.ts:495` — always verify against deployed npm dist. See `external-patterns/2026-08-02-boss-delegation-enforcement.md`. | applied |
| 2026-08-02 | orchestrator + ai-specialist + coder (config audit) | OpenCode config audit & fixes: gate findings recorded in `external-patterns/2026-08-02-config-audit-fixes.md` (deepMerge array replacement behaviour, model-string override short-circuit, runtime log visibility for resolved model, `opencode models` practical authority, and two flagged residual model refs). Status: applied. | applied |
| 2026-08-04 | ai--3 research + owner (§10) | Copilot legacy-annual pricing: credit multiplier (PRU) governs cost — `gemini-3.5-flash` 14x (worst deal, ~21 interactions/mo), `gpt-5-mini` 0.33x (cheapest, GitHub #1 recommended vision model, ~909 interactions/mo); ≤6x owner policy; cebula observer fallback swapped gemini-3.5-flash → gpt-5-mini (42x cheaper per interaction). See `external-patterns/2026-08-04-copilot-legacy-annual-pricing.md`. | applied |
| 2026-08-05 | Copilot PR #2 review + ai-specialist gate (§10, ses_02f7d3527ffe7vY9c5406DJ6Lb) | AI-tooling config fixes (Commit B of dev-infra-copilot-fixes): hardcoded `/home/qualt` paths in `.opencode/commands/` telemetry commands → `${HOME:?}` POSIX fail-fast guard (portability); committed runtime cache `.config/opencode/skills/book-rag/knowledge-bases.yaml` → gitignore + delete (generated artifacts out of version control); CORRECTED rationale — `query_rag.py` exists at `.opencode/scripts/query_rag.py` (1328 lines), cache regenerated on demand, so "orphaned" spec claim was false (lesson: verify file-existence claims against the tree); failures.md duplicate bullet dedup (memory hygiene). See `external-patterns/2026-08-05-copilot-pr2-config-fixes.md`. | applied |
| 2026-08-06 | §10 silent-session-logging campaign (ai-specialist gate + independent review) | Plugin ground truth: `Hooks.tool` registration returns `tool:` on the hooks object (NOT a separate `{hooks, tool}` shape); `appendFileSync` in a hook handler blocks the event loop (hooks awaited sequentially); no official append-only sidecar — official channel is `client.app.log()`; `tool.execute.after` fires for ALL tools. Adopted silent JSONL sidecar via plugin hooks (fail-soft try/catch, console.warn, no rethrow) + `log_decision` allow on orchestrator; messages.md derived view; jsonl-cross-check gate; DIA-051 resolved-by-implementation; P5 smoke 100% (8/8). See `external-patterns/2026-08-06-silent-session-logging.md`. | worked |
| 2026-08-07 | orchestrator + ai-specialist (gate) + coder | Research-to-persistence pipeline: NEW skill research-pipeline + researcher agent file + orchestratorPrompt ×3 presets. Closes @researcher → @conspecter handoff gap. See `external-patterns/2026-08-07-research-persistence-pipeline.md`. | applied |
| 2026-08-07 | code-executor (§10 Phase 4) | cebula preset: full revert of 7 agents to pre-commit all-flash model assignments (DIA-064). Commit 2e0c4f3e had changed all 7 from flash→pro — cost-critical leak. Approved Option A. Lesson: preset model changes in config commits need explicit review. See `external-patterns/2026-08-07-cebula-preset-revert.md`. | applied |
