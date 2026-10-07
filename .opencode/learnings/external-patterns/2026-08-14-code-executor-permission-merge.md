---
date: 2026-08-14
topic: code-executor permission merge (frontmatter clobbers jsonc agent block)
source: ai-specialist phase-1 gate, DIA-078
ticket: DIA-078-coder-snip-wrapper-loop
status: active
---

# Code-executor permission merge failure (DIA-078 Phase 1 gate findings)

## 1. Merge semantics (CONFIRMED: per-key, frontmatter wins and DESTROYS the JSON object)

When an agent .md frontmatter declares `bash: allow` (flat string) AND the jsonc agent block declares `bash: { "snip": "deny", "snip *": "deny" }` (object), the runtime resolves to the flat string. The object is lost entirely — this is not a merge, it is a replacement.

Root cause (source code analysis, Tier-1): OpenCode config loader (packages/opencode/src/config/config.ts, loadInstanceState) merge order:
1. Global opencode.jsonc (agent blocks merged into result.agent)
2. Project opencode.jsonc (agent blocks merged on top)
3. .opencode/agents/*.md files loaded via ConfigAgent.load(dir) and merged on top: `result.agent = mergeDeep(result.agent ?? {}, ConfigAgent.load(dir))`

mergeDeep is remeda's deep conditional merge. When the source value is a primitive (string "allow") and the target value is an object ({ snip: "deny" }), the types are incompatible — remeda's mergeDeep REPLACES the target with the source. The later value (frontmatter string) destroys the earlier value (JSON object).

Empirical verification: `opencode debug agent code-executor` = 128 effective rules, 0 snip denies. `opencode debug agent coder` = 129 rules, both snip denies present (coder has no .md file, so no clobber).

## 2. Canonical pattern

Both approaches work, but canonical is (a): remove the flat frontmatter entry and let the JSON agent block govern. Official docs (https://opencode.ai/docs/agents/ Permissions section) show frontmatter DOES support nested object syntax — the code-executor.md comment claiming "frontmatter supports flat tool->action only" is factually wrong. However (a) is still preferred: separation of concerns (base tool access in frontmatter, pattern rules in JSON), global permission.bash."*": "allow" already provides the base, less duplication. Variant B syntax (if chosen) would be:

```yaml
---
permission:
  read: allow
  edit: allow
  bash:
    "*": allow
    "snip": deny
    "snip *": deny
  webfetch: deny
---
```

## 3. Gotchas

1. Frontmatter string-vs-object clobber (this bug): flat `tool: action` string in .md frontmatter replaces any `tool: { pattern: action }` object from the JSON agent block. Applies to ANY tool, not just bash.
2. Load order: .md files ALWAYS load after JSON configs; the .md file always wins for conflicting keys.
3. "Last matching rule wins" within a single permission object (WITHIN-object rule, not cross-source).
4. permission key naming: read, edit, bash, glob, grep, task, doom_loop, webfetch, websearch, lsp, skill, question, external_directory, todowrite. doom_loop accepts flat action only; bash/edit/read/glob/grep/task/external_directory/lsp/skill accept either flat or object syntax.
5. Restart required for permission changes to take effect.
6. Debug: `opencode debug agent <name>` (effective rules), `opencode debug config` (merged config).
7. Agents with NO .md file are immune to this bug class (coder, coder-escalated).
8. gigaplan.md is vulnerable too (flat `bash: deny` in frontmatter) — latent if a JSON block is ever added.
9. gigabuild.md has no permission frontmatter — safe.

## 4. Recommendation (Phase 2 input)

Variant A: remove `bash: allow` from code-executor.md frontmatter (L10) so the JSON agent block snip denies govern; global "*": "allow" provides the base. Matches the proven coder pattern, minimal, no frontmatter object syntax risk. Must correct the stale comment L12-14. Variant C (status quo) unacceptable — empirical evidence (3 consecutive lanes violating prompt guardrails) proves prompt-level defense structurally insufficient.

## 5. Sources

- https://opencode.ai/docs/agents/ (2026-08-14, Tier-2)
- https://opencode.ai/docs/permissions/ (2026-08-14, Tier-2)
- https://opencode.ai/docs/config/ (2026-08-14, Tier-2)
- https://github.com/anomalyco/opencode/blob/dev/packages/opencode/src/config/config.ts (2026-08-14, Tier-1)
- https://github.com/anomalyco/opencode/blob/dev/packages/opencode/src/config/agent.ts (2026-08-14, Tier-1)
- .opencode/oh-my-opencode-slim/knowledge/opencode-best-practices.md (Tier-1; no specific merge-semantics guidance — gap to capture)
- docs/dev-infra-audit/tickets/DIA-078-coder-snip-wrapper-loop.md (Tier-3)
- ~/.config/opencode/opencode.jsonc (Tier-3)
- .opencode/opencode.jsonc (Tier-3)
- ~/.config/opencode/agents/code-executor.md (Tier-3)
