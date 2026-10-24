# P0 Workflow Fixes - Gate Review Findings

**Date:** 2026-08-19
**Agent:** ai-specialist
**Ticket:** DIA-260819-mh6p
**Session:** ses_fe60ed6aeffeyiedwFGDgzLXki

## Summary

Gate review for P0 workflow compliance fixes (routing violation hard block + empty result escalation) revealed that both fixes are partially implemented but have bugs.

## Key Findings

### Fix 1: Routing Violation Hard Block (DIA-230)
- **Status:** Hard block implemented but neutered by catch-block bug
- **Bug:** Catch block at lines 2891-2911 only re-throws errors starting with "§10 TICKET GATE:", but routing gate throws "ROUTING GATE:" -- error falls through to fail-soft path
- **Fix:** Add `|| err.message.startsWith("ROUTING GATE:")` to re-throw condition at line 2895-2899
- **Effort:** Low (1-line fix + test)
- **Risk:** Low

### Fix 2: Empty Result Escalation (DIA-099)
- **Status:** Crisis event already emitted but with wrong resolution_status
- **Gap:** `resolution_status` is "in-flight" not "escalated"; no `content_ref` field; orchestrator prompt not updated
- **Fix:** Enhance crisis event (line 3581-3592) + update orchestrator prompt (orchestrator_append.md L271-308)
- **Effort:** Medium (plugin + prompt)
- **Risk:** Low-Medium (prompt tuning)

## Recommendation

**Variant A (recommended):** Fix catch-block bug for routing gate; enhance crisis event + orchestrator prompt for empty results.

**Evidence:**
- DIA-230 ticket says "blocking" intent
- DIA-099 Variant A2 is orchestrator-side
- Analysis found 20+ violations in 2 days

## Outcome

Pending implementation.
