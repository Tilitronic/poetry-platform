---
date: 2026-08-02
source: orchestrator + ai-specialist (gate research) + architector (design) + coder (implementation) + ai-specialist (independent review)
finding: |
  AIHero interview-first gate was present as organizational intent but only 52/100 enforced. Root cause: five one-shot bypass paths (skills/commands: `openspec-propose`, `/opsx-propose`, `/opsx-new`, `/opsx-continue`, `/tdd-cycle` step1) and boss preset denylist `["*"]` that effectively allowed vendored openspec-propose behavior to bypass the interview requirement. The repo was running npm oh-my-opencode-slim@2.2.8 whose base workflow contains no Interview Gate (grep: "Path Selection" present, "Interview Gate"=0). The vendored fork's boss.ts gate edit was never built, leaving a runtime gap.

  Action taken (Phase 1 enforcement): rewrote `openspec-propose` skill and commands `/opsx-propose`, `/opsx-new`, `/opsx-continue`, `/tdd-cycle` to require a mandatory Socratic interview via `@openspec-plan` and to synthesize artifacts from the interview transcript only; added `openspec validate` before apply. Applied boss skills denylist change in all 3 OMO presets to `["*", "!openspec-propose"]`. Introduced a Fast-Path Opt-In gate (explicit approval checklist + audit trail; never auto-classified) and an Interactive Review Gate row in `boss_append.md`. Extended `@openspec-plan` orchestratorPrompt with a deep-interview protocol (Full/Compressed/Skip depth modes, silent context scan, one-question-at-a-time battery Q1–Q11 including numerical-invariants battery). Added Review Disposition zone + Artifact Ownership Tracking to `practice-protected.md`. Created `scripts/test-interview-enforcement.sh` and used it to validate enforcement.

  Independent review (ai-specialist): PASS after one blocking fix (section renumbering in `practice-protected.md`) and two wording cleanups. Decision: Option C approved by user — do not fork oh-my-opencode-slim; keep plugins auto-updating (npm oh-my-opencode-slim@2.2.8 unchanged). A compiled-boss escape hatch (Phase 2) is deferred; trigger condition: observed boss invoking one-shot spec generation without interview in any session.

status: applied
evidence: |
  - Validation script: `scripts/test-interview-enforcement.sh` — 5/5 PASS (2026-08-02)
  - Config files parsed successfully. Restart + functional smoke test pending user.
---
