# Dev-Infra Audit — Ticket Ledger

Ledger of all dev-infra audit tickets. Each row points to the ticket file, which
carries the full detail (description, verification, fix, re-verify evidence).

> Archive policy (2026-08-03): completed tickets (VERIFIED or CLOSED for ≥1 cycle with no reopen) move to `tickets/archive/` instead of deletion. Git history preserves all prior states. See [archive/README.md](archive/README.md) for triggers.

## Index

| ID      | Title                                                    | Area            | Severity | Status      | Ticket file              |
| ------- | -------------------------------------------------------- | --------------- | -------- | ----------- | ------------------------ |
| DIA-037 | make test-skills gap — no validation of SKILL.md content | opencode-config | Minor    | IMPLEMENTED | [DIA-037.md](DIA-037.md) |

## Status summary

| Severity | Count |
| -------- | ----- |
| Blocker  | 0     |
| Critical | 0     |
| Major    | 0     |
| Medium   | 0     |
| Minor    | 1     |
| Info     | 0     |

| Status      | Count |
| ----------- | ----- |
| OPEN        | 0     |
| DEFERRED    | 0     |
| MONITOR     | 0     |
| FIXED       | 0     |
| IMPLEMENTED | 1     |
| VERIFIED    | 0     |
| CLOSED      | 0     |
| BLOCKED     | 0     |

## How to add a ticket

1. Copy `_TEMPLATE.md` → `DIA-<NNN>.md` (YAML frontmatter format).
2. Fill all fields; `Fix` and `Re-verify` stay blank with a "fill at fix time /
   re-verify time" note until the work happens.
3. Add a row to the index table above with matching Severity and Status.
4. Update the status summary counts.
