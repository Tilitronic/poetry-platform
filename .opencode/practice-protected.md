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

## 4. Agent Permission Classification

All agents fall into one of three permission tiers. New agents must declare their tier.

| Tier | Permissions | Produces | Examples |
|------|------------|----------|----------|
| **pure-analyst** | `read_files` only | Output in conversation only | @architector, @ai_assist_specialist, @reviewer, @openspec-plan |
| **artifact-producer** | Write+Bash, scoped to `knowledge/` | Structured reports, conspects, analyses | @analyzer, @conspecter |
| **executor** | Full Write+Bash | Implementation, refactoring, scribe work | @coder, @designer |

**Rule:** If a pure-analyst agent's output needs to be persisted as a file, the
orchestrator delegates to an executor for transcription. Pure-analysts never
write files. Artifact-producers write only to their designated output directory
and never modify source files.

## Enforcement

- All agents (native and OMO-managed) should check this file before entering
  any of the protected zones listed above.
- Violations should be surfaced via the Phase 4 self-improvement loop
  (reflect → oh-my-opencode-slim) for process correction.
