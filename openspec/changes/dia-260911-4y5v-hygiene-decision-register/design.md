---
ownership:
  substance: developer
  structure: AI
  interview_depth: full
  interview_reason: 'DIA-104 cross-cutting trigger; developer confirmed Q1-Q7 and the interview summary.'
campaign_ticket: DIA-260911-4y5v
---

## Context

See [proposal.md](proposal.md) for motivation. This is a documentation-only
change. `architecture.md` remains authoritative for the application, but no
application module, boundary, or `.sdd/` document is affected; no `.sdd/`
architecture document exists for this documentation register.

The sole evidence set is the completed campaign audits: architect session
`ses_f6d68b31cffe4vSDgqyX7kY1dl`, AI-specialist session
`ses_f6b1bae72ffeQC1XRgX6Sp1yjf`, and analyzer session
`ses_f6b1badc9ffeX3HtV69RY0fu0N`. Their row-level inventories must be read
when composing the register. Their summaries alone do not authorize inferred
paths or edits.

## Goals / Non-Goals

**Goals:**

- Produce one compact, planning-only Markdown register at
  `docs/dev-infra-audit/hygiene-decisions.md`.
- Make the architect verdict authoritative, then reconcile AI-specialist and
  analyzer findings conservatively.
- Give every audited path one and only one action classification and make the
  evidence and safety requirements visible at the row that needs them.
- Make pending evidence and ticket conflicts safe by default.

**Non-Goals:**

- Do not edit, delete, move, merge, archive, refresh, register, or rename any
  audited artifact.
- Do not modify OpenCode configuration, active agent instructions, ticket
  status, the memory shelf, or application code.
- Do not create an autonomous cleanup process, a validator, or another policy
  layer.

## Decisions

### 1. Use one authority order and a conservative conflict result

The document opens with an authority rule in this exact order: architect,
AI-specialist, analyzer. The architect's `FAIL for hygiene, PASS for
preservation` verdict is preserved as the primary decision when findings
disagree. A disagreement with an architect preservation decision, or any
missing path-level evidence, becomes `preserve/pending` until the developer
resolves it.

This avoids treating a lower-priority recommendation as permission to destroy
history. The rejected alternative is voting or averaging the three audits,
which would dilute the developer's stated architect-first decision.

### 2. Use a single action register with a strict row contract

The main document section is one Markdown table. Each audited path appears
once and has exactly one primary classification from this closed set:
`delete`, `compress`, `fix`, `merge`, `archive`, or `preserve`.

Every row contains:

| Field          | Required content                                                                                    |
| -------------- | --------------------------------------------------------------------------------------------------- |
| Path           | Exact repository-relative path from an audit record                                                 |
| Classification | Exactly one value from the closed set; `preserve/pending` is a preserve status, not a seventh class |
| Source verdict | Architect, AI-specialist, analyzer, or the stated conflict relationship                             |
| Priority       | Source priority such as P0-P3, or `pending`                                                         |
| Exact action   | Literal edit, destination, merge target, or reason to preserve; never an inferred target            |
| Safety gate    | Required inverse-reference, ticket, destination, rollback, and approval evidence                    |
| Status         | `planned` or `preserve/pending`; no execution-complete status is allowed in this planning document  |

The register includes the known campaign constraints: the AI-specialist's
three mechanical delete candidates remain delete candidates only if their
exact paths are present in its audit; bottleneck reports are archive candidates
rather than delete candidates; and `res036` through `res038` remain
`preserve/pending` while `DIA-260821-8kpc` is OPEN. The architect inventory
supplies the authoritative P0 light edits, delete list, merge table, compress
list, archive candidates, shelf repairs, and agent-document edits. The
analyzer's P0-P3 refresh/register/archive/merge plan and two unregistered live
directory warnings are reconciled against those rows rather than copied as
unscoped work.

### 3. Make safety gates fail closed at each non-preserve row

Before any non-preserve row can be executed, the register requires all of:

1. **Inverse-reference gate:** search for inbound references; remove or update
   every result and record the evidence. Any unresolved reference blocks the
   action.
2. **Ticket-status gate:** use `scripts/tickets` to show that no related ticket
   is OPEN. An OPEN ticket changes the row to `preserve/pending`.
3. **Archive gate:** for an archive action, verify the destination exists before
   moving the source.
4. **Rollback gate:** perform the approved action only in Git-tracked changes,
   so a revert restores the prior state.
5. **Developer-approval gate:** attach the above evidence and obtain explicit
   developer approval for the row before a delete, move, merge, archive, or
   other non-preserve action.

The rejected alternative is a document-level approval or a best-effort search;
those approaches cannot distinguish a safe row from a blocked row.

### 4. Keep execution instructions reusable but minimal

After the table, add one short checklist that repeats the gates in execution
order and an explicit rollback rule: revert the Git-tracked action, restore a
moved item to its original path if required, then re-run inverse-reference and
ticket checks. Do not add scripts, policies, automation, or duplicated audit
narrative.

## Seams and verification

- **S1: audit evidence to register row.** Each row traces to an exact path and
  action in one of the three audit records. A claim lacking both is
  `preserve/pending`.
- **S2: register row to later cleanup execution.** The row's safety-gate and
  approval columns are the public handoff boundary; this change does not cross
  it.

Verification is document-level: review the final table for one row per audited
path, closed-set classification, provenance, and the required gates; confirm
the reusable checklist includes all five gates; and run `openspec validate`.
No application seam or runtime test is applicable.

## Risks / Trade-offs

- **Audit session detail may be unavailable to the document author** -> Do not
  reconstruct it from summaries; record the claim as `preserve/pending`.
- **An OPEN ticket can make a desirable hygiene action unsafe** -> Preserve it
  pending rather than closing or bypassing the ticket.
- **The register can become stale after later audits** -> Add rows by the same
  authority and gate rules; do not silently rewrite a prior decision.
- **A long table could duplicate audit reports** -> Keep only path, decision,
  exact action, provenance, and gate evidence; leave audit rationale in its
  source record.

## Migration Plan

1. Create the single documentation artifact from the three source inventories.
2. Review it against this design's closed classification and gate contract.
3. Commit only the document and its OpenSpec artifacts; no cleanup action is
   part of this change.
4. Roll back by reverting that documentation commit if a source decision was
   transcribed incorrectly.

## Open Questions

None. Any missing source detail is deliberately represented by
`preserve/pending`, which does not change the approach or task breakdown.
