# Pattern: Todowrite Prompt Gap

**Date:** 2026-08-19
**Ticket:** DIA-260819-880v
**Category:** prompt-gap

## Observation
The orchestrator had the `todowrite` tool allowed (opencode.jsonc permission) but ZERO mentions across all prompt surfaces (orchestrator_append.md, oh-my-opencode-slim.jsonc x3 presets, AGENTS.md, NEXT-RUN.md, best-practices). Result: orchestrator changed plans mid-stream without tracking, abandoning pending items silently.

## Root Cause
Prompt gap -- tool permitted but undocumented. No workflow guidance, no state-transition rules, no completion discipline.

## Fix
Added todowrite discipline to three surfaces: orchestrator_append.md (workflow section), oh-my-opencode-slim.jsonc (compact rule block x3 presets), drift-checker marker #9 (mechanical enforcement).

## Rule
When a tool is in the permission allow-list, it MUST be mentioned in at least one prompt surface with workflow guidance. Permitted-but-undocumented tools are invisible bugs.

## Verification
`scripts/check-orchestrator-prompt-drift.sh` marker #9 locks the guidance -- future drift caught by `make test-config`.

## Outcome

**Status:** applied
**Applied:** 2026-08-19
**Result:** Todowrite discipline added to orchestrator_append.md (A7 section), oh-my-opencode-slim.jsonc (3 presets, byte-identical), drift-checker marker #9. make test-config 56/56 pass.
**Regression check:** drift-checker marker #9 locks the guidance -- future drift caught by `make test-config`.
