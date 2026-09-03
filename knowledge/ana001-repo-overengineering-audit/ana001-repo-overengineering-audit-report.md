<!-- ANALYZER-OUTPUT-CONTRACT
schema-version: 1.0
agent: analyzer
claim-type: finding
evidence-source: /workspace (git ls-files whole-tree scan, session grep verification)
confidence: High
shelf-registration: memory-shelf.yaml (shelf.analyses), delegated to @memory-manager
-->

# ana001 - Repo-Wide Ponytail Over-Engineering Audit

Campaign ticket DIA-260825-wprb. Whole-tree scan of /workspace: apps/,
packages/, scripts/, tools/, .opencode/ plugins and scripts, knowledge/ code.
Skipped per rules: vendored code (.opencode/oh-my-opencode-slim has
REFERENCE-ONLY.md + own LICENSE + dist/), lockfiles, node_modules, .venv,
generated files (phonetics-core/src/atlas/generated/*,
scripts/generated/python/*), __pycache__.

Method: every finding verified by grep for callers/importers across all
non-vendored source before inclusion. No speculative findings.

## Findings (BIGGEST CUT FIRST)

- delete: run_phase_a.sh v1 superseded by run_phase_a_v2.sh in same folder; only reference is a historical mention in README-phase-a.txt. Keep v2 + report only. [knowledge/res012-scientific-methodology/run_phase_a.sh]
- delete: ChankManager.ts is 101 lines of entirely commented-out code; zero imports anywhere. Delete file. [packages/editor-engine/src/tokenizer/ChankManager.ts]
- delete: check-secrets-ownership.sh is called by nothing except its own bats test; not wired into any Makefile target, husky hook, pre-commit/pre-push, or compose flow. Wire it into verify-pre-commit or delete it. [scripts/check-secrets-ownership.sh]
- delete: data-contracts package has zero consumers - no TS or Python file imports @poetry/data-contracts despite 6 packages declaring it in package.json. Delete package (keep schemas/contract.json if the schema itself matters). [packages/data-contracts/]
- delete: errorMessage + safeJsonStringify duplicated verbatim across both plugins (~54 lines dup). Extract one shared module under .opencode/plugins/lib/. [.opencode/plugins/delegation-observer.ts:186-247 + .opencode/plugins/needs-input-observer.ts:200-265]
- delete: dead health-store module: HEALTH_PATH, readHealth, writeHealth, AgentHealth, HealthStore, _getAgentHealth, _setAgentHealth are referenced only by each other; health.json is never read or written by live code. [packages/../.opencode/plugins/delegation-observer.ts:827,1680-1721]
- delete: Quasar scaffold counter store; useCounterStore used only by its own scaffold test. [apps/author-studio/src/stores/example-store.ts + example-store.test.ts]
- delete: _selectAgentByPerformance + EXPLORATION_RATE explicitly commented "Available for future wiring"; never called. [packages/../.opencode/plugins/delegation-observer.ts:1732,1831-1845]
- delete: stress-lang-core package unconsumed: detectTokenLang throws "not implemented", no importer anywhere; author-studio declares the dep without importing it. Delete package until the W1 worker lands. [packages/stress-lang-core/]
- delete: publishing-platform app is an empty scaffold: package.json + README only, no src, no scripts, but it pulls 3 workspace deps into every install/lockfile resolution. Delete until the app exists. [apps/publishing-platform/]
- yagni: OpusState.getLineAt and moveLine have zero callers and zero test references. [packages/editor-engine/src/state/PoetryState.ts:16-19,39-43]
- stdlib: hand-rolled base64url encode/decode; Buffer.toString("base64url") and Buffer.from(x, "base64url") do both natively (Node >= 15). [packages/../.opencode/plugins/delegation-observer.ts:80-87,139]
- shrink: _save_kb_cache does tmp-write + unlink-if-exists + rename dance; os.replace() is atomic and overwrites, drops the unlink branch. [.opencode/scripts/query_rag.py:236-264]
- delete: four empty placeholder modules ("export {};") in analyzer/engine/memory dirs of phonetics-core; scaffolding for later, later can create its own files. [packages/phonetics-core/src/analyzer/debounce.ts, analyzer/patterns.ts, engine/ipa.ts, memory/ring-buffer.ts]
- yagni: LineAtom.revisionComputed computed() is constructed per line and read by nobody. [packages/editor-engine/src/state/atoms.ts:17,30]
- delete: _IDEMPOTENCY_CACHE_PATH constant defined, never used (cache is in-memory only). [packages/../.opencode/plugins/delegation-observer.ts:823]

## Dependency removals

Removable from apps/author-studio/package.json dependencies (declared, never imported by that app):
- signia (editor-engine keeps its own copy)
- @poetry/stress-lang-core
- @poetry/phonetics-core
- @poetry/data-contracts

Removable entirely with the package deletions above:
- @poetry/data-contracts (whole workspace package)
- @poetry/stress-lang-core (whole workspace package)

Note: visualizer-2d, visualizer-3d, editor-engine, phonetics-core also declare
@poetry/data-contracts in package.json without importing it; those entries go
too when the package is deleted (or immediately, as unused dep entries).

## Totals

- Net lines removable: ~671
  (191 + 101 + 62 + 73 + 54 + 55 + 48 + 20 + 24 + 15 + 8 + 7 + 5 + 4 + 3 + 1)
- Dependencies removable: @poetry/data-contracts, @poetry/stress-lang-core,
  plus 4 unused dep entries in apps/author-studio (signia,
  @poetry/stress-lang-core, @poetry/phonetics-core, @poetry/data-contracts)

## Not flagged (checked and found lean or deliberate)

- context7-docs.mjs hand-rolled YAML/semver parsing: documented ponytail-style
  tradeoff in-file ("dependency-free by design"), dev-triggered tool.
- ToolCircuitBreaker, adaptive routing state machine: live code paths, called
  from dispatch gates.
- errorMessage robustness ladder: DIA-098 audit-mandated behavior.
- oh-my-opencode-slim: vendored reference-only tree, out of scope.
- jsonl-stats / session-query / session-analytics: three readers but distinct
  formats and purposes (rollup vs SQL vs cost breakdown), each Makefile-wired.

## Addendum (2026-08-25, DIA-260825-wprb fix-all disposition)

- Finding 4 (data-contracts): **KEPT** per developer decision - the package
  is the architecture.md-declared schema seam (STATE: PoetryDataContract,
  Single Source of Truth); removal would delete a design-recorded boundary.
- Finding 7 (example-store): **KEPT** per developer sign-off; overrides the
  audit consensus. Recorded in the DIA-260825-aapj ticket UPDATE block;
  PONYTAIL-DEBT.md prior disposition stands.
