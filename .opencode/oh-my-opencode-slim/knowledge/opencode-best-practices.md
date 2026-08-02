# OpenCode Best Practices Reference (Mid-2026)

> Curated knowledge for ai-specialist. Compiled from official docs, community guides, and GitHub analyses.
> Sources drawn primarily from last ~3-6 months (early-to-mid 2026).

---

## 1. Building OpenCode Agents

### Agent Types
- **Primary agents** (Build, Plan): Full-access or read-only. Toggle with Tab.
- **Subagents** (custom): Invocable via `@name`. Specialized tasks like review, exploration, verification.

### Key Practices
- **Start with built-ins, extend**: Use default Build (full tools) and Plan (restricted, read-only). Add custom subagents for code review, exploration, verification.
- **Granular permissions & models**: Assign specific models per agent (fast/cheap for exploration/Plan, frontier for Build). Temperature: 0.0-0.2 for deterministic planning, 0.3-0.5 balanced, higher for creative. Limit max steps for cost control. Use `"ask"` for edits/bash initially.
- **Multi-agent teams**: Reviewer subagents (frontend/backend/DevOps) running in parallel. Use shared memory or messaging for coordination. Primary agents delegate.
- **Skills + MCPs**: Pair with focused SKILL.md files (specific triggers, deterministic scripts). Install narrow, repo-relevant skills first. MCPs for external tools (web/search, SaaS via Composio).
- **Workflow**: Plan → review/refine → Build. Start small. Run in clean branches. Let agents "run wild" initially to learn behaviors, then add guardrails. Verify outputs rigorously.

### Config Location
- `opencode.json` (global or per-project `.opencode/`) or Markdown files (`~/.config/opencode/agents/review.md`)

---

## 2. Workflow Best Practices

- **Plan-Build-Verify loop**: Plan mode for outlining (analysis without changes). Review, refine, switch to Build. Subagents for parallel specialized work. Include self-review, test verification, PR review.
- **High-level directives + iteration**: Assign broad tasks; let agents handle details with observation-revise cycles. Use validation loops, error recovery, quality thresholds.
- **Multi-agent orchestration**: Specialist teams (planner → worker → verifier). Permissions, shared context, phase sequencing.
- **Daily flows**: Scaffold with `/init`. Explore first (Scout/Explore subagents). Atomic commits in manual mode. Post-implementation: auditor/review agents + tests/lint. Skills for repeatable SOPs (TDD, release notes).
- **Safety**: Clean branches, verify root causes of errors, skills for determinism. Minimize context bloat. Model-switching (fast for simple, strong for complex).

---

## 3. AGENTS.md File Construction

AGENTS.md (plural preferred) is a vendor-agnostic "README for agents" at repo root. Used by 60k+ repos.

### Key Rules
- **Human-curated only**: Avoid LLM-generated (can hurt performance). Focus on non-inferable details: custom commands, architecture decisions, "why" explanations, gotchas, security, team conventions, boundaries.
- **Keep concise**: Start 20-50 lines. Revisit weekly. Passive context beats on-demand skills.
- **Core sections**: Project overview/structure, build/lint/test/deploy commands (exact order), code style/examples, testing instructions, PR/commit guidelines, security considerations, personas/roles.
- **Structure**: Machine-readable (lists, code blocks). Group into sections or reference other files (CONTEXT.md, ADRs).
- **Monorepos**: Nested files + root instructions. Nearest wins.
- **Maintenance**: Living doc — update based on agent mistakes. Use `/init` to bootstrap.
- **Pitfalls**: Dumping obvious info (wastes tokens/context rot), overly long files, conflicting instructions (closest wins; user prompts override).

### Example Skeleton
```
# Project Overview
...
# Structure
...
# Commands
Build: ...
Test: ...
# Code Style
...
# Boundaries / Gotchas
Never ...
```

---

## 4. Critical Evaluation Rules

When reviewing community resources (awesome-opencode, GitHub repos, blog posts):

- **Star count is PRIMARY quality signal**: More stars = more community validation, battle-testing, ongoing maintenance.
- **< 100 stars**: Experimental. Only recommend if nothing else covers the gap. Flag low adoption risk.
- **100-500 stars**: Reasonable adoption. Note star count and recent commit activity.
- **500+ stars**: Well-established. Recommend more confidently, but verify last update date.
- **5000+ stars**: Industry standard. High confidence.
- **Check last commit/release date**: High stars + no commits in 6+ months = abandoned. Flag this.
- **Cross-reference with official OpenCode docs**: Community tools may lag behind API changes.
- **Do NOT recommend unmaintained tools**: Even with high stars — security risk and compatibility issues.
