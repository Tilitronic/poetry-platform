# Tasks: dia-260909-zeik-scenario-cleanup-dedupe

Vertical slices; each ends green under the design.md section 7 gate for that slice. One implementation commit at the end (slices are work units, not commits). Exactly 4 implementation files across all slices (C1).

## 0. Pre-flight (no file edits)

- [x] 0.1 Container gate: `docker compose ps` shows `poetry-dev` Up; capture output as evidence (AGENTS.md 6 pre-work + merge-gate evidence convention).
- [x] 0.2 Baseline green: inside the container, `bun run` all three scenarios in `.opencode/plugins/__tests__/harness-scenarios/`; each exits 0. Record results.
- [x] 0.3 Confirm today's cleanup-site inventory matches the design (24 sites: 4 + 8 + 12) so the post-refactor grep diff in 4.3 has a baseline.

## 1. Slice 1: runner + scenario-1 (walking skeleton)

- [x] 1.1 Create `.opencode/plugins/__tests__/harness-scenarios/scenario-runner.mjs` per design.md section 2: single export `runScenario`, injected `fail`, module-private `ScenarioFailure`, one `try/finally` cleanup with the verbatim `[cleanup]` log line, `process.exit(code)`; error states per design.md section 3. No test-framework imports; no `mock.module` literal; <= 40 lines.
- [x] 1.2 Migrate `empty-result-silent-failure.scenario.mjs`: keep `mockOpencodePlugin()` + dynamic plugin import at module top (C4); wrap the body in `runScenario("c5-s1-", ...)`; replace 3 branch cleanup sites + trailing finally/exit(0) with `fail(...)` guards. Assertions, messages, and `readRegistry` stay behavior-identical.
- [x] 1.3 Verify: `bun run empty-result-silent-failure.scenario.mjs` exits 0. Negative probe (design.md 7.3a): temporarily flip one assertion -> exit 1, `FAIL:` line, no `c5-s1-*` dir left in /tmp; revert probe, re-run green. Record probe output as evidence.

## 2. Slice 2: scenario-2 migration

- [x] 2.1 Migrate `parallel-handoff-archive.scenario.mjs`: same pattern; 7 branches to `fail(...)`, 8 cleanup sites removed; `canonicalChecksum`/`readJson`/`writeTerminalHandoff` stay local (C8); UUID-pattern and checksum assertions untouched.
- [x] 2.2 Verify: `bun run parallel-handoff-archive.scenario.mjs` exits 0; unexpected-throw probe (design.md 7.3b): temporarily throw inside the body -> `ERROR:` line, exit 1, temp dir gone; revert, re-run green. Record evidence.

## 3. Slice 3: scenario-3 migration

- [x] 3.1 Migrate `slot-identity-no-clobber.scenario.mjs`: same pattern; 11 branches to `fail(...)`, 12 cleanup sites removed; per-scenario checksum/readJson helpers stay local (C8).
- [x] 3.2 Verify: all three scenarios exit 0 under `bun run`; unedited replay suite green: `make test-shell` (or run `scripts/__tests__/harness-scenario-replay.bats` directly on the host with Docker available) -> 3/3 pass.

## 4. Compliance gates (before commit)

- [x] 4.1 LOC delta: `git diff --stat` across the 4 files; measured net -88 (scenarios -124 plus runner +36), accepted as over-delivered de-bloat per developer disposition; no-pad rule cited (never padded to fit the -45..-70 estimate).
- [x] 4.2 Untouched-set check: `git status` / `git diff --name-only` shows no changes to `helpers/plugin-harness.mjs`, `harness-scenario-replay.bats`, `delegation-observer.ts`, `lib/*.ts`. Exactly 4 implementation files changed (C1); the one-line `scripts/budget-baselines.json` backing entry for OPEN DIA-260909-zeik is ruling-authorized (o7n0 campaign CLOSED).
- [x] 4.3 Budget-pattern + cap checks: the `mock.module("@opencode-ai/plugin"` literal appears only in `plugin-harness.mjs`; export counts: plugin-harness 4 (unchanged), scenario-runner 1.
- [x] 4.4 Commit (single, atomic): subject names `DIA-260909-zeik`; trailer `Budget-Scope: test-debloat` (backing: ruling-authorized test-debloat entry for OPEN DIA-260909-zeik). commit-msg hook `scripts/check-budget-gate.sh` passes; capture the `ok:` line as evidence.

## 5. Post-flight (evidence, outside the 4-file cap)

- [x] 5.1 Fill ticket DIA-260909-zeik Fix section: baseline/post `bun run` results, negative-probe outputs, bats 3/3, LOC delta, untouched-set proof, budget-gate `ok:` line.
- [x] 5.2 Review per AGENTS.md (reviewer lane; config-adjacent surface may route to ai-auditor at orchestrator discretion) and append the `.opencode/CHANGELOG.yaml` entry via `scripts/changelog-add --ticket DIA-260909-zeik`.
- [x] 5.3 Handoff: report spec paths + `openspec validate` exit code + verification evidence to the orchestrator.
