---
name: review-re-verify
description: Use when performing a targeted re-review after fix verification — confirms each prior finding resolved with evidence, produces a findings-resolution table.
compatibility: opencode
metadata:
  audience: reviewers
  workflow: re-review
---

# Re-Review Protocol — Targeted Findings Verification

Activated when the orchestrator dispatches @reviewer for a re-review (cycle N/2) with prior findings context.

## Mode: Targeted Re-Review

This is NOT a full review. You are verifying that specific prior findings were resolved by the coder's fixes. Do not re-scan the entire diff for new issues — only confirm or deny resolution of the listed findings.

## Inputs (from orchestrator dispatch)

1. **Fixed point** — same commit/branch/tag as the original review
2. **Prior findings** — the list of findings the developer accepted for fixing (finding-id, severity, file:line, description)
3. **Fixes-applied summary** — coder's description of what was changed
4. **Verification evidence** — coder's test/lint/typecheck exit codes + summary lines
5. **Cycle counter** — `re-review cycle N/2`

## Procedure

For each prior finding:

1. Read the referenced file at the current HEAD
2. Check whether the specific issue described in the finding is resolved
3. Cross-reference with coder's verification evidence (test output, lint result)
4. Assign a status and write evidence

## Findings-Resolution Table

| finding-id | status | evidence |
|------------|--------|----------|
| S-01 | verified-closed | `make test exit 0; 42 passed, 0 failed — test_new_case passes` |
| M-03 | still-open | `file.ts:88 — hardcoded string still present; coder did not address` |
| S-02 | partial | `lint clean but typecheck shows TS2345 at line 92 — related type not updated` |

### Status enum

- **verified-closed** — the specific issue is resolved; evidence confirms it
- **still-open** — the issue persists unchanged; coder did not address it or the fix is ineffective
- **partial** — partially addressed; describe what remains in the evidence column

### Evidence rules

- Cite specific output: exit codes, test counts, lint messages, line numbers
- Reference coder-provided verification evidence where applicable
- If coder provided no evidence for a finding, note "no evidence provided" and mark still-open
- You are read-only (bash:deny) — you verify by reading code + coder evidence, not by running commands

## Re-Review Observations (optional)

If you notice a new issue introduced by the fix (e.g., a regression), note it AFTER the table under "Re-Review Observations" — these are NOT part of the resolution table and enter the normal practice-protected §4 disposition flow.

## Summary

- Total findings reviewed: N
- Verified-closed: N
- Still-open: N
- Partial: N
- New observations: N (if any)

If all findings are verified-closed: state "All findings resolved — re-review complete."
If any remain: state "N findings unresolved — see table above."

## Mode: Clean-Termination Independent Verification

Activated when a FRESH session reads a HANDOFF.md with `exit_state: clean` and must
independently verify it before accepting the handoff (design.md §9, ADR-003 — the
producer session cannot certify its own completion).

### Inputs

1. **HANDOFF.md** — with `exit_state: clean` and a populated `## Verification request`
   section (per-verification_id `what_to_verify` / `success_criteria` / `how_to_verify`)
2. **Verification request** — the exact verification_request list from the HANDOFF.md
3. **Working tree** — the actual files at the handoff point
4. **Test infrastructure** — test suites, build tools, `openspec` CLI as applicable

### Procedure

For EACH verification_request:

1. Execute `how_to_verify` **independently** — do NOT trust the producer's claims.
2. Run the verification yourself: commands, file reads, test executions.
3. Compare the observed result against `success_criteria` (observable, testable).
4. Record status: `verified-pass` | `verified-fail` (no `verified-partial` in this mode —
   a partial result counts as a fail for that verification_id).

### `## Verification Result` section

Write the section appended to HANDOFF.md — by the VERIFIER, NEVER by the producer:

| verification_id | status | evidence |
|-----------------|--------|----------|
| VR-001 | verified-pass | `make test-config exit 0; 6/6 checks pass` |
| VR-002 | verified-fail | `openspec validate exit 1 — design.md §7 fails schema` |

Evidence rules:

- Cite specific output: exit codes, test counts, lint messages, line numbers, file paths.
- If a command cannot be executed (permission, missing infra), mark `verified-fail` with
  "could not execute" as the evidence — do NOT pass it on trust.
- You are read-only for code (bash:deny for repo mutation) but MUST run verification
  commands where your permissions allow; if you cannot run them, record that explicitly.

### Outcome

- **ALL pass** → confirm `exit_state: clean` and append `Verified by: <session-id>,
  <timestamp>` to the HANDOFF.md.
- **ANY fail** → downgrade `exit_state` to `crisis` and append the failure details
  (verification_id, observed vs expected, evidence).
