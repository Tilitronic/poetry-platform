# AI-specialist Gate - DIA-260911-4y5v datetime artifact ID examples

Ticket: DIA-260911-4y5v
Change: dia-260911-4y5v-datetime-artifact-id-examples
Source: ai-specialist gate session
Verdict: CONDITIONAL PASS
Date: 2026-09-12
Lane: learnings-registration-only (no implementation)

## Gate summary

CONDITIONAL PASS for change dia-260911-4y5v-datetime-artifact-id-examples.
Sequential numeric artifact ID examples are replaced with datetime ID
examples matching the allocator ground truth. Scope is docs-only example
and prose fixes; no behavior or schema changes.

## Ground truth

- scripts/allocate-id emits <type>-YYMMDD-<random4>-<slug>.
- Example: DIA-260911-4y5v matches <type>-YYMMDD-<random4>-<slug>.
- Sequential forms (DIA-100, DIA-190, res001 style concrete IDs) are
  obsolete as literal examples and must not be reintroduced.

## Required fixes (constrained)

1. orchestrator_append.md:55 - obsolete path must be replaced, not
   bullet-deleted. Keep the bullet structure intact; swap the stale
   sequential example path for the datetime form. Deleting the bullet
   drops a load-bearing checklist item.
2. analyzer.md:38 - sequential example to datetime. Replace the concrete
   sequential ID example with a datetime ID example of the same shape
   as the allocator output.
3. researcher.md - res<id> generic templates preserved plus prose
   clarification to avoid doubled slug. Keep the generic res<id>
   template placeholders as-is; add prose noting the allocator already
   appends -<slug>, so callers must not append a second slug suffix.

## Routing

User-approved constrained fix -> coder -> focused search + make
test-config -> restart/smoke -> ai-auditor.

1. Developer approves the constrained fix scope above (no expansion).
2. Coder applies the three file-scoped edits only.
3. Focused search confirms zero remaining sequential example hits in
   the touched files, then make test-config passes.
4. Restart plus smoke check per section 2.5 step 5.
5. ai-auditor independent review per section 2.5 step 6.

## Out of scope

- No allocator or script behavior changes.
- No ticket ledger or changelog edits in this change.
- No preset, model, or routing changes.

## Outcome (2026-09-12, implemented)

Status: implemented. Changelog entry appended via scripts/changelog-add
for DIA-260911-4y5v, validated and rendered.

- F1 verified-closed: orchestrator_append.md obsolete sequential example
  path replaced with datetime form, bullet structure intact.
- F4 conditional-pass: restart plus smoke check per section 2.5 step 5
  still pending; ai-auditor review to follow.
