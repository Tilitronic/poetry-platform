# DIA-260901-r0hx: qwen3.8-flash preset swap - ai-specialist findings (2026-09-01)

- **Date:** 2026-09-01
- **Ticket:** DIA-260901-r0hx
- **Source:** ai-specialist read-only research (AGENTS.md section 2.5 gate step) - model-identifier swap analysis across assistant preset definitions
- **Status:** REGISTERED - findings only. No preset or config file was edited by this registration (knowledge-registration task only).

## Ticket

- **DIA-260901-r0hx** (OPEN) - "register research findings to the learnings directory (knowledge-registration task, NOT a config edit)". This entry is the mandatory ai-specialist findings registration that must precede any @coder config-work dispatch for the swap.

## Finding

- **Swap:** replacing model identifier `opencode-go/qwen3.7-plus` with `opencode-go/qwen3.8-flash` across all presets is a **mechanical, drop-in swap** (identical Anthropic-messages endpoint).
- **Scope:** 20 occurrences in 3 files (preset definitions). No architecture or prompt change required.
- **Coupled renames:** the council seat key and the permission allow-list key that embed the model identifier must be renamed together with the model `id` fields; renaming only the `id` values would leave dangling seat/permission keys.
- **Registry:** the model routing registry carries model-specific pricing that must be updated alongside the identifier swap; pricing is model-specific and stale pricing would misrepresent cost.
- **Benchmark gap:** no archived benchmark for the new model (`qwen3.8-flash`) yet. The swap is mechanical on the routing/endpoint axis; performance characteristics remain unverified until a benchmark conspect is archived.

## Recommendation

- **PROCEED (mechanical, no design needed).** The change is a find-replace across the 3 preset files with the coupled council/permission key renames and a registry pricing update. No `design.md` or architecture decision is required. Route directly to `@coder` for the mechanical swap.

## Caveat

- **Historical files must be excluded from any find-replace.** Changelog (`.opencode/CHANGELOG.yaml`/`.md`), memory (`.opencode/memory/`), and knowledge conspects (`knowledge/` / `.opencode/oh-my-opencode-slim/knowledge/`) are historical evidence and must NOT be touched by the swap. The coder's find-replace must be scoped to the 3 live preset/config files only.

## Reusable lesson

- Treat model-identifier swaps as a 4-surface mechanical change: (1) preset `id` fields, (2) council seat keys, (3) permission allow-list keys, (4) routing-registry pricing. Verify endpoint compatibility first; if identical, the swap is drop-in and needs no design gate. Always exclude historical/evidence files from the replace scope.

## Tags

DIA-260901-r0hx, qwen3.7-plus, qwen3.8-flash, opencode-go, preset-swap, mechanical-swap, anthropic-messages, council-seat-key, permission-allow-list, model-routing-registry, pricing, benchmark-gap, ai-specialist-gate
