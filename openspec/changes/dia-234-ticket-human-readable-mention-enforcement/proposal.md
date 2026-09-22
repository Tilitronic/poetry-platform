## Why

DIA-234 introduced datetime ticket IDs (DIA-YYMMDD-XXXX) and a human-readable mention convention, but only the ID generator (scripts/tickets new) shipped. The human-readable-mention requirement is still NOT enforced: ticket references in user-facing output and ticket bodies should carry the slug from the filename (e.g. "DIA-100 'git worktrees for parallel dev sessions'"), not a bare ID. AGENTS.md section 2.3 already states the rule; nothing checks it. scripts/validate-dia-mentions.sh exists and is wired into make test-config (Makefile:207) but is warn-only and scans only AGENTS.md, not ticket bodies. This follow-up enforces the requirement at two points: ticket creation (scripts/tickets new) and the make test-config gate (ticket bodies).

## What Changes

- Extend scripts/validate-dia-mentions.sh to ALSO scan ticket bodies (docs/dev-infra-audit/tickets/\*.md) for bare DIA references without a following slug, and convert the ticket-body check from warn-only to HARD FAIL (exit 1) for tickets created on or after an enforcement date; pre-existing (grandfathered) tickets remain warn-only.
- Add a creation-time guard to scripts/tickets new: the generated ticket body MUST contain a human-readable self-mention (DIA-<id> '<slug>'), and the command MUST fail (exit 1) if the generated file contains a bare DIA reference without a slug.
- Document the enforcement in AGENTS.md section 2.3 / 2.5 (the mention-format contract and the two enforcement points).
- (Optional / "ideally") Extend the delegation-observer DIA-217 dispatch gate to require a slug when it materializes a ticket_id. Deferred by default due to conflict with the existing "campaign ticket DIA-NNN" marker convention; see design Decision 5.

## Capabilities

### New Capabilities

None. This is a dev-infra / tooling change with no product behavior contract. The change sets skip_specs: true in .openspec.yaml (no spec-level delta).

### Modified Capabilities

None.

## Impact

- Code: scripts/validate-dia-mentions.sh gains a ticket-body scan mode + date-cutoff grandfathering + hard-fail exit. scripts/tickets gains a self-mention write + post-write validation call. No change to delegation-observer.ts unless the optional gate enhancement is taken.
- Tests: new bats tests for (a) validate-dia-mentions.sh hard-fails a post-cutoff ticket body with a bare ref, warn-only for a pre-cutoff one, passes when all refs carry slugs; (b) scripts/tickets new writes a self-mention and fails on a bare-ref body.
- APIs: none.
- Dependencies: none added.
- Systems: make test-config now fails the build on non-compliant NEW ticket bodies (shift-left enforcement of DIA-234's mention rule).

## Testing Decisions

What makes a good test: a test that proves the gate actually blocks a violating input and passes a compliant one, at both enforcement points (creation + test-config). Modules tested: scripts/validate-dia-mentions.sh (fixture ticket bodies with controlled created: dates) and scripts/tickets new (fixture invocation asserting self-mention presence + failure on bare ref). Prior art: the existing warn-only validate-dia-mentions.sh; the chicken-egg-ticket-gate change (dia-260820-jlu0) which extended the same delegation-observer gate and added bats tests; the DIA-234 ticket itself (datetime ID format). Tests must run under make test-config (host, no container) and the bats suite (make test-shell).

## Alternatives considered

- Option A (CHOSEN): dual enforcement - scripts/tickets new self-mention + validator hard-fail on post-cutoff ticket bodies, with date-cutoff grandfathering. Evidence: Tier-1 (existing scripts/validate-dia-mentions.sh seed; AGENTS.md 2.3 mention rule; chicken-egg change pattern for gate/bats testing).
- Option B: test-config only, no scripts/tickets new guard. Rejected: late feedback; does not stop a non-compliant ticket from being created and committed. Evidence: Tier-1 (AGENTS.md ticket-gate philosophy favors shift-left attribution).
- Option C: scripts/tickets new only, no test-config gate. Rejected: does not catch hand-edited bodies or cross-references added after creation. Evidence: Tier-1 (the existing validator already scans; a warn-only scan is insufficient per DIA-234 intent).
- Option D: full hard-fail with NO grandfathering. Rejected: breaks hundreds of existing tickets; unshippable. Evidence: Tier-1 (Makefile:187 comment "warn-not-fail on grandfathered bare references").
- Option E (delegation-observer gate slug check, "ideally"): include as optional only. Rejected as default: conflicts with the "campaign ticket DIA-NNN" marker convention already required by AGENTS.md 2.3.1; would over-block legitimate dispatches. Evidence: Tier-1 (AGENTS.md 2.3.1 marker convention vs 2.3 slug convention tension).
- Status-quo / do nothing: rejected - the human-readable-mention requirement stays unenforced, defeating the DIA-234 follow-up.
  Chosen option: Option A - because it enforces the requirement at creation (shift-left) and as a build gate, while grandfathering avoids breaking the existing ledger.
