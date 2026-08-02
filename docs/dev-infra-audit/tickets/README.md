# Dev-Infra Audit — Ticket Ledger

Ledger of all dev-infra audit tickets. Each row points to the ticket file, which
carries the full detail (description, verification, fix, re-verify evidence).

## Index

| ID      | Title                                                                                                               | Area            | Severity | Status | Ticket file              |
| ------- | ------------------------------------------------------------------------------------------------------------------- | --------------- | -------- | ------ | ------------------------ |
| DIA-001 | references.shelf.path points to directory `.opencode` (opencode.jsonc:227)                                          | opencode-config | Minor    | FIXED  | [DIA-001.md](DIA-001.md) |
| DIA-002 | .npmrc shamefully-hoist=true antipattern — evaluate/document                                                        | js-tooling      | Minor    | FIXED  | [DIA-002.md](DIA-002.md) |
| DIA-003 | skills-lock.json contains only cli-review — pin all skills                                                          | opencode-config | Minor    | OPEN   | [DIA-003.md](DIA-003.md) |
| DIA-004 | Duplicate agents in system prompt (explorer vs code_explorer, oracle vs code_architect)                             | opencode-config | Minor    | CLOSED | [DIA-004.md](DIA-004.md) |
| DIA-005 | Ghost agents code-navigator/researcher — verify usage; document or remove                                           | opencode-config | Minor    | CLOSED | [DIA-005.md](DIA-005.md) |
| DIA-006 | api-server has no production Dockerfile — evaluate need                                                             | docker          | Major    | OPEN   | [DIA-006.md](DIA-006.md) |
| DIA-007 | Split ai-specialist into resource-manager + specialist                                                              | opencode-config | Major    | OPEN   | [DIA-007.md](DIA-007.md) |
| DIA-008 | .husky/pre-commit untracked — hook vanishes on clone                                                                | git-hooks       | Critical | CLOSED | [DIA-008.md](DIA-008.md) |
| DIA-009 | test-interview-enforcement.sh orphaned — not in Makefile despite CHANGELOG claim                                    | scripts         | Minor    | FIXED  | [DIA-009.md](DIA-009.md) |
| DIA-010 | onboarding.md broken prompts/ refs + stale tables + "api-server not yet created"                                    | docs            | Minor    | FIXED  | [DIA-010.md](DIA-010.md) |
| DIA-011 | openspec version skew tools/opencode-docker 1.6.0 vs Dockerfile.dev 1.7.0                                           | docker          | Major    | FIXED  | [DIA-011.md](DIA-011.md) |
| DIA-012 | .env missing CONTEXT7_API_KEY vs .env.example                                                                       | env             | Minor    | FIXED  | [DIA-012.md](DIA-012.md) |
| DIA-013 | analytics-pipeline pytest config without deps/tests/ruff coverage; verify-python covers api-server only             | python-tooling  | Major    | FIXED  | [DIA-013.md](DIA-013.md) |
| DIA-014 | Empty secret placeholder files (4/5) contradict README non-empty rule                                               | secrets         | Minor    | FIXED  | [DIA-014.md](DIA-014.md) |
| DIA-015 | pnpm missing from Volta toolchain + empty node_modules → pnpm JS gates exit 126                                     | env             | Blocker  | CLOSED | [DIA-015.md](DIA-015.md) |
| DIA-016 | Global DCP sparse vs project DCP 14 models — unify                                                                  | opencode-config | Minor    | CLOSED | [DIA-016.md](DIA-016.md) |
| DIA-017 | ai-assist-sources.yaml — verify path consistency; close as verified if moot                                         | opencode-config | Minor    | FIXED  | [DIA-017.md](DIA-017.md) |
| DIA-018 | Ports documented — close as verified (docker-dev.md + .env.example + compose agree)                                 | docs            | Minor    | CLOSED | [DIA-018.md](DIA-018.md) |
| DIA-019 | book-rag/SKILL.md + commands/rag.md reference nonexistent ~/.config/opencode/scripts/query_rag.py                   | opencode-config | Major    | FIXED  | [DIA-019.md](DIA-019.md) |
| DIA-020 | global ~/.config/opencode/oh-my-opencode-slim.jsonc presets lacked !openspec-propose                                | opencode-config | Minor    | FIXED  | [DIA-020.md](DIA-020.md) |
| DIA-021 | make test-infra red: bats test 50 login-shell PATH shadowing                                                        | tests-infra     | Major    | FIXED  | [DIA-021.md](DIA-021.md) |
| DIA-022 | tools/opencode-docker/bootstrap.py ALLOWED_SECRETS 8 vs 5                                                           | docker          | Minor    | FIXED  | [DIA-022.md](DIA-022.md) |
| DIA-023 | tools/opencode-docker/TODO.md stale line refs + F13 version                                                         | docker          | Minor    | FIXED  | [DIA-023.md](DIA-023.md) |
| DIA-024 | turbo.json dead compile:lezer pipeline (no script, no \*.grammar)                                                   | js-tooling      | Major    | FIXED  | [DIA-024.md](DIA-024.md) |
| DIA-025 | lint-staged py glob apps/api-server/\*_/_.py only; analytics .py escaped ruff                                       | python-tooling  | Major    | FIXED  | [DIA-025.md](DIA-025.md) |
| DIA-026 | format drift 7 files                                                                                                | js-tooling      | Minor    | FIXED  | [DIA-026.md](DIA-026.md) |
| DIA-027 | pnpm audit 13 vulns (10 high)                                                                                       | deps            | Major    | FIXED  | [DIA-027.md](DIA-027.md) |
| DIA-028 | no pip-audit capability                                                                                             | deps            | Medium   | FIXED  | [DIA-028.md](DIA-028.md) |
| DIA-029 | no Python lockfiles                                                                                                 | deps            | Medium   | FIXED  | [DIA-029.md](DIA-029.md) |
| DIA-030 | unverified installs in Dockerfile.dev                                                                               | docker          | Medium   | OPEN   | [DIA-030.md](DIA-030.md) |
| DIA-031 | 5 API keys passed as container env (docker inspect leak)                                                            | docker          | Low      | FIXED  | [DIA-031.md](DIA-031.md) |
| DIA-032 | postgres default credential poetry                                                                                  | docker          | Low      | FIXED  | [DIA-032.md](DIA-032.md) |
| DIA-033 | 3 pre-existing hashtag test failures (test_unknown_hashtag, test_hashtag_with_digits, test_hashtag_with_underscore) | scripts         | Minor    | FIXED  | [DIA-033.md](DIA-033.md) |
| DIA-034 | pip-audit finding: apps/api-server ecdsa 0.19.2 PYSEC-2026-1325 (transitive via python-jose), NO fix version        | deps            | Medium   | OPEN   | [DIA-034.md](DIA-034.md) |
| DIA-035 | lint-staged ran bash -n on \*.{sh,bats} → any staged .bats failed pre-commit                                        | js-tooling      | Minor    | FIXED  | [DIA-035.md](DIA-035.md) |
| DIA-036 | Orchestrator operating model — read-restriction + session continuity + NEXT-RUN instruction                         | opencode-config | Minor    | FIXED  | [DIA-036.md](DIA-036.md) |

## Status summary

| Severity | Count |
| -------- | ----- |
| Blocker  | 1     |
| Critical | 1     |
| Major    | 9     |
| Medium   | 4     |
| Minor    | 19    |
| Low      | 2     |

| Status | Count |
| ------ | ----- |
| FIXED  | 25    |
| CLOSED | 6     |
| OPEN   | 5     |

## How to add a ticket

1. Copy `_TEMPLATE.md` → `DIA-<NNN>.md` (next sequential number).
2. Fill all fields; `Fix` and `Re-verify` stay blank with a "fill at fix time /
   re-verify time" note until the work happens.
3. Add a row to the index table above with matching Severity and Status.
4. Update the status summary counts.
