# 2026-08-01 — Agent Naming & Permissions (C4 + C6)

> Phase 1 research report + implementation record. Researcher: @opencode_service (read-only), then applied per user decision.

## A. Verified Ground Truth: Two Different Plugins, Two Native Name Sets

| | Global OMO | Project OMO (fork) |
|---|---|---|
| Version | npm `oh-my-opencode-slim` **2.2.8** (`~/.cache/opencode/packages/`) | vendored TS fork at `.opencode/oh-my-opencode-slim/` |
| Native subagents | `explorer, librarian, oracle, designer, fixer, observer, council, councillor` | `code-navigator, researcher, architector, reviewer, designer, coder, observer, council, councillor` |
| AGENT_ALIASES | `explore→explorer`, `frontend-ui-ux-engineer→designer` | `oracle→architector`, `fixer→coder`, `explorer/explore→code-navigator`, `librarian→researcher`, `orchestrator→boss`, `frontend-ui-ux-engineer→designer` |

**Key insight:** the divergence is NOT two name sets inside one config — it is **two different plugin versions** with different canonical names. The project fork already aliases the old global names; global 2.2.8 does NOT know `architector/coder/...`.

**Critical caveat found (replaces earlier wrong claims):**
- Global `.md` prompt files (`oracle.md`, `fixer.md`, ...) live in the **user config dir** (`~/.config/opencode/oh-my-opencode-slim/`), loaded by `loadAgentPrompt()` from config search dirs — NOT library files. Renaming config keys + prompt files survives plugin updates.
- `AGENT_ALIASES`/`SUBAGENT_NAMES` in `src/config/constants.ts` ARE library code — do not edit them; aliases already handle old names.
- Earlier claim "project AGENTS.md is Ukrainian" was FALSE — it is English. Only `docs/dev-infra-audit-plan.md` is Ukrainian.
- Earlier claim "renaming global breaks other projects" was overstated — only 2 projects exist; `visualPoetryResearch` references no agent names.

## B. C4 — Applied Changes (global config → canonical project names)

Files: `~/.config/opencode/oh-my-opencode-slim.jsonc`, `~/.config/opencode/AGENTS.md`, `.md` prompt files.

| Old key | New key |
|---|---|
| `oracle` | `architector` |
| `fixer` | `coder` |
| `code-reviewer` | `reviewer` |
| `opencode-service` | `ai-specialist` |
| `explorer` | `code-navigator` |
| `librarian` | `researcher` |

- 3 presets + agents section keys renamed (4 occurrences each).
- Removed stale `displayName` overrides (`web_scout`, `code_executor`, `code_explorer`, `code_architect`) so the canonical key is the only name.
- `disabled_agents: ["oracle","fixer","explorer","librarian"]` — disables native 2.2.8 agents that no longer have config, preventing duplicates.
- `orchestrator` left as-is (safe: `orchestrator→boss` would break 2.2.8 dispatch).
- Renamed `.md` prompts: `oracle.md→architector.md`, `oracle_append.md→architector_append.md`, `fixer.md→coder.md`, `fixer_append.md→coder_append.md`, `code-reviewer.md→reviewer.md`, `librarian.md→researcher.md`, `librarian_append.md→researcher_append.md`, `explorer_append.md→code-navigator_append.md`.
- Updated internal `@`-references in prompts + AGENTS.md §8 + `memory-shelf.md`.

## C. C6 — Applied Changes (project ai-specialist permissions)

Files: project `.opencode/opencode.jsonc`, `.opencode/oh-my-opencode-slim.jsonc`, `.opencode/practice-protected.md`, `knowledge/ai-assist-sources.yaml`, `knowledge/opencode-best-practices.md`.

- Renamed `ai-assist-specialist` → `ai-specialist` (3 presets + agents block).
- `mode: primary` → `subagent`.
- `edit: allow` → `deny`; added `task: deny`; kept `bash curl/wget` for read-only web research.
- orchestratorPrompt: `edit (allow)→(deny)`, `bash (ask, fetch only)→(allow curl/wget only)`.
- practice-protected.md: kept in pure-analyst tier + footnote documenting curl/wget.

## D. New Audit Task (user-requested, recorded in dev-infra-audit-plan.md M8)

Split `ai-specialist` into two agents:
1. **Resource manager / source curator** — finds relevant doc sources, caches them locally, registers on its own memory-shelf, sets a **critical-review term** per source to periodically re-check for better solutions/changes.
2. **Specialist** — answers from cached docs; if a needed source is missing, requests the resource manager to find new ones. When the resource manager searches, it uses `@researcher` and simultaneously asks the user for recommendations.

## E. Validation

- All 3 jsonc configs parse clean (JSONC-aware strip test).
- No stale `@oracle/@fixer/@web_scout/@code_*` references remain in global config/AGENTS.md/prompts (except intentionally in `disabled_agents`).
- Project configs still reference `@web_scout` in orchestratorPrompts — flagged as remaining C4 project-level cleanup (project still has duplicate `librarian`+`researcher` preset keys).
