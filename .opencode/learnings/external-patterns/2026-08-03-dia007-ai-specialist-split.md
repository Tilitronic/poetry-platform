# 2026-08-03 — Split ai-specialist into resource-manager + ai-specialist (DIA-007)

> §10 config-change workflow record (global AGENTS.md §10 Phase 6 — orchestrator-registered finding).

## Pattern

Splitting a dual-role agent into a **mechanical curator** + a **pure-analyst reviewer**:

- **resource-manager (NEW)** — artifact-producer tier: cheap/fast model (`opencode-go/deepseek-v4-flash`), edit scoped to `.opencode/oh-my-opencode-slim/knowledge/*` only, bash curl/wget/trafilatura, `task: allow` → @researcher/@conspecter, mcps [websearch]. Owns ai-assist-sources.yaml curation, Tier-1 caching, Tier-2 re-fetch, awesome-opencode star-count evaluation.
- **ai-specialist (RETAINED)** — unchanged name and roles: pure-analyst `qwen3.7-plus`, still the §10 gate + independent review + telemetry pattern receiver. Prompt gained one step (source-referral to @resource-manager); orchestratorPrompt trimmed to a ~2-line routing summary.

Driven by the §10 workflow: **gate research → owner decision → architector design → coder implement → independent review → register**. The dual-role agent previously served as both the §10 gate AND the resource curator; the split keeps the reviewer pure and moves mechanical curation to a cheaper, narrowly-scoped worker.

## Outcome

- **Status:** implemented.
- **Phase 6 review:** APPROVE WITH CHANGES — required fix was the ledger sync; accepted by owner.
- **Ledger sync:** accepted by owner; DIA-007 now IMPLEMENTED in the ticket ledger with rollup recount.
- **Commit:** pending post-restart-verify (restart OpenCode + functional smoke test first).

## Best-practice rules that drove the design

- practice-protected.md §5 tier taxonomy — artifact-producers write only to their designated output dirs; `resource-manager` edit is scoped to `.opencode/oh-my-opencode-slim/knowledge/*` only.
- Minimal-delta prompt changes preserve tested behavior — ai-specialist prompt gained a single source-referral step instead of a rewrite; orchestratorPrompt was only trimmed (mild redundancy fix, no dual-prompt conflict).
- Independent review (Phase 6) is mandatory for §10 changes — the review caught the stale ledger status, which the owner accepted as a required fix.
- Bonus: the split also fixed pre-existing stale WINDOWS paths in ai-assist-sources.yaml (6 paths → Linux).
