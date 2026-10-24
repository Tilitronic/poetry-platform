# DIA-139 — audit pre-commit and pre-push hook test coverage for edge-case gaps

<!-- Analysis ticket (baseline): edge-case coverage audit of turbo-driven hook
     test gates. Filed 2026-08-12, cod-lane. -->

---

id: DIA-139
title: "Audit pre-commit and pre-push hook test coverage (turbo-driven) for edge-case gaps"
area: git-hooks
severity: Medium
status: CLOSED
blocked_by: []
discovered: 2026-08-12
source: baseline
date: 2026-08-12
created: 2026-08-12
updated: 2026-08-12

# --- Session Attribution (v2 schema, optional) ---

session_id: "ses_00b5f2f4affeavJUt86vac4dn6"
lane_id: "cod-lane"
agent: "coder"
model: ""
parent_session_id: "ses_00b5f2f4affeavJUt86vac4dn6"
attempts: 0
lease_expires_at: ""
files_touched: ["docs/dev-infra-audit/tickets/DIA-139-hook-test-coverage-audit.md"]
artifacts: []
evidence: []

---

## Description

Pre-commit and pre-push hooks run test suites via turbo (make test-shell / test-config / test-infra / test-python gates; scripts/verify-pre-commit.sh). No audit has verified whether these cover enough edge cases, failure modes, and behavior variants across the affected zones (shell scripts, docker infra, config validation, python tests).

## Verification

Dispatch @analyzer to produce knowledge/ana<id>-hook-test-coverage report enumerating covered vs missing edge cases per gate with concrete additions/changes; report registered in memory-shelf.yaml shelf.analyses.

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.

<!-- UPDATE 2026-08-14 (RENUMBER + CLOSE): ticket renumbered DIA-115 -> DIA-139 (duplicate-ID collision resolution, developer decision; local campaign ticket DIA-115-evidence-based-decision-variants keeps its ID). Work demonstrably landed: the ana014 hook-test-coverage audit report was committed (b3cbde7, knowledge/ana014-hook-test-coverage/) and its developer-approved findings were implemented by the fix ticket DIA-142 (was DIA-118; hook wiring commit 2baf8f9, 'feat(hooks): wire test-shell/test-config into pre-push, fix turbo cache inputs, mark validators executable (DIA-118)'). Merge 4b3dbf7 confirmed the teammate branch integration. Status OPEN -> CLOSED per renumber/close convention. -->
