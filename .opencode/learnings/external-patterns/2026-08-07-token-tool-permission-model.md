# Token-tool permission model — wildcard denies + plugin-array concatenation (2026-08-07)

- **Date:** 2026-08-07
- **Source:** §10 Phase-1 gate research by @ai-specialist for DIA-055/056 (token-tool permission hardening). Registered per AGENTS.md §10 ("orchestrator registers the findings"); the executor lane persists them so they are recoverable beyond the git diffs. Owner approval (Phase 2) received; implementation is the 4-delta append-only change to `.opencode/opencode.jsonc` agent permission blocks.
- **Status:** applied (Phase 4 implementation done; independent @ai-specialist review + restart + Phase-5 smoke follow)

## Findings

- **F1 — OpenCode plugin arrays CONCATENATE across config layers.** Global + project config plugin lists are merged — `Array.from(new Set([...target.plugin, ...source.plugin]))` in `packages/opencode/src/config/config.ts`. Consequence: token tools (opencode-token-monitor@0.5.0) are loaded in the project context even when the project `plugin[]` array does not list the plugin. Permission hardening must therefore be per-agent deny, not plugin-list removal. Best-practice rule: "Deny tools by name at the agent scope when the agent must not use them."

- **F2 — OpenCode permission model: most permissions default to allow.** Per-tool override maps (agent → global → default-allow); unlisted tools fall through to default allow. Wildcard `tool_*` syntax is supported by OpenCode (mymcp_* documented example); this change introduces the `token_*` wildcard as a new application of that syntax. This repo's envsitter entries are NOT wildcards — they are explicit per-tool keys (e.g. `.opencode/opencode.jsonc` lines 78-85, 250-265). Deny-by-default is NOT implemented upstream. Best-practice rule: "Permission rules must enumerate every tool an agent may use; unlisted tools are not implicitly denied."

- **F3 — opencode-token-monitor@0.5.0 `token_export` is write-capable.** Arbitrary `file_path` via `mkdirSync`+`writeFileSync` (NO path allowlist) plus an auto CWD-write when content > 10k chars. `token_stats` / `token_history` are read-only. Only `token_export` needs the deny for write-capability closure; the wildcard `token_*`: deny covers all three uniformly.

- **F4 — DIA-055 S5 correction.** opencode-best-practices.md and ai-assist-sources.yaml DO exist on disk at `.opencode/oh-my-opencode-slim/knowledge/` — the prior "missing from disk" assertion (2026-08-06 learnings) was wrong. No @resource-manager curation action required for existence.

- **F5 — Unified fold-in fix (DIA-056 candidate (d)).** @ai-auditor verifies token denies via config-block inspection (candidate c), never invokes token tools at runtime — avoids stacking the token-monitor trigger during audit. Verification is static: read the `permission` block and assert `token_*: deny` present.

## Outcome

Owner approved the 4-delta change: (Δ1) orchestrator keeps `token_export: allow` (explicit intent, token-accounting use); (Δ2) pure-analyst tier (architector/analyzer/reviewer) gain `token_*: deny`; (Δ3) ai-auditor `token_export: deny` → `token_*: deny`; (Δ4) council/resource-manager/ai-specialist gain `token_*: deny`. All edits append-only, preserving existing envsitter_* entries and comments. Restart + Phase-5 smoke (attempt token_export from a denied tier → must be DENIED) follows the independent @ai-specialist review.

## Tags

§10-gate, permissions, token-monitor, plugin-array-concatenation, wildcard-deny, DIA-055, DIA-056
