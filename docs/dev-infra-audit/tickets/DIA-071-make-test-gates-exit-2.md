# DIA-071 — make test-infra/test-shell exit 2 — host check-host-lsp gate fails

<!-- UPDATE 2026-08-13 (IMPLEMENTED + REVIEWED + RE-VERIFIED - TICKET CLOSED):
     tolerant-gate fix implemented by cod-23 (ses_00346c535ffe9kGhJdUAgIkOve):
     scripts/check-host-lsp.sh now emits warn (exit 0) when a host LSP is
     MISSING (dev container provides all 3 LSPs per DIA-106),
     CHECK_HOST_LSP_STRICT=1 restores the pre-fix hard gate; version DRIFT on a
     present tool, container-path mismatch, and lsp-versions.env defects still
     hard-fail; summary line 'N ok, M fail, W warn, K skip'. Files:
     scripts/check-host-lsp.sh (+36/-14), scripts/__tests__/check-host-lsp.bats
     (9->10 tests incl strict-mode), docs/dev-infra/host-lsp-setup.md
     (+51/-36). Validation: make test-shell exit 0 (252 tests), make
     check-host-lsp exit 0 (3 ok), fresh-host simulation BEFORE exit 1 / AFTER
     exit 0 (3 warn) / AFTER+STRICT exit 1, bash -n clean. Review rev-2
     (ses_003383779ffeFS1TxG81xhrKfw): Standards 2 Minor judgement calls
     (em-dashes repo-consistent; summary-stream divergence vs check-host-jq -
     both ACCEPTED no change), Spec 1 Major (test-infra not run) + 1 Minor
     (STRICT container-path semantics defensible, ACCEPTED). Developer
     disposition 2026-08-13: ACCEPT + run test-infra; minors accepted without
     code change. Re-verify PASSED 2026-08-13 (this lane): make test-infra exit
     0 (252 bats + 6 pytest tests ok) with dev container up. Ticket CLOSED per
     Re-verify convention; commit deferred to end-of-session.

     Discovered 2026-08-08 during DIA-067 verification (lane
     ses_01fd79d07ffe1ALaVr04mIjNnk). PRE-EXISTING — NOT caused by DIA-067:
     scripts/test-docker-smoke.sh `check-host-lsp` fails because
     typescript-language-server/pyright/rust-analyzer are absent from the HOST
     PATH. Zero references to DIA-067-changed files. -->

---

id: DIA-071
title: "make test-infra/test-shell exit 2 — host check-host-lsp gate fails"
area: dev-infra
severity: Low
status: CLOSED
blocked_by: []
discovered: 2026-08-08
source: test-lane
date: 2026-08-08
created: 2026-08-08
updated: 2026-08-13

# --- Session Attribution (v2 schema, optional) ---

session_id: "ses_01fd79d07ffe1ALaVr04mIjNnk"
lane_id: ""
agent: "coder"
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: ""
files_touched: []
artifacts: []
evidence: ["ses_01fd79d07ffe1ALaVr04mIjNnk (DIA-067 verification lane)"]

---

## Description

`make test-infra` and `make test-shell` exit 2 in this environment because the
host-side `check-host-lsp` gate in `scripts/test-docker-smoke.sh` fails:
`typescript-language-server`, `pyright`, and `rust-analyzer` are absent from
the HOST PATH.

**Pre-existing — NOT a regression of DIA-067:** the failing script has zero
references to DIA-067-changed files (Dockerfile.dev, test-docker-smoke.sh
probes). The smoke test itself passes (`exit 0`); `make test-opencode-docker`
exit 0; bats suite 183/183 ok.

**Impact:** `make test-infra` / `make test-shell` never exit 0 in this
environment → verification gate friction for every dev-infra change (the
DIA-067 lane had to document exit 2 with the pre-existing-cause explanation).

## Verification

- [x] 1. `make test-infra` — exit 2, failing at `check-host-lsp`. (2026-08-08 pre-fix evidence; post-fix exit 0 — see UPDATE.)
- [x] 2. `bash scripts/test-docker-smoke.sh` — exit 0 (smoke itself passes).
- [x] 3. `which typescript-language-server pyright rust-analyzer` — all absent from
     host PATH.
- [x] 4. Post-fix (see Fix direction): `make test-infra` — exit 0. RE-RUN 2026-08-13
     (closure lane, dev container UP per DIA-094): `make test-infra` REAL exit 0 —
     gen-jsconfig ok, test-shell 252/252 bats ok (incl check-host-lsp 3 ok / 0 fail /
     0 warn / 0 skip), docker smoke passed (container LSP probes: all 3 present per
     DIA-106), pytest 2+4=6 passed. Last 5 output lines (final docker-compose down
     of the smoke chain): `Container poetry-postgres Stopped` / `Removing` /
     `Removed` / `Network poetry-platform_poetry-net Removing` / `Removed`.

## Fix

**Fix direction:**

- Install the host LSPs (typescript-language-server, pyright, rust-analyzer) on
  the dev host, OR
- Make `check-host-lsp` tolerant/skippable when host tools are absent
  (documented decision — e.g. warn + skip instead of hard fail when the gate is
  host-tool dependent and the container provides the tooling).

**§10 routing note:** dev-infra change — per project AGENTS.md §2.4, spec for

> 20-line changes; review via @reviewer.

FIX COMPLETE 2026-08-13 (cod-23): tolerant gate with CHECK_HOST_LSP_STRICT=1
escape hatch (Option 1, ticket Fix direction #2). See top UPDATE.

## Re-verify

RE-VERIFY PASS 2026-08-13: make test-shell exit 0 (252), make check-host-lsp
exit 0, make test-infra exit 0 (see top UPDATE).

1. `make test-infra` — exit 0.
2. `make test-shell` — exit 0.
