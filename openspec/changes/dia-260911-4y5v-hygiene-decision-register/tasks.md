---
ownership:
  substance: developer
  structure: AI
  interview_depth: full
  interview_reason: 'DIA-104 cross-cutting trigger; developer confirmed Q1-Q7 and the interview summary.'
campaign_ticket: DIA-260911-4y5v
---

## 1. Evidence intake and conservative reconciliation

- [ ] 1.1 Blocking edges: none. Obtain the path-level inventories from the
      architect, AI-specialist, and analyzer campaign audits; record each claim's
      source, priority, exact path, and exact proposed edit or destination. Accept
      when no action target is reconstructed from an audit summary alone.
- [ ] 1.2 Blocking edges: 1.1. Reconcile the inventories with architect first,
      then AI-specialist, then analyzer. Give every audited path exactly one of the
      six classifications; mark incomplete evidence or any lower-priority conflict
      as `preserve/pending`. Accept when the AI-specialist's `res036`-`res038`
      constraint remains pending while `DIA-260821-8kpc` is OPEN and no
      lower-priority finding overrides architect preservation.

## 2. Planning-only hygiene decision register

- [ ] 2.1 Blocking edges: 1.2. Create the single shared Markdown register with
      its authority rule, one path-by-path action table, and only the exact edits,
      destinations, priorities, source verdicts, and pending reasons supported by
      the reconciled evidence. Accept when every row has one primary
      classification and the register authorizes no cleanup itself.
- [ ] 2.2 Blocking edges: 2.1. Add the reusable per-row execution checklist:
      inverse-reference evidence, `scripts/tickets` proof of no related OPEN
      ticket, archive-destination existence where applicable, Git-tracked
      rollback, and explicit developer approval before any non-preserve action.
      Accept when a failed or incomplete gate requires `preserve/pending` and the
      rule explicitly covers delete, move, merge, and archive actions.

## 3. Documentation verification and handoff

- [ ] 3.1 Blocking edges: 2.1, 2.2. Review the document against the closed
      classification set, source precedence, gate contract, and planning-only
      boundary. Accept when no implementation, ticket-status, archive, or
      configuration file was changed as part of this documentation task.
- [ ] 3.2 Blocking edges: 3.1. Run `openspec validate
dia-260911-4y5v-hygiene-decision-register` and record its result with the
      campaign ticket. Accept when validation passes and the handoff identifies the
      register as ready for developer-approved, row-by-row follow-up work only.
