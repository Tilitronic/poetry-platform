---
ownership:
  substance: developer
  structure: AI
  interview_depth: full
  interview_reason: 'DIA-104 cross-cutting trigger; developer confirmed Q1-Q7 and the interview summary.'
campaign_ticket: DIA-260911-4y5v
---

## Why

The architect, AI-specialist, and analyzer completed hygiene audits but their
path-level actions are not yet one safe, authoritative worklist. A compact
register is needed now to retain the architect-first preservation verdict,
make disagreements explicit, and prevent irreversible cleanup from proceeding
without reference and ticket checks.

## What Changes

- Add `docs/dev-infra-audit/hygiene-decisions.md` as a planning-only shared
  decision and instruction register.
- Record each audited path with exactly one primary classification: `delete`,
  `compress`, `fix`, `merge`, `archive`, or `preserve`; use
  `preserve/pending` when audit evidence is incomplete or lower-priority
  findings conflict with the architect verdict.
- Establish the evidence authority order: architect, AI-specialist, analyzer.
  The register preserves lower-priority disagreements rather than inferring a
  destructive action.
- Require inverse-reference evidence, live `scripts/tickets` status evidence,
  archive-destination checks, Git-tracked rollback, and developer approval per
  row before any delete, move, merge, or archive action.
- Keep the raw audit-session inventories as the evidence source. A missing
  exact path or edit remains `preserve/pending`; the register does not invent
  an action target.

## Capabilities

### New Capabilities

None. This is documentation-only planning and does not change a product or
system behavior requirement.

### Modified Capabilities

None.

## Impact

- **Added document:** `docs/dev-infra-audit/hygiene-decisions.md` only.
- **Governed evidence:** architect session `ses_f6d68b31cffe4vSDgqyX7kY1dl`,
  AI-specialist session `ses_f6b1bae72ffeQC1XRgX6Sp1yjf`, and analyzer session
  `ses_f6b1badc9ffeX3HtV69RY0fu0N`.
- **No implementation:** no application code, OpenCode configuration, active
  instructions, ticket status, knowledge artifact, or archive is changed by
  this OpenSpec change.

## Testing Decisions

The document is the artifact under test. A good check proves that its required
sections and row contract are present, its six classifications are exhaustive,
and it does not authorize execution without the declared gates and developer
approval. Verify the Markdown document directly and run `openspec validate`;
no runtime or application test applies. Existing hygiene audits are evidence
prior art, not tests to alter.

## Rollback Plan

The document is one Git-tracked file. Revert its introducing commit if it
misstates an audit decision; it performs no destructive operation itself.

## Alternatives considered

- **Separate follow-up documents per audit:** rejected. The developer-approved
  interview summary requires one shared register, and split documents would
  obscure the architect-first conflict rule. Evidence: developer Q5
  confirmation, campaign ticket DIA-260911-4y5v.
- **Auto-executable cleanup runbook:** rejected. The audits include delete,
  merge, and archive candidates, while developer Q7 requires per-row approval
  after safety evidence. Evidence: developer Q4 and Q7 confirmations.
- **Status quo / do nothing:** rejected. The three audits retain unresolved,
  differently prioritized hygiene actions without a single conservative
  decision point. Evidence: developer-supplied campaign audit verdicts.

Chosen option: one planning-only action register, because it centralizes the
three audit verdicts without authorizing cleanup before safety checks and
developer approval.
