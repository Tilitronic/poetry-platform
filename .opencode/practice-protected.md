# Practice-Protected Zones

These zones are protected for skill growth over throughput. In these zones,
agents MUST ask guiding questions and wait for the user's draft before
proceeding or applying changes.

## Protected Zones

### 1. OpenSpec proposal.md / design.md authoring
- Agents may reference existing specs but must NOT write new proposal/design
  content without the user's explicit draft.
- Exception: fixing formatting or broken links in existing specs.

### 2. TDD edge-case identification
- During RED-GREEN-REFACTOR cycles, edge cases identified by agents must be
  surfaced to the user for prioritization before test implementation.
- The user decides which edge cases to test, not the agent.

### 3. Architectural decisions flagged by @architector
- When an agent detects a significant architectural decision point, it must
  present the options with trade-offs and wait for explicit user direction.
- Do not silently choose an architecture path and implement it.

### 4. Review disposition
- When @reviewer produces findings, the developer decides disposition
  (accept/reject/clarify) before the orchestrator proceeds. The orchestrator does not silently
  apply reviewer recommendations.
- Exception: automated lint/format fixes that the reviewer labels as
  'mechanical' may be auto-applied if the developer has pre-approved mechanical
  fixes.

### 5. Research persistence decision
- When `@researcher` returns findings with `PERSISTENCE_RECOMMENDED: true`, the orchestrator presents the persistence decision to the developer (persist, skip, or partial). The orchestrator does not auto-decide.

## 6. Agent Permission Classification

All agents fall into one of three permission tiers. New agents must declare their tier.

| Tier | Permissions | Produces | Examples |
|------|------------|----------|----------|
| **pure-analyst** | `read_files` only | Output in conversation only | @architector, @ai-specialist, @reviewer, @openspec-plan |
| **artifact-producer** | Write+Bash, scoped to `knowledge/` | Structured reports, conspects, analyses | @analyzer, @conspecter, @resource-manager |
| **executor** | Full Write+Bash | Implementation, refactoring, scribe work | @coder, @designer |

**Rule:** If a pure-analyst agent's output needs to be persisted as a file, the
orchestrator delegates to an executor for transcription. Pure-analysts never
write files. Artifact-producers write only to their designated output directory
and never modify source files.

> **Note (ai-specialist):** Classified pure-analyst (read-only). It is granted
> `bash: curl/wget` for read-only web research (fetching docs); it never writes
> files and never dispatches subagents (`edit: deny`, `task: deny`).

> **Note (resource-manager):** Classified artifact-producer (DIA-007). Its `edit`
> permission is scoped to `.opencode/oh-my-opencode-slim/knowledge/*` ONLY — it
> curates ai-assist-sources.yaml, Tier-1 Markdown caches, and per-source review
> terms, and never modifies source files or config. It may dispatch
> @researcher/@conspecter (`task: allow`) to gather curation evidence.

## 7. Artifact Ownership Tracking

All practice-protected artifacts (proposal.md, design.md, tasks.md, .sdd/ documents) must note authorship in their YAML frontmatter or a trailing metadata block:
```
ownership:
  substance: developer | AI | collaborative
  structure: AI
  interview_depth: full | compressed | skip
  interview_reason: "<reason if skip>"
```
Rules: `substance: developer` = developer wrote core content, agent structured/formatted; `substance: AI` = agent drafted from interview transcript (allowed ONLY when developer confirmed the interview summary and explicitly delegated drafting); `substance: collaborative` = co-authoring with developer edits on AI draft. The agent ALWAYS records the interview depth mode and reason.

## Enforcement

- All agents (native and OMO-managed) should check this file before entering
  any of the protected zones listed above.
- Violations should be surfaced via the Phase 4 self-improvement loop
  (reflect → oh-my-opencode-slim) for process correction.
