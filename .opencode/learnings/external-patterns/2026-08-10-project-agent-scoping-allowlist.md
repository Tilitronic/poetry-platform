# Project-agent scoping: orchestrator permission.task allowlist (2026-08-10)

- **Date:** 2026-08-10
- **Source:** developer agent-scoping concern raised in session 3 (code-executor is GLOBAL, used for project docs/config lanes per L20260810-001) → ai--3 §10 gate → cod-6 implementation → ai--4 Phase 6 review (GO, no rework).
- **Status:** APPLIED — `.opencode/opencode.jsonc` orchestrator `permission.task` allowlist L106-129; restart-verify pending (next session, after developer restart).

## (a) Developer intent

The project uses ONLY project-scoped agents. Global agents (defined under `~/.config/opencode/`) must not be dispatched from the project orchestrator — the project's routing and permission contracts apply to project agents; global agents bypass those contracts (e.g., global code-executor carries its own `bash: allow` and was invisible to project permission scoping).

## (b) Mechanics

- **OpenCode merges global + project agents additively.** Global agent-markdown discovery (`~/.config/opencode/agents/*.md`) and project agents coexist; a `subagent_type` is resolvable if it exists in EITHER scope. This is why `code-executor` was dispatchable despite having no project block.
- **`permission.task` allowlist is THE mechanical control.** OpenCode's agent permissions support a `task` key whose value can be an allowlist of subagent types (or `"allow"` / `"deny"`). A denied subagent is REMOVED from the Task tool entirely for that agent — dispatch fails before any prompt/model machinery runs (opencode.ai/docs/agents).
- **OMO `disabled_agents` is UI-only.** It hides an agent from the UI/picker but does NOT prevent `task()` dispatch — it is not a mechanical control.
- **`validate-agent-names.sh` scopes to project S1–S4 only.** It validates the project agent-name contract (AGENTS.md table ↔ project opencode.jsonc blocks ↔ OMO config ↔ `.opencode/agents/*.md` stems). Global agents are invisible to it — so global-only agents like code-executor never surface in `make test-config`; their blocking must be enforced by the allowlist, not by the validator.

## (c) Allowlist diff (before/after)

- **Before:** `"permission": { ..., "task": "allow" }` (orchestrator could dispatch ANY resolvable subagent type, including globals).
- **After:** `"permission": { ..., "task": { "coder": "allow", "architector": "allow", "analyzer": "allow", "reviewer": "allow", "designer": "allow", "code-navigator": "allow", "researcher": "allow", "observer": "allow", "memory-manager": "allow", "resource-manager": "allow", "ai-specialist": "allow", "ai-auditor": "allow", "conspecter": "allow", "openspec-plan": "allow", "council": "allow", "councillor": "allow", "councillor-claude-sonnet-4.5": "allow", "councillor-deepseek": "allow", "councillor-gemini-3.1-pro": "allow", "councillor-gpt-5.3-codex": "allow", "councillor-qwen3.7-plus": "allow", "*": "deny" } }` (21 named allows + `"*": "deny"` fallback, opencode.jsonc L106-129).

## (d) Now-blocked globals

`code-executor`, `gigabuild`, `gigaplan` — all global-only agents, now denied for orchestrator dispatch via the `"*": "deny"` catch-all. After restart, `task({subagent_type: 'code-executor'})` must fail with an allowed-agents error; project agents (coder, reviewer, architector, …) still dispatch normally.

## (e) councillor-* inert finding

The `councillor-*` allowlist entries (councillor-claude-sonnet-4.5, councillor-deepseek, councillor-gemini-3.1-pro, councillor-gpt-5.3-codex, councillor-qwen3.7-plus) are inert/superfluous — harmless, no S1 (AGENTS.md §9) row needed for them. Kept to future-proof council dispatch; no contract drift.

## (f) doom_loop live-efficacy — OPEN QUESTION

DOOM_LOOP LIVE-EFFICACY UNPROVEN: cod-6's 3×-identical snip calls were NOT blocked despite `doom_loop: deny` being present in session-2 config. Requires a deliberate live probe next session (after restart): intentional 3×-identical tool call in a coder lane → verify the 3rd is blocked. This determines whether `doom_loop: deny` actually enforces at runtime.

## (g) Lesson

Advisory routing (L20260810-001) silently used a GLOBAL agent (code-executor) for project docs/config lanes — no mechanical blocker existed, and the global agent did not inherit project permission scoping. Mechanical scoping (permission.task allowlist) is the fix. Routing decisions must flag agent provenance (project vs global) so a routing choice never silently escapes project contracts.

## Tags

§10, permission.task, allowlist, agent-scoping, project-agents, code-executor, gigabuild, gigaplan, doom_loop, agent-provenance, coder-restore
