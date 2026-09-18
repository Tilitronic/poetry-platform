# Comment Accuracy in Fail-Path Code

**Date:** 2026-08-19  
**Source:** DIA-235 ai-specialist gate review  
**Pattern:** Comments in error-handling paths must accurately reflect behavior (fail-soft vs fail-closed)

## Observation

Comments in error-handling paths must accurately reflect behavior. Misleading comments create maintainability risk because developers trust comments over code inspection.

## Rule

When code has error handling, the comment must state:
1. What triggers the error path
2. What the actual behavior is (not what the developer wished it was)
3. Why this behavior was chosen (if non-obvious)

## Example

```typescript
// WRONG: "Fail-soft: scan error -> treat as no prior dispatch"
// RIGHT: "Fail-closed: scan error -> hasAiSpecialist=false -> hard block (ROUTING_VIOLATION)"
```

## Reference

- DIA-235 ai-auditor finding (Minor severity)
- delegation-observer.ts:2747-2750
