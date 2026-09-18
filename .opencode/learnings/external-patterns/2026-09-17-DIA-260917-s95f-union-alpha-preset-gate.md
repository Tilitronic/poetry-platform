# DIA-260917-s95f union-alpha preset gate

Ticket: DIA-260917-s95f
Research ID: res-260917-6tnm-union-alpha-variants
Date: 2026-09-17
Gate: ai-specialist (AGENTS.md 2.5 step 1, docs only, no config edits)

## Variants

- Single live variant: opencode/union-alpha (Zen) = opencode-go/union-alpha (Go).
- stealth/union-alpha is invalid inside preset blocks; must not be referenced.
- No mini / preview / dated variants exist for union-alpha; do not invent any.

## Lane scope

- 9 lanes approved for prepend: orchestrator, architector, openspec-plan,
  coder, reviewer, analyzer, ai-specialist, ai-auditor, researcher.
- Prepend-not-replace: union-alpha entries go first, existing entries retained.
- Zen primary variant A approved (Zen docs opencode/<id> rule).

## Risks

- R1 diversity collapse: all 9 lanes on one model family removes fallback diversity.
- R2 auditor correlated failure: ai-auditor on same model as lanes it audits.
- R3 blast radius reveal-day circa 2026-09-23: stealth-to-paid cutover may change cost/availability.
- R4 no benchmarks: no Tier-1 benchmark for union-alpha on project tasks.
- R5 variant acceptance unconfirmed: opencode/<id> acceptance in project runtime not yet smoke-tested.
- Retention weaker claim operative: union-alpha zero-retention claim is weaker than Big Pickle; treat as operative risk.
- Generator ROUTING must update: preset generator ROUTING table must list union-alpha or output stays stale.
- Registry stale: model registry entry for union-alpha missing/outdated until refreshed.

## EBDV

- Choice A (Zen primary opencode/union-alpha prepended on 9 lanes) selected
  because Zen docs require the opencode/<id> form and the Big Pickle
  precedent established the same prepend-not-replace pattern for a stealth
  launch model.

## Outcome

- Implemented 2026-09-17 (DIA-260917-s95f): variant A Zen primary live on
  9 lanes, registry refreshed, changelog appended, committed no-push.
- Auditor APPROVE-WITH-NOTES disposition accepted-all: notes (a) through
  (e) each accepted and applied (registry entry, accelerated review,
  single-run-only guard, non-sensitive-only condition, generator bug
  follow-up). See ticket DIA-260917-s95f Verification / Fix blocks.
