# 2026-09-03 - De-bloat gate research (DIA-260903-o7n0)

## Verdict
APPROVE the de-bloat plan as dispositioned. 4 corrections (C1-C4), 5 risks (R-A..R-E), zero blocking conflicts. 20 external sources.

## Key external patterns (with source URLs)
1. Bun test module registry: default `bun test` shares ONE module registry + global across all files; `mock.restore()` does NOT restore module mocks; per-file re-registration required. https://bun.sh/docs/test/mocks , https://bun.sh/docs/test/parallel
2. Test-helper extraction threshold: extract when 3+ files need identical setup; keep one-offs local; DAMP over DRY (duplication OK if it improves readability). https://testland.io/blog/pytest-fixtures-guide , https://testdino.com/blog/playwright-fixtures
3. Dead-code removal: static grep has a plugin/dynamic-dispatch blind spot (zero-caller grep LIES for plugin-registry-probed shapes); tombstone technique (log-on-hit, run suite, then delete) for large claims; separate PRs per removal type. https://docs.rhi.zone/normalize/workflows/dead-code-elimination.html , https://phpatscale.substack.com/p/php-at-scale-18
4. LOC-budget CI gates: report-only/neutral first, blocking after rules configured; grandfathered frozen-baseline ratchet (shrink-only anchor); test files excluded from prod limits; authorized override path. https://docs.sentry.io/product/size-analysis/integrating-into-ci/ , https://github.com/anthony-chaudhary/fak/blob/main/docs/explainers/god-file-growth-gate.md , https://github.com/n8n-io/n8n/blob/3f7258b1/.github/scripts/quality/check-pr-size.mjs

## Corrections (fold into implementation)
- C1: ".ts adds strip-types runtime dependency" is FALSE under Bun (plugin .mjs tests already import .ts). True reason for .mjs helpers: repo-wide node-runnable test convention (scripts/__tests__ run under plain node) + surface consistency. Keep .mjs; fix the rationale in ticket text.
- C2: helper file may import ONLY `mock` from bun:test - never `test`/`expect` - because harness-scenario files execute under `bun run`, not `bun test`.
- C3: mockOpencodePlugin() must be idempotent and callable multiple times per file (plugin-load-smoke.test.mjs re-registers per test).
- C4: createTempWorkspace should own ONE module-level temp-dir list + ONE process.on("exit") handler (21 files x 1 handler accumulates in one process under non-isolated bun test).

## Risks (carry into implementation)
- R-A: default bun test shares module registry process-wide; helpers MUST preserve per-file re-registration; do NOT register child_process mocks once globally (4 files use DIFFERENT spy shapes).
- R-B: budget-B grep-needle gate can false-pass if a reformatted mock block stops matching the literal needle; validate both directions during report-only window (real files pass; deliberately injected duplicate goes red).
- R-C: for R5 (normalizeGateArgs 44-LOC deletion) prefer tombstone (log-on-hit + suite + delete) over pure grep confidence.
- R-D: after E lands, annotate Wy guards with //keep: Wy loader contract so the next dead-code sweep does not re-flag them.
- R-E: post-D, re-run BOTH plugin gates (bats harness-scenario-replay AND bun test) before each of the four pattern commits.

## Source-gap note
ai-assist-sources.yaml has no Bun-testing-docs entry; recommend @resource-manager add bun.sh/docs/test/mocks + bun.sh/docs/test/parallel under tier2_volatile_web (non-blocking).
