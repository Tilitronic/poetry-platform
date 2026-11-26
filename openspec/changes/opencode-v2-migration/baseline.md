# Baseline Measurement Record - opencode-v2-migration

Campaign ticket: DIA-261119-vioa
Date: 2026-11-19
Slice: S0
Purpose: record the gate-measurement baseline (feature worktree vs main worktree) for the opencode-v2 migration, plus configuration, runtime, cache, and container-engine state.

## 1. Git state

| Worktree                                    | Branch                              | HEAD     | Clean/dirty | Pre-existing dirty entries |
| ------------------------------------------- | ----------------------------------- | -------- | ----------- | -------------------------- |
| /workspace/.worktrees/opencode-v2 (feature) | feature/DIA-261112-exon-opencode-v2 | 9d58ec50 | clean       | 0                          |
| /workspace (main)                           | omo-slim-changes                    | 9d58ec50 | dirty       | 13                         |

Main worktree dirty-entry PATHS (from `git -C /workspace status --porcelain`, paths only, no diffs):

1. .opencode/learnings/index.md
2. .opencode/memory-shelf.yaml
3. Dockerfile.dev
4. docs/dev-infra-audit/tickets/DIA-260903-oj59-self-rerun-thresholds-60-primary-75-safety-net-new-default.md
5. docs/dev-infra-audit/tickets/README.md
6. .opencode/learnings/external-patterns/2026-11-12-dia-261112-exon-pin-divergences-and-install-block.md (untracked)
7. .opencode/learnings/external-patterns/2026-11-13-dia-261112-exon-dual-pin-model-and-red-baseline.md (untracked)
8. docs/dev-infra-audit/tickets/DIA-261110-03hs-update-docker-image-to-opencode-2-x-and-omo-slim-3-x.md (untracked)
9. knowledge/ana-261112-ibny-opencode-infra-keep-or-delete-matrix/ (untracked)
10. knowledge/res-261112-1ima-opencode-version-migration/ (untracked)
11. knowledge/res-261113-hi88-opencode-v2-native-capabilities/ (untracked)
12. openspec/changes/researcher-fetch-adapter-and-protected-path-gate/ (untracked)
13. Gorshhe: analyzer.md (untracked; non-ASCII filename shown as-is from git status quoting)

## 2. Baseline gate table (green vs red)

| Gate                                       | Feature worktree (A)                   | Main worktree (B)                                                                              |
| ------------------------------------------ | -------------------------------------- | ---------------------------------------------------------------------------------------------- |
| Aggregate config gate (`make test-config`) | EXIT 0, completes                      | EXIT 2, aborting at Makefile:267                                                               |
| Shell suite                                | EXIT 0 (bats plan 1..799, 0 failures)  | not measured in this slice                                                                     |
| Typecheck                                  | EXIT 0 (tsc 5.9.3 --noEmit clean)      | not measured in this slice                                                                     |
| Pin-parity gate                            | EXIT 0 (4 ok, 0 fail)                  | EXIT 1 - `fail: opencode - .mise.toml=1.18.32 Dockerfile.dev=2.2.6`                            |
| Version-sync gate                          | EXIT 0 (active pins aligned at 2.2.19) | EXIT 1 - `fail: OMO version drift: opencode.jsonc=2.2.19 tui.json=2.2.19 Dockerfile.dev=3.0.7` |

Per-step table - feature worktree, individual exit codes (all measured EXIT 0):

Prerequisite steps (Makefile):

| Makefile line | Step                                                                             | Exit |
| ------------- | -------------------------------------------------------------------------------- | ---- |
| 229           | test-interview: bash scripts/test-interview-enforcement.sh                       | 0    |
| 236           | test-skills: bash .opencode/scripts/validate-skills.sh                           | 0    |
| 312           | test-typecheck: npx --no-install tsc --noEmit -p .opencode/plugins/tsconfig.json | 0    |

Recipe-body steps (Makefile 265-307, 24 steps):

| Makefile line | Step                                                               | Exit |
| ------------- | ------------------------------------------------------------------ | ---- |
| 265           | echo NOTE: compose config validation is host-scoped                | 0    |
| 266           | bash .opencode/scripts/validate-opencode-config.sh                 | 0    |
| 267           | bash scripts/check-omo-version-sync.sh                             | 0    |
| 268           | bash scripts/validate-agent-names.sh                               | 0    |
| 269           | bash scripts/validate-output-contracts.sh                          | 0    |
| 270           | bash scripts/validate-reviewer-sections.sh                         | 0    |
| 271           | bash scripts/validate-decision-variants.sh                         | 0    |
| 272           | bash scripts/validate-grilling-gate.sh                             | 0    |
| 273           | bash scripts/check-orchestrator-prompt-drift.sh                    | 0    |
| 274           | bash scripts/validate-handoff.sh                                   | 0    |
| 275           | bash scripts/test-ticket-gate.sh                                   | 0    |
| 276           | bash scripts/test-builtin-containment.sh                           | 0    |
| 277           | bash scripts/validate-memory-shelf.sh                              | 0    |
| 278           | bash scripts/validate-changelog.sh                                 | 0    |
| 279           | bash scripts/validate-dia-mentions.sh                              | 0    |
| 280           | bash scripts/validate-model-ids.sh                                 | 0    |
| 281           | bash scripts/audit-agent-tool-coverage.sh .opencode/opencode.jsonc | 0    |
| 287           | node scripts/**tests**/batch-d-infra.test.mjs                      | 0    |
| 290           | node scripts/**tests**/routing-order-gate.test.mjs                 | 0    |
| 293           | node scripts/**tests**/envelope-gate.test.mjs                      | 0    |
| 298           | node scripts/**tests**/destination-policy.test.mjs                 | 0    |
| 299           | node scripts/**tests**/tripwire-classifier.test.mjs                | 0    |
| 304           | bash scripts/validate-observer-dedupe.sh                           | 0    |
| 307           | bash scripts/validate-plugin-structure.sh                          | 0    |

Separate aggregate rows:

| Item                    | Exit | Detail                       |
| ----------------------- | ---- | ---------------------------- |
| Shell suite (aggregate) | 0    | bats plan 1..799, 0 failures |
| Typecheck (aggregate)   | 0    | tsc 5.9.3 --noEmit clean     |

## 3. Root cause of the green/red difference

Both trees sit on the SAME commit 9d58ec50. Main carries ONE uncommitted pre-existing edit, visible in `git -C /workspace status --porcelain` as Dockerfile.dev - a dev-image build file change of 9 insertions and 24 deletions, and it is nobody's campaign work. The version-pin file is byte-identical in both trees and is not the cause. After normalizing path prefixes the two gate logs are identical through line 83; the first semantic divergence is line 84: the feature worktree passes with `ok: active OMO pins aligned at 2.2.19`, while main fails with the OMO version drift line above. The feature worktree at /workspace/.worktrees/opencode-v2 is the campaign measurement baseline; main's red state comes from a pre-existing uncommitted edit owned by nobody in this campaign.

## 4. Configuration-surface inventory (names only, no contents)

Repository root layer (configuration files):

- AGENTS.md
- CONTEXT.md
- architecture.md
- Makefile
- package.json
- pnpm-workspace.yaml
- pnpm-lock.yaml
- bun.lock
- tsconfig.json
- pyrightconfig.json
- turbo.json
- eslint.base.config.js
- eslint.config.js
- docker-compose.yml
- docker-compose.podman.yml
- docker-compose.rootless-docker.yml
- docker-compose.wsl.yml
- Dockerfile.dev
- dev-entrypoint.sh

Project agent-config directory: `.opencode/`

Top-level files (11):

- CHANGELOG.md
- CHANGELOG.yaml
- memory-shelf.yaml
- oh-my-opencode-slim.jsonc
- opencode-overnight.jsonc
- opencode.jsonc
- package-lock.json
- package.json
- practice-protected.md
- promo-registry.json
- tui.json

Top-level file count: 11 (plus 12 top-level subdirectories).

## 5. V1 binary and mise state

- V1 runtime: opencode version 1.18.32 resolved through a mise shim.
- The global CLI package is absent.

## 6. Cache / data directory inventory (visible here)

| Directory                                                   | Entry count |
| ----------------------------------------------------------- | ----------- |
| .opencode/session (boot.json, registry.jsonl, registry.seq) | 3           |
| knowledge/                                                  | 97          |
| secrets/                                                    | 1           |
| scripts/**pycache**                                         | 1           |
| /home/dev/.cache/opencode                                   | 6           |
| /home/dev/.local/share/opencode                             | 284         |

## 7. Container-engine state

UNVERIFIED - not reachable inside the dev container. No engine probe was run from this lane.

Host-side probes pending (to be run on the host, not inside the container):

1. Volume state for the dev cache/state volumes: inspect named volumes `dev_cache` and `dev_state` (declared in docker-compose.yml `volumes:` block; siblings `pgdata`, `pnpm_store` for context).
2. Image ids: list the built dev/postgres image ids and digests.
3. Current service definitions: enumerate running services and their compose-defined definitions (`dev`, `postgres`).
4. Host-scoped compose config check: `make check-compose-config` (PHASE 5 / T12.4 - runs host-side via verify-pre-push.sh, removed from in-container test-config).

## 8. ADR preconditions and branch/path exception

ADR preconditions:

- ADR 11 amended at .sdd/dev-infra/architecture.md:94.
- ADR 15 new at .sdd/dev-infra/architecture.md:139.
- Both committed as 9d58ec50.

Branch/path exception:

- Branch name feature/DIA-261112-exon-opencode-v2 is ADR 2 compliant.
- The direct worktree add at .worktrees/opencode-v2 is the documented path-only exception to scripts/worktrees.sh.
- .worktrees/opencode-v2-analytics must be created from the MAIN worktree per DIA-202 and never nested.
- Husky shim: 17 files under the worktree's .husky/\_ (ADR 9 copy, matching main's 17).

## 9. C1 status

C1 (baseline certainty): CLOSED.

Caveats: the campaign baseline is the feature worktree (/workspace/.worktrees/opencode-v2, green on all measured gates); main stays red from a pre-existing unrelated edit (Dockerfile.dev, uncommitted, owned by nobody in this campaign); container-engine items remain unverified pending host probes (section 7).
