# Dev-Infra Audit — Ticket Ledger

Ledger of all dev-infra audit tickets. Each row points to the ticket file, which
carries the full detail (description, verification, fix, re-verify evidence).

## Index

| ID      | Title                                                                                              | Area            | Severity | Status | Ticket file              |
| ------- | -------------------------------------------------------------------------------------------------- | --------------- | -------- | ------ | ------------------------ |
| DIA-001 | references.shelf.path points to directory `.opencode` (opencode.jsonc:227)                         | opencode-config | Minor    | OPEN   | [DIA-001.md](DIA-001.md) |
| DIA-002 | .npmrc shamefully-hoist=true antipattern — evaluate/document                                       | js-tooling      | Minor    | OPEN   | [DIA-002.md](DIA-002.md) |
| DIA-003 | skills-lock.json contains only cli-review — pin all skills                                         | opencode-config | Minor    | OPEN   | [DIA-003.md](DIA-003.md) |
| DIA-004 | Duplicate agents in system prompt (explorer vs code_explorer, oracle vs code_architect)            | opencode-config | Minor    | OPEN   | [DIA-004.md](DIA-004.md) |
| DIA-005 | Ghost agents code-navigator/researcher — verify usage; document or remove                          | opencode-config | Minor    | OPEN   | [DIA-005.md](DIA-005.md) |
| DIA-006 | api-server has no production Dockerfile — evaluate need                                            | docker          | Major    | OPEN   | [DIA-006.md](DIA-006.md) |
| DIA-007 | Split ai-specialist into resource-manager + specialist                                             | opencode-config | Major    | OPEN   | [DIA-007.md](DIA-007.md) |
| DIA-008 | .husky/pre-commit untracked — hook vanishes on clone                                               | git-hooks       | Critical | OPEN   | [DIA-008.md](DIA-008.md) |
| DIA-009 | test-interview-enforcement.sh orphaned — not in Makefile despite CHANGELOG claim                   | scripts         | Minor    | OPEN   | [DIA-009.md](DIA-009.md) |
| DIA-010 | onboarding.md broken prompts/ refs + stale tables + "api-server not yet created"                   | docs            | Minor    | OPEN   | [DIA-010.md](DIA-010.md) |
| DIA-011 | openspec version skew tools/opencode-docker 1.6.0 vs Dockerfile.dev 1.7.0                          | docker          | Major    | OPEN   | [DIA-011.md](DIA-011.md) |
| DIA-012 | .env missing CONTEXT7_API_KEY vs .env.example                                                      | env             | Minor    | OPEN   | [DIA-012.md](DIA-012.md) |
| DIA-013 | analytics-pipeline pytest config without dev deps/tests/ruff; verify-python covers api-server only | python-tooling  | Major    | OPEN   | [DIA-013.md](DIA-013.md) |
| DIA-014 | Empty secret placeholder files (4/5) contradict README non-empty rule                              | secrets         | Minor    | OPEN   | [DIA-014.md](DIA-014.md) |
| DIA-015 | pnpm missing from Volta toolchain + empty node_modules → pnpm JS gates exit 126                    | env             | Blocker  | OPEN   | [DIA-015.md](DIA-015.md) |
| DIA-016 | Global DCP sparse vs project DCP 14 models — unify                                                 | opencode-config | Minor    | OPEN   | [DIA-016.md](DIA-016.md) |
| DIA-017 | ai-assist-sources.yaml — verify path consistency; close as verified if moot                        | opencode-config | Minor    | OPEN   | [DIA-017.md](DIA-017.md) |
| DIA-018 | Ports documented — close as verified (docker-dev.md + .env.example + compose agree)                | docs            | Minor    | OPEN   | [DIA-018.md](DIA-018.md) |

## Status summary

| Severity | Count |
| -------- | ----- |
| Blocker  | 1     |
| Critical | 1     |
| Major    | 3     |
| Minor    | 13    |

## How to add a ticket

1. Copy `_TEMPLATE.md` → `DIA-<NNN>.md` (next sequential number).
2. Fill all fields; `Fix` and `Re-verify` stay blank with a "fill at fix time /
   re-verify time" note until the work happens.
3. Add a row to the index table above with matching Severity and Status.
4. Update the status summary counts.
