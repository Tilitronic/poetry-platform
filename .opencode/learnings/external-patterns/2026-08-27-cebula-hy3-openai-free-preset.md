# cebula-hy3 OpenAI-free preset gate findings (DIA-260827-qc59)

Source: read-only ai-specialist section-2.5 gate, 2026-08-27.

1. The live OpenCode catalog exposes `opencode/hy3-free`; there is no
   `opencode-go/hy3-free` model ID.
2. Model variants are provider-specific. `opencode/hy3-free` supports
   `low`, `medium`, and `high`; `opencode-go/hy3` supports `none`, `low`,
   and `high`; DeepSeek V4 Flash supports `low`, `high`, and `max`.
   Qwen 3.7 Plus publishes no named variants.
3. Heterogeneous fallback chains must use inline entries such as
   `{ "id": "opencode/hy3-free", "variant": "medium" }`. A scalar agent
   variant can become unsupported or contradictory when models differ.
4. Reviewer and coder should use different primary model families. Fallback
   arrays activate on recognized errors and do not guarantee recovery from a
   silent empty result.
5. A preset can avoid direct OpenAI API billing by containing no `openai/*`
   models. Removing GPT-branded Copilot fallbacks as well makes the preset
   model-family OpenAI-free, although inactive presets and council seats may
   still contain those references.

Evidence:

- `knowledge/model-registry.yaml` HY3, Qwen, and DeepSeek routing entries.
- `.opencode/oh-my-opencode-slim/knowledge/ai-assist-sources.yaml` model-role
  mapping and reviewer-diversity rule.
- Live `opencode models --verbose` output captured on 2026-08-27.
- <https://opencode.ai/docs/go/>
- <https://opencode.ai/docs/models/>

Developer decision, 2026-08-27: create and activate `cebula-hy3` using the
recommended free-first design, with these overrides: reviewer primary is
DeepSeek V4 Flash High; architector primary is Qwen 3.7 Plus with no unsupported
`high` variant; OpenSpec Plan primary is HY3 Free High. Other role mappings stay
as recommended by the gate.

Outcome: APPROVED, implementation pending.
