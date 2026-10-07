# GitHub Copilot Provider Model-ID Contract (ai-auditor lane error root cause)

## Verdict: the github-copilot/ prefix is CORRECT; a bare model id is WRONG

## Key facts (source-verified 2026-09-02)
1. OpenCode requires provider_id/model_id format (opencode.ai/docs/models): "the full ID is provider_id/model_id". A bare `gpt-5.3-codex` would fail identically to the current error.
2. `github-copilot/gpt-5.3-codex` was verified as a LIVE id twice in this project: CHANGELOG 2026-08-04 and DIA-189 2026-08-17; ADR line 1273 "github-copilot/gpt-5.3-codex is a valid second entry".
3. The "Did you mean: gpt-5.3-codex" dispatch error is a FUZZY MODEL-NAME HINT, not a pasteable id.
4. ROOT CAUSE: the GitHub Copilot provider is NOT currently connected. Fix = `/connect` GitHub Copilot + confirm live ids via `/models` — NOT a config edit.
5. Affected agents (active preset `promo`): ai-auditor (primary github-copilot/gpt-5.3-codex, secondary github-copilot/gemini-3.1-pro-preview), architector (primary github-copilot/gemini-3.1-pro-preview), designer (primary github-copilot/claude-sonnet-4.5), ai-specialist (fallback github-copilot/gpt-5.3-codex, survives via opencode-go/qwen3.8-flash primary), council default seats (github-copilot/gemini-3.1-pro-preview, gpt-5.3-codex, claude-sonnet-4.5). Same ids latent in non-active presets (opencode-go, cebula, free).
6. make test-config has NO model-id validation: validate-opencode-config.sh checks JSONC syntax + config lockstep only; validate-agent-names.sh enforces agent-NAME cross-reference and treats council model-seat names as non-agents. Model ids are exercised only at runtime dispatch or via `opencode models`/`opencode debug agent`.

## Action guidance
- Do NOT apply a bare-id config edit (would break the lane a second way).
- Developer must run `/connect` for GitHub Copilot, then confirm live ids via `/models` / `opencode models`.
- Only if the developer confirms Copilot IS connected and a slug genuinely changed should the id be updated to the live `/models` value — never to a prefix-less bare id.
- After the provider is connected, dispatch @ai-auditor (AGENTS.md section 2.5 Phase 6) for the independent review.

## Sources
- opencode.ai/docs/models + opencode.ai/docs/providers (2026-09-02, Tier-2 fresh)
- .opencode/opencode.jsonc L600-779 (ai-auditor block L622-653 has NO model key — model comes from OMO preset)
- .opencode/oh-my-opencode-slim.jsonc (preset=promo; 19 github-copilot/ hits)
- knowledge/model-registry.yaml (bare gpt-5.3-codex slug, role reviewer, "Copilot credits - skip guard")
- CHANGELOG.yaml / adr.md / learnings (model history: github-copilot/gpt-5.3-codex live 2026-08-04, 2026-08-17)
