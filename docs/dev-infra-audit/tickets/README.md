# Dev-Infra Audit — Ticket Ledger

Ledger of all dev-infra audit tickets. Each row points to the ticket file, which
carries the full detail (description, verification, fix, re-verify evidence).

> Archive policy (2026-08-03): completed tickets (VERIFIED or CLOSED for ≥1 cycle with no reopen) move to `tickets/archive/` instead of deletion. Git history preserves all prior states. See [archive/README.md](archive/README.md) for triggers.

## Index

| ID      | Title                                                                            | Area            | Severity | Status | Ticket file              |
| ------- | -------------------------------------------------------------------------------- | --------------- | -------- | ------ | ------------------------ |
| DIA-045 | OpenCode config drift backlog (ai-specialist review 2026-08-04, findings F6–F21) | opencode-config | Medium   | OPEN   | [DIA-045.md](DIA-045.md) |
| DIA-050 | .mise.toml ↔ Dockerfile.dev pin-sync gap (DIA-045 F15)                           | dev-infra       | Low      | OPEN   | [DIA-050.md](DIA-050.md) |
| DIA-051 | Raw JSONL telemetry leak into human chat UI (messages.jsonl sidecar)             | opencode-config | Medium   | CLOSED | [DIA-051.md](DIA-051.md) |
| DIA-052 | Skill dup cleanup + two-tier dup detection in validate-skills.sh (5 dirs)        | scripts         | Major    | DONE   | [DIA-052.md](DIA-052.md) |
| DIA-053 | @ai-auditor 4-source registration + @ai-specialist docs-only narrowing           | opencode-config | Medium   | DONE   | [DIA-053.md](DIA-053.md) |
| DIA-054 | NEXT-RUN.md §2 council budget guard (COUNCIL-BUDGET-GUARD)                       | docs            | Medium   | DONE   | [DIA-054.md](DIA-054.md) |
| DIA-055 | Write-capable token_export exposed to all subagents (permission default-allow)   | opencode-config | Medium   | OPEN   | [DIA-055.md](DIA-055.md) |
| DIA-056 | @ai-auditor subagent token-tool stacking loop (session error, cancelled)         | opencode-config | Medium   | OPEN   | [DIA-056.md](DIA-056.md) |
| DIA-057 | Knowledge-workflow violation — conspect not created on research request (2026-08-06) | docs            | Low      | OPEN   | [DIA-057.md](DIA-057.md) |

## Status summary

| Severity | Count |
| -------- | ----- |
| Blocker  | 0     |
| Critical | 0     |
| Major    | 1     |
| Medium   | 6     |
| Minor    | 0     |
| Low      | 2     |
| Info     | 0     |

| Status      | Count |
| ----------- | ----- |
| OPEN        | 5     |
| DONE        | 3     |
| VALIDATE    | 0     |
| E2E         | 0     |
| DEFERRED    | 0     |
| MONITOR     | 0     |
| FIXED       | 0     |
| IMPLEMENTED | 0     |
| VERIFIED    | 0     |
| CLOSED      | 1     |
| BLOCKED     | 0     |

## How to add a ticket

1. Copy `_TEMPLATE.md` → `DIA-<NNN>.md` (YAML frontmatter format).
2. Fill all fields; `Fix` and `Re-verify` stay blank with a "fill at fix time /
   re-verify time" note until the work happens.
3. Add a row to the index table above with matching Severity and Status.
4. Update the status summary counts.
