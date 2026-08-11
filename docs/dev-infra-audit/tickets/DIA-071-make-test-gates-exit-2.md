# DIA-071 — make test-infra/test-shell exit 2 — host check-host-lsp gate fails

<!-- Discovered 2026-08-08 during DIA-067 verification (lane
     ses_01fd79d07ffe1ALaVr04mIjNnk). PRE-EXISTING — NOT caused by DIA-067:
     scripts/test-docker-smoke.sh `check-host-lsp` fails because
     typescript-language-server/pyright/rust-analyzer are absent from the HOST
     PATH. Zero references to DIA-067-changed files. -->

---

id: DIA-071
title: "make test-infra/test-shell exit 2 — host check-host-lsp gate fails"
area: dev-infra
severity: Low
status: OPEN
blocked_by: []
discovered: 2026-08-08
source: test-lane
date: 2026-08-08
created: 2026-08-08
updated: 2026-08-08

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

1. `make test-infra` — exit 2, failing at `check-host-lsp`.
2. `bash scripts/test-docker-smoke.sh` — exit 0 (smoke itself passes).
3. `which typescript-language-server pyright rust-analyzer` — all absent from
   host PATH.
4. Post-fix (see Fix direction): `make test-infra` — exit 0.

## Fix

**Fix direction:**

- Install the host LSPs (typescript-language-server, pyright, rust-analyzer) on
  the dev host, OR
- Make `check-host-lsp` tolerant/skippable when host tools are absent
  (documented decision — e.g. warn + skip instead of hard fail when the gate is
  host-tool dependent and the container provides the tooling).

**§10 routing note:** dev-infra change — per project AGENTS.md §2.4, spec for

> 20-line changes; review via @reviewer.

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.

1. `make test-infra` — exit 0.
2. `make test-shell` — exit 0.
