# Gate FINDINGS - oh-my-opencode-slim 3.0.x config compatibility (DIA-261119-vioa, 2026-11-20)

> Section 2.5 config gate (read-only ai-specialist research lane) for the OMO 3.x pin bump in the V2 tree. Registered per AGENTS.md section 2.5 step 1. Governing ticket: DIA-261119-vioa.

date: 2026-11-20

## Source

- ai-specialist read-only research lane, consulted 2026-11-20: oh-my-opencode-slim releases for 3.0.7 and 3.0.5, PR #1787, docs/configuration.md, README.
- Registration (this file) + pin bump performed by the coder lane of the same campaign ticket, step order: findings first, then the config bump.

## Verdict

- **APPROVE: 3.0.x is a breaking schema revision, but this repo's config surface is entirely inside the 3.x-valid key set.** The keys we actually declare - top-level `preset`, `compactSidebar`, `disabled_agents`, `presets`, `agents`, `council.presets`, and per-agent `model` / `variant` / `temperature` / `skills` / `mcps` / `orchestratorPrompt` - all remain valid under the 3.x schema. No config rewrite is required for the bump itself.

## Removed keys we do NOT use

3.0.x removes a set of keys; none of them appear in this repo's config, so the removals are inert here:

- `webfetch`
- `tmux`
- `council.master*`
- the `councillors` wrapper
- fallback timeout / retry keys
- `multiplexer.zellij_pane_mode`
- `backgroundJobs.*` lifecycle keys

## Two semantics to watch (post-bump)

1. **`disabled_agents` librarian now disables `explorer`.** We disable both entries already, so the net effect survives the change - but any future edit that disables `librarian` alone will now also silence `explorer`.
2. **`oracle` / `fixer` alias validity in 3.x is unconfirmed.** Both are disabled aliases in our config (see the agent-name lockstep table); a config smoke test after the bump closes this.

## Host requirement

- OMO 3.x requires OpenCode >= 2.3.0. Our V2 image pins OpenCode 2.3.2 (`Dockerfile.dev` `ARG OPENCODE_VERSION`), so the V2 service satisfies the floor. V1 stays on the 1.18.32 toolchain pin and keeps OMO 2.2.19 - the per-service split is intended (ADR 11).

## Sources (all consulted 2026-11-20)

- oh-my-opencode-slim releases: 3.0.7 and 3.0.5
- oh-my-opencode-slim PR #1787
- oh-my-opencode-slim docs/configuration.md
- oh-my-opencode-slim README

## Caveat

- The docs consulted were **master-HEAD, not tag-pinned**. A post-bump config smoke test (config load + startup in the dev-v2 service) closes that gap: it is the only check that validates the 3.0.7 tag's schema against our config rather than the moving HEAD docs.

## Tags

DIA-261119-vioa, oh-my-opencode-slim, omo-3x, config-compatibility, pin-bump, section-2.5-gate, ADR-11

status: registered (findings recorded 2026-11-20; bump + gate evidence reported to orchestrator)
