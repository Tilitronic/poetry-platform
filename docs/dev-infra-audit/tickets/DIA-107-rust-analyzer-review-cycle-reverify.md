# DIA-107 - rust-analyzer container setup review-cycle re-verify

---

id: DIA-107
title: "rust-analyzer container setup review-cycle re-verify"
area: dev-infra
severity: Low
status: CLOSED
blocked_by: [] # DIA-NNN refs, or empty
discovered: 2026-08-11
source: test-lane
date: 2026-08-11
created: 2026-08-11
updated: 2026-08-11

# --- Session Attribution (v2 schema, optional) ---

session_id: "ses_00d617de4ffeLyNu3EpYtQ3kgf" # OpenCode session ID that owned this ticket
lane_id: "" # e.g. cod-1, ai--3
agent: "coder" # agent name (coder, reviewer, etc.)
model: "deepseek-v4-flash" # model ID used
parent_session_id: "" # orchestrator's session ID (populated via get-my-session-id tool)
attempts: 0 # how many delegations attempted
lease_expires_at: "" # ISO-8601; set on DISPATCHED, cleared on COMPLETE
files_touched: ["docs/dev-infra-audit/tickets/DIA-107-rust-analyzer-review-cycle-reverify.md", "docs/dev-infra-audit/tickets/README.md"] # list of file paths modified
artifacts: [] # list of artifact references (commits, test outputs)
evidence: [] # list of evidence URIs (messages.md#row, registry.jsonl#seq)

---

## Description

AGENTS.md section 2.3.1 targeted re-review (cycle 1/2) of the container-first
rust-analyzer dev-infra change's close-out commit 1dc8f76, which closed the
prior rust-analyzer container setup ticket DIA-106. The prior ticket was
reviewed (APPROVE both axes: Standards + Spec fidelity) and closed; the
section 2.3.1 re-review loop requires an OPEN ticket for the re-verify
dispatch, so this follow-up ticket satisfies the DIA-063 ticket gate.

Scope (verify resolved on commit 1dc8f76):

- S1: `extract_version()` helper in scripts/check-host-lsp.sh - duplicated
  version-extraction regex removed, behavior identical.
- S5: docs/dev-infra/host-lsp-setup.md + scripts/install-host-lsp.sh version
  examples 1.83.0 -> 1.97.1, plus the container-first note.
- S3: approval-trace History note in the prior ticket DIA-106.
- Accepted as-is from the prior review: S2 / S4 / P1 / P2 (no re-verification
  required).

Also verify the S1 refactor introduced no regression: same `ok:` / `fail:` /
`summary:` output shapes, exit-code contract, SKIP_RUST=1 neutral handling, and
container-probe logic in scripts/check-host-lsp.sh.

## Verification

Concrete gates to re-run against the close-out state (commit 1dc8f76).
Evidence on record at close-out:

- `bash -n scripts/check-host-lsp.sh` exit 0 (no syntax errors).
- `scripts/check-host-lsp.sh` exit 0 via container path
  ('ok: rust-analyzer 1.97.1 (container poetry-dev ...)').
- `make test-shell` exit 0 (193 ok / 0 not-ok; check-host-lsp.bats 9/9 green
  after the S1 refactor).
- `make test-config` exit 0 (224 WARNs baseline unchanged).
- Commit 1dc8f76 pushed via the container-delegated pre-commit hook
  (no --no-verify; DIA-094 / DIA-096).

Re-verify actions: re-run the commands above against commit 1dc8f76, confirm
the S1 helper extraction, S5 version bumps, and S3 History entry are present
in the working tree, and confirm no regression in probe output shapes or the
exit-code contract.

## Fix

> To be filled at fix time.

N/A for this follow-up ticket - it exists only to satisfy the DIA-063 ticket
gate for the section 2.3.1 re-verify dispatch. Any fix arising from re-review
findings, if opened, becomes a new ticket.

## Re-verify

> To be filled at re-verify time.

Expected proof: all four close-out gates re-run green against 1dc8f76, S1/S5/S3
changes confirmed present in the working tree, no regression in
check-host-lsp.sh behavior (ok/fail/summary shapes, exit-code contract,
SKIP_RUST=1, container-probe logic).

## History

- 2026-08-11 (created): Ticket created by the docs lane to satisfy the DIA-063
  ticket gate for the section 2.3.1 re-review dispatch (cycle 1/2) of the
  closed rust-analyzer container setup ticket DIA-106's close-out commit
  1dc8f76.
- 2026-08-11 (Session-11 close-out): rev-3 re-review complete: S1/S3/S5
  verified-closed (3/3), S4 close-out verified, S2/P1/P2 accepted-as-is,
  0 still-open/0 partial, regression scan clean (extract_version refactor
  behavior-identical), no new observations, no cycle 2 needed. DIA-107 CLOSED.

## Informational note (not a finding, non-blocking)

The version-extraction regex `[0-9]+(\.[0-9]+)+` now exists in 3 places:

- scripts/check-host-lsp.sh: `extract_version()` (lines 56-58)
- scripts/install-host-lsp.sh: `tool_version()` (lines 46-48)
- scripts/check-host-jq.sh: inline (line 39)

Cross-script duplication, out of DIA-106 scope; consider a future
consolidation ticket if desired. Informational only - not a finding.
