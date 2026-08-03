# cebula preset rebalance — Copilot Pro utilization (2026-08-03)

> §10 config-change workflow record (global AGENTS.md §10 Phase 6 — orchestrator-registered GATE research finding).

- **date**: 2026-08-03
- **source**: §10 GATE research 2026-08-03 (@ai_specialist: fresh Copilot Pro + OpenCode Go pricing fetch, model GA check, current-preset audit)
- **finding**: Subscription quota drain was concentrated on OpenCode Go while Copilot Pro credits sat under-utilized, so low-traffic agent lanes can be moved to Copilot without cost risk:
  - **Budget math:** OpenCode Go has a $60/mo cap with aggressive windows ($12/5h + $30/wk); Copilot Pro gives 1,500 credits = $15/mo. Target Copilot:Go spend ratio ≈ 8:1.
  - **Key insight:** Copilot $/token is 4.5–21x the bundled Go rates, so ONLY low-traffic lanes (observer, conspecter, code-navigator, resource-manager) can move — high-volume lanes (coder, analyzer, ai-specialist) must stay on Go.
  - **Models confirmed GA (as of 2026-07-21):** `gpt-5-mini` and `gemini-3.6-flash` are both generally available in the Copilot catalog.
  - **Stale guideline found:** `ai-assist-sources.yaml:204` maps `observer` → "GPT-5 mini (Copilot) — passive monitoring, cheap", but GPT-5 mini is **NOT multimodal** and observer's lane is visual/media analysis (AGENTS.md §9 naming table) — the guideline is wrong; gemini-3.6-flash (multimodal) is the correct observer seat.
- **applied**:
  - `oh-my-opencode-slim.jsonc` cebula preset — `observer` → `github-copilot/gemini-3.6-flash` (fallbacks: opencode-go/kimi-k2.7-code → opencode/big-pickle); `conspecter` → `github-copilot/gpt-5-mini` (fallbacks: opencode-go/deepseek-v4-flash → opencode/deepseek-v4-flash); `code-navigator` → `github-copilot/gpt-5-mini` (same fallbacks); `resource-manager` → `github-copilot/gpt-5-mini` (same fallbacks).
  - `dcp.jsonc` — `github-copilot/gemini-3.6-flash` added to `modelMaxLimits` ("50%") and `modelMinLimits` ("25%"), mirroring `github-copilot/gemini-3.1-pro-preview` (NIT-1 fix).
  - ai-assist-sources.yaml:204 observer mapping left for a follow-up curation pass by @resource-manager (guideline now stale vs config).
- **status**: applied (config change live in working tree; restart OpenCode for effect)
- **outcome**: monitoring — 2-week monitoring plan (2026-08-03 → mid-month): track Copilot vs Go utilization via `token_stats`; flip `conspecter` back to Go if Copilot utilization exceeds 80% by mid-month.
- **lesson**: model-selection guidelines must be re-verified against capability (multimodal vs text-only) at GATE time — a cheap-model heuristic ("passive monitoring, cheap") can silently assign a non-multimodal model to a vision lane; and Copilot price-per-token is 4.5–21x bundled Go rates, so Copilot seats are only safe on low-traffic lanes regardless of credit headroom.
