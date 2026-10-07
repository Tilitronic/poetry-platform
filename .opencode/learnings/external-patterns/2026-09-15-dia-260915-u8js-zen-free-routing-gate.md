# DIA-260915-u8js Zen-free routing gate

## Scope

Read-only review of the inactive `muse-qwen-balanced` preset after the active
default moved to `openai-first-cost-balanced`.

## Findings

- Live catalogs expose `opencode/muse-spark-1.3-contributor-free`,
  `opencode/mimo-v2.5-free`, and `openai/gpt-5.6-luna`.
- The pending routes remove paid OpenCode Go fallbacks from orchestrator,
  coder, researcher, resource-manager, memory-manager, and code-navigator.
- The preset remains inactive; the project pointer stays
  `openai-first-cost-balanced`.
- The composition comment still describes the retired paid Muse, DeepSeek,
  and MiMo routing and must be synchronized with the actual block.

## Decision

GO-WITH-CHANGES: retain the pending route mapping, update only its composition
comment, then run config validation, restart/live resolution smoke, independent
config audit, and changelog registration before closing the ticket.

## Outcome

Implemented in `231eafd`. Static config validation passed, live catalogs
resolved all three referenced models, and a process-scoped
`muse-qwen-balanced` run resolved Muse Free and returned non-empty
`U8JS_SMOKE_OK`. Independent config audit passed; the persistent active pointer
remained `openai-first-cost-balanced`.
