# Dev-Infra Audit — Ticket Ledger

Ledger of all dev-infra audit tickets. Each row points to the ticket file, which
carries the full detail (description, verification, fix, re-verify evidence).

> Archive policy (2026-08-03): completed tickets (VERIFIED or CLOSED for ≥1 cycle with no reopen) move to `tickets/archive/` instead of deletion. Git history preserves all prior states. See [archive/README.md](archive/README.md) for triggers.

## Index

| ID      | Title                                                                                                                 | Area            | Severity | Status      | Ticket file              |
| ------- | --------------------------------------------------------------------------------------------------------------------- | --------------- | -------- | ----------- | ------------------------ |
| DIA-037 | make test-skills gap — no validation of SKILL.md content                                                              | opencode-config | Minor    | IMPLEMENTED | [DIA-037.md](DIA-037.md) |
| DIA-038 | Makefile gate matrix validation (test-config / test-shell / test-skills / test-interview / jsonl-stats / check-tools) | tests-infra     | Medium   | VERIFIED    | [DIA-038.md](DIA-038.md) |
| DIA-039 | pnpm verify pipeline + pnpm audit                                                                                     | js-tooling      | Medium   | VERIFIED    | [DIA-039.md](DIA-039.md) |
| DIA-040 | Python gates (verify-python, audit-python, container pytest)                                                          | python-tooling  | Medium   | VERIFIED    | [DIA-040.md](DIA-040.md) |
| DIA-041 | Docker E2E — full make test-infra                                                                                     | docker          | Medium   | VERIFIED    | [DIA-041.md](DIA-041.md) |
| DIA-042 | Browser E2E — Playwright flows (author-studio / publishing-platform)                                                  | tests-infra     | Medium   | E2E         | [DIA-042.md](DIA-042.md) |
| DIA-043 | Husky hooks not CI-enforced (no CI exists)                                                                            | git-hooks       | Minor    | OPEN        | [DIA-043.md](DIA-043.md) |
| DIA-044 | tools/opencode-docker not wired into root Makefile gates                                                              | docker          | Minor    | OPEN        | [DIA-044.md](DIA-044.md) |
| DIA-045 | OpenCode config drift backlog (ai-specialist review 2026-08-04, findings F6–F21)                                      | opencode-config | Medium   | OPEN        | [DIA-045.md](DIA-045.md) |
| DIA-046 | Prettier format failures (verify:format exit 1 — 5 files)                                                             | js-tooling      | Minor    | VERIFIED    | [DIA-046.md](DIA-046.md) |
| DIA-047 | pnpm audit: esbuild <0.28.1 advisory (GHSA-g7r4-m6w7-qqqr)                                                            | deps            | Minor    | VERIFIED    | [DIA-047.md](DIA-047.md) |
| DIA-048 | Stale pnpm_store named volume + presence-only skip guard masks author-studio probe failures                           | docker          | Major    | OPEN        | [DIA-048.md](DIA-048.md) |
| DIA-049 | publishing-platform is a stub — no runnable dev entry (browser E2E impossible)                                        | tests-infra     | Medium   | OPEN        | [DIA-049.md](DIA-049.md) |

## Status summary

| Severity | Count |
| -------- | ----- |
| Blocker  | 0     |
| Critical | 0     |
| Major    | 1     |
| Medium   | 7     |
| Minor    | 5     |
| Info     | 0     |

| Status      | Count |
| ----------- | ----- |
| OPEN        | 5     |
| VALIDATE    | 0     |
| E2E         | 1     |
| DEFERRED    | 0     |
| MONITOR     | 0     |
| FIXED       | 0     |
| IMPLEMENTED | 1     |
| VERIFIED    | 6     |
| CLOSED      | 0     |
| BLOCKED     | 0     |

## How to add a ticket

1. Copy `_TEMPLATE.md` → `DIA-<NNN>.md` (YAML frontmatter format).
2. Fill all fields; `Fix` and `Re-verify` stay blank with a "fill at fix time /
   re-verify time" note until the work happens.
3. Add a row to the index table above with matching Severity and Status.
4. Update the status summary counts.
