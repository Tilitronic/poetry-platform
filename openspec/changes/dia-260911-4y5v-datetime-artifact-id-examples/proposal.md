## Why

Four OpenCode instruction surfaces retain ambiguous or obsolete artifact-ID
guidance despite the current allocated datetime-ID rule. The mixed examples can cause agents to
produce obsolete artifact paths and undermine the allocation workflow.

## What Changes

- Delete only the confirmed obsolete quoted `knowledge/res<NN>-<topic>/sources/`
  example in the orchestrator append guidance, while retaining the datetime
  allocation rule.
- Replace the in-scope analyzer illustrative ID with a multi-word allocated
  datetime example, and clarify that researcher IDs returned by the allocator
  are used verbatim.
- Correct the research-pipeline skill's doubled-slug destination and add the
  same verbatim-ID guard.
- Preserve generic `<type><id>` templates where they describe the naming rule.
- Add a focused obsolete-example search and `make test-config` to the
  implementation verification path.

## Capabilities

No capability specifications are required: this is a documentation-only
configuration correction with no behavior or public-contract change.

## Impact

- `.opencode/oh-my-opencode-slim/orchestrator_append.md`
- `.opencode/skills/research-pipeline/SKILL.md`
- `.opencode/agents/analyzer.md`
- `.opencode/agents/researcher.md`
- No application code, APIs, dependencies, ticket identity, or generated
  artifacts change.

## Testing Decisions

Good evidence proves both the narrow textual correction and the existing config
gate: search only the four scoped files for obsolete and doubled-slug examples,
then run `make test-config`. No new test infrastructure is warranted
for a documentation-only correction.

## Alternatives considered

- Normalize the confirmed in-scope examples and delete only the obsolete quoted
  path: selected. Tier-1 evidence: the current files retain generic naming
  templates while their concrete examples use sequential forms
  (`.opencode/agents/analyzer.md:32-39`,
  `.opencode/agents/researcher.md:9,49-64`, and
  `.opencode/oh-my-opencode-slim/orchestrator_append.md:52-55`, plus
  `.opencode/skills/research-pipeline/SKILL.md:14`).
- Remove all concrete examples: rejected. Tier-1 evidence: the analyst and
  researcher instructions use examples to make the generic artifact-path
  templates actionable; keeping them with the correct ID form preserves that
  clarity.
- Status-quo / do nothing: rejected. Tier-1 evidence: the obsolete sequential
  examples conflict with the allocated datetime form confirmed in the interview.

Chosen option: normalize only the confirmed examples and delete the one obsolete
quoted path, because it resolves the documented inconsistency while preserving
the generic rule and useful guidance.
