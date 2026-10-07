---
# DIA-217 ticket-ID extraction repair (external pattern registration)

- Date: 2026-08-25
- Ticket: DIA-260824-p3hf 'repair DIA-217 task ticket ID schema pass-through'
- Source: ai-specialist gate review ses_fc6f516efffeO0DdLJ4kEH4r2J (VERDICT: APPROVE-WITH-NOTES)

## Finding

DIA-260824-p3hf repaired the DIA-217 ticket gate schema pass-through. Extraction
priority: explicit ticket_id field > marked ticket (campaign/governing/ticket_id
prefix, case-insensitive) > single literal DIA-ID (case-sensitive) > block on
ambiguity. Regex: marked uses /gi, literal uses /g. Normalization ensures
uppercase DIA- prefix; format validation enforces lowercase datetime suffix
(DIA-234).

Edge case: literal regex can match DIA-IDs in filename contexts (DIA-217 from
DIA-217-hardening.md), mitigated by marker priority + ambiguity block +
convention. Test coverage: 8 tests cover core branches; edge cases (multiple
markers, case-insensitive marker, filename context) untested. Rule text
consistent across AGENTS.md, orchestrator_append.md, 5 preset prompts. No
unrelated changes.

## Reviewer notes (LOW severity, non-blocking)

1. delegation-observer.ts:2845 vs 2852 - regex case-sensitivity inconsistency (/gi vs /g); handled by normalization + format validation.
2. delegation-observer.ts:2852 - literal regex false-positive on filename contexts; convention-mitigated.
3. dia217-ticket-gate.test.mjs - missing edge-case tests: multiple marked tickets block, case-insensitive marker matching, filename context false positive.

## Outcome

Committed with the p3hf repair; runtime smoke passed post-restart (gate accepted campaign-ticket marker from prompt text without capability token).
---
