## Why

The DIA ticket ledger contains OPEN tickets from August 2026 whose frontmatter status may not reflect actual evidence (commits, OpenSpec change state, ana026 audit findings, test results). Without reconciliation, the ledger drifts from reality: CLOSED tickets may lack evidence, OPEN tickets may be demonstrably done, and ana026 P0/P1 findings may have no corresponding ticket. This change produces an evidence-backed triage table for developer approval before any ledger edits, restoring alignment between ticket status and verifiable state.

## What Changes

- Evidence gathering across three sources: git log (commit references to DIA IDs), OpenSpec change state (archived vs active, tasks.md checkbox mapping), and ana026 P0/P1 finding verification against current code/config.
- Test-status disclosure: every CLOSE recommendation cites green automated tests or explicitly states "no tests exist" / "tests not run" -- never inferred from file/commit evidence alone.
- Reverse-drift detection: tickets whose CLOSED status contradicts placeholder Fix/Re-verify sections are flagged separately as informational findings.
- ana026 gap analysis: P0/P1 findings with no corresponding OPEN ticket are flagged as "recommend new ticket" without creating them until developer approves.
- Triage table output: grouped markdown table (CLOSE / UPDATE / KEEP OPEN / OBSOLETE / reverse-drift / ana026 gaps) presented in conversation for developer approval.
- Ticket frontmatter updates (status, Fix, Re-verify) applied only after explicit developer approval of the triage table.
- No implementation code changes. No OpenSpec task checkbox edits. No new ticket creation without explicit approval.

## Capabilities

### New Capabilities

None. This is a reconciliation audit, not a feature.

### Modified Capabilities

None. No spec-level behavior changes.

This change sets `skip_specs: true` in `.openspec.yaml` -- it is a docs/process reconciliation with no behavioral impact on the system.

## Impact

- **Affected files**: `docs/dev-infra-audit/tickets/DIA-*.md` frontmatter (status, Fix, Re-verify sections) for tickets with `created: 2026-08-*`.
- **Read-only during evidence gathering**: git log, OpenSpec change directories, ana026 report, current code/config for ana026 P0/P1 verification, test execution.
- **No changes to**: implementation code, OpenSpec artifacts (proposal.md, design.md, tasks.md checkboxes), `.sdd/` documents, `.opencode/` config.
- **Dependencies**: `scripts/tickets` for ticket queries; `openspec` CLI for change state; git for commit history.

## Alternatives considered

- **Full ledger audit (all tickets, all dates)**: rejected -- unbounded scope, high token cost, low marginal value for pre-August tickets that have had multiple reconciliation cycles. Evidence: DIA-260820-y268 established scripts-based queries as the canonical ticket access method, reducing per-ticket inspection cost but not eliminating the need for bounded scope.
- **Automated reconciliation (script that auto-closes based on commit references)**: rejected -- practice-protected zone requires developer approval before status changes. Evidence: DIA-104 grilling gate and AGENTS.md section 4 establish practice-protected zones where agents must ask, not silently implement.
- **Skip ana026 cross-reference**: rejected -- ana026 P0/P1 findings are the most recent external audit (2026-08-19) and may reveal gaps not captured by ticket-level evidence alone. Evidence: ana026 report at `knowledge/ana026-opencode-setup-audit/ana026-opencode-setup-audit-report.md` identifies P0 runtime plugin duplication and P0 container socket security as active risks.
- **Status-quo / do nothing**: rejected -- ticket ledger drift compounds over time; OPEN tickets with no evidence waste orchestrator dispatch cycles and obscure actual work. Evidence: DIA-260821-bqy7 was created specifically to address this drift.
  Chosen option: bounded interview-first reconciliation with developer approval gate -- because it respects practice-protected zones, limits scope to August 2026 tickets, and uses three-source evidence (git + OpenSpec + ana026) with explicit test-status disclosure.

## Testing Decisions

This change produces a triage table, not code. The "test" is the evidence-gathering plan itself:

- **What makes a good test**: each triage recommendation must cite at least one verifiable evidence source (commit SHA, OpenSpec change path, ana026 finding verification result, or test execution output).
- **Modules tested**: ticket frontmatter parsing, git log search, OpenSpec change state inspection, ana026 P0/P1 finding verification against current code/config.
- **Prior art**: DIA-260820-y268 established `scripts/tickets` as the canonical query interface; this change extends that pattern with cross-source evidence gathering.
- **Test-status disclosure**: CLOSE recommendations without green test evidence must explicitly state "no tests exist" or "tests not run" -- this is the primary quality gate for the triage table.
