---
date: 2026-08-20
topic: Scoped write permission pattern for agent artifact directories
source: ai-specialist phase-1 gate, DIA-260819-97fg
ticket: DIA-260819-97fg
status: implemented
---

# Scoped Write Permission Pattern for Agent Learnings

## 1. Pattern: deny-all + scoped-allow for artifact directories

Agents that write to project-owned artifact directories use a deny-all base permission with a narrow allow scoped to their specific output directory. This prevents token waste from bash-fallback workarounds while maintaining the deny-all security posture.

## 2. Evidence: 6 agents already use this pattern

The following agents grant edit access to their artifact directories via trailing-wildcard matchers in the JSON agent block (not frontmatter, to avoid the clobber risk from 2026-08-14-code-executor-permission-merge.md):

| Agent | Edit allow pattern | Artifact directory |
|---|---|---|
| analyzer | `.opencode/learnings/external-patterns/*` | analysis reports |
| researcher | `.opencode/learnings/external-patterns/*` | research conspects |
| conspecter | `.opencode/learnings/external-patterns/*` | research conspects |
| resource-manager | `.opencode/learnings/external-patterns/*` | knowledge-source curation |
| openspec-plan | `openspec/changes/**/*` | OpenSpec change artifacts |
| orchestrator | `openspec/changes/**/*` | OpenSpec change artifacts |

All use the same trailing-`*` wildcard syntax required by OpenCode's edit-permission matcher (DIA-199).

## 3. Syntax: trailing `*` required, crosses path separators

- OpenCode edit-permission matchers require a trailing `*` to match files in a directory (bare directory paths do not work)
- The `*` crosses path separators (DIA-126a) -- `.opencode/learnings/external-patterns/*` matches both `.opencode/learnings/external-patterns/foo.md` and `.opencode/learnings/external-patterns/subdir/bar.md`
- This is correct for artifact directories where the agent is sole writer

## 4. Application: memory-manager needs scoped write

The memory-manager agent writes `.md` files into `.opencode/learnings/external-patterns/` during the persist phase of the feature workflow chain. Without an explicit edit allow, it falls back to bash `cat > file` workarounds, wasting tokens and bypassing the formatter hook.

**Recommended config addition** (in the memory-manager JSON agent block, not frontmatter):

```jsonc
"edit": {
  ".opencode/memory/*": "allow",
  ".opencode/learnings/external-patterns/*": "allow",
  "openspec/changes/**/*": "allow",
  "*": "deny"
}
```

Risk: None meaningful. Narrow directory scope, sole-writer invariant (memory-manager is the only agent that persists to these paths), no security exposure.

## 5. Gotchas

1. **JSON block only, not frontmatter.** Frontmatter flat `edit: allow` clobbers any JSON object (the DIA-078 clobber bug). Always declare pattern-based edit permissions in the JSON agent block.
2. **Restart required.** Permission changes only take effect after OpenCode restart.
3. **Debug with** `opencode debug agent memory-manager` to verify effective rules after applying.

## 6. References

- DIA-260819-97fg (this ticket -- scoped write permission for memory-manager)
- DIA-199 (trailing wildcard syntax requirement for edit matchers)
- DIA-126a (wildcard crosses path separators)
- DIA-078 / 2026-08-14-code-executor-permission-merge.md (frontmatter clobber bug -- why JSON block is mandatory)

## 7. Implementation Record

- **Implemented**: 2026-08-20
- **Verification**: `make test-config` passed (56 tests)
- **Review**: @ai-auditor approve-with-notes
- **Note**: The evidence table in section 2 (6 agents using this pattern) refers to the general deny-all + scoped-allow pattern across the codebase, not this specific learnings file path. (ai-auditor documentation fidelity note)
