# Dev-Infra Audit — Ticket Ledger

Ledger of all dev-infra audit tickets. Each row points to the ticket file, which
carries the full detail (description, verification, fix, re-verify evidence).

> Archive policy (2026-08-03): completed tickets (VERIFIED or CLOSED for ≥1 cycle with no reopen) move to `tickets/archive/` instead of deletion. Git history preserves all prior states. See [archive/README.md](archive/README.md) for triggers.

## Index

| ID      | Title                                                                            | Area            | Severity | Status | Ticket file              |
| ------- | -------------------------------------------------------------------------------- | --------------- | -------- | ------ | ------------------------ |
| DIA-045 | OpenCode config drift backlog (ai-specialist review 2026-08-04, findings F6–F21) | opencode-config | Medium   | OPEN   | [DIA-045.md](DIA-045.md) |
| DIA-050 | .mise.toml ↔ Dockerfile.dev pin-sync gap (DIA-045 F15)                           | dev-infra       | Low      | OPEN   | [DIA-050.md](DIA-050.md) |

## Status summary

| Severity | Count |
| -------- | ----- |
| Blocker  | 0     |
| Critical | 0     |
| Major    | 0     |
| Medium   | 1     |
| Minor    | 0     |
| Low      | 1     |
| Info     | 0     |

| Status      | Count |
| ----------- | ----- |
| OPEN        | 2     |
| VALIDATE    | 0     |
| E2E         | 0     |
| DEFERRED    | 0     |
| MONITOR     | 0     |
| FIXED       | 0     |
| IMPLEMENTED | 0     |
| VERIFIED    | 0     |
| CLOSED      | 0     |
| BLOCKED     | 0     |

## How to add a ticket

1. Copy `_TEMPLATE.md` → `DIA-<NNN>.md` (YAML frontmatter format).
2. Fill all fields; `Fix` and `Re-verify` stay blank with a "fill at fix time /
   re-verify time" note until the work happens.
3. Add a row to the index table above with matching Severity and Status.
4. Update the status summary counts.
