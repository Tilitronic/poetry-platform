# DIA-261006-y72h - at-sign agent-mention hygiene: strip leading at-sign from agent mentions on the instruction surface, codify the dispatch-payload mention rule, reconcile CAUSE A

---

id: DIA-261006-y72h
title: "at-sign agent-mention hygiene: strip leading at-sign from agent mentions on the instruction surface, codify the dispatch-payload mention rule, reconcile CAUSE A"
area: scripts
severity: Medium
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-10-06
source: inventory
date: 2026-10-06
created: 2026-10-06
updated: 2026-10-06

# --- Session Attribution (v2 schema, optional) ---

session_id: ""
lane_id: ""
agent: ""
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: "" # ISO-8601; set on DISPATCHED, cleared on COMPLETE
files_touched: []
artifacts: []
evidence: []

---

## Description

OpenCode core appends a synthetic, UI-invisible "call the task tool with subagent: <name>" part to a CHILD prompt when a dispatch payload contains a leading at-sign before an agent name (upstream packages/opencode/src/session/prompt.ts). The instruction surface carried 236 leading at-sign agent mentions across 23 files, re-triggering the defect. Review follow-up (F1) extended the fix to `.opencode/oh-my-opencode-slim.jsonc`, which carried 98 further at-sign agent mentions (the two inline orchestrator `prompt` strings, the ai-specialist `prompt`, and every per-agent `orchestratorPrompt` value).

## Verification

- [x] `make test-config` exit 0
- [x] `scripts/validate-agent-names.sh` exit 0 (26 passed)
- [x] token-aware negative grep over the manifest == 0
- [x] the rule codified at `.opencode/oh-my-opencode-slim/orchestrator_append.md` (subsection A8) and `AGENTS.md` (section 6 gate 4)
- [x] `.opencode/oh-my-opencode-slim.jsonc`: token-aware negative grep == 0, both inline orchestrator prompts carry the new rule 5, and the file still parses (`make test-config` exit 0)

## Fix

Token-aware strip (236 -> 0) across 23 instruction-surface .md files; rule codification; durable rationale at `.opencode/learnings/external-patterns/2026-10-06-opencode-core-synthetic-task-tool-append.md`.

Review follow-up (F1-F6): token-aware strip (98 -> 0) across the whole `.opencode/oh-my-opencode-slim.jsonc` plus rule 5 appended to both inline orchestrator `prompt` strings; `AGENTS.md` section 9 first column renamed to "Mention form" with non-live cells and a runtime-mention-form prose line; F3 wording softened in A8 and gate 4; `.opencode/learnings/index.md` entry added; OMO `AGENTS.md` launch-example reworded as prose.

Exact 23-file manifest behind the "0 residual" claim:

1. AGENTS.md
2. .opencode/oh-my-opencode-slim/orchestrator_append.md
3. .opencode/oh-my-opencode-slim/analyzer_append.md
4. .opencode/oh-my-opencode-slim/AGENTS.md
5. .opencode/practice-protected.md
6. docs/dev-infra-audit/NEXT-RUN.md
7. docs/onboarding.md
8. .opencode/agents/researcher.md
9. .opencode/agents/analyzer.md
10. .opencode/agents/conspecter.md
11. .opencode/agents/coder-escalated.md
12. .opencode/agents/analyzer-escalated.md
13. .opencode/agents/ai-specialist.md
14. .opencode/agents/ai-auditor.md
15. .opencode/skills/code-review-fowler/SKILL.md
16. .opencode/skills/debugging-workflow/SKILL.md
17. .opencode/skills/domain-grilling/SKILL.md
18. .opencode/skills/openspec-apply-change/SKILL.md
19. .opencode/skills/openspec-propose/SKILL.md
20. .opencode/skills/promo-review/SKILL.md
21. .opencode/skills/research-pipeline/SKILL.md
22. .opencode/skills/review-re-verify/SKILL.md
23. .opencode/skills/tdd-craftsman/SKILL.md

Reproduce: token-aware grep for a leading at-sign before any canonical agent name over the 23 paths above plus `.opencode/oh-my-opencode-slim.jsonc` must return 0 matches.

CAUSE A, originally diagnosed in DIA-260926-ch1d (CLOSED), is recorded durably at the learnings path above and reconciled here.

## Re-verify

> To be filled at re-verify time.
