# DIA-040 — Python gates (verify-python, audit-python, container pytest)

---

id: DIA-040
title: "Python gates (verify-python, audit-python, container pytest)"
area: python-tooling
severity: Medium
status: VERIFIED
blocked_by: []
discovered:
source: baseline
date: 2026-08-04
created: 2026-08-04
updated: 2026-08-04

---

## Description

The three Python gates have not been validated in this campaign:

- `bash scripts/verify-python.sh` — host Python gate (uv venv → `ruff check .` →
  `ruff format --check .` → pytest; bats-covered, 4 cases).
- `make audit-python` — `uv export` per package + `uvx pip-audit@2.10.1
--disable-pip -r <export>`; **aggregate exit** (rc accumulates across
  `apps/api-server` and `packages/analytics-pipeline`, fails at the end —
  Makefile:131–138). Expected to **fail** on the known residual:
  `apps/api-server` resolves `ecdsa 0.19.2` / `PYSEC-2026-1325` (transitive via
  `python-jose`). DIA-034 was CLOSED + archived 2026-08-03 as
  accepted-with-justification (python-jose/ecdsa unused; upstream declares the
  class of issue out of scope) — the finding persists, so a nonzero exit is the
  _expected_ outcome; the point of this validation is that the aggregate-exit
  path audits BOTH packages and reports both results.
- `make test-python` — container pytest (`docker compose exec`; api-server +
  analytics-pipeline suites), requires the stack to be UP.

## Verification

1. `bash scripts/verify-python.sh` → exit 0; record suite count.
2. `make audit-python` → expected rc=1 reporting `ecdsa 0.19.2` / `PYSEC-2026-1325` for `apps/api-server`; confirm the aggregate path still audits `packages/analytics-pipeline` and reports its result.
3. Ensure the stack is up (`make up`), then `make test-python` → exit 0 (api-server + analytics-pipeline pytest).
4. Record every exit code + finding text in Re-verify.

## Fix

> To be filled at fix time.

## Re-verify

Re-verify 2026-08-04 (Python gates): `bash scripts/verify-python.sh` exit 0
(ruff check + ruff format --check + pytest pass). `make audit-python` — nonzero
exit reporting **only** the known residual: `apps/api-server` resolves
`ecdsa 0.19.2` / `PYSEC-2026-1325` (transitive via `python-jose`), accepted per
DIA-034 (closed 2026-08-03 with justification; no new findings in
`packages/analytics-pipeline`). Container pytest 6/6 via `make test-infra`
(DIA-041). Python gates VERIFIED (known-residual documented, not a regression).
