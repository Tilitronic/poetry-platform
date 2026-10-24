# Repo-wide over-engineering audit: tree + open-ticket execution map

<!-- ANALYZER-OUTPUT-CONTRACT
schema-version: 1.0
agent: analyzer
claim-type: recommendation
evidence-source: /workspace (git ls-files @ DIA-261022-5n2v)
confidence: High
shelf-registration: memory-shelf.yaml (shelf.analyses), delegated to memory-manager
-->

Campaign ticket: DIA-261022-5n2v. Method: `ponytail-audit` skill over the whole
tracked tree (not a diff). Over-engineering only: no correctness, security,
test-gap or style findings are reported here. Every `delete`/`yagni` finding was
verified caller-free with `rg` across the tree; every `stdlib`/`native` finding
names the exact library/platform feature.

Scope notes: `node_modules`, `.git`, build output, `knowledge/` prose and
`openspec/changes/archive/` excluded as instructed. One tracked *vendored
checkout* (`.opencode/oh-my-opencode-slim/`) is reported because it lives in the
tree and declares itself reference-only; it is the only vendor-shaped item in
scope. Prose comment blocks were not counted as removable lines (only code and
tracked-artifact lines are counted), which makes every number below conservative.

## Findings (ranked: biggest removable cut first)

delete: the vendored reference-only OMO upstream checkout: `src/` (275 files, 73076 lines), `companion/` (Rust, 2363 lines + 4433-line Cargo.lock), `docs/` (4663), `scripts/` (621), `.agents/skills/cli-review` (94), `img/` + `companion/animations` (21 MB), the three translated READMEs and README/AGENTS/codemap (3613), and the build scaffolding (package.json, tsconfig, biome, bunfig, bun.lock) that builds a tree nothing loads. Keep only the 5 live prompt-override files (`coder.md`, `coder_append.md`, `reviewer.md`, `analyzer_append.md`, `orchestrator_append.md`), `knowledge/` (2 files) and `REFERENCE-ONLY.md`; drop `make test-omo` + `scripts/test-omo.sh` (32) with it -- upstream CI owns that suite. [.opencode/oh-my-opencode-slim/**]

delete: the entire dead phonetic-atlas loader chain -- `load-atlas.ts` (339) + its test (348), `load_atlas.py` (336) + `test_load_atlas.py` (250) + `test_parity.py` (136) + `test_import.py` (29), both generated binding trees (889 TS + 600 Python), `codegen.js` (103), `parity_dump.mjs` (65), and the byte-identical `dist/phonetic_atlas.bin` (sha256 7e59bf37... equal to the src copy). Keep `phonetic_atlas.fbs`, `generate_phonetic_atlas.py` and one `.bin`; regenerate bindings with `flatc --ts` when W1/W2 actually land. [packages/phonetics-core/src/atlas/**, packages/phonetics-core/scripts/**, packages/phonetics-core/tests/**]

shrink: replace the 718-line commit-trailer budget gate + its 857 lines of bats (budget-gate.bats 608, budget-gate-range-exemption.bats 249) with a ~30-line check that compares `wc -l` on the plugin tree against the two numbers already in `scripts/budget-baselines.json` (prod_ceiling 5900, shell_ceiling 4037) and drops the `Budget-Scope`/`Budget-Exception` trailer protocol, the campaign-allowlist JSON and the one-pattern duplication detector (canonical string is already enforced by code review). [scripts/check-budget-gate.sh, scripts/__tests__/budget-gate.bats, scripts/__tests__/budget-gate-range-exemption.bats, scripts/budget-baselines.json]

delete: the committed derived changelog view -- `changelog-render` (137) and `.opencode/CHANGELOG.md` (1321 lines regenerated from the YAML on every append); keep `CHANGELOG.yaml` + `validate-changelog.sh` as the single source of truth and read it with the existing per-DIA `python3 -c "import yaml..."` query already documented in AGENTS.md 2.5 step 7. [scripts/changelog-render, .opencode/CHANGELOG.md, scripts/changelog-add:96-103]

delete: the ticket-ledger README index and all machinery that keeps it in sync -- `rollup` subcommand + count tables + index-row insert + column-width padding (`scripts/tickets:301-764`, ~464 lines, plus ~56 README lines inside `cmd_new`), and the 422-line generated `README.md`. Replacement: `scripts/tickets list|frontier|stats` already derive every view live from ticket frontmatter, and AGENTS.md itself says the README is a drifting snapshot not to be trusted. [scripts/tickets, docs/dev-infra-audit/tickets/README.md, scripts/__tests__/tickets.bats]

delete: `query_web.py` (290) + `test_query_web.py` (528) -- no skill, agent, Makefile target or script invokes it; the researcher lane already uses the platform's native `websearch` tool. Replacement: native `websearch`/`webfetch`. [.opencode/scripts/query_web.py, .opencode/scripts/test_query_web.py]

shrink: collapse the 8 `opsx-*.md` command files (843 lines) that restate the `openspec-*` skills step-by-step into 5-line stubs that say "load and follow the openspec-<verb> skill", so the workflow lives in exactly one place. [.opencode/commands/opsx-apply.md, opsx-archive.md, opsx-continue.md, opsx-explore.md, opsx-new.md, opsx-propose.md, opsx-sync.md, opsx-update.md]

delete: two duplicate JSONL session readers -- `scripts/session-log` (220; its own header admits `stats` mirrors `.opencode/scripts/jsonl-stats.sh`) and `.opencode/scripts/jsonl-stats.sh` (131). Replacement: `make session-query ARGS="--count-by status"` (scripts/session-query.mjs, node:sqlite, already covers every rollup) plus the existing `make session-log-render` if a markdown view is still wanted. [scripts/session-log, .opencode/scripts/jsonl-stats.sh, Makefile:317-318]

shrink: nine copies of the same ~35-line JSONC comment/trailing-comma stripper (7 Python, 2 Node) -- keep one (`scripts/jsonc_strip.py` or the existing `node .opencode/scripts/lib/jsonc-parse.js <file>` CLI) and import/call it; delete the inline copies and their per-copy tests. [scripts/jsonc_strip.py, scripts/validate-agent-names.sh:122, scripts/audit-agent-tool-coverage.sh:93, scripts/test-interview-enforcement.sh:38, scripts/test-builtin-containment.sh:44, scripts/check-orchestrator-prompt-drift.sh:105, .opencode/scripts/validate-skills.sh:377, .opencode/scripts/lib/jsonc-parse.js:16, scripts/validate-observer-dedupe.sh:12]

delete: Quasar starter demo residue + the whole i18n stack that localizes zero strings -- `ExampleComponent.vue` (37), `EssentialLink.vue` (27, imported by nothing), `models.ts` (8), the demo body of `IndexPage.vue` (26 -> 0: `/` renders MainLayout, whose `q-page-container` already hosts the editor), `boot/i18n.ts` (31), `src/i18n/` (12), and the `@intlify/unplugin-vue-i18n` block in `quasar.config.ts` (zero `$t(`/`useI18n` usages repo-wide). [apps/author-studio/src/components/, apps/author-studio/src/pages/IndexPage.vue, apps/author-studio/src/boot/i18n.ts, apps/author-studio/src/i18n/, apps/author-studio/quasar.config.ts:67,79]

shrink: `validate-plugin-structure.sh` Gate B/C are name blocklists (`MY_FORMATTER`, `getStallMinutes`, `requireAny`, removed-alias list) that only catch the exact spellings someone guessed; keep Gate A (production importer + symbol-use check, ~40 lines) and delete ~90 lines of heuristics -- the TypeScript compiler and `noUnusedLocals` already catch unused exports. [scripts/validate-plugin-structure.sh]

delete: `PUNCTUATION` (78 lines, eng/pol/ukr tables) and the `'typographical'` member of `TokenType` -- neither is ever read: `tokenize()` uses `TOKEN_RE` only and never emits `typographical`. [packages/editor-engine/src/tokenizer/tokenizer.ts:1,24-101]

delete: `CommandBus` (41) plus the sole producer that pushes `execute: () => {}` and its export -- a priority queue, timestamp sort and async flush loop whose only job is running an empty function. Replacement: nothing; a real async pipeline is a 10-line promise chain when one is needed. [packages/editor-engine/src/orchestrator/command-bus.ts, packages/editor-engine/src/view/opusDecorator.ts:36-40, packages/editor-engine/src/index.ts:2]

delete: `scripts/promo-preset-apply` (51) -- a self-declared retired no-op kept only so old `--dry-run/--config` invocations do not exit 2; nothing in the repo calls it (only CHANGELOG history does). Replacement: nothing; delete the file (and `.opencode/promo-registry.json`, 91 lines, which no longer has a reader). [scripts/promo-preset-apply, .opencode/promo-registry.json]

shrink: two copies of the same `/run/secrets` loader and 5-name whitelist (`dev-entrypoint.sh:15-40` and `scripts/dev-secrets-profile.sh`, whose header says the whitelist MUST mirror the entrypoint); source one shared function from both. [dev-entrypoint.sh, scripts/dev-secrets-profile.sh]

delete: docstring-only placeholder modules -- `packages/analytics-pipeline/src/{core/numpy_calc.py,daemon/cron.py,db/uow.py}` (3 lines each, zero code) and `apps/api-server/app/{core/auth.py,db/postgres.py}` (3 lines each); the import-pinning tests that guard the PEP 420 layout stay. [packages/analytics-pipeline/src/, apps/api-server/app/]

## Open-ticket execution map (findings the ledger already owns)

| Finding (rank) | OPEN ticket | Status note |
| --- | --- | --- |
| 1 vendored OMO tree | DIA-260827-15xv, DIA-260825-wprb | never actioned; needs a decision, not new analysis |
| 2 phonetics dead chain | DIA-260831-r7s8, DIA-260831-t9u0, DIA-260831-v1w2 | sibling atlas tickets; the deletion itself has no ticket |
| 3 budget gate | DIA-260903-o7n0 (campaign) | gate was built for this campaign; retiring it is a scope decision |
| 4 CHANGELOG.md | none | new |
| 5 tickets README index | none (DIA-229 covers `new` only) | new |
| 6 query_web | DIA-260827-nza6 | that ticket asks to gate these tests; deleting them closes it |
| 7 opsx commands | DIA-260827-6g6r | same surface, adjacent problem |
| 8 session readers | DIA-260916-z5pf | that ticket optimizes the cross-check, not deletes the duplicates |
| 9 JSONC strippers | none | new |
| 10 Quasar demo + i18n | DIA-260831-z5a6 | exactly this finding, still OPEN |
| 11 plugin-structure gate | DIA-260827-gnrr | same class (gates asserting source text) |
| 12 tokenizer tables | DIA-260831-f1g2 | still OPEN |
| 13 CommandBus | DIA-260831-d9e0 | still OPEN |
| 14 promo no-op | none | new |
| 15 secret loader | none | new |
| 16 stub modules | none | new |

## Summary

NET_LINES_REMOVABLE: 94169
DEPENDENCIES_REMOVABLE: vue-i18n, @intlify/unplugin-vue-i18n, flatbuffers, fast-check, @fast-check/vitest

## Independent verification (3 lenses) - corrections

1. P1: "a tree nothing loads" is stale - the tree root now carries package.json, dist/ and node_modules; prompt discovery is a filename convention (src/config/loader.ts:43,359-374) with no manifest; knowledge/ is live via .opencode/opencode.jsonc:543-555 and agent prompts, not via the loader; the vendored copy is 2.2.11 while the loaded npm plugin is pinned at 2.2.19 (.opencode/opencode.jsonc:769), so make test-omo has been green-testing undeployed code.
2. P2: the proposed keep-set self-breaks - packages/phonetics-core/package.json:6-27 makes src/atlas/load-atlas.ts the package main/types/exports; packages/editor-engine/package.json:20 + tsconfig.json:6 depend on it; scripts/gen-jsconfig.sh:119 hard-errors inside make test-infra on a missing declared entry; the kept scripts/generate_phonetic_atlas.py:138-139,323-330,485-494 imports the very generated Python bindings the proposal deletes (plus flatbuffers/pandas/panphon); deleting all tests leaves pytest collecting zero (Makefile:215); the two .bin copies are not redundant (package.json:23-24 vs load_atlas.py:331 vs turbo.json:10 vs .gitignore:13); test_parity.py/test_load_atlas.py are the only FlatBuffers schema-drift guard.
3. P3: the baselines are stale - live prod 7,537 vs ceiling 5,900 and shell 4,148 vs 4,037, so the proposed ~30-line compare would fail immediately and, because .husky/commit-msg:5 runs the gate on every commit and scripts/verify-pre-push.sh:120 runs --range, it would block every commit repo-wide; the proposal also drops the opencode-mock duplication detector and the fail-closed backing check.
4. P4: contradicts a recorded decision - DIA-194 evaluated and REJECTED "retire the MD view" (EBDV Variant C), see .opencode/learnings/external-patterns/2026-08-28-dia194-changelog-yaml-ledger-already-complete.md:1; scripts/changelog-add:103 renders unconditionally.
5. P5: the replacement covers READS only - scripts/tickets:849,878,969-981 (cmd_new) and :1931-1943 (cmd_update) hard-require docs/dev-infra-audit/tickets/README.md, and `scripts/tickets new` is the literal DIA-217 carve-out; the README was deliberately kept hours ago.
6. P8: the named replacement (make session-log-render) IS one of the two deletion targets (Makefile:329-330 -> bash scripts/session-log render); and .opencode/scripts/jsonl-stats.sh:69-128 implements the A3 dangling-delegation and C3 orphan-dispatch detectors over the append-only registry, which scripts/session-query.mjs cannot express.
7. P9: twelve copies, not nine, with deliberate semantic divergence - one is runtime plugin code (.opencode/plugins/preset-model-guard.ts:73), one is frozen by openspec/changes/test-suite-audit-fixes/design.md:57, one import shape is pinned by scripts/__tests__/workspace-preset-selection.bats:69.
8. P10: the report missed apps/author-studio/quasar.config.ts:15 boot: ['i18n'] (boot sequence) and that IndexPage.vue is the routed child of / (routes.ts:6-7), so it cannot become zero lines; flatbuffers and fast-check belong to packages/phonetics-core, not the app; @fast-check/vitest has zero importers anywhere.
9. Status claims are stale: the campaign tickets behind ranks 1 and 3 are CLOSED today, and the two duplicate whole-repo audit tickets (DIA-260827-15xv, DIA-260825-wprb) were closed as superseded by DIA-261022-5n2v.
10. Honest net: about 89,830 lines and 3 dependencies (vue-i18n, @intlify/unplugin-vue-i18n, @fast-check/vitest) - of which ~88,880 is P1 alone. The headline 94,169 is essentially one decision, not ten.

Verdicts: SAFE 1 (P6); SAFE_WITH_SEQUENCE 3 (P1, P7-partial, P10); UNSAFE_AS_SPECIFIED 4 (P2, P3, P5, P8); NOT_WORTH_IT 2 (P4, P9).
