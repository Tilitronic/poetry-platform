# DIA-260819-qibv: Research Pipeline Persistence Decision Gate Bug

**Date:** 2026-08-19
**Source:** ai-specialist research
**Ticket:** DIA-260819-qibv

## Problem

The research-pipeline skill has a Phase 3 "persistence decision" gate that incorrectly treats conspect creation as optional. After expensive Phase 2 work (source archival, manifest writing), the orchestrator asks the developer "KEEP or DELETE?" — but conspect is the canonical synthesis and should ALWAYS be created.

## Root Cause

Phase 3 (SKILL.md lines 42-54) presents a binary KEEP/DELETE choice after Phase 2 has already done expensive work. The `PERSISTENCE_RECOMMENDED` flag was designed as a convenience signal but Phase 3 elevated it to a gate.

## Recommended Fix (Option A)

Remove the gate, make conspect automatic after successful Phase 2 source capture.

### Files Requiring Changes

1. **`.opencode/skills/research-pipeline/SKILL.md`**
   - Phase 3 (lines 42-54): Replace KEEP/DELETE decision with quality gate
   - Guard Gates (lines 77-78): Replace "No silent persistence" with "Conspect is automatic"
   - Delegation Rules (line 94): Change Phase 3 from "practice-protected binary decision" to "quality check, auto-proceed"

2. **`.opencode/practice-protected.md`**
   - §5 (lines 32-33): Remove or redefine "Research persistence decision"

3. **`.opencode/oh-my-opencode-slim/orchestrator_append.md`**
   - Lines 61-83: Rewrite "Research Persistence Gate" section
   - Remove "MUST present the persistence decision" language
   - HARD GATE becomes: orchestrator must not close researcher lane until conspect synthesis is complete or quality criteria fail

4. **`.opencode/oh-my-opencode-slim.jsonc`**
   - 3 presets (lines 187, 411, 592): Change "practice-protected decision" to "automatic conspect synthesis"

5. **`.opencode/agents/researcher.md`**
   - Line 76: Change "the orchestrator decides" to "conspect synthesis proceeds automatically"

6. **`.opencode/plugins/delegation-observer.ts`**
   - Lines 3176-3247: Optional rename `persistence-pending.json` to `conspect-pending.json` (semantic, not structural)

## Verification Criteria

1. `make test-config` passes
2. Phase 3 no longer contains KEEP/DELETE language in SKILL.md
3. `practice-protected.md` §5 is removed or redefined
4. `orchestrator_append.md` no longer says "MUST present the persistence decision"
5. All 3 presets in `oh-my-opencode-slim.jsonc` say "automatic conspect synthesis"
6. Live smoke test: researcher with 3+ sources → conspect created automatically
7. Negative test: researcher with `PERSISTENCE_RECOMMENDED: false` and <3 sources → conspect correctly skipped

## Risks

- **Low-quality conspects auto-created:** Mitigated by quality criteria table (≥3 sources, domain gap, etc.)
- **Plugin semantics change:** `persistence-pending.json` meaning shifts from "ask developer" to "conspect pending" — must update atomically with skill/prompt changes
- **practice-protected.md removal:** Config change requires section-10 workflow routing

## Decision

Proceed with Option A: Remove the gate, make conspect automatic.
