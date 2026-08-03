# Dev-Infra Audit — Ticket Ledger

Ledger of all dev-infra audit tickets. Each row points to the ticket file, which
carries the full detail (description, verification, fix, re-verify evidence).

> Cleanup 2026-08-03: 32 tickets (25 FIXED + 6 CLOSED + 1 IMPLEMENTED) audited, validated, and deleted — all fixes verified present in the repo. Deleted tickets remain recoverable via git history. 4 OPEN tickets retained.

## Index

| ID      | Title                                                                                                        | Area            | Severity | Status | Ticket file              |
| ------- | ------------------------------------------------------------------------------------------------------------ | --------------- | -------- | ------ | ------------------------ |
| DIA-003 | skills-lock.json contains only cli-review — pin all skills                                                   | opencode-config | Minor    | OPEN   | [DIA-003.md](DIA-003.md) |
| DIA-006 | api-server has no production Dockerfile — evaluate need                                                      | docker          | Major    | OPEN   | [DIA-006.md](DIA-006.md) |
| DIA-030 | unverified installs in Dockerfile.dev                                                                        | docker          | Medium   | OPEN   | [DIA-030.md](DIA-030.md) |
| DIA-034 | pip-audit finding: apps/api-server ecdsa 0.19.2 PYSEC-2026-1325 (transitive via python-jose), NO fix version | deps            | Medium   | OPEN   | [DIA-034.md](DIA-034.md) |
| DIA-037 | make test-skills gap — no validation of SKILL.md content                                                    | opencode-config | Minor    | OPEN   | [DIA-037.md](DIA-037.md) |

## Status summary

| Severity | Count |
| -------- | ----- |
| Blocker  | 0     |
| Critical | 0     |
| Major    | 1     |
| Medium   | 2     |
| Minor    | 2     |
| Low      | 0     |

| Status      | Count |
| ----------- | ----- |
| FIXED       | 0     |
| CLOSED      | 0     |
| IMPLEMENTED | 0     |
| OPEN        | 4     |

## How to add a ticket

1. Copy `_TEMPLATE.md` → `DIA-<NNN>.md` (next sequential number).
2. Fill all fields; `Fix` and `Re-verify` stay blank with a "fill at fix time /
   re-verify time" note until the work happens.
3. Add a row to the index table above with matching Severity and Status.
4. Update the status summary counts.
