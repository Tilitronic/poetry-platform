# OpenAI-first cost-balanced preset gate findings (2026-09-12)

- **Date:** 2026-09-12
- **Ticket:** DIA-260912-dean 'add OpenAI-first cost-balanced preset with Luna Terra Sol routing'
- **Source:** completed ai-specialist gate findings; developer EBDV decision
- **Status:** implemented and runtime-verified on 2026-09-14

## Findings

1. **Authoritative model shape:** OpenCode native `AgentConfig.model` is a single
   scalar `provider/model-id`, not a model-array fallback contract. The strict
   preset must therefore use explicit OpenAI IDs per agent; provider fallback
   behavior must not be inferred from the native scalar field.
2. **Fallback policy:** this preset is strict OpenAI-only. Do not configure a
   fallback to OpenCode Go, Zen/free, or another provider. If a later design
   adds fallback IDs, every ID must still be an OpenAI model and must be
   validated against the live catalog.
3. **Proposed role mapping:** Luna (`openai/gpt-5.6-luna`) handles the
   orchestrator, coder, and bounded/high-volume lanes; Terra
   (`openai/gpt-5.6-terra`) handles planning, review, analysis, and explicit
   escalation; Sol (`openai/gpt-5.6-sol`) handles architecture. Proposed
   primaries are: orchestrator Luna medium; openspec-plan Terra medium; coder
   Luna high; reviewer/analyzer Terra medium; architector Sol high;
   coder-escalated Terra high; analyzer-escalated Terra high.

## Risks and evidence path

- Risks: scalar configuration does not provide automatic recovery; unavailable
  or renamed OpenAI IDs can cause routing failure; one variant applies across
  any future model chain; paid OpenAI usage and quota need monitoring; the
  inactive preset could drift from the live catalog before activation.
- Validation evidence to collect before activation: `.opencode/scripts/validate-opencode-config.sh`,
  `make test-config`, JSONC parsing, runtime resolver output, restart smoke
  dispatches with non-empty results for each distinct model/variant, and an
  independent `@ai-auditor` review. Record the final decision in
  `.opencode/CHANGELOG.yaml`.

## Developer decision (EBDV)

**Option 1 selected, then explicitly activated by the developer.** The strict
preset was added without fallback arrays, validated, selected as the project
default, restarted, and exercised across all six distinct OpenAI model/variant
routes. The initial inactive state was a rollout gate, not a permanent policy.
